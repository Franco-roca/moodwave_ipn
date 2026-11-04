import '../../records/domain/record.dart';
import '../../statistics/domain/statistics.dart';
import '../../health/domain/daily_health.dart';

enum AnalyticsPeriod { week, month, last7, last30, last90 }

enum Metric { mood, energy }

extension MetricValues on Metric {
  String get label => this == Metric.mood ? 'Ánimo' : 'Energía';
  int get maximum => this == Metric.mood ? 8 : 10;
  double value(Record record) =>
      (this == Metric.mood ? record.mood.value : record.energy).toDouble();
}

class DateSpan {
  DateSpan(DateTime start, DateTime end) : start = day(start), end = day(end) {
    if (!this.end.isAfter(this.start)) throw ArgumentError('Rango inválido');
  }
  final DateTime start, end;
  int get days => DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
  bool contains(DateTime date) =>
      !day(date).isBefore(start) && day(date).isBefore(end);
  List<Record> select(Iterable<Record> records) =>
      records.where((r) => contains(r.date)).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  static DateSpan forPeriod(AnalyticsPeriod period, DateTime anchor) =>
      switch (period) {
        AnalyticsPeriod.week => DateSpan(
          shiftDay(day(anchor), 1 - anchor.weekday),
          shiftDay(day(anchor), 8 - anchor.weekday),
        ),
        AnalyticsPeriod.month => DateSpan(
          DateTime(anchor.year, anchor.month),
          DateTime(anchor.year, anchor.month + 1),
        ),
        _ => DateSpan(
          shiftDay(
            day(anchor),
            1 -
                switch (period) {
                  AnalyticsPeriod.last7 => 7,
                  AnalyticsPeriod.last30 => 30,
                  _ => 90,
                },
          ),
          shiftDay(day(anchor), 1),
        ),
      };
}

class EmotionalSummaryService {
  Statistics summarize(Iterable<Record> records, DateSpan span) =>
      Statistics(span.select(records));
}

enum Evidence { insufficient, initial, supported }

Evidence evidenceFor(int count) =>
    count < 5 ? Evidence.insufficient : Evidence.supported;
String evidenceLabel(Evidence evidence) => switch (evidence) {
  Evidence.insufficient => 'Datos insuficientes',
  Evidence.initial => 'Relación inicial',
  Evidence.supported => 'Mayor respaldo en tus datos',
};

class ActivitySummary {
  const ActivitySummary({
    required this.name,
    required this.count,
    required this.moodAverage,
    required this.energyAverage,
    required this.moodDifference,
    required this.energyDifference,
    required this.percentage,
    required this.best,
    required this.worst,
  });
  final String name;
  final int count, best, worst;
  final double moodAverage,
      energyAverage,
      moodDifference,
      energyDifference,
      percentage;
  Evidence get evidence => evidenceFor(count);
  double average(Metric metric) =>
      metric == Metric.mood ? moodAverage : energyAverage;
  double difference(Metric metric) =>
      metric == Metric.mood ? moodDifference : energyDifference;
}

class ActivityAnalyticsService {
  List<ActivitySummary> analyze(List<Record> records) {
    if (records.isEmpty) return [];
    final general = Statistics(records);
    final groups = <String, List<Record>>{}, names = <String, String>{};
    for (final r in records) {
      final seen = <String>{};
      for (final raw in r.activities) {
        final name = raw.trim().replaceAll(RegExp(r'\s+'), ' '),
            key = raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        if (key.isEmpty || !seen.add(key)) continue;
        names.putIfAbsent(key, () => name);
        groups.putIfAbsent(key, () => []).add(r);
      }
    }
    final result = <ActivitySummary>[];
    for (final entry in groups.entries) {
      final summary = Statistics(entry.value);
      final values = entry.value.map((r) => r.mood.value).toList()..sort();
      result.add(
        ActivitySummary(
          name: names[entry.key]!,
          count: entry.value.length,
          moodAverage: summary.moodAverage,
          energyAverage: summary.energyAverage,
          moodDifference: summary.moodAverage - general.moodAverage,
          energyDifference: summary.energyAverage - general.energyAverage,
          percentage: entry.value.length / records.length * 100,
          best: values.last,
          worst: values.first,
        ),
      );
    }
    return result..sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
  }
}

