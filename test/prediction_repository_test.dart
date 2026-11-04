import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moodwave/features/records/data/record_repository.dart';
import 'package:moodwave/features/records/domain/synthetic_data_generator.dart';
import 'package:moodwave/features/prediction/data/model_repository.dart';
import 'package:moodwave/features/prediction/domain/learning.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  test(
    'Dos modelos reales persisten por separado y cambian con registros',
    () async {
      final repository = await RecordRepository.open(
        databasePath: inMemoryDatabasePath,
      );
      final models = ModelRepository(repository.db);
      final days = SyntheticDataGenerator().generate(DateTime(2026, 10, 31));
      final observations = observationsFrom(
        days.map((d) => d.record).toList(),
        days.map((d) => d.health).toList(),
        synthetic: true,
      );
      final demo = MoodPredictionService()
          .train(observations, DateTime(2026, 10, 31))
          .model!;
      final personalData = observations
          .map(
            (o) => Observation(
              date: o.date,
              mood: o.mood,
              energy: o.energy,
              sleep: o.sleep,
              steps: o.steps,
              activities: o.activities,
              synthetic: false,
            ),
          )
          .toList();
      final personal = MoodPredictionService()
          .train(personalData, DateTime(2026, 10, 31))
          .model!;
      await models.save(demo);
      await models.save(personal);
      expect((await models.load())!.synthetic, isFalse);
      expect(
        (await models.load(synthetic: true))!.coefficients,
        demo.coefficients,
      );
      await repository.save(days.first.record);
      expect(await models.load(), isNull);
      expect(await models.load(synthetic: true), isNull);
      await repository.db.close();
    },
  );
}
