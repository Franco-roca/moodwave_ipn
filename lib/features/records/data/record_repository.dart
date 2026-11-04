import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../domain/synthetic_data_generator.dart';
import '../../prediction/data/model_repository.dart';

import '../../health/data/health_repository.dart';
import '../../health/domain/daily_health.dart';

import '../domain/record.dart';

class RecordRepository {
  RecordRepository(this.db);
  final Database db;
  static Future<RecordRepository> open({
    String? databasePath,
  }) async => RecordRepository(
    await openDatabase(
      databasePath ?? p.join(await getDatabasesPath(), 'moodwave.db'),
      version: 4,
      onCreate: (db, v) async {
        await db.execute(
          'CREATE TABLE registros (id INTEGER PRIMARY KEY AUTOINCREMENT, dateKey TEXT NOT NULL UNIQUE, fecha INTEGER NOT NULL, estadoAnimo INTEGER NOT NULL CHECK(estadoAnimo BETWEEN 1 AND 8), nivelEnergia INTEGER NOT NULL CHECK(nivelEnergia BETWEEN 1 AND 10), actividades TEXT NOT NULL, reflexion TEXT NOT NULL, horaActualizacion INTEGER NOT NULL, isTest INTEGER NOT NULL DEFAULT 0)',
        );
        await db.execute(healthSchema);
        await db.execute(modelSchema);
      },
      onUpgrade: (db, old, v) async {
        if (old < 2) {
          await db.execute(
            'ALTER TABLE registros ADD COLUMN isTest INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            "UPDATE registros SET isTest=1 WHERE reflexion LIKE '[PRUEBA]%'",
          );
        }
        if (old < 3) await db.execute(healthSchema);
        if (old < 4) {
          if (old >= 3) {
            await db.execute(
              'ALTER TABLE daily_health_data RENAME TO health_v3',
            );
            await db.execute(healthSchema);
            await db.execute(
              "INSERT INTO daily_health_data (id,dateKey,fecha,sleepMinutes,steps,source,updatedAt,isTest) SELECT id,dateKey,fecha,sleepMinutes,steps,CASE WHEN isTest=1 THEN 'synthetic' ELSE source END,updatedAt,isTest FROM health_v3",
            );
            await db.execute('DROP TABLE health_v3');
          }
          await db.execute(modelSchema);
        }
      },
    ),
  );
  Future<List<Record>> all() async => (await db.query(
    'registros',
    orderBy: 'dateKey DESC',
  )).map(Record.fromMap).toList();
  Future<Record?> byDate(DateTime date) async {
    final r = await db.query(
      'registros',
      where: 'dateKey=?',
      whereArgs: [dateKey(date)],
    );
    return r.isEmpty ? null : Record.fromMap(r.first);
  }

  Future<Record?> byId(int id) async {
    final r = await db.query('registros', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : Record.fromMap(r.first);
  }

  Future<void> save(
    Record r, {
    DailyHealthData? health,
    bool updateHealth = false,
  }) async {
    if (health != null && health.dateKeyValue != dateKey(r.date)) {
      throw ArgumentError('Las fechas deben coincidir.');
    }
    if (r.reflection.characters.length > 300) {
      throw ArgumentError('Máximo 300 caracteres');
    }
    await db.transaction((t) async {
      final n = await t.update(
        'registros',
        r.toMap(),
        where: 'dateKey=?',
        whereArgs: [dateKey(r.date)],
      );
      if (n == 0) await t.insert('registros', r.toMap());
      await t.delete('prediction_model');
      if (updateHealth) {
        if (health == null) {
          await t.delete(
            'daily_health_data',
            where: 'dateKey=?',
            whereArgs: [dateKey(r.date)],
          );
        } else {
          await HealthRepository.upsert(t, health);
        }
      }
    });
  }

  Future<void> delete(int id) async {
    await db.transaction((t) async {
      final rows = await t.query(
        'registros',
        columns: ['dateKey'],
        where: 'id=?',
        whereArgs: [id],
      );
      if (rows.isNotEmpty) {
        await t.delete(
          'daily_health_data',
          where: 'dateKey=?',
          whereArgs: [rows.first['dateKey']],
        );
      }
      await t.delete('registros', where: 'id=?', whereArgs: [id]);
      await t.delete('prediction_model');
    });
  }

  Future<void> deleteTests() async {
    await db.transaction((t) async {
      await t.delete('daily_health_data', where: 'isTest=1');
      await t.delete('registros', where: 'isTest=1');
      await t.delete('prediction_model');
    });
  }

  Future<void> deleteAll() async {
    await db.transaction((t) async {
      await t.delete('daily_health_data');
      await t.delete('registros');
      await t.delete('prediction_model');
    });
  }

  Future<void> generate(
    DateTime now, {
    bool withGaps = false,
    int seed = 42,
    bool replaceSynthetic = false,
    bool emotional = true,
    bool physical = true,
  }) async {
    final days = SyntheticDataGenerator().generate(
      now,
      seed: seed,
      withGaps: withGaps,
    );
    await db.transaction((t) async {
      if (replaceSynthetic) {
        await t.delete('daily_health_data', where: 'isTest=1');
        await t.delete('registros', where: 'isTest=1');
      }
      for (final d in days) {
        if (emotional && (await t.query(
          'registros',
          columns: ['id'],
          where: 'dateKey=?',
          whereArgs: [dateKey(d.record.date)],
        )).isNotEmpty) {
          continue;
        }
        if (emotional) {
          await t.insert('registros', d.record.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        if (physical) {
          await t.insert('daily_health_data', d.health.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      await t.delete('prediction_model');
    });
  }
}
