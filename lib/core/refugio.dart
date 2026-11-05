import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/records/domain/record.dart';

/// Presentation-only identity. No dependencies on persistence or application state.
abstract final class Refugio {
  static const forest = Color(0xff285747);
  static const paper = Color(0xfffaf5e9);
  static const ink = Color(0xff233e32);
  static const apricot = Color(0xfff3b58d);
  static const radius = 22.0;
  static const hero = 'assets/refugio/sanctuary.png';
  static const faces = 'assets/refugio/emotions.png';

  static ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: forest,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xffb2d5b9) : forest,
          onPrimary: dark ? const Color(0xff143628) : Colors.white,
          primaryContainer: dark
              ? const Color(0xff324e3b)
              : const Color(0xffdfe7cf),
          onPrimaryContainer: dark ? const Color(0xffe4efdc) : ink,
          surface: dark ? const Color(0xff17251e) : paper,
          onSurface: dark ? const Color(0xffeeeade) : ink,
          surfaceContainerLow: dark
              ? const Color(0xff203027)
              : const Color(0xfffffcf5),
          surfaceContainerHighest: dark
              ? const Color(0xff354439)
              : const Color(0xffeee8d9),
          outline: dark ? const Color(0xffa5b5a5) : const Color(0xff687665),
          outlineVariant: dark
              ? const Color(0xff4c5e4e)
              : const Color(0xffd9d7c7),
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Roboto',
    );
    final text = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontFamily: 'serif',
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontFamily: 'serif',
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontFamily: 'serif',
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontFamily: 'serif',
        fontWeight: FontWeight.w700,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark
            ? const Color(0xff203027)
            : const Color(0xfffffcf5),
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
            color: scheme.onSurface,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: dark ? 0 : 1,
        shadowColor: forest.withValues(alpha: .12),
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .65)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          elevation: dark ? 0 : 2,
          shadowColor: forest.withValues(alpha: .2),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontFamily: 'Roboto',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }
}

/// Painted botanical accents remain crisp without another image or animation loop.
class BotanicalArt extends CustomPainter {
  const BotanicalArt({this.dark = false});
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? const Color(0xff94ab78) : const Color(0xff637c4e))
          .withValues(alpha: dark ? .48 : .16);
    for (final right in [false, true]) {
      canvas.save();
      if (right) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      final stem = Path()
        ..moveTo(-8, size.height)
        ..quadraticBezierTo(34, size.height * .5, 16, 0);
      canvas.drawPath(
        stem,
        Paint()
          ..color = paint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      for (var i = 0; i < 6; i++) {
        canvas.save();
        canvas.translate(
          16 + (i.isEven ? 2 : 8),
          size.height * (.12 + i * .14),
        );
        canvas.rotate(i.isEven ? -.65 : .65);
        canvas.drawOval(const Rect.fromLTWH(-5, -13, 13, 29), paint);
        canvas.restore();
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(BotanicalArt oldDelegate) => oldDelegate.dark != dark;
}

class RefugioFace extends StatefulWidget {
  const RefugioFace({super.key, required this.mood, this.size = 48});
  final Mood mood;
  final double size;
  @override
  State<RefugioFace> createState() => _RefugioFaceState();
}

class _RefugioFaceState extends State<RefugioFace> {
  static Future<ui.Image>? _atlas;
  static Future<ui.Image> load() async {
    final bytes = await rootBundle.load(Refugio.faces);
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(),
      targetWidth: 1024,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<ui.Image>(
        future: _atlas ??= load(),
        builder: (context, snapshot) => snapshot.hasData
            ? CustomPaint(
                painter: _FacePainter(snapshot.data!, widget.mood.index),
              )
            : Icon(
                Icons.spa_outlined,
                size: widget.size * .7,
                color: Theme.of(context).colorScheme.primary,
              ),
      ),
    ),
  );
}

class _FacePainter extends CustomPainter {
  const _FacePainter(this.image, this.index);
  final ui.Image image;
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    final w = image.width / 4, h = image.height / 2;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH((index % 4) * w, (index ~/ 4) * h, w, h),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_FacePainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.index != index;
}
