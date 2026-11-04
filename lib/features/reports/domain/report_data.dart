import '../../records/domain/record.dart';
import '../../health/domain/daily_health.dart';
import '../../analytics/domain/analytics.dart';
import '../../statistics/domain/statistics.dart';
import '../../prediction/domain/learning.dart';
import '../../prediction/data/model_repository.dart';

class MoodWaveReportData {
  const MoodWaveReportData({
    required this.title,
    required this.span,
    required this.generatedAt,
    required this.records,
    required this.summary,
    required this.activities,
    required this.patterns,
    required this.health,
    required this.trend,
    required this.includeReflections,
    required this.includeHealth,
    required this.version,
    this.model,
    this.prediction,
    this.currentStreak = 0,
    this.bestHistoricalStreak = 0,
  });
  final String title, version;
  final DateSpan span;
  final DateTime generatedAt;
  final List<Record> records;
  final Statistics summary;
  final List<ActivitySummary> activities;
  final List<DetectedPattern> patterns;
  final HealthAnalysis health;
  final PeriodComparison trend;
  final bool includeReflections, includeHealth;
  final TrainedModel? model;
  final Prediction? prediction;
  final int currentStreak, bestHistoricalStreak;
}

class ReportDataService {
  MoodWaveReportData build({
    required List<Record> records,
    required List<DailyHealthData> health,
    required DateSpan span,
    required DateTime now,
    required bool monthly,
    bool includeReflections = false,
    bool includeHealth = true,
    String version = '',
    bool includePrediction = false,
    TrainedModel? model,
  }) {
    final selected = span
        .select(records)
        .map(
          (r) => Record(
            id: r.id,
            date: r.date,
            mood: r.mood,
            energy: r.energy,
            activities: r.activities,
            reflection: includeReflections ? r.reflection : '',
            updated: r.updated,
            test: r.test,
          ),
        )
        .toList();
    return MoodWaveReportData(
      title: monthly ? 'Tu mes en MoodWave' : 'Tu semana en MoodWave',
      span: span,
      generatedAt: now,
      records: selected,
      summary: Statistics(selected),
      activities: ActivityAnalyticsService().analyze(selected),
      patterns: PatternDetectionService().detect(selected),
      health: HealthAnalyticsService().analyze(
        selected,
        includeHealth ? health : [],
        span,
      ),
      trend: TrendAnalysisService().compare(
        records,
        shiftDay(span.end, -1),
        monthly ? 30 : 7,
        Metric.mood,
      ),
      includeReflections: includeReflections,
      includeHealth: includeHealth,
      version: version,
      currentStreak: Statistics(records).currentStreak(now),
      bestHistoricalStreak: Statistics(records).bestStreak,
      model: includePrediction ? model : null,
      prediction: includePrediction && model != null
          ? MoodPredictionService().infer(
              model,
              observationsFrom(records, health, synthetic: model.synthetic),
            )
          : null,
    );
  }
}
