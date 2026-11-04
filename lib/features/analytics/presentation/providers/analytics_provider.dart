import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analytics.dart';
import '../../../records/domain/record.dart';
import '../../../statistics/domain/statistics.dart';
import '../../../health/domain/daily_health.dart';

final analyticsServicesProvider = Provider<AnalyticsServices>(
  (ref) => AnalyticsServices(),
);

class AnalyticsSnapshot {
  AnalyticsSnapshot({
    required this.records,
    required this.summary,
    required this.activities,
    required this.patterns,
    required this.health,
    required this.points,
    required this.comparison,
  });
  final List<Record> records;
  final Statistics summary;
  final List<ActivitySummary> activities;
  final List<DetectedPattern> patterns;
  final HealthAnalysis health;
  final List<TrendPoint> points;
  final PeriodComparison comparison;
  late final List<double?> moodMoving = TrendAnalysisService().movingAverage(
    points,
    Metric.mood,
    points.length <= 7 ? 3 : 7,
  );
  late final List<double?> energyMoving = TrendAnalysisService().movingAverage(
    points,
    Metric.energy,
    points.length <= 7 ? 3 : 7,
  );
}

class AnalyticsServices {
  List<Record>? _records;
  List<DailyHealthData>? _health;
  final _cache = <String, AnalyticsSnapshot>{};
  AnalyticsSnapshot build(
    List<Record> records,
    List<DailyHealthData> health,
    DateSpan span,
    Metric metric,
    int comparisonDays,
  ) {
    if (!identical(_records, records) || !identical(_health, health)) {
      _cache.clear();
      _records = records;
      _health = health;
    }
    final key = '${span.start}:${span.end}:${metric.name}:$comparisonDays';
    if (_cache.containsKey(key)) return _cache[key]!;
    if (_cache.length >= 8) _cache.remove(_cache.keys.first);
    return _cache[key] = AnalyticsSnapshot(
      records: span.select(records),
      summary: EmotionalSummaryService().summarize(records, span),
      activities: ActivityAnalyticsService().analyze(span.select(records)),
      patterns: PatternDetectionService().detect(span.select(records)),
      health: HealthAnalyticsService().analyze(records, health, span),
      points: TrendAnalysisService().points(records, span),
      comparison: TrendAnalysisService().compare(
        records,
        shiftDay(span.end, -1),
        comparisonDays,
        metric,
      ),
    );
  }
}
