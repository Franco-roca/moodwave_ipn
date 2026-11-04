import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../records/domain/record.dart';
import '../domain/daily_health.dart';

const healthSchema = '''CREATE TABLE daily_health_data (
id INTEGER PRIMARY KEY AUTOINCREMENT, dateKey TEXT NOT NULL UNIQUE, fecha INTEGER NOT NULL,
sleepMinutes INTEGER CHECK(sleepMinutes BETWEEN 0 AND 1440), steps INTEGER CHECK(steps BETWEEN 0 AND 200000),
source TEXT NOT NULL CHECK(source IN ('manual','health_connect','imported','synthetic')), updatedAt INTEGER NOT NULL,
isTest INTEGER NOT NULL DEFAULT 0)''';

class HealthRepository {
  HealthRepository(this.db);
  final Database db;
  final _changes = StreamController<void>.broadcast();
  Future<List<DailyHealthData>> all() async => (await db.query(
    'daily_health_data',
    orderBy: 'dateKey DESC',
  )).map(DailyHealthData.fromMap).toList();
  Future<DailyHealthData?> byDate(DateTime date) async {
    final rows = await db.query(
      'daily_health_data',
      where: 'dateKey=?',
      whereArgs: [dateKey(date)],
    );
    return rows.isEmpty ? null : DailyHealthData.fromMap(rows.first);
  }

  Future<List<DailyHealthData>> byRange(DateTime start, DateTime end) async =>
      (await db.query(
        'daily_health_data',
        where: 'dateKey>=? AND dateKey<?',
        whereArgs: [dateKey(start), dateKey(end)],
        orderBy: 'dateKey',
      )).map(DailyHealthData.fromMap).toList();
  Stream<List<DailyHealthData>> watch() async* {
    yield await all();
    yield* _changes.stream.asyncMap((_) => all());
  }

  void changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> save(DailyHealthData data) async {
    await db.transaction((t) async {
      await upsert(t, data);
      await t.delete('prediction_model');
    });
    changed();
  }

  Future<void> delete(DateTime date) async {
    await db.transaction((t) async {
      await t.delete(
        'daily_health_data',
        where: 'dateKey=?',
        whereArgs: [dateKey(date)],
      );
      await t.delete('prediction_model');
    });
    changed();
  }

  Future<int> importRange(
    List<DailyHealthData> data, {
    bool replaceManual = false,
  }) async {
    var count = 0;
    await db.transaction((t) async {
      for (final h in data) {
        final existing = await t.query(
          'daily_health_data',
          where: 'dateKey=?',
          whereArgs: [h.dateKeyValue],
        );
        if (!replaceManual &&
            existing.isNotEmpty &&
            existing.first['source'] != 'health_connect') {
          continue;
        }
        await upsert(t, h);
        count++;
      }
      if (count > 0) await t.delete('prediction_model');
    });
    changed();
    return count;
  }

  static Future<void> upsert(DatabaseExecutor db, DailyHealthData data) async {
    if (data.isEmpty) {
      await db.delete(
        'daily_health_data',
        where: 'dateKey=?',
        whereArgs: [data.dateKeyValue],
      );
      return;
    }
    final n = await db.update(
      'daily_health_data',
      data.toMap(),
      where: 'dateKey=?',
      whereArgs: [data.dateKeyValue],
    );
    if (n == 0) await db.insert('daily_health_data', data.toMap());
  }

  Future<void> dispose() => _changes.close();
}
