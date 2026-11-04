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
import 'package:moodwave/features/records/domain/record.dart';
import 'package:moodwave/features/records/presentation/editor.dart';
import 'package:moodwave/features/health/domain/daily_health.dart';

class JourneyStore extends AppStore {
  @override
  Future<void> save(
    Record record, {
    DailyHealthData? health,
    bool updateHealth = false,
  }) async {
    records = [record];
    if (updateHealth) healthData = health == null ? [] : [health];
    notifyListeners();
  }
}

void main() {
  const capture = bool.fromEnvironment('CAPTURE_UI');
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    if (capture) {
      final font = FontLoader('Roboto');
      font.addFont(
        Future.value(
          ByteData.sublistView(
            await File(
              'C:/src/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
            ).readAsBytes(),
          ),
        ),
      );
      await font.load();
      final fallback = FontLoader('Ahem');
      fallback.addFont(
        Future.value(
          ByteData.sublistView(
            await File(
              'C:/src/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
            ).readAsBytes(),
          ),
        ),
      );
      await fallback.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(
        Future.value(
          ByteData.sublistView(
            await File(
              'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
            ).readAsBytes(),
          ),
        ),
      );
      await icons.load();
      final emoji = FontLoader('Segoe UI Emoji');
      emoji.addFont(
        Future.value(
          ByteData.sublistView(
            await File('C:/Windows/Fonts/seguiemj.ttf').readAsBytes(),
          ),
        ),
      );
      await emoji.load();
    }
  });

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (!capture) return;
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('docs/screenshots').create(recursive: true);
      await File('docs/screenshots/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> open(
    WidgetTester tester,
    AppStore store, {
    double scale = 1,
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const RepaintBoundary(
            key: ValueKey('capture'),
            child: Editor(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Recorrido conserva selección y guarda todos los datos', (
    tester,
  ) async {
    final store = JourneyStore();
    await open(tester, store);
    await screenshot(tester, 'journey-feel');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Elige la emoción que más se acerque a tu día.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Feliz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feliz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Mi batería de hoy'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(8);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ejercicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ejercicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Paso anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Hoy me siento feliz'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 8);
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Ejercicio'),
    );
    expect(chip.selected, isTrue);
    await screenshot(tester, 'journey-live');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Un paseo que me hizo bien.',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await screenshot(tester, 'journey-remember');
    await tester.tap(find.text('Guardar mi momento'));
    await tester.pumpAndSettle();
    expect(store.records.single.mood, Mood.happy);
    expect(store.records.single.energy, 8);
    expect(store.records.single.activities, ['Ejercicio']);
    expect(store.records.single.reflection, 'Un paseo que me hizo bien.');
    expect(find.text('Tu día está guardado'), findsOneWidget);
    await screenshot(tester, 'journey-saved');
    await tester.ensureVisible(find.text('Cambiar algo de mi día'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar algo de mi día'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recordar'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Un paseo que me hizo bien.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Recorrido accesible con letra grande y tema oscuro', (
    tester,
  ) async {
    await open(tester, JourneyStore(), scale: 1.6, dark: true);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Vivir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Recordar'));
    await tester.pumpAndSettle();
    await screenshot(tester, 'journey-dark-large');
    expect(tester.takeException(), isNull);
  });
}
