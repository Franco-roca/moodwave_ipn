import 'package:flutter/material.dart';

import 'refugio.dart';

import '../features/records/domain/record.dart';

extension MoodStyle on Mood {
  Color get color => Color(hex);
  Color background(bool dark) => Color.lerp(
    dark ? const Color(0xff203027) : Refugio.paper,
    color,
    dark ? .30 : .09,
  )!;
}
