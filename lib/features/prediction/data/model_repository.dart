import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/learning.dart';
import '../../records/domain/record.dart';
import '../../health/domain/daily_health.dart';

const modelSchema =
    'CREATE TABLE prediction_model (id INTEGER PRIMARY KEY CHECK(id IN (1,2)), payload TEXT NOT NULL)';

class ModelRepository {
  ModelRepository(this.db);
  final Database db;
  Future<void> save(TrainedModel model) => db
      .insert('prediction_model', {
        'id': model.synthetic ? 2 : 1,
        'payload': jsonEncode(model.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<TrainedModel?> load({bool synthetic = false}) async {
    final rows = await db.query(
      'prediction_model',
      where: 'id=?',
      whereArgs: [synthetic ? 2 : 1],
    );
    if (rows.isEmpty) return null;
    try {
      return TrainedModel.fromJson(jsonDecode(rows.first['payload'] as String));
    } catch (_) {
      await db.delete(
        'prediction_model',
        where: 'id=?',
        whereArgs: [synthetic ? 2 : 1],
      );
      return null;
    }
  }

  Future<void> delete() async {
    await db.delete('prediction_model');
  }
}

List<Observation> observationsFrom(
  List<Record> records,
  List<DailyHealthData> health, {
  required bool synthetic,
}) {
  final map = {
    for (final h in health.where((h) => h.isSynthetic == synthetic))
      h.dateKeyValue: h,
  };
  return records.where((r) => r.test == synthetic).map((r) {
    final h = map[dateKey(r.date)];
    return Observation(
      date: r.date,
      mood: r.mood.value,
      energy: r.energy,
      sleep: h?.sleepMinutes?.toDouble(),
      steps: h?.steps?.toDouble(),
      activities: r.activities,
      synthetic: r.test,
      revision:
          r.updated.millisecondsSinceEpoch +
          (h?.updatedAt.millisecondsSinceEpoch ?? 0),
    );
  }).toList()..sort((a, b) => a.date.compareTo(b.date));
}
