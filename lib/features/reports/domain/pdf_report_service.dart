import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../analytics/domain/analytics.dart';
import '../../records/domain/record.dart';
import 'report_data.dart';

class ReportPdf {
  const ReportPdf(this.bytes, this.pageCount);
  final Uint8List bytes;
  final int pageCount;
}

Future<ReportPdf> renderReport(
  ({MoodWaveReportData data, Uint8List regular, Uint8List bold}) work,
) async {
  await initializeDateFormatting('es_MX');
  return PdfReportService().generate(
    work.data,
    regularFont: work.regular,
    boldFont: work.bold,
  );
}

String pdfText(String text) => text
    .replaceAll('−', '-')
    .replaceAll('–', '-')
    .replaceAll('—', '-')
    .replaceAll('…', '...')
    .runes
    .map((c) => c <= 255 ? String.fromCharCode(c) : '[símbolo]')
    .join();

class PdfReportService {
  static const teal = PdfColor.fromInt(0xff075e62),
      pale = PdfColor.fromInt(0xffeaf5f2);
  Future<ReportPdf> generate(
    MoodWaveReportData data, {
    required Uint8List regularFont,
    required Uint8List boldFont,
  }) async {
    final document = pw.Document(
      title: data.title,
      author: 'MoodWave',
      subject: 'Diario emocional local',
    );
    final date = DateFormat('d MMM yyyy', 'es_MX');
    pw.Widget text(
      String value, {
      double size = 11,
      bool bold = false,
      PdfColor? color,
    }) => pw.Text(
      pdfText(value),
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    );
    pw.Widget heading(String title) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 10),
      child: text(title, size: 17, bold: true, color: teal),
    );
    pw.Widget box(String label, String value) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: pale,
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            text(value, size: 21, bold: true, color: teal),
            pw.SizedBox(height: 6),
            text(label, size: 10),
          ],
        ),
      ),
    );
    pw.Widget table(List<String> headers, List<List<String>> rows) =>
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows.map((r) => r.map(pdfText).toList()).toList(),
          headerStyle: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(color: teal),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellPadding: const pw.EdgeInsets.all(6),
          border: null,
          oddRowDecoration: const pw.BoxDecoration(color: pale),
        );
    pw.Widget healthTable(String title, List<HealthBucket> groups) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        heading(title),
        table(
          ['Rango', 'Días', 'Ánimo /8', 'Energía /10'],
          [
            for (final g in groups)
              [
                g.label,
                '${g.count}',
                g.moodAverage?.toStringAsFixed(1) ?? 'Sin datos',
                g.energyAverage?.toStringAsFixed(1) ?? 'Sin datos',
              ],
          ],
        ),
        pw.SizedBox(height: 8),
        ...groups
            .where((g) => g.count > 0)
            .map(
              (g) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  children: [
                    pw.SizedBox(width: 120, child: text(g.label, size: 9)),
                    pw.Container(
                      width: 240 * (g.moodAverage! - 1) / 7,
                      height: 9,
                      color: teal,
                    ),
                    pw.SizedBox(width: 8),
                    text(
                      '${g.moodAverage!.toStringAsFixed(1)} · n=${g.count}',
                      size: 9,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
    final s = data.summary;
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        maxPages: 100,
        theme: pw.ThemeData.withFont(
          base: pw.Font.ttf(ByteData.sublistView(regularFont)),
          bold: pw.Font.ttf(ByteData.sublistView(boldFont)),
        ),
        header: (c) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            text('MOODWAVE', size: 10, bold: true, color: teal),
            text('Tu historia, a tu ritmo', size: 9),
          ],
        ),
        footer: (c) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
          ),
          child: pw.Column(
            children: [
              text(
                'Generado ${date.format(data.generatedAt)} · ${c.pageNumber}/${c.pagesCount} · Datos personales: comparte solo si lo deseas.',
                size: 8,
              ),
              pw.SizedBox(height: 3),
              text(
                'MoodWave no realiza diagnósticos médicos ni sustituye atención profesional.',
                size: 8,
              ),
            ],
          ),
        ),
        build: (c) => [
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(22),
            decoration: pw.BoxDecoration(
              color: teal,
              borderRadius: pw.BorderRadius.circular(18),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                text(data.title, size: 25, bold: true, color: PdfColors.white),
                pw.SizedBox(height: 12),
                text(
                  '${date.format(data.span.start)} - ${date.format(shiftDay(data.span.end, -1))}',
                  color: PdfColors.white,
                ),
                pw.SizedBox(height: 12),
                pw.CustomPaint(
                  size: const PdfPoint(420, 14),
                  painter: (canvas, size) {
                    canvas
                      ..setStrokeColor(const PdfColor(.4, .75, .7))
                      ..setLineWidth(2)
                      ..moveTo(0, 7)
                      ..curveTo(100, 24, 180, -10, 260, 7)
                      ..curveTo(330, 20, 360, 0, 420, 8)
                      ..strokePath();
                  },
                ),
              ],
            ),
          ),
          heading('Tu periodo de un vistazo'),
          pw.Row(
            children: [
              box(
                'Ánimo sobre 8',
                s.records.isEmpty
                    ? 'Sin datos'
                    : s.moodAverage.toStringAsFixed(1),
              ),
              box(
                'Energía sobre 10',
                s.records.isEmpty
                    ? 'Sin datos'
                    : s.energyAverage.toStringAsFixed(1),
              ),
              box('Días registrados', '${s.records.length}/${data.span.days}'),
            ],
          ),
          heading('Lo que aparece en tus registros'),
          text(
            'n=${s.count} · Media ${s.count == 0 ? 'Sin datos' : s.moodAverage.toStringAsFixed(2)} · Mediana ${s.median?.toStringAsFixed(2) ?? 'Sin datos'} · Desviación poblacional ${s.populationStd?.toStringAsFixed(2) ?? 'Sin datos'}',
            size: 10,
          ),
          pw.SizedBox(height: 6),
          text(
            'Moda${s.modes.length > 1 ? 's empatadas' : ''}: ${s.modes.isEmpty ? 'Sin datos' : s.modes.map((m) => m.name).join(', ')}',
          ),
          pw.SizedBox(height: 8),
          text(
            'Mejor día: ${s.best == null ? 'Sin datos suficientes' : '${date.format(s.best!.date)} · ${s.best!.mood.name} · Energía ${s.best!.energy}/10'}',
          ),
          pw.SizedBox(height: 8),
          text(
            'Racha al cierre del periodo: ${s.currentStreak(shiftDay(data.span.end, -1))} días · Mejor racha del periodo: ${s.bestStreak} días',
          ),
          heading('Tendencia del ánimo'),
          text(
            'Racha actual global: ${data.currentStreak} días · Mejor racha histórica: ${data.bestHistoricalStreak} días',
            size: 10,
          ),
          text(data.trend.label),
          pw.SizedBox(height: 6),
          text(
            'Periodo reciente: ${data.trend.recent?.toStringAsFixed(1) ?? 'Sin datos'} (${data.trend.recentCount} registros). Anterior: ${data.trend.previous?.toStringAsFixed(1) ?? 'Sin datos'} (${data.trend.previousCount} registros).',
          ),
          if (data.trend.direction != TrendDirection.insufficient)
            text(
              'Diferencia: ${signed(data.trend.difference!)} puntos. Comparación de ${data.span.days == 7 ? 7 : 30} días frente a los anteriores.',
            ),
          pw.SizedBox(height: 16),
          text(
            'Las asociaciones describen estos datos personales; no prueban causalidad. Una actividad puede coincidir con muchas otras circunstancias.',
          ),
          pw.SizedBox(height: 16),
          text(
            'Privacidad: sin PIN, hash, salt ni datos biométricos. Reflexiones ${data.includeReflections ? 'incluidas por elección explícita' : 'excluidas'}. Versión ${data.version}.',
            size: 9,
          ),
          pw.NewPage(),
          heading('Evolución emocional'),
          text(
            'Escala 1-8. Los huecos corresponden a días sin registro. Línea de referencia: media del periodo.',
            size: 10,
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.SizedBox(
                width: 18,
                height: 120,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [for (var v = 8; v >= 1; v--) text('$v', size: 8)],
                ),
              ),
              pw.CustomPaint(
                size: const PdfPoint(490, 120),
                painter: (canvas, size) {
                  canvas
                    ..setStrokeColor(PdfColors.grey400)
                    ..setLineWidth(.5);
                  for (var y = 1; y <= 8; y++) {
                    final py = (y - 1) / 7 * 110;
                    canvas
                      ..moveTo(0, py)
                      ..lineTo(490, py)
                      ..strokePath();
                  }
                  if (s.records.isNotEmpty) {
                    final average = (s.moodAverage - 1) / 7 * 110;
                    canvas
                      ..setStrokeColor(const PdfColor.fromInt(0xff8a6a24))
                      ..setLineWidth(1.2)
                      ..moveTo(0, average)
                      ..lineTo(490, average)
                      ..strokePath();
                  }
                  final points = TrendAnalysisService().points(
                    data.records,
                    data.span,
                  );
                  PdfPoint? previous;
                  for (var i = 0; i < points.length; i++) {
                    final r = points[i].record;
                    if (r == null) {
                      previous = null;
                      continue;
                    }
                    final p = PdfPoint(
                      i / (points.length <= 1 ? 1 : points.length - 1) * 490,
                      (r.mood.value - 1) / 7 * 110,
                    );
                    canvas
                      ..setStrokeColor(teal)
                      ..setFillColor(teal)
                      ..setLineWidth(2);
                    if (previous != null) {
                      canvas
                        ..moveTo(previous.x, previous.y)
                        ..lineTo(p.x, p.y)
                        ..strokePath();
                    }
                    canvas
                      ..drawEllipse(p.x, p.y, 2.5, 2.5)
                      ..fillPath();
                    previous = p;
                  }
                },
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.SizedBox(
            width: 508,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                text(date.format(data.span.start), size: 9),
                text(date.format(shiftDay(data.span.end, -1)), size: 9),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          text(
            s.records.isEmpty
                ? 'Sin media disponible'
                : 'Referencia: media ${s.moodAverage.toStringAsFixed(1)}/8',
            size: 9,
          ),
          heading('Tus actividades'),
          if (data.activities.isEmpty)
            text('Sin actividades registradas.')
          else
            table(
              [
                'Actividad',
                'Registros',
                'Ánimo /8',
                'Energía /10',
                'Dif. ánimo',
              ],
              [
                for (final a in data.activities)
                  [
                    a.name,
                    '${a.count}',
                    a.moodAverage.toStringAsFixed(1),
                    a.energyAverage.toStringAsFixed(1),
                    signed(a.moodDifference),
                  ],
              ],
            ),
          heading('Patrones personales'),
          if (data.patterns.isEmpty)
            text(
              'Sin patrones: se requieren 14 días, 5 observaciones del grupo y una diferencia mínima de 0.30 puntos.',
            )
          else
            ...data.patterns.map(
              (p) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  text(p.message, bold: true),
                  pw.SizedBox(height: 5),
                  text(p.explanation, size: 9),
                  pw.SizedBox(height: 12),
                ],
              ),
            ),
          if (data.includeHealth) ...[
            pw.NewPage(),
            heading('Sueño y pasos'),
            text(
              'Días emparejados con emoción: ${data.health.pairedDays}. Fuente: registros locales. Los campos ausentes no se convierten en cero.',
            ),
            pw.SizedBox(height: 12),
            text(
              'Sueño promedio: ${data.health.sleepAverage == null ? 'Sin datos suficientes' : '${(data.health.sleepAverage! / 60).toStringAsFixed(1)} h (${data.health.sleepDays} días)'}',
            ),
            pw.SizedBox(height: 8),
            text(
              'Pasos promedio: ${data.health.stepsAverage == null ? 'Sin datos suficientes' : '${NumberFormat.decimalPattern('es_MX').format(data.health.stepsAverage!.round())} (${data.health.stepDays} días)'}',
            ),
            healthTable('Sueño por rango', data.health.sleep),
            healthTable('Pasos por rango', data.health.steps),
            heading('Observaciones'),
            if (data.health.patterns.isEmpty)
              text(
                'Sin patrones con respaldo suficiente (14 días totales y 5 observaciones por grupo).',
              )
            else
              ...data.health.patterns.map(
                (p) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    text(p.message),
                    pw.SizedBox(height: 6),
                    text(p.explanation, size: 9),
                    pw.SizedBox(height: 10),
                  ],
                ),
              ),
            text(
              'Las barras muestran ánimo promedio (1-8). Consultar la tabla para valores y tamaños de muestra. No representan recomendaciones ni relaciones causales.',
              size: 9,
            ),
          ],
          if (data.prediction != null && data.model != null) ...[
            pw.NewPage(),
            heading('Predicción experimental local'),
            text(
              data.model!.synthetic
                  ? 'DEMOSTRACIÓN SINTÉTICA. No es una predicción personal.'
                  : 'Modelo entrenado con registros personales.',
            ),
            pw.SizedBox(height: 12),
            text(
              '${(data.prediction!.probability * 100).toStringAsFixed(1)} % de ánimo 1-4 en el próximo día registrado.',
              size: 21,
              bold: true,
            ),
            text(
              'Entrada: ${date.format(data.prediction!.date)}. No corresponde necesariamente a mañana ni a una fecha exacta.',
            ),
            heading('Evaluación temporal'),
            table(
              ['Medida', 'Modelo', 'Referencia'],
              [
                [
                  'n prueba',
                  '${data.model!.metrics.count}',
                  '${data.model!.baseline.count}',
                ],
                for (final key in [
                  'accuracy',
                  'balancedAccuracy',
                  'precision',
                  'recall',
                  'f1',
                ])
                  [
                    key,
                    (data.model!.metrics.toJson()[key] as double?)
                            ?.toStringAsFixed(3) ??
                        'No disponible',
                    (data.model!.baseline.toJson()[key] as double?)
                            ?.toStringAsFixed(3) ??
                        'No disponible',
                  ],
              ],
            ),
            text(
              data.model!.beatsBaseline
                  ? 'Supera la referencia en esta prueba; no demuestra generalización.'
                  : 'No supera la referencia: no aporta una mejora demostrada.',
            ),
            text(
              'Entrenamiento ${data.model!.trainDateRange.join(' a ')}. Prueba ${data.model!.testDateRange.join(' a ')}. División temporal 80/20. Referencia: repetir la clase actual. Umbral 0.5. Regresión logística con regularización L2, imputación y normalización calculadas solo en entrenamiento.',
            ),
            heading('Contribuciones exactas al logit'),
            table(
              ['Variable', 'Peso × valor normalizado'],
              [
                for (final e
                    in (data.prediction!.contributions.entries.toList()..sort(
                          (a, b) => b.value.abs().compareTo(a.value.abs()),
                        ))
                        .take(6))
                  [e.key, e.value.toStringAsFixed(3)],
              ],
            ),
            text(
              'Intercepto ${data.model!.intercept.toStringAsFixed(3)}. La sigmoide de la suma produce la probabilidad. Las contribuciones no son causas. Faltantes imputados: ${data.prediction!.missing.isEmpty ? 'ninguno' : data.prediction!.missing.join(', ')}. Muestras pequeñas, actividades concurrentes y registro irregular limitan el resultado. No es una evaluación clínica.',
            ),
          ],
          if (data.includeReflections) ...[
            pw.NewPage(),
            heading('Reflexiones que decidiste incluir'),
            text(
              'Contenido personal. Los caracteres no disponibles en la fuente, incluidos emojis, se sustituyen por [símbolo].',
              size: 9,
            ),
            pw.SizedBox(height: 10),
            ...data.records
                .where((r) => r.reflection.isNotEmpty)
                .map(
                  (r) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 14),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        text(
                          '${date.format(r.date)} · ${r.mood.name}',
                          bold: true,
                        ),
                        pw.SizedBox(height: 5),
                        text(r.reflection),
                      ],
                    ),
                  ),
                ),
          ],
          if (data.records.isEmpty)
            text('No hay registros emocionales en este periodo.'),
        ],
      ),
    );
    final bytes = await document.save();
    return ReportPdf(bytes, document.document.pdfPageList.pages.length);
  }
}
