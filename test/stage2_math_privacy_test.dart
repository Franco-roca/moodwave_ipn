import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:moodwave/features/records/domain/record.dart';
import 'package:moodwave/features/records/domain/synthetic_data_generator.dart';
import 'package:moodwave/features/statistics/domain/statistics.dart';
import 'package:moodwave/features/analytics/domain/analytics.dart';
import 'package:moodwave/features/analytics/domain/statistical_relationship.dart';
import 'package:moodwave/features/privacy/domain/data_export.dart';
import 'package:moodwave/features/support/domain/risk_support.dart';

Record row(int d, int mood, {List<String> activities = const []}) => Record(
  date: DateTime(2026, 10, d),
  mood: Mood.values[mood - 1],
  energy: mood,
  activities: activities,
);
void main() {
  test(
    'Media, mediana par/impar, modas empatadas y desviación poblacional',
    () {
      final even = Statistics([row(1, 2), row(2, 2), row(3, 4), row(4, 4)]);
      expect(even.moodAverage, 3);
      expect(even.median, 3);
      expect(even.modes, [Mood.sad, Mood.worried]);
      expect(even.populationStd, 1);
      final odd = Statistics([row(1, 1), row(2, 2), row(3, 2)]);
      expect(odd.median, 2);
      expect(odd.modes, [Mood.sad]);
      expect(odd.populationStd, closeTo(math.sqrt(2 / 9), 1e-10));
      expect(Statistics([]).median, isNull);
      expect(Statistics([]).populationStd, isNull);
      expect(Statistics([]).modes, isEmpty);
      expect(Statistics([row(1, 5)]).populationStd, 0);
    },
  );
  test('Media móvil causal, ventana calendario y huecos sin ceros', () {
    final engine = TrendAnalysisService();
    final points = engine.points([
      row(1, 2),
      row(2, 4),
      row(4, 8),
      row(5, 2),
    ], DateSpan(DateTime(2026, 10, 1), DateTime(2026, 10, 6)));
    expect(engine.movingAverage(points, Metric.mood, 3), [2, 3, null, 6, 5]);
    expect(engine.movingAverage(points.take(2).toList(), Metric.mood, 3), [
      2,
      3,
    ]);
  });
  test('Umbral 14 días y cinco observaciones exactos', () {
    List<Record> data(int days, int group) => [
      for (var i = 1; i <= days; i++)
        row(i, i <= group ? 8 : 2, activities: i <= group ? ['A'] : ['B']),
    ];
    expect(PatternDetectionService().detect(data(13, 5)), isEmpty);
    expect(
      PatternDetectionService()
          .detect(data(14, 4))
          .any((p) => p.activity == 'A'),
      isFalse,
    );
    expect(
      PatternDetectionService()
          .detect(data(14, 5))
          .any((p) => p.activity == 'A'),
      isTrue,
    );
    final s = StatisticalRelationshipService();
    expect(s.classify(.299), DifferenceSize.small);
    expect(s.classify(-.30), DifferenceSize.moderate);
    expect(s.classify(.70), DifferenceSize.relevant);
  });
  test(
    'Generador reproducible con huecos y relaciones plantadas recuperables',
    () {
      final generator = SyntheticDataGenerator();
      final a = generator.generate(
        DateTime(2026, 10, 30),
        seed: 42,
        withGaps: true,
      );
      final b = generator.generate(
        DateTime(2026, 10, 30),
        seed: 42,
        withGaps: true,
      );
      expect(
        jsonEncode(a.map((d) => d.record.toMap()).toList()),
        jsonEncode(b.map((d) => d.record.toMap()).toList()),
      );
      expect(a.length, 116);
      expect(a.every((d) => d.record.test && d.health.isSynthetic), isTrue);
      final activities = ActivityAnalyticsService().analyze(
        a.map((d) => d.record).toList(),
      );
      expect(
        activities.firstWhere((v) => v.name == 'Ejercicio').moodDifference,
        greaterThan(.30),
      );
      expect(
        activities.firstWhere((v) => v.name == 'Trabajo').energyDifference,
        lessThan(-.70),
      );
      final walking = a.where(
        (v) =>
            v.record.activities.contains('Caminata') && v.health.steps != null,
      );
      final rest = a.where(
        (v) =>
            !v.record.activities.contains('Caminata') && v.health.steps != null,
      );
      double mean(Iterable<SyntheticDay> rows) =>
          rows.map((d) => d.health.steps!).reduce((a, b) => a + b) /
          rows.length;
      expect(mean(walking), greaterThan(mean(rest)));
      final health = HealthAnalyticsService().analyze(
        a.map((d) => d.record).toList(),
        a.map((d) => d.health).toList(),
        DateSpan(DateTime(2026, 8, 1), DateTime(2026, 11, 1)),
      );
      expect(
        health.sleep[2].energyAverage,
        greaterThan(health.sleep[0].energyAverage!),
      );
    },
  );
  test('Exportación tiene lista blanca, origen y ningún dato de seguridad', () {
    final data = DataExportService().build(
      records: [row(1, 6)],
      health: [],
      activities: ['Trabajo'],
      theme: 'dark',
      now: DateTime(2026),
    );
    expect(data.keys.toSet(), {
      'schemaVersion',
      'exportedAt',
      'emociones',
      'salud',
      'actividades',
      'preferencias',
    });
    final keys = jsonEncode(data).toLowerCase();
    for (final key in [
      'pin',
      'hash',
      'salt',
      'biometric',
      'coefficients',
      'secure',
    ]) {
      expect(keys, isNot(contains(key)));
    }
  });
  test('Apoyo local distingue expresiones directas y negaciones simples', () {
    final rules = RiskSupportService();
    expect(rules.shouldOffer('Quiero hacerme daño'), isTrue);
    expect(rules.shouldOffer('No quiero seguir viviendo'), isTrue);
    expect(rules.shouldOffer('No quiero morir'), isFalse);
    expect(rules.shouldOffer('Estoy triste por el trabajo'), isFalse);
    expect(rules.shouldOffer('Quiero matarme. No quiero morir'), isTrue);
  });
}
