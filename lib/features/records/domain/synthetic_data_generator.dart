import 'dart:math';

import 'record.dart';
import '../../health/domain/daily_health.dart';

class SyntheticDay {
  const SyntheticDay(this.record, this.health);
  final Record record;
  final DailyHealthData health;
}

class SyntheticDataGenerator {
  List<SyntheticDay> generate(
    DateTime anchor, {
    int seed = 42,
    int days = 120,
    bool withGaps = true,
  }) {
    final rng = Random(seed), result = <SyntheticDay>[];
    // Cuatro periodos permiten probar tendencias sin crear una serie perfecta.
    final activityPool = <String>[
      'Ejercicio',
      'Caminata',
      'Estudio',
      'Trabajo',
      'Descanso',
      'Amigos',
      'Meditación',
      'Entretenimiento',
      'Aire libre',
      'Tareas domésticas',
    ];
    for (var i = 0; i < days; i++) {
      final date = shiftDay(day(anchor), i - days + 1);
      final period = i ~/ 30;
      final exercise = rng.nextDouble() < [.22, .38, .28, .34][period],
          walk = rng.nextDouble() < [.35, .55, .42, .60][period],
          work = rng.nextDouble() < [.40, .48, .68, .42][period],
          study = rng.nextDouble() < [.42, .48, .65, .38][period],
          social = rng.nextDouble() < [.15, .20, .18, .32][period];
      final sleep = period == 2
          ? 330 + rng.nextInt(300)
          : period == 3
          ? 390 + rng.nextInt(220)
          : 360 + rng.nextInt(300);
      final steps =
          (period == 0
              ? 1800
              : period == 1
              ? 5800
              : period == 2
              ? 4300
              : 7200) +
          rng.nextInt(5200);
      final weekday = date.weekday;
      final stressDay = i >= days - 28 && i % 3 == 0;
      final dayEffect = weekday == DateTime.monday
          ? -.25
          : weekday == DateTime.friday
          ? .25
          : 0;
      final activityEffect =
          (exercise ? 1.0 : 0) +
          (walk ? .45 : 0) +
          (social ? .45 : 0) -
          (work ? .25 : 0);
      final sleepEffect = sleep >= 420 && sleep <= 540
          ? .45
          : sleep < 360
          ? -.55
          : 0;
      var mood =
          (4.0 +
                  period * .25 +
                  activityEffect +
                  sleepEffect +
                  (steps >= 8000 ? .55 : 0) +
                  dayEffect +
                  (rng.nextDouble() * 2 - 1.0))
              .round()
              .clamp(1, 8)
              .toInt();
      // Garantiza variación de ambas clases en la ventana de prueba temporal,
      // sin convertir los datos en una serie perfectamente periódica.
      if (stressDay) {
        mood = 2 + (i ~/ 7) % 3;
      }
      final energy =
          (5.0 +
                  period * .15 +
                  (exercise ? 1.0 : 0) +
                  (steps >= 8000 ? .75 : 0) +
                  sleepEffect * 1.5 -
                  (work ? 1.4 : 0) +
                  (stressDay ? 1.8 : 0) * -1 +
                  (rng.nextDouble() * 2 - 1.0))
              .round()
              .clamp(1, 10)
              .toInt();
      final activities = <String>[];
      if (exercise) activities.add(activityPool[0]);
      if (walk) activities.add(activityPool[1]);
      if (study) activities.add(activityPool[2]);
      if (work) activities.add(activityPool[3]);
      if (social) activities.add(activityPool[5]);
      if (weekday == DateTime.sunday || rng.nextDouble() < .25)
        activities.add(activityPool[4]);
      if (activities.isEmpty) {
        activities.add('Tareas domésticas');
      }
      if (activities.length == 1) {
        activities.add(weekday == DateTime.sunday ? 'Descanso' : 'Estudio');
      }
      final record = Record(
        date: date,
        mood: Mood.values[mood - 1],
        energy: energy,
        activities: activities,
        reflection: '[SINTÉTICO] Escenario de demostración; no representa una experiencia personal.',
        updated: day(anchor),
        test: true,
      );
      final health = DailyHealthData(
        date: date,
        sleepMinutes: i % 11 == 0 ? null : (sleep / 5).round() * 5,
        steps: i % 17 == 0 ? null : steps,
        source: HealthSource.synthetic,
        updatedAt: day(anchor),
        isTest: true,
      );
      if (withGaps && (i == 12 || i == 39 || i == 67 || i == 81)) continue;
      result.add(SyntheticDay(record, health));
    }
    return result;
  }
}
