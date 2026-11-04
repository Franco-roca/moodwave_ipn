import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moodwave/features/records/domain/record.dart';
import 'package:moodwave/features/health/domain/daily_health.dart';
import 'package:moodwave/features/analytics/domain/analytics.dart';
import 'package:moodwave/features/reports/domain/report_data.dart';
import 'package:moodwave/features/reports/domain/pdf_report_service.dart';
import 'package:moodwave/features/records/domain/synthetic_data_generator.dart';
import 'package:moodwave/features/prediction/domain/learning.dart';
import 'package:moodwave/features/prediction/data/model_repository.dart';

void main() {
  late Uint8List regularFont, boldFont;
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    regularFont = await File('assets/fonts/Roboto-Regular.ttf').readAsBytes();
    boldFont = await File('assets/fonts/Roboto-Bold.ttf').readAsBytes();
  });
  Future<ReportPdf> generate(MoodWaveReportData data) => PdfReportService()
      .generate(data, regularFont: regularFont, boldFont: boldFont);
  final now = DateTime(2026, 10, 30, 12),
      span = DateSpan(DateTime(2026, 10, 1), DateTime(2026, 11, 1));
  final records = [
    for (var i = 1; i <= 24; i++)
      Record(
        date: DateTime(2026, 10, i),
        mood: Mood.values[i % 8],
        energy: i % 10 + 1,
        activities: [i.isEven ? 'Ejercicio' : 'Trabajo', 'Familia'],
        reflection: 'Reflexión privada: un día con alegría 😄',
      ),
  ];
  final health = [
    for (var i = 1; i <= 24; i++)
      DailyHealthData(
        date: DateTime(2026, 10, i),
        sleepMinutes: i.isEven ? 480 : 330,
        steps: i.isEven ? 9000 : 1500,
      ),
  ];
  test('Modelo del reporte filtra y redacta reflexiones por defecto', () {
    final data = ReportDataService().build(
      records: records,
      health: health,
      span: span,
      now: now,
      monthly: true,
    );
    expect(data.records.length, 24);
    expect(data.records.every((r) => r.reflection.isEmpty), isTrue);
    expect(data.health.pairedDays, 24);
    expect(data.generatedAt, now);
  });
  test('Exclusión explícita de salud y elección de reflexiones', () {
    final data = ReportDataService().build(
      records: records,
      health: health,
      span: span,
      now: now,
      monthly: true,
      includeHealth: false,
      includeReflections: true,
    );
    expect(data.health.pairedDays, 0);
    expect(data.records.first.reflection, contains('privada'));
  });
  test('PDF no vacío sin datos físicos', () async {
    final data = ReportDataService().build(
      records: records,
      health: [],
      span: span,
      now: now,
      monthly: true,
      includeHealth: false,
    );
    final pdf = await generate(data);
    expect(ascii.decode(pdf.bytes.take(4).toList()), '%PDF');
    expect(pdf.bytes.length, greaterThan(1000));
    expect(pdf.pageCount, greaterThanOrEqualTo(2));
  });
  test('PDF completo con salud, acentos e indicadores vectoriales', () async {
    final data = ReportDataService().build(
      records: records,
      health: health,
      span: span,
      now: now,
      monthly: true,
      version: '1.0.0-trial',
    );
    final pdf = await generate(data);
    expect(pdf.pageCount, greaterThanOrEqualTo(3));
    expect(pdf.bytes.length, greaterThan(1000));
    if (const bool.fromEnvironment('GENERATE_SAMPLE')) {
      await Directory('output/pdf').create(recursive: true);
      await File('output/pdf/moodwave-demo.pdf').writeAsBytes(pdf.bytes);
    }
  });
  test('PDF semanal vacío no fabrica valores', () async {
    final data = ReportDataService().build(
      records: [],
      health: [],
      span: DateSpan.forPeriod(AnalyticsPeriod.week, now),
      now: now,
      monthly: false,
    );
    expect(data.summary.best, isNull);
    expect(data.health.sleepAverage, isNull);
    expect((await generate(data)).bytes, isNotEmpty);
  });
  test('Texto PDF reemplaza emojis sin cuadros rotos', () {
    expect(pdfText('Sueño, emoción, energía 😄'), contains('[símbolo]'));
    expect(pdfText('México − 7–9'), 'México - 7-9');
  });
  test('Predicción requiere opt-in y agrega evaluación real al PDF', () async {
    final days = SyntheticDataGenerator().generate(now);
    final rs = days.map((d) => d.record).toList(),
        hs = days.map((d) => d.health).toList();
    final model = MoodPredictionService()
        .train(observationsFrom(rs, hs, synthetic: true), now)
        .model!;
    final excluded = ReportDataService().build(
      records: rs,
      health: hs,
      span: span,
      now: now,
      monthly: true,
      model: model,
    );
    expect(excluded.model, isNull);
    expect(excluded.prediction, isNull);
    final included = ReportDataService().build(
      records: rs,
      health: hs,
      span: span,
      now: now,
      monthly: true,
      model: model,
      includePrediction: true,
    );
    expect(included.prediction, isNotNull);
    expect(included.model!.metrics.count, 17);
    expect((await generate(included)).pageCount, greaterThanOrEqualTo(4));
  });
}