class DetectedPattern {
  const DetectedPattern({
    required this.activity,
    required this.metric,
    required this.activityAverage,
    required this.globalAverage,
    required this.difference,
    required this.sampleCount,
    required this.totalCount,
  });
  final String activity;
  final Metric metric;
  final double activityAverage, globalAverage, difference;
  final int sampleCount, totalCount;
  Evidence get confidenceLevel => evidenceFor(sampleCount);
  String get message =>
      '$activity · ${signed(difference)} ${metric.label.toLowerCase()} · n=$sampleCount';
  String get explanation =>
      'Promedio con $activity: ${activityAverage.toStringAsFixed(1)}. Media del periodo: ${globalAverage.toStringAsFixed(1)} ($totalCount registros). Diferencia: ${activityAverage.toStringAsFixed(1)} − ${globalAverage.toStringAsFixed(1)} = ${signed(difference)} puntos. Es una asociación personal, no una causa ni un diagnóstico.';
}

String signed(double value) =>
    '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';

class PatternDetectionService {
  List<DetectedPattern> detect(List<Record> records) {
    if (records.map((r) => dateKey(r.date)).toSet().length < 14) return [];
    final summary = Statistics(records), result = <DetectedPattern>[];
    for (final a
        in ActivityAnalyticsService()
            .analyze(records)
            .where((a) => a.count >= 5)) {
      final metric = a.moodDifference.abs() >= a.energyDifference.abs()
          ? Metric.mood
          : Metric.energy;
      if (a.difference(metric).abs() < .30) continue;
      result.add(
        DetectedPattern(
          activity: a.name,
          metric: metric,
          activityAverage: a.average(metric),
          globalAverage: metric == Metric.mood
              ? summary.moodAverage
              : summary.energyAverage,
          difference: a.difference(metric),
          sampleCount: a.count,
          totalCount: records.length,
        ),
      );
    }
    result.sort((a, b) {
      final c = b.sampleCount.compareTo(a.sampleCount);
      return c != 0 ? c : b.difference.abs().compareTo(a.difference.abs());
    });
    return result.take(3).toList();
  }
}

enum TrendDirection { ascending, descending, stable, insufficient }

class PeriodComparison {
  const PeriodComparison(
    this.recent,
    this.previous,
    this.recentCount,
    this.previousCount,
  );
  final double? recent, previous;
  final int recentCount, previousCount;
  double? get difference =>
      recent == null || previous == null ? null : recent! - previous!;
  TrendDirection get direction => recentCount < 3 || previousCount < 3
      ? TrendDirection.insufficient
      : difference! >= .25
      ? TrendDirection.ascending
      : difference! <= -.25
      ? TrendDirection.descending
      : TrendDirection.stable;
  String get label => switch (direction) {
    TrendDirection.ascending => 'Ascendente',
    TrendDirection.descending => 'Descendente',
    TrendDirection.stable => 'Estable',
    TrendDirection.insufficient =>
      'Se necesitan más registros para comparar estos periodos',
  };
}

class TrendPoint {
  const TrendPoint(this.date, this.record);
  final DateTime date;
  final Record? record;
}

class TrendAnalysisService {
  List<TrendPoint> points(List<Record> records, DateSpan span) {
    final map = {
      for (final r in records.where((r) => span.contains(r.date)))
        dateKey(r.date): r,
    };
    return List.generate(span.days, (i) {
      final date = shiftDay(span.start, i);
      return TrendPoint(date, map[dateKey(date)]);
    });
  }

  List<double?> movingAverage(
    List<TrendPoint> points,
    Metric metric,
    int window,
  ) {
    if (window < 1) throw ArgumentError('Ventana inválida');
    return List.generate(points.length, (i) {
      if (points[i].record == null) return null;
      var sum = 0.0, n = 0;
      for (var j = (i - window + 1).clamp(0, i); j <= i; j++) {
        final r = points[j].record;
        if (r != null) {
          sum += metric.value(r);
          n++;
        }
      }
      return n == 0 ? null : sum / n;
    });
  }

  PeriodComparison compare(
    List<Record> records,
    DateTime anchor,
    int days,
    Metric metric,
  ) {
    final end = shiftDay(day(anchor), 1),
        start = shiftDay(day(anchor), 1 - days);
    final a = DateSpan(start, end).select(records),
        b = DateSpan(shiftDay(start, -days), start).select(records);
    double? mean(List<Record> list) => list.isEmpty
        ? null
        : list.fold<double>(0, (sum, r) => sum + metric.value(r)) / list.length;
    return PeriodComparison(mean(a), mean(b), a.length, b.length);
  }
}

class HealthBucket {
  const HealthBucket(this.label, this.records);
  final String label;
  final List<Record> records;
  int get count => records.length;
  double? get moodAverage =>
      records.isEmpty ? null : Statistics(records).moodAverage;
  double? get energyAverage =>
      records.isEmpty ? null : Statistics(records).energyAverage;
  double? differenceFrom(double? baseline) =>
      moodAverage == null || baseline == null ? null : moodAverage! - baseline;
}

