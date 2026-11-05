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
import 'package:moodwave/core/refugio.dart';
import 'package:moodwave/features/records/presentation/editor.dart';

import 'journey_test.dart' show JourneyStore;

void main() {
  testWidgets(
    'Refugio visual: existing steps at narrow widths, dark and large text',
    (t) async {
      await initializeDateFormatting('es_MX');
      await t.runAsync(() async {
        final cache = File(Platform.resolvedExecutable)
            .parent
            .parent
            .parent
            .parent;
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
      for (final width in [320.0, 412.0]) {
        for (final dark in [false, true]) {
          t.view.physicalSize = Size(width, 1000);
          t.view.devicePixelRatio = 1;
          final capture = GlobalKey();
          final store = JourneyStore();
          await t.pumpWidget(
            ProviderScope(
              overrides: [storeProvider.overrideWithValue(store)],
              child: MaterialApp(
                theme: waveTheme(dark ? Brightness.dark : Brightness.light),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(width == 320 ? 2 : 1),
                  ),
                  child: child!,
                ),
                home: RepaintBoundary(key: capture, child: const Editor()),
              ),
            ),
          );
          await t.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 500));
          });
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          expect(find.byType(RefugioFace), findsWidgets);
          for (final step in ['Vivir', 'Recordar', 'Sentir']) {
            await t.ensureVisible(find.text(step));
            await t.tap(find.text(step));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
          }
          if (const bool.fromEnvironment('CAPTURE_REFUGIO')) {
            await t.runAsync(() async {
              final render =
                  capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('docs/screenshots/refugio')
                  .create(recursive: true);
              await File(
                'docs/screenshots/refugio/today-${width.toInt()}-${dark ? 'dark' : 'light'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await t.pumpWidget(const SizedBox());
        }
      }
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    },
  );
}
