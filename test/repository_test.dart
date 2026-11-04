import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moodwave/features/records/domain/record.dart';
import 'package:moodwave/features/records/data/record_repository.dart';

void main() {
  late RecordRepository repo;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    repo = await RecordRepository.open(databasePath: inMemoryDatabasePath);
  });
  tearDown(() async => repo.db.close());
  test('Los datos sobreviven a cerrar y abrir la base', () async {
    final directory = await Directory.systemTemp.createTemp('moodwave-test-');
    final path = '${directory.path}/diary.db';
    var disk = await RecordRepository.open(databasePath: path);
    await disk.save(
      Record(date: DateTime(2026, 10, 30), mood: Mood.excellent, energy: 9),
    );
    await disk.db.close();
    disk = await RecordRepository.open(databasePath: path);
    expect((await disk.all()).single.mood, Mood.excellent);
    await disk.db.close();
    await directory.delete(recursive: true);
  });
  test('Un día se actualiza sin duplicar ni cambiar id', () async {
    await repo.save(
      Record(date: DateTime(2026, 10, 30, 8), mood: Mood.good, energy: 5),
    );
    final id = (await repo.all()).first.id;
    await repo.save(
      Record(date: DateTime(2026, 10, 30, 22), mood: Mood.happy, energy: 8),
    );
    expect((await repo.all()).length, 1);
    expect((await repo.byDate(DateTime(2026, 10, 30)))!.mood, Mood.happy);
    expect((await repo.byId(id!))!.energy, 8);
  });
  test('Generador no sobrescribe y genera valores válidos', () async {
    final now = DateTime(2026, 10, 30);
    await repo.save(
      Record(
        date: shiftDay(now, -1),
        mood: Mood.angry,
        energy: 1,
        reflection: 'Personal',
      ),
    );
    await repo.generate(now);
    await repo.generate(now);
    final list = await repo.all();
    expect(list.length, 120);
    expect((await repo.byDate(shiftDay(now, -1)))!.reflection, 'Personal');
    for (final r in list.where((r) => r.test)) {
      expect(r.mood.value, inInclusiveRange(1, 8));
      expect(r.energy, inInclusiveRange(1, 10));
      expect(r.activities.length, greaterThanOrEqualTo(2));
      expect(r.reflection, startsWith('[SINTÉTICO]'));
    }
    await repo.deleteTests();
    expect((await repo.all()).length, 1);
  });
  test('Eliminar uno y todos', () async {
    await repo.save(Record(date: DateTime(2026), mood: Mood.good, energy: 5));
    await repo.delete((await repo.all()).first.id!);
    expect(await repo.all(), isEmpty);
    await repo.save(Record(date: DateTime(2026), mood: Mood.good, energy: 5));
    await repo.deleteAll();
    expect(await repo.all(), isEmpty);
  });
}
