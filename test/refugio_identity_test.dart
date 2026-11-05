import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moodwave/app/app.dart';
import 'package:moodwave/app/screens.dart';
import 'package:moodwave/app/state.dart';
import 'package:moodwave/core/refugio.dart';
import 'package:moodwave/core/refugio_art.dart';
import 'package:moodwave/features/records/presentation/journey_widgets.dart';
import 'package:moodwave/features/records/domain/record.dart';
import 'package:moodwave/features/records/domain/synthetic_data_generator.dart';
import 'package:moodwave/features/analytics/presentation/screens/patterns_screen.dart';
import 'package:moodwave/features/reports/presentation/report_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await RefugioFace.preload();
    await Future.wait([
      RefugioAtlas.image('assets/refugio/banners.png'),
      RefugioAtlas.image('assets/refugio/banners-night.png'),
      RefugioAtlas.image('assets/refugio/symbols.png'),
    ]);
    final cache = File(Platform.resolvedExecutable).parent.parent.parent.parent;
    final fonts = {
      'Roboto': 'assets/fonts/Roboto-Regular.ttf',
      'MaterialIcons':
          '${cache.path}/artifacts/material_fonts/materialicons-regular.otf',
      if (Platform.isWindows)
        'serif': '${Platform.environment['WINDIR']}/Fonts/georgia.ttf',
    };
    for (final entry in fonts.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          Future.value(
            ByteData.sublistView(await File(entry.value).readAsBytes()),
          ),
        );
      await loader.load();
    }
  });
  AppStore sample() {
    final days = SyntheticDataGenerator().generate(DateTime.now());
    return AppStore()
      ..records = [
        for (final d in days)
          if (dateKey(d.record.date) != dateKey(DateTime.now())) d.record,
        Record(date: DateTime.now(), mood: Mood.happy, energy: 7, test: true),
      ]
      ..healthData = days.map((d) => d.health).toList();
  }

  final boundary = GlobalKey();
  Future<void> open(
    WidgetTester t,
    Widget screen,
    bool dark, {
    double width = 412,
    double scale = 1,
  }) async {
    await t.pumpWidget(const SizedBox());
    t.view.physicalSize = Size(width, 900);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(sample())],
        child: MaterialApp(
          theme: waveTheme(dark ? Brightness.dark : Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(body: screen),
          ),
        ),
      ),
    );
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  Future<void> shot(WidgetTester t, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_IDENTITY')) return;
    await t.pumpAndSettle();
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await t.runAsync(() async {
      final image = await render.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('docs/screenshots/refugio-full').create(recursive: true);
      await File('docs/screenshots/refugio-full/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  test('Day and night banner bitmaps contain different artwork', () async {
    final day = await RefugioAtlas.image('assets/refugio/banners.png');
    final night = await RefugioAtlas.image('assets/refugio/banners-night.png');
    final dayBytes = (await day.toByteData())!;
    final nightBytes = (await night.toByteData())!;
    var differences = 0;
    for (
      var i = 0;
      i < dayBytes.lengthInBytes && i < nightBytes.lengthInBytes;
      i += 400
    ) {
      if (dayBytes.getUint32(i) != nightBytes.getUint32(i)) differences++;
    }
    expect(differences, greaterThan(100));
  });
  testWidgets(
    'Calendar and profile use painted faces, symbols and section banners',
    (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (final dark in [false, true]) {
        await open(t, const CalendarScreen(), dark);
        expect(find.byType(RefugioFace), findsWidgets);
        expect(
          t.widget<RefugioBanner>(find.byType(RefugioBanner).first).scene,
          RefugioScene.calendar,
        );
        expect(
          t.widget<RefugioTile>(find.byType(RefugioTile).first).asset,
          dark
              ? 'assets/refugio/banners-night.png'
              : 'assets/refugio/banners.png',
        );
        await shot(t, 'calendar-${dark ? 'night' : 'day'}');
        await open(t, const ProfileScreen(), dark);
        expect(find.byType(RefugioIllustration), findsWidgets);
        await shot(t, 'profile-${dark ? 'night' : 'day'}');
        await open(t, const ReportScreen(), dark);
        expect(
          t.widget<RefugioBanner>(find.byType(RefugioBanner).first).scene,
          RefugioScene.reports,
        );
        await shot(t, 'reports-${dark ? 'night' : 'day'}');
      }
    },
  );
  testWidgets('All six analysis tabs keep selection and use their own banner', (
    t,
  ) async {
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final names = [
      'Resumen',
      'Actividades',
      'Tendencias',
      'Sueño y pasos',
      'Predicción',
      'Reportes',
    ];
    final scenes = [
      RefugioScene.summary,
      RefugioScene.activities,
      RefugioScene.trends,
      RefugioScene.sleep,
      RefugioScene.prediction,
      RefugioScene.reports,
    ];
    for (final dark in [false, true]) {
      await open(t, const PatternsScreen(), dark);
      for (var i = 0; i < names.length; i++) {
        final chip = find.widgetWithText(ChoiceChip, names[i]);
        await t.ensureVisible(chip);
        await t.pumpAndSettle();
        await t.tap(chip);
        await t.pumpAndSettle();
        expect(t.widget<ChoiceChip>(chip).selected, isTrue);
        expect(
          t.widget<RefugioBanner>(find.byType(RefugioBanner).first).scene,
          scenes[i],
        );
        expect(t.takeException(), isNull);
        await shot(t, 'analysis-$i-${dark ? 'night' : 'day'}');
      }
    }
  });
  testWidgets(
    'Night mode swaps the cabin artwork without changing mood selection',
    (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (final dark in [false, true]) {
        await open(
          t,
          const Center(child: MoodOrb(mood: null, size: 160)),
          dark,
        );
        final image = t.widget<Image>(find.byType(Image));
        expect(
          (image.image as AssetImage).assetName,
          dark ? Refugio.nightHero : Refugio.hero,
        );
        await shot(t, 'cabin-${dark ? 'night' : 'day'}');
      }
    },
  );
  testWidgets('Illustrated sections fit a narrow display with enlarged text', (
    t,
  ) async {
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await open(t, const CalendarScreen(), true, width: 320, scale: 1.4);
    await open(t, const ProfileScreen(), true, width: 320, scale: 1.4);
    await open(t, const PatternsScreen(), true, width: 320, scale: 1.4);
    for (final name in [
      'Actividades',
      'Tendencias',
      'Sueño y pasos',
      'Predicción',
      'Reportes',
    ]) {
      final chip = find.widgetWithText(ChoiceChip, name);
      await t.ensureVisible(chip);
      await t.pumpAndSettle();
      await t.tap(chip);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }
  });
}
