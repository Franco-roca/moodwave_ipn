import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodwave/design_lab/main.dart';
import 'package:moodwave/design_lab/draft.dart';
import 'package:moodwave/features/records/domain/record.dart';

void main() {
  test('validates mood and health without touching persistence', () async {
    final d = LabDraft();
    d.selectScenario(LabScenario.empty);
    expect(d.validate(), isFalse);
    d.mood = Mood.happy;
    d.hours = '25';
    expect(d.validate(), isFalse);
    d.hours = '7';
    await d.save();
    expect(d.scenario, LabScenario.saved);
    d.dispose();
  });

  testWidgets('variant changes preserve the shared draft and allow saving', (
    t,
  ) async {
    await t.pumpWidget(const DesignLabApp());
    await t.ensureVisible(find.byKey(const ValueKey('mood-Feliz')));
    await t.tap(find.byKey(const ValueKey('mood-Feliz')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('variant-2')));
    await t.pumpAndSettle();
    expect(find.text('TU REGISTRO\nFeliz · Energía 6/10'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('primary-action')));
    await t.pumpAndSettle();
    expect(find.text('Tu día está registrado'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('variant-1')));
    await t.pumpAndSettle();
    expect(find.text('Tu día está registrado'), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('layouts fit $width at text scale $scale', (t) async {
        t.view.physicalSize = Size(width, 800);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await t.pumpWidget(const DesignLabApp());
        for (var i = 0; i < 3; i++) {
          await t.tap(find.byKey(ValueKey('variant-$i')));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await t.drag(
            find.byType(SingleChildScrollView).last,
            const Offset(0, -600),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('captures all variants with local fonts', (t) async {
    if (!const bool.fromEnvironment('CAPTURE_LAB')) return;
    await t.runAsync(() async {
      final cache = File(Platform.resolvedExecutable)
          .parent
          .parent
          .parent
          .parent;
      final fonts = <String, String>{
        'MaterialIcons':
            '${cache.path}/artifacts/material_fonts/materialicons-regular.otf',
        if (Platform.isWindows)
          'serif': '${Platform.environment['WINDIR']}/Fonts/georgia.ttf',
        if (Platform.isWindows)
          'Segoe UI Emoji':
              '${Platform.environment['WINDIR']}/Fonts/seguiemj.ttf',
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
      for (final font in ['Roboto-Regular', 'Roboto-Bold']) {
        final loader = FontLoader('Roboto')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File('assets/fonts/$font.ttf').readAsBytes(),
              ),
            ),
          );
        await loader.load();
      }
    });
    t.view.physicalSize = const Size(412, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(key: boundary, child: const DesignLabApp()),
    );
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(ValueKey('variant-$i')));
      await t.pumpAndSettle();
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await t.runAsync(() async {
        final frame = await render.toImage();
        final bytes = await frame.toByteData(format: ui.ImageByteFormat.png);
        await Directory('docs/screenshots/design-lab').create(recursive: true);
        await File('docs/screenshots/design-lab/variant-$i.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        frame.dispose();
      });
    }
  });
}
