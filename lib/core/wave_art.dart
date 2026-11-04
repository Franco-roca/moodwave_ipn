import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Painted shapes instead of images: a few paths, no downloads or animation loop.
class WaveArt extends CustomPainter {
  const WaveArt({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final path = Path()..moveTo(0, size.height * (.70 + .08 * i));
      for (var x = 0.0; x <= size.width; x += 8) {
        path.lineTo(
          x,
          size.height * (.70 + .08 * i) +
              math.sin(x / size.width * math.pi * 2 + i) * 12,
        );
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: .025 + i * .015),
      );
    }
    canvas.drawCircle(
      Offset(size.width - 32, 20),
      56,
      Paint()..color = color.withValues(alpha: .06),
    );
    canvas.drawCircle(
      Offset(size.width - 55, 30),
      24,
      Paint()..color = color.withValues(alpha: .06),
    );
  }

  @override
  bool shouldRepaint(covariant WaveArt oldDelegate) =>
      oldDelegate.color != color;
}
