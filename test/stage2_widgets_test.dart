import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moodwave/app/state.dart';
import 'package:moodwave/app/app.dart';
import 'package:moodwave/features/records/domain/record.dart';
import 'package:moodwave/features/health/domain/daily_health.dart';
import 'package:moodwave/features/health/presentation/health_fields.dart';
import 'package:moodwave/features/analytics/domain/analytics.dart';
import 'package:moodwave/features/analytics/presentation/screens/patterns_screen.dart';
import 'package:moodwave/features/reports/data/report_platform.dart';
import 'package:moodwave/features/reports/domain/report_data.dart';
import 'package:moodwave/features/reports/domain/pdf_report_service.dart';
import 'package:moodwave/features/reports/presentation/report_screen.dart';

class FakeReports extends ReportPlatform {
  MoodWaveReportData? last;
  int saves = 0, shares = 0, generations = 0;
  @override
  Future<String> version() async => '1.0-test';
  @override
  Future<ReportPdf> generate(MoodWaveReportData data) async {
    last = data;
    generations++;
    return ReportPdf(Uint8List.fromList([37, 80, 68, 70]), 3);
  }

  @override
  Future<String?> save(ReportPdf pdf, String name) async {
    saves++;
    return '/test/$name';
  }

  @override
  Future<bool> share(ReportPdf pdf, String name) async {
    shares++;
    return true;
  }
}

void main() {
  setUpAll(() async => initializeDateFormatting('es_MX'));
  AppStore sample() => AppStore()
    ..records = [
      for (var i = 0; i < 12; i++)
        Record(
          date: shiftDay(day(DateTime.now()), -i),
          mood: i.isEven ? Mood.happy : Mood.good,
          energy: i % 10 + 1,
          activities: [i.isEven ? 'Ejercicio' : 'Trabajo'],
          reflection: 'Texto privado',
        ),
    ]
    ..healthData = [
      for (var i = 0; i < 12; i++)
        DailyHealthData(
          date: shiftDay(day(DateTime.now()), -i),
          sleepMinutes: 480,
          steps: 9000,
        ),
    ];
  Future<void> open(
    WidgetTester tester,
    Widget screen,
    AppStore store, {
    FakeReports? reports,
    bool dark = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeProvider.overrideWithValue(store),
          if (reports != null)
            reportPlatformProvider.overrideWithValue(reports),
        ],
        child: MaterialApp(
          theme: waveTheme(dark ? Brightness.dark : Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Filtros de periodo y actividades alternan ánimo y energía', (
    tester,
  ) async {
    await open(tester, const PatternsScreen(), sample());
    await tapVisible(
      tester,
      find.byType(DropdownButtonFormField<AnalyticsPeriod>),
    );
    await tester.tap(find.text('Últimos 30 días').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Actividades'));
    await tapVisible(tester, find.text('Energía').first);
    expect(find.text('Energía por actividad · 1–10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Tendencias y salud conservan filtros y funcionan en oscuro', (
    tester,
  ) async {
    await open(
      tester,
      const PatternsScreen(),
      sample(),
      dark: true,
      scale: 1.4,
    );
    await tapVisible(tester, find.text('Tendencias'));
    await tapVisible(tester, find.text('30 días'));
    await tapVisible(tester, find.text('Energía').first);
    await tapVisible(tester, find.text('Sueño y pasos'));
    await tapVisible(tester, find.text('Tendencias'));
    final control = tester.widget<SegmentedButton<Metric>>(
      find.byType(SegmentedButton<Metric>),
    );
    expect(control.selected, {Metric.energy});
    expect(tester.takeException(), isNull);
  });
  testWidgets('Estado vacío de salud no fabrica promedios', (tester) async {
    await open(tester, const PatternsScreen(), AppStore());
    await tapVisible(tester, find.text('Sueño y pasos'));
    await tester.scrollUntilVisible(
      find.text('Crear mi primer registro'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Crear mi primer registro'), findsOneWidget);
    expect(find.textContaining('Todavía no hay registros'), findsOneWidget);
  });
  testWidgets('Actividad con un registro indica datos insuficientes', (
    tester,
  ) async {
    final store = AppStore()
      ..records = [
        Record(
          date: DateTime.now(),
          mood: Mood.good,
          energy: 5,
          activities: ['Ejercicio'],
        ),
      ];
    await open(tester, const PatternsScreen(), store);
    await tapVisible(tester, find.text('Actividades'));
    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.textContaining('patrón confiable'), findsWidgets);
  });
  testWidgets('Sueño y pasos validan límites sin aceptar negativos', (
    tester,
  ) async {
    final hours = TextEditingController(),
        minutes = TextEditingController(),
        steps = TextEditingController();
    await open(
      tester,
      StatefulBuilder(
        builder: (context, set) => ListView(
          children: [
            HealthFields(
              hours: hours,
              minutes: minutes,
              steps: steps,
              onChanged: () => set(() {}),
            ),
          ],
        ),
      ),
      AppStore(),
    );
    await tapVisible(tester, find.text('Bienestar físico'));
    await tester.enterText(find.byType(TextFormField).at(0), '25');
    await tester.pumpAndSettle();
    expect(find.textContaining('El sueño debe estar'), findsWidgets);
    await tester.enterText(find.byType(TextFormField).at(0), '7');
    await tester.enterText(find.byType(TextFormField).at(1), '30');
    await tester.enterText(find.byType(TextFormField).at(2), '200001');
    await tester.pumpAndSettle();
    expect(find.text('El máximo es 200,000 pasos.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(2), '7840');
    await tester.pumpAndSettle();
    expect(find.text('7,840 pasos'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    hours.dispose();
    minutes.dispose();
    steps.dispose();
  });
  testWidgets('Reflexiones del reporte requieren aceptación explícita', (
    tester,
  ) async {
    await open(tester, const ReportScreen(), sample(), reports: FakeReports());
    await tapVisible(tester, find.text('Incluir reflexiones'));
    expect(
      find.text('Las reflexiones pueden contener información personal'),
      findsOneWidget,
    );
    await tester.tap(find.text('No incluir'));
    await tester.pumpAndSettle();
    final switches = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .toList();
    expect(switches.first.value, isFalse);
  });
  testWidgets(
    'Generar, guardar y compartir usan el mismo PDF y excluyen reflexiones',
    (tester) async {
      final reports = FakeReports();
      await open(tester, const ReportScreen(), sample(), reports: reports);
      await tapVisible(tester, find.text('Guardar'));
      expect(reports.saves, 1);
      expect(reports.last!.includeReflections, isFalse);
      expect(reports.last!.records.every((r) => r.reflection.isEmpty), isTrue);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Compartir'));
      expect(reports.shares, 1);
      expect(reports.generations, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