class HealthPattern {
  const HealthPattern(
    this.label,
    this.group,
    this.baseline,
    this.baselineCount,
  );
  final String label;
  final HealthBucket group;
  final double baseline;
  final int baselineCount;
  double get difference => group.moodAverage! - baseline;
  String get message =>
      '$label · ${signed(difference)} ánimo · n=${group.count}';
  String get explanation =>
      'Se emparejan las fechas locales. Media del grupo: ${group.moodAverage!.toStringAsFixed(1)} (${group.count} días). Media de días emparejados con ese dato: ${baseline.toStringAsFixed(1)} ($baselineCount días). Diferencia: ${signed(difference)} puntos. No demuestra causalidad.';
}

class HealthAnalysis {
  const HealthAnalysis({
    required this.sleep,
    required this.steps,
    required this.pairedDays,
    required this.sleepDays,
    required this.stepDays,
    required this.sleepAverage,
    required this.stepsAverage,
    required this.patterns,
  });
  final List<HealthBucket> sleep, steps;
  final int pairedDays, sleepDays, stepDays;
  final double? sleepAverage, stepsAverage;
  final List<HealthPattern> patterns;
  double? baseline(bool useSteps) {
    final groups = useSteps ? steps : sleep;
    final count = useSteps ? stepDays : sleepDays;
    return count == 0
        ? null
        : groups
                  .where((g) => g.count > 0)
                  .fold<double>(0, (s, g) => s + g.moodAverage! * g.count) /
              count;
  }
}

class HealthAnalyticsService {
  static const sleepLabels = [
    'Menos de 6 h',
    '6 a menos de 7 h',
    '7 a 9 h',
    'Más de 9 h',
  ];
  static const stepLabels = [
    'Menos de 2,000',
    '2,000 a 4,999',
    '5,000 a 7,999',
    '8,000 o más',
  ];
  int sleepBucket(int minutes) => minutes < 360
      ? 0
      : minutes < 420
      ? 1
      : minutes <= 540
      ? 2
      : 3;
  int stepBucket(int steps) => steps < 2000
      ? 0
      : steps < 5000
      ? 1
      : steps < 8000
      ? 2
      : 3;
  HealthAnalysis analyze(
    List<Record> records,
    List<DailyHealthData> health,
    DateSpan span,
  ) {
    final selected = span.select(records),
        map = {
          for (final h in health.where((h) => span.contains(h.date)))
            h.dateKeyValue: h,
        };
    final sleep = List.generate(4, (i) => HealthBucket(sleepLabels[i], [])),
        steps = List.generate(4, (i) => HealthBucket(stepLabels[i], []));
    final sleepRecords = <Record>[], stepRecords = <Record>[];
    var paired = 0, sleepTotal = 0, stepTotal = 0;
    for (final r in selected) {
      final h = map[dateKey(r.date)];
      if (h == null || h.isEmpty) continue;
      paired++;
      if (h.sleepMinutes != null) {
        sleep[sleepBucket(h.sleepMinutes!)].records.add(r);
        sleepRecords.add(r);
        sleepTotal += h.sleepMinutes!;
      }
      if (h.steps != null) {
        steps[stepBucket(h.steps!)].records.add(r);
        stepRecords.add(r);
        stepTotal += h.steps!;
      }
    }
    final patterns = <HealthPattern>[];
    void detect(List<HealthBucket> groups, List<Record> base, bool isSleep) {
      if (selected.length < 14 || base.length < 5) return;
      final average = Statistics(base).moodAverage;
      final eligible =
          groups
              .where(
                (g) => g.count >= 5 && (g.moodAverage! - average).abs() >= .30,
              )
              .toList()
            ..sort((a, b) {
              final c = b.count.compareTo(a.count);
              return c != 0
                  ? c
                  : (b.moodAverage! - average).abs().compareTo(
                      (a.moodAverage! - average).abs(),
                    );
            });
      if (eligible.isNotEmpty) {
        final g = eligible.first;
        patterns.add(
          HealthPattern(
            '${g.label}${isSleep ? ' de sueño' : ' pasos'}',
            g,
            average,
            base.length,
          ),
        );
      }
    }

    detect(sleep, sleepRecords, true);
    detect(steps, stepRecords, false);
    return HealthAnalysis(
      sleep: sleep,
      steps: steps,
      pairedDays: paired,
      sleepDays: sleepRecords.length,
      stepDays: stepRecords.length,
      sleepAverage: sleepRecords.isEmpty
          ? null
          : sleepTotal / sleepRecords.length,
      stepsAverage: stepRecords.isEmpty ? null : stepTotal / stepRecords.length,
      patterns: patterns,
    );
  }
}
