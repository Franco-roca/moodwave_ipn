import '../../records/domain/record.dart';
import '../../health/domain/daily_health.dart';

/// Explicit whitelist; never accepts security storage or preference maps.
class DataExportService {
  Map<String, Object?> build({
    required List<Record> records,
    required List<DailyHealthData> health,
    required List<String> activities,
    required String theme,
    required DateTime now,
  }) => {
    'schemaVersion': 4,
    'exportedAt': now.toUtc().toIso8601String(),
    'emociones': [
      for (final r in records)
        {
          'dateKey': dateKey(r.date),
          'mood': r.mood.value,
          'energy': r.energy,
          'activities': r.activities,
          'reflection': r.reflection,
          'updatedAt': r.updated.toIso8601String(),
          'isSynthetic': r.test,
        },
    ],
    'salud': [
      for (final h in health)
        {
          'dateKey': h.dateKeyValue,
          'sleepMinutes': h.sleepMinutes,
          'steps': h.steps,
          'source': h.source == HealthSource.healthConnect
              ? 'health_connect'
              : h.source.name,
          'updatedAt': h.updatedAt.toIso8601String(),
          'isSynthetic': h.isSynthetic,
        },
    ],
    'actividades': activities,
    'preferencias': {'theme': theme},
  };
}
