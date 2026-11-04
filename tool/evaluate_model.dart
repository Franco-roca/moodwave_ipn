import 'dart:convert';
import 'dart:io';

import 'package:moodwave/features/records/domain/synthetic_data_generator.dart';
import 'package:moodwave/features/prediction/domain/learning.dart';

void main() {
  final days = SyntheticDataGenerator().generate(
    DateTime(2026, 10, 31),
    seed: 20261031,
    withGaps: true,
  );
  final observations = days
      .map(
        (d) => Observation(
          date: d.record.date,
          mood: d.record.mood.value,
          energy: d.record.energy,
          sleep: d.health.sleepMinutes?.toDouble(),
          steps: d.health.steps?.toDouble(),
          activities: d.record.activities,
          synthetic: true,
        ),
      )
      .toList();
  final result = MoodPredictionService().train(
    observations,
    DateTime(2026, 10, 31),
  );
  final model = result.model;
  if (model == null) throw StateError(result.message);
  final output = {
    'data': 'synthetic-only',
    'seed': 20261031,
    'samples': model.sampleCount,
    'trainCount': model.trainCount,
    'trainPositive': model.trainPositives,
    'trainDateRange': model.trainDateRange,
    'testDateRange': model.testDateRange,
    'model': model.metrics.toJson(),
    'baseline': model.baseline.toJson(),
    'beatsBaseline': model.beatsBaseline,
    'nonzeroCoefficients': model.coefficients
        .where((w) => w.abs() > 1e-8)
        .length,
    'initialLoss': model.fit.initialLoss,
    'finalLoss': model.fit.finalLoss,
    'iterations': model.fit.iterations,
    'converged': model.fit.converged,
    'modelBytes': utf8.encode(jsonEncode(model.toJson())).length,
    'modelVersion': TrainedModel.modelVersion,
  };
  Directory('output').createSync(recursive: true);
  File('output/model-evaluation.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(output));
}
