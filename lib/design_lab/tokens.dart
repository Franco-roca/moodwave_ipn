import 'package:flutter/material.dart';

enum LabVariant { marea, cuaderno, pulso }

class LabTokens {
  const LabTokens(
    this.name,
    this.background,
    this.ink,
    this.primary,
    this.accent,
    this.radius,
  );

  final String name;
  final Color background, ink, primary, accent;
  final double radius;
  static const gap = 16.0;
  static const page = 20.0;
  static const maxWidth = 640.0;
  static const variants = [
    LabTokens(
      'Marea',
      Color(0xfff3f8f6),
      Color(0xff183c3a),
      Color(0xff006b64),
      Color(0xffd7eba6),
      28,
    ),
    LabTokens(
      'Cuaderno',
      Color(0xfffff8ee),
      Color(0xff352f2b),
      Color(0xff9e4938),
      Color(0xffe4e8d5),
      8,
    ),
    LabTokens(
      'Pulso',
      Color(0xfff4f6fc),
      Color(0xff19243c),
      Color(0xff344bc0),
      Color(0xff90e0d0),
      16,
    ),
  ];

  ThemeData theme(bool dark) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: dark ? scheme.surface : background,
      textTheme: base.textTheme.apply(
        bodyColor: dark ? scheme.onSurface : ink,
        displayColor: dark ? scheme.onSurface : ink,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}
