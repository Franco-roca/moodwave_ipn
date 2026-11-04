import '../../records/domain/record.dart';

import 'dart:math' as math;

class Statistics {
  Statistics(Iterable<Record> input)
    : records = input.toList()..sort((a, b) => a.date.compareTo(b.date));
  final List<Record> records;
  int get count => records.length;
  double? get median {
    if (records.isEmpty) return null;
    final v = records.map((r) => r.mood.value).toList()..sort();
    final n = v.length;
    return n.isOdd ? v[n ~/ 2].toDouble() : (v[n ~/ 2 - 1] + v[n ~/ 2]) / 2;
  }

  List<Mood> get modes {
    if (records.isEmpty) return [];
    final counts = <Mood, int>{};
    for (final r in records) {
      counts[r.mood] = (counts[r.mood] ?? 0) + 1;
    }
    final max = counts.values.reduce(math.max);
    return Mood.values.where((m) => counts[m] == max).toList();
  }

  double? get populationStd {
    if (records.isEmpty) return null;
    final mean = moodAverage;
    return math.sqrt(
      records.fold<double>(0, (s, r) => s + math.pow(r.mood.value - mean, 2)) /
          records.length,
    );
  }

  double get moodAverage => records.isEmpty
      ? 0
      : records.fold<int>(0, (s, r) => s + r.mood.value) / records.length;
  double get energyAverage => records.isEmpty
      ? 0
      : records.fold<int>(0, (s, r) => s + r.energy) / records.length;
  Mood? get frequentMood => mostFrequent(records.map((r) => r.mood));
  String? get frequentActivity =>
      mostFrequent(records.expand((r) => r.activities));
  Record? get best {
    if (records.isEmpty) return null;
    final sorted = [...records]
      ..sort((a, b) {
        var c = b.mood.value.compareTo(a.mood.value);
        if (c == 0) c = b.energy.compareTo(a.energy);
        if (c == 0) c = b.date.compareTo(a.date);
        return c;
      });
    return sorted.first;
  }

  int get bestStreak {
    var best = 0, run = 0;
    DateTime? last;
    for (final d
        in records.map((r) => dateKey(r.date)).toSet().toList()..sort()) {
      final dt = DateTime.parse(d);
      run = last != null && dateKey(shiftDay(last, 1)) == d ? run + 1 : 1;
      if (run > best) best = run;
      last = dt;
    }
    return best;
  }

  int currentStreak(DateTime now) {
    final keys = records.map((r) => dateKey(r.date)).toSet();
    var d = day(now);
    if (!keys.contains(dateKey(d))) d = shiftDay(d, -1);
    var n = 0;
    while (keys.contains(dateKey(d))) {
      n++;
      d = shiftDay(d, -1);
    }
    return n;
  }

  static List<Record> period(
    List<Record> records,
    DateTime anchor,
    bool monthly,
  ) {
    final start = monthly
        ? DateTime(anchor.year, anchor.month)
        : shiftDay(day(anchor), 1 - anchor.weekday);
    final end = monthly
        ? DateTime(anchor.year, anchor.month + 1)
        : shiftDay(start, 7);
    return records
        .where((r) => !r.date.isBefore(start) && r.date.isBefore(end))
        .toList();
  }
}

T? mostFrequent<T>(Iterable<T> values) {
  final counts = <T, int>{};
  for (final v in values) {
    counts[v] = (counts[v] ?? 0) + 1;
  }
  T? result;
  var max = 0;
  for (final e in counts.entries) {
    if (e.value > max) {
      max = e.value;
      result = e.key;
    }
  }
  return result;
}
