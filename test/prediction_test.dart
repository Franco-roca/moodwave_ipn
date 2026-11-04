import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:moodwave/features/prediction/domain/learning.dart';
import 'package:moodwave/features/records/domain/synthetic_data_generator.dart';

List<Observation> sample({int seed = 42}) => SyntheticDataGenerator()
    .generate(DateTime(2026, 10, 31), seed: seed, withGaps: true)
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
void main() {
  late List<Observation> data;
  late TrainedModel model;
  setUpAll(() {
    data = sample();
    model = MoodPredictionService().train(data, DateTime(2026, 10, 31)).model!;
  });
  test('Sigmoide estable y entropía verificable', () {
    expect(sigmoid(0), .5);
    expect(sigmoid(1000), closeTo(1, 1e-12));
    expect(sigmoid(-1000), closeTo(0, 1e-12));
    expect(binaryCrossEntropy(.5, 1), closeTo(math.log(2), 1e-12));
  });
  test('Convergencia detiene entrenamiento antes del límite', () {
    final fit = LogisticRegressionTrainer().train(
      [
        [-1],
        [1],
      ],
      [0, 1],
      config: const TrainerConfig(l2: .1, tolerance: 1e-5, maxIterations: 2000),
    );
    expect(fit.converged, isTrue);
    expect(fit.iterations, lessThan(2000));
    expect(fit.finalLoss, lessThan(fit.initialLoss));
    expect(fit.coefficients.single, greaterThan(0));
  });
  test('Gradiente coincide con diferencias finitas', () {
    final trainer = LogisticRegressionTrainer(),
        x = [
          [1.0, 2.0],
          [-1.0, .5],
        ],
        y = [1, 0],
        w = [.2, -.3];
    const b = .1, l2 = .02, e = 1e-5;
    final g = trainer.gradient(x, y, w, b, l2);
    for (var j = 0; j < 2; j++) {
      final a = [...w], c = [...w];
      a[j] += e;
      c[j] -= e;
      expect(
        g.weights[j],
        closeTo(
          (trainer.loss(x, y, a, b, l2) - trainer.loss(x, y, c, b, l2)) /
              (2 * e),
          1e-6,
        ),
      );
    }
    expect(
      g.intercept,
      closeTo(
        (trainer.loss(x, y, w, b + e, l2) - trainer.loss(x, y, w, b - e, l2)) /
            (2 * e),
        1e-6,
      ),
    );
  });
  test('Imputación y normalización solo usan entrenamiento', () {
    final n = Normalization.fit([
      [1.0, null],
      [3.0, 10.0],
    ]);
    expect(n.means, [2, 10]);
    expect(n.medians, [2, 10]);
    expect(n.std, [1, 1]);
    expect(n.transform([10000, null]), [8, 0]);
    expect(n.means, [2, 10]);
  });
  test('Features no consultan observaciones futuras ni vocabulario futuro', () {
    final e = FeatureEngineeringService();
    final a = data.take(6).toList();
    final b = [
      ...a,
      Observation(
        date: DateTime(2099),
        mood: 1,
        energy: 1,
        sleep: 0,
        activities: ['solo futuro'],
      ),
    ];
    final vocabulary = e.vocabulary(a);
    expect(vocabulary, isNot(contains('solo futuro')));
    expect(e.at(a, 3, vocabulary), e.at(b, 3, vocabulary));
  });
  test(
    'Modelo aprende coeficientes, reduce pérdida y se evalúa contra baseline',
    () {
      expect(model.coefficients.any((w) => w.abs() > .01), isTrue);
      expect(model.fit.finalLoss, lessThan(model.fit.initialLoss));
      expect(
        model.metrics.balancedAccuracy,
        greaterThan(model.baseline.balancedAccuracy!),
      );
      expect(model.beatsBaseline, isTrue);
      expect(model.metrics.count, greaterThan(0));
    },
  );
  test('División temporal sin fuga entre fechas objetivo', () {
    expect(
      DateTime.parse(model.trainDateRange.last)
          .isBefore(DateTime.parse(model.testDateRange.first)),
      isTrue,
    );
    expect(model.trainCount / model.sampleCount, closeTo(.8, .02));
  });
  test('Matriz, accuracy balanceada, precision, recall y F1', () {
    const m = ConfusionMatrix(3, 1, 4, 2);
    expect(m.accuracy, .7);
    expect(m.balancedAccuracy, .7);
    expect(m.precision, .75);
    expect(m.recall, .6);
    expect(m.f1, closeTo(2 / 3, 1e-12));
    expect(const ConfusionMatrix(0, 0, 5, 0).balancedAccuracy, isNull);
  });
  test('Cold start, clase única y ejemplos escasos no entrenan', () {
    final service = MoodPredictionService();
    expect(service.train(data.take(20).toList(), DateTime(2026)).model, isNull);
    final one = data
        .map((o) => Observation(date: o.date, mood: 2, energy: o.energy))
        .toList();
    expect(service.train(one, DateTime(2026)).model, isNull);
  });
  test('Persistencia JSON completa y versión incompatible', () {
    final encoded =
        jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>;
    final restored = TrainedModel.fromJson(encoded);
    expect(restored.coefficients, model.coefficients);
    expect(restored.normalization.medians, model.normalization.medians);
    expect(restored.metrics.toJson(), model.metrics.toJson());
    encoded['featureVersion'] = 999;
    expect(() => TrainedModel.fromJson(encoded), throwsFormatException);
  });
  test('Inferencia y contribuciones reconstruyen el cálculo real', () {
    final p = MoodPredictionService().infer(model, data);
    expect(
      p.probability,
      closeTo(
        sigmoid(
          model.intercept +
              p.contributions.values.fold<double>(0, (s, v) => s + v),
        ),
        1e-12,
      ),
    );
    expect(p.probability, inInclusiveRange(0, 1));
  });
  test(
    'Cambiar datos invalida el modelo y produce otra predicción al entrenar',
    () {
      final service = MoodPredictionService(), last = data.last;
      final changed = [
        ...data.take(data.length - 1),
        Observation(
          date: last.date,
          mood: last.mood,
          energy: last.energy < 5 ? 10 : 1,
          sleep: last.sleep,
          steps: last.steps,
          activities: last.activities,
          synthetic: true,
        ),
      ];
      expect(() => service.infer(model, changed), throwsStateError);
      final other = service.train(changed, DateTime(2026)).model!;
      expect(
        (service.infer(model, data).probability -
                service.infer(other, changed).probability)
            .abs(),
        greaterThan(.01),
      );
    },
  );
  test('Faltantes mantienen probabilidades finitas', () {
    final missing = data
        .map(
          (o) => Observation(
            date: o.date,
            mood: o.mood,
            energy: o.energy,
            activities: o.activities,
            synthetic: true,
          ),
        )
        .toList();
    final m = MoodPredictionService().train(missing, DateTime(2026)).model!;
    final p = MoodPredictionService().infer(m, missing);
    expect(p.probability.isFinite, isTrue);
    expect(p.missing, containsAll(['sleep', 'steps']));
  });
}
