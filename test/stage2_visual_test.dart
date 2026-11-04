import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moodwave/app/app.dart';
import 'package:moodwave/app/state.dart';
import 'package:moodwave/features/records/domain/synthetic_data_generator.dart';
import 'package:moodwave/features/analytics/presentation/screens/patterns_screen.dart';
import 'package:moodwave/features/analytics/domain/analytics.dart';
import 'package:moodwave/features/analytics/presentation/widgets/charts.dart';
import 'package:moodwave/features/prediction/domain/learning.dart';
import 'package:moodwave/features/prediction/data/model_repository.dart';
import 'package:moodwave/features/reports/presentation/report_screen.dart';
import 'package:moodwave/features/support/presentation/support_screen.dart';
import 'package:moodwave/features/health/data/health_connect.dart';
import 'package:moodwave/features/health/presentation/health_connection_card.dart';

void main() {
  const capture = bool.fromEnvironment('CAPTURE_UI');
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    if (capture) {
      for (final pair in {
        'Roboto': 'C:/src/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        'Ahem': 'C:/src/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        'MaterialIcons': 'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        'Segoe UI Emoji': 'C:/Windows/Fonts/seguiemj.ttf',
      }.entries) {
        final f = FontLoader(pair.key)
          ..addFont(
            Future.value(
              ByteData.sublistView(await File(pair.value).readAsBytes()),
            ),
          );
        await f.load();
      }
    }
  });
  AppStore sample() {
    final days = SyntheticDataGenerator().generate(DateTime.now());
    return AppStore()
      ..records = days.map((d) => d.record).toList()
      ..healthData = days.map((d) => d.health).toList();
  }

  Future<void> open(
    WidgetTester t,
    Widget screen,
    AppStore store, {
    bool dark = false,
    double scale = 1,
  }) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    var theme = waveTheme(dark ? Brightness.dark : Brightness.light);
    if (capture) {
      theme = theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: theme.filledButtonTheme.style?.copyWith(
            textStyle: const WidgetStatePropertyAll(
              TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        textTheme: theme.textTheme.apply(
          fontFamily: 'Roboto',
          fontFamilyFallback: ['Segoe UI Emoji'],
        ),
      );
    }
    await t.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: theme,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const ValueKey('stage2-capture'),
            child: Scaffold(body: screen),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> shot(WidgetTester t, String name) async {
    if (!capture) return;
    final b = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('stage2-capture')),
    );
    await t.runAsync(() async {
      final i = await b.toImage(pixelRatio: 1.5);
      final bytes = await i.toByteData(format: ui.ImageByteFormat.png);
      await Directory('docs/screenshots').create(recursive: true);
      await File('docs/screenshots/stage2-$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      i.dispose();
    });
  }

  Future<void> tab(WidgetTester t, String name) async {
    final f = find.widgetWithText(ChoiceChip, name);
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets('Seis secciones visuales con 120 días y predicción real', (
    t,
  ) async {
    final store = sample();
    store.demoPredictionModel = MoodPredictionService()
        .train(
          observationsFrom(store.records, store.healthData, synthetic: true),
          DateTime.now(),
        )
        .model;
    await open(t, const PatternsScreen(), store);
    await t.tap(find.byType(DropdownButtonFormField<AnalyticsPeriod>));
    await t.pumpAndSettle();
    await t.tap(find.text('Últimos 90 días').last);
    await t.pumpAndSettle();
    await shot(t, 'summary');
    await tab(t, 'Tendencias');
    await shot(t, 'trends');
    expect(find.textContaining('Media móvil'), findsOneWidget);
    await tab(t, 'Actividades');
    await shot(t, 'activities');
    await t.ensureVisible(find.text('Ejercicio').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Ejercicio').first);
    await t.pumpAndSettle();
    expect(
      find.textContaining('No demuestra causalidad', skipOffstage: false),
      findsWidgets,
    );
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await tab(t, 'Sueño y pasos');
    await shot(t, 'health');
    await t.scrollUntilVisible(
      find.byType(HealthScatter),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await t.pumpAndSettle();
    await shot(t, 'health-scatter');
    await tab(t, 'Predicción');
    await t.tap(find.byType(SwitchListTile).first);
    await t.pumpAndSettle();
    await shot(t, 'prediction');
    expect(find.textContaining('Ánimo de 1–4'), findsOneWidget);
    await t.ensureVisible(find.text('Métricas y método'));
    await t.pumpAndSettle();
    await t.tap(find.text('Métricas y método'));
    await t.pumpAndSettle();
    expect(find.text('Balanceada'), findsOneWidget);
    await t.ensureVisible(find.text('¿Por qué veo esto?'));
    await t.pumpAndSettle();
    await t.tap(find.text('¿Por qué veo esto?'));
    await t.pumpAndSettle();
    expect(find.textContaining('Probabilidad = sigmoide'), findsOneWidget);
    await open(t, const ReportScreen(), store);
    await shot(t, 'reports');
    expect(find.text('Incluir predicción experimental'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Resumen oscuro con texto grande y estados de pocos datos', (
    t,
  ) async {
    await open(t, const PatternsScreen(), sample(), dark: true, scale: 1.4);
    await shot(t, 'dark-large');
    expect(t.takeException(), isNull);
    await open(t, const PatternsScreen(), AppStore());
    await shot(t, 'empty');
    expect(find.text('Crear mi primer registro'), findsOneWidget);
    final small = sample()
      ..records = sample().records.reversed.take(2).toList();
    await open(t, const PatternsScreen(), small);
    await tab(t, 'Actividades');
    expect(find.textContaining('descriptivo'), findsWidgets);
    expect(t.takeException(), isNull);
  });
  testWidgets('Health Connect solicita permiso solo al pulsar conectar', (
    t,
  ) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(HealthConnectDataSource.channel, (
          call,
        ) async {
          calls.add(call.method);
          return call.method == 'connect' ? 'denied' : 'available';
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(HealthConnectDataSource.channel, null),
    );
    await open(t, HealthConnectionCard(store: AppStore()), AppStore());
    expect(calls, ['status']);
    await t.tap(find.text('Health Connect'));
    await t.pumpAndSettle();
    await t.tap(find.text('Conectar'));
    await t.pumpAndSettle();
    expect(calls, ['status', 'connect']);
    expect(find.textContaining('Permiso no concedido'), findsOneWidget);
  });
  testWidgets('Protocolo de apoyo puede cerrarse y no muestra estadísticas', (
    t,
  ) async {
    await open(t, const SupportScreen(), AppStore());
    expect(find.textContaining('No tienes que atravesar'), findsOneWidget);
    expect(find.text('Ánimo promedio'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
