import 'package:flutter_test/flutter_test.dart';
import 'package:moodwave/features/analytics/domain/analytics.dart';
import 'package:moodwave/features/records/domain/record.dart';
import 'package:moodwave/features/health/domain/daily_health.dart';

Record r(
  int day, {
  int mood = 6,
  int energy = 5,
  List<String> activities = const ['Trabajo'],
}) => Record(
  date: DateTime(2026, 10, day),
  mood: Mood.values[mood - 1],
  energy: energy,
  activities: activities,
);
void main() {
  final span = DateSpan(DateTime(2026, 10, 1), DateTime(2026, 11, 1));
  test('Resumen y promedios generales solo usan el rango', () {
    final s = EmotionalSummaryService().summarize([
      r(1, mood: 2, energy: 2),
      r(2, mood: 8, energy: 10),
      r(32),
    ], span);
    expect(s.moodAverage, 5);
    expect(s.energyAverage, 6);
  });
  test(
    'Actividad se agrupa normalizando espacios y mayúsculas una vez por día',
    () {
      final a = ActivityAnalyticsService().analyze([
        r(1, activities: [' Ejercicio ', 'ejercicio', '  ']),
        r(2, activities: ['Ejercicio']),
      ]);
      expect(a.length, 1);
      expect(a.single.count, 2);
      expect(a.single.percentage, 100);
    },
  );
  test('Promedios, diferencias, mejor y peor por actividad', () {
    final a = ActivityAnalyticsService().analyze([
      r(1, mood: 8, energy: 10, activities: ['Ejercicio']),
      r(2, mood: 6, energy: 8, activities: ['Ejercicio']),
      r(3, mood: 1, energy: 3),
    ]).first;
    expect(a.name, 'Ejercicio');
    expect(a.moodAverage, 7);
    expect(a.energyAverage, 9);
    expect(a.moodDifference, 2);
    expect(a.energyDifference, 2);
    expect(a.best, 8);
    expect(a.worst, 6);
    expect(a.percentage, closeTo(66.666, 0.01));
  });
  test('Clasifica observaciones sin significancia estadística', () {
    expect(evidenceFor(1), Evidence.insufficient);
    expect(evidenceFor(2), Evidence.insufficient);
    expect(evidenceFor(3), Evidence.insufficient);
    expect(evidenceFor(4), Evidence.insufficient);
    expect(evidenceFor(5), Evidence.supported);
  });
  test('Patrones excluyen menos de cinco observaciones y limitan a tres', () {
    final list = [
      for (var i = 1; i <= 18; i++)
        r(
          i,
          mood: i <= 9 ? 8 : 2,
          activities: i <= 9 ? ['A', 'B', 'C', 'D'] : ['X'],
        ),
      r(19, activities: ['Solo una']),
    ];
    final patterns = PatternDetectionService().detect(list);
    expect(patterns.length, lessThanOrEqualTo(3));
    expect(patterns.every((p) => p.sampleCount >= 5), isTrue);
    expect(patterns.any((p) => p.activity == 'Solo una'), isFalse);
    expect(patterns.first.explanation, contains('Media del periodo'));
  });
  test('Patrones priorizan observaciones y usan mensajes de asociación', () {
    final list = [
      for (var i = 1; i <= 20; i++)
        r(
          i,
          mood: i <= 12 ? 8 : 1,
          activities: i <= 12 ? ['Frecuente'] : ['Otra'],
        ),
    ];
    final p = PatternDetectionService().detect(list).first;
    expect(p.activity, 'Frecuente');
    expect(p.sampleCount, 12);
    expect(p.message, contains('n=12'));
    expect(p.message, isNot(contains('causa')));
  });
  test('Tendencia conserva fechas ausentes sin cero', () {
    final points = TrendAnalysisService().points([
      r(1),
      r(3),
    ], DateSpan(DateTime(2026, 10, 1), DateTime(2026, 10, 5)));
    expect(points.length, 4);
    expect(points[1].record, isNull);
    expect(points[2].record, isNotNull);
  });
  for (final days in [7, 30]) {
    test('Compara $days días sin solapamiento', () {
      final anchor = DateTime(2026, 10, 30);
      final records = [
        for (var i = 0; i < days * 2; i++)
          Record(
            date: shiftDay(anchor, -i),
            mood: i < days ? Mood.happy : Mood.good,
            energy: 5,
          ),
      ];
      final c = TrendAnalysisService().compare(
        records,
        anchor,
        days,
        Metric.mood,
      );
      expect(c.recentCount, days);
      expect(c.previousCount, days);
      expect(c.difference, 1);
      expect(c.direction, TrendDirection.ascending);
    });
  }
  test('Umbrales y datos insuficientes en comparaciones', () {
    expect(
      const PeriodComparison(5.25, 5, 3, 3).direction,
      TrendDirection.ascending,
    );
    expect(
      const PeriodComparison(4.75, 5, 3, 3).direction,
      TrendDirection.descending,
    );
    expect(
      const PeriodComparison(5.24, 5, 3, 3).direction,
      TrendDirection.stable,
    );
    expect(
      const PeriodComparison(8, 2, 2, 3).direction,
      TrendDirection.insufficient,
    );
  });
  test('Periodos 7,30,90 incluyen fecha de referencia y cruces de año', () {
    for (final p in [
      AnalyticsPeriod.last7,
      AnalyticsPeriod.last30,
      AnalyticsPeriod.last90,
    ]) {
      final s = DateSpan.forPeriod(p, DateTime(2026, 1, 1));
      expect(
        s.days,
        p == AnalyticsPeriod.last7
            ? 7
            : p == AnalyticsPeriod.last30
            ? 30
            : 90,
      );
      expect(s.contains(DateTime(2026, 1, 1)), isTrue);
      expect(s.contains(DateTime(2026, 1, 2)), isFalse);
    }
  });
  test('Sueño convierte horas y minutos y permite vacío/cero', () {
    expect(parseSleep('7', '35'), 455);
    expect(parseSleep('', ''), isNull);
    expect(parseSleep('0', '0'), 0);
    expect(parseSleep('24', '0'), 1440);
    for (final args in [
      ['-1', '0'],
      ['24', '1'],
      ['8', '60'],
      ['abc', '0'],
      ['1.5', '0'],
    ]) {
      expect(() => parseSleep(args[0], args[1]), throwsFormatException);
    }
  });
  test('Pasos valida enteros, límites y ausencia sin convertir en cero', () {
    expect(parseSteps(''), isNull);
    expect(parseSteps('0'), 0);
    expect(parseSteps('200000'), 200000);
    for (final value in ['-1', '200001', '5.5', 'hola']) {
      expect(() => parseSteps(value), throwsFormatException);
    }
  });
  test('Rangos de sueño son exactos en límites', () {
    final s = HealthAnalyticsService();
    expect([359, 360, 419, 420, 540, 541].map(s.sleepBucket), [
      0,
      1,
      1,
      2,
      2,
      3,
    ]);
  });
  test('Rangos de pasos son exactos en límites', () {
    final s = HealthAnalyticsService();
    expect([1999, 2000, 4999, 5000, 7999, 8000].map(s.stepBucket), [
      0,
      1,
      1,
      2,
      2,
      3,
    ]);
  });
  test('Cruce por dateKey, campos parciales y ceros válidos', () {
    final h = HealthAnalyticsService().analyze(
      [r(1, mood: 8), r(2, mood: 2)],
      [
        DailyHealthData(date: DateTime(2026, 10, 1, 23), sleepMinutes: 480),
        DailyHealthData(date: DateTime(2026, 10, 2), steps: 0),
        DailyHealthData(date: DateTime(2026, 10, 3), steps: 10000),
      ],
      span,
    );
    expect(h.pairedDays, 2);
    expect(h.sleepDays, 1);
    expect(h.stepDays, 1);
    expect(h.sleepAverage, 480);
    expect(h.stepsAverage, 0);
    expect(h.sleep[2].moodAverage, 8);
    expect(h.patterns, isEmpty);
  });
  test('Health vacío no fabrica promedios ni patrones', () {
    final h = HealthAnalyticsService().analyze([r(1)], [], span);
    expect(h.sleepAverage, isNull);
    expect(h.stepsAverage, isNull);
    expect(h.pairedDays, 0);
    expect(h.patterns, isEmpty);
    expect(h.sleep.every((g) => g.moodAverage == null), isTrue);
  });
  test('Patrones de salud requieren cinco y 14 días y se limitan a dos', () {
    final records = [for (var i = 1; i <= 20; i++) r(i, mood: i <= 10 ? 8 : 2)];
    final health = [
      for (var i = 1; i <= 20; i++)
        DailyHealthData(
          date: DateTime(2026, 10, i),
          sleepMinutes: i <= 10 ? 480 : 300,
          steps: i <= 10 ? 9000 : 1000,
        ),
    ];
    final h = HealthAnalyticsService().analyze(records, health, span);
    expect(h.patterns.length, 2);
    expect(h.patterns.every((p) => p.group.count >= 5), isTrue);
    expect(h.patterns.first.explanation, contains('No demuestra causalidad'));
  });
}
