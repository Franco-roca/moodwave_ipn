import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moodwave/features/records/data/record_repository.dart';
import 'package:moodwave/features/records/domain/record.dart';
import 'package:moodwave/features/health/data/health_repository.dart';
import 'package:moodwave/features/health/domain/daily_health.dart';

void main() {
  late RecordRepository records;
  late HealthRepository health;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    records = await RecordRepository.open(databasePath: inMemoryDatabasePath);
    health = HealthRepository(records.db);
  });
  tearDown(() async {
    await health.dispose();
    await records.db.close();
  });
  test('Guarda, actualiza, consulta rangos y elimina salud', () async {
    final date = DateTime(2026, 10, 30);
    await health.save(
      DailyHealthData(date: date, sleepMinutes: 480, steps: 7840),
    );
    final id = (await health.byDate(date))!.id;
    await health.save(
      DailyHealthData(
        date: date,
        sleepMinutes: 450,
        source: HealthSource.imported,
      ),
    );
    expect((await health.all()).length, 1);
    expect((await health.byDate(date))!.id, id);
    expect((await health.byDate(date))!.source, HealthSource.imported);
    expect(
      (await health.byRange(
        DateTime(2026, 10, 1),
        DateTime(2026, 11, 1),
      )).length,
      1,
    );
    await health.delete(date);
    expect(await health.all(), isEmpty);
  });
  test('Fuentes manual, importada y health_connect se conservan', () async {
    for (var i = 0; i < 3; i++) {
      await health.save(
        DailyHealthData(
          date: DateTime(2026, 10, i + 1),
          steps: 100,
          source: HealthSource.values[i],
        ),
      );
    }
    for (var i = 0; i < 3; i++) {
      expect(
        (await health.byDate(DateTime(2026, 10, i + 1)))!.source,
        HealthSource.values[i],
      );
    }
  });
  test('Emoción se guarda sin salud', () async {
    await records.save(
      Record(date: DateTime(2026), mood: Mood.good, energy: 5),
      updateHealth: true,
    );
    expect((await records.all()).length, 1);
    expect(await health.all(), isEmpty);
  });
  test('Transacción revierte emoción cuando falla salud', () async {
    final date = DateTime(2026, 10, 1);
    await records.save(Record(date: date, mood: Mood.sad, energy: 3));
    await records.db.execute(
      "CREATE TRIGGER reject_health BEFORE INSERT ON daily_health_data BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      records.save(
        Record(date: date, mood: Mood.happy, energy: 8),
        health: DailyHealthData(date: date, sleepMinutes: 480),
        updateHealth: true,
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect((await records.byDate(date))!.mood, Mood.sad);
    expect(await health.all(), isEmpty);
  });
  test('Watch emite el estado inicial y los cambios', () async {
    final iterator = StreamIterator(health.watch());
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, isEmpty);
    final next = iterator.moveNext();
    await health.save(DailyHealthData(date: DateTime(2026), steps: 500));
    expect(await next, isTrue);
    expect(iterator.current.single.steps, 500);
    await iterator.cancel();
  });
  test('Migración v2 a v4 conserva datos y agrega tabla', () async {
    final temp = await Directory.systemTemp.createTemp('moodwave-migration-');
    final path = '${temp.path}/old.db';
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, v) async {
          await db.execute(
            'CREATE TABLE registros (id INTEGER PRIMARY KEY AUTOINCREMENT, dateKey TEXT NOT NULL UNIQUE, fecha INTEGER NOT NULL, estadoAnimo INTEGER NOT NULL, nivelEnergia INTEGER NOT NULL, actividades TEXT NOT NULL, reflexion TEXT NOT NULL, horaActualizacion INTEGER NOT NULL, isTest INTEGER NOT NULL DEFAULT 0)',
          );
        },
      ),
    );
    await old.insert(
      'registros',
      Record(
        date: DateTime(2026, 10, 30),
        mood: Mood.excellent,
        energy: 8,
        reflection: 'Se conserva',
      ).toMap(),
    );
    await old.close();
    final upgraded = await RecordRepository.open(databasePath: path);
    expect(await upgraded.db.getVersion(), 4);
    expect((await upgraded.all()).single.reflection, 'Se conserva');
    expect((await HealthRepository(upgraded.db).all()), isEmpty);
    await upgraded.db.close();
    expect(
      temp.absolute.path.startsWith(Directory.systemTemp.absolute.path),
      isTrue,
    );
    await temp.delete(recursive: true);
  });
  test('Generador no sobrescribe salud real y elimina solo pruebas', () async {
    final now = DateTime(2026, 10, 30);
    await health.save(DailyHealthData(date: shiftDay(now, -1), steps: 123));
    await records.generate(now);
    expect((await health.byDate(shiftDay(now, -1)))!.steps, 123);
    await records.deleteTests();
    expect((await health.all()).single.steps, 123);
  });
  test('Migración v3 conserva IDs, manuales y sintéticos e invalida modelo al editar', () async {
    final temp = await Directory.systemTemp.createTemp('moodwave-v3-');
    final path = '${temp.path}/v3.db';
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, v) async {
          await db.execute(
            'CREATE TABLE registros (id INTEGER PRIMARY KEY AUTOINCREMENT, dateKey TEXT NOT NULL UNIQUE, fecha INTEGER NOT NULL, estadoAnimo INTEGER NOT NULL, nivelEnergia INTEGER NOT NULL, actividades TEXT NOT NULL, reflexion TEXT NOT NULL, horaActualizacion INTEGER NOT NULL, isTest INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute(healthSchema.replaceAll(",'synthetic'", ''));
        },
      ),
    );
    final real = DailyHealthData(date: DateTime(2026, 10, 1), steps: 123);
    await old.insert('daily_health_data', real.toMap());
    await old.insert(
      'daily_health_data',
      DailyHealthData(
        date: DateTime(2026, 10, 2),
        steps: 456,
        isTest: true,
      ).toMap(),
    );
    await old.insert(
      'registros',
      Record(
        date: DateTime(2026, 10, 1),
        mood: Mood.good,
        energy: 6,
        reflection: 'Conservar',
      ).toMap(),
    );
    final id = (await old.query('daily_health_data')).first['id'];
    await old.close();
    final upgraded = await RecordRepository.open(databasePath: path);
    final repo = HealthRepository(upgraded.db);
    expect(await upgraded.db.getVersion(), 4);
    expect((await upgraded.all()).single.reflection, 'Conservar');
    expect((await repo.byDate(real.date))!.id, id);
    expect(
      (await repo.byDate(DateTime(2026, 10, 2)))!.source,
      HealthSource.synthetic,
    );
    await upgraded.db.insert('prediction_model', {'id': 1, 'payload': 'test'});
    await repo.save(DailyHealthData(date: real.date, steps: 789));
    expect(await upgraded.db.query('prediction_model'), isEmpty);
    await upgraded.db.close();
    await repo.dispose();
    expect(
      temp.absolute.path.startsWith(Directory.systemTemp.absolute.path),
      isTrue,
    );
    await temp.delete(recursive: true);
  });
  test('Importación por rango conserva manual salvo confirmación y evita duplicados', () async {
    final date = DateTime(2026, 10, 1);
    await health.save(DailyHealthData(date: date, steps: 123));
    final imported = [
      DailyHealthData(
        date: date,
        steps: 500,
        source: HealthSource.healthConnect,
      ),
    ];
    expect(await health.importRange(imported), 0);
    expect((await health.byDate(date))!.steps, 123);
    expect(await health.importRange(imported, replaceManual: true), 1);
    expect((await health.byDate(date))!.steps, 500);
    await health.importRange(imported);
    expect((await health.all()).length, 1);
  });
}
