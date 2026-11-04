import 'package:flutter/material.dart';

import '../features/records/domain/record.dart';

extension MoodStyle on Mood {
  Color get color => Color(hex);
  Color background(bool dark) => Color.lerp(
    dark ? const Color(0xff172328) : Colors.white,
    color,
    dark ? .30 : .13,
  )!;
}
