import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

class Observation {
  const Observation({
    required this.date,
    required this.mood,
    required this.energy,
    this.sleep,
    this.steps,
    this.activities = const [],
    this.synthetic = false,
    this.revision = 0,
  });
  final DateTime date;
  final int mood, energy, revision;
  final double? sleep, steps;
  final List<String> activities;
  final bool synthetic;
  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'mood': mood,
    'energy': energy,
    'sleep': sleep,
    'steps': steps,
    'activities': [...activities]..sort(),
    'synthetic': synthetic,
    'revision': revision,
  };
}

String dataFingerprint(List<Observation> observations) => sha256
    .convert(
      utf8.encode(jsonEncode(observations.map((o) => o.toJson()).toList())),
    )
    .toString();
String canonicalActivity(String text) =>
    text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

class Example {
  const Example(
    this.values,
    this.target,
    this.currentClass,
    this.date,
    this.targetDate,
  );
  final List<double?> values;
  final int target, currentClass;
  final DateTime date, targetDate;
}

class FeatureEngineeringService {
  static const version = 1;
  static const baseNames = [
    'mood',
    'energy',
    'sleep',
    'steps',
    'moodMean3',
    'moodMean7',
    'energyMean7',
    'trend3',
    'weekdaySin',
    'weekdayCos',
    'daysSincePrevious',
    'missingSleep',
    'missingSteps',
    'unknownActivities',
  ];
  List<String> vocabulary(List<Observation> training) {
    final counts = <String, int>{};
    for (final o in training) {
      for (final a
          in o.activities
              .map(canonicalActivity)
              .where((a) => a.isNotEmpty)
              .toSet()) {
        counts[a] = (counts[a] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return entries.take(24).map((e) => e.key).toList()..sort();
  }

  List<String> names(List<String> vocabulary) => [
    ...baseNames,
    ...vocabulary.map((a) => 'activity:$a'),
  ];
  List<double?> at(
    List<Observation> history,
    int index,
    List<String> vocabulary,
  ) {
    final current = history[index];
    double rolling(int days, bool energy) {
      final start = DateTime(
        current.date.year,
        current.date.month,
        current.date.day - days + 1,
      );
      final rows = history
          .take(index + 1)
          .where((o) => !o.date.isBefore(start))
          .toList();
      return rows.fold<double>(0, (s, o) => s + (energy ? o.energy : o.mood)) /
          rows.length;
    }

    final activities = current.activities.map(canonicalActivity).toSet();
    final mean3 = rolling(3, false);
    return [
      current.mood.toDouble(),
      current.energy.toDouble(),
      current.sleep,
      current.steps,
      mean3,
      rolling(7, false),
      rolling(7, true),
      current.mood - mean3,
      math.sin(2 * math.pi * (current.date.weekday - 1) / 7),
      math.cos(2 * math.pi * (current.date.weekday - 1) / 7),
      index == 0
          ? 0
          : current.date.difference(history[index - 1].date).inHours / 24,
      current.sleep == null ? 1 : 0,
      current.steps == null ? 1 : 0,
      activities.difference(vocabulary.toSet()).length.toDouble(),
      ...vocabulary.map((a) => activities.contains(a) ? 1.0 : 0.0),
    ];
  }

  List<Example> examples(List<Observation> sorted, List<String> vocabulary) => [
    for (var i = 0; i < sorted.length - 1; i++)
      Example(
        at(sorted, i, vocabulary),
        sorted[i + 1].mood <= 4 ? 1 : 0,
        sorted[i].mood <= 4 ? 1 : 0,
        sorted[i].date,
        sorted[i + 1].date,
      ),
  ];
}

class Normalization {
  const Normalization(this.medians, this.means, this.std);
  final List<double> medians, means, std;
  factory Normalization.fit(List<List<double?>> training) {
    if (training.isEmpty) throw ArgumentError('Sin entrenamiento');
    final medians = <double>[], means = <double>[], std = <double>[];
    for (var col = 0; col < training.first.length; col++) {
      final values =
          training
              .map((r) => r[col])
              .whereType<double>()
              .where((v) => v.isFinite)
              .toList()
            ..sort();
      final median = values.isEmpty
          ? 0.0
          : values.length.isOdd
          ? values[values.length ~/ 2]
          : (values[values.length ~/ 2 - 1] + values[values.length ~/ 2]) / 2;
      final filled = training
          .map((r) => r[col] != null && r[col]!.isFinite ? r[col]! : median)
          .toList();
      final mean = filled.fold<double>(0, (s, x) => s + x) / filled.length;
      final deviation = math.sqrt(
        filled.fold<double>(0, (s, x) => s + math.pow(x - mean, 2)) /
            filled.length,
      );
      medians.add(median);
      means.add(mean);
      std.add(deviation < 1e-8 ? 1 : deviation);
    }
    return Normalization(medians, means, std);
  }
  List<double> transform(List<double?> row) => List.generate(
    means.length,
    (i) =>
        (((row[i] != null && row[i]!.isFinite ? row[i]! : medians[i]) -
                    means[i]) /
                std[i])
            .clamp(-8, 8)
            .toDouble(),
  );
}

double sigmoid(double value) {
  final x = value.clamp(-35, 35);
  return x >= 0 ? 1 / (1 + math.exp(-x)) : math.exp(x) / (1 + math.exp(x));
}

double binaryCrossEntropy(double probability, int target) {
  final p = probability.clamp(1e-12, 1 - 1e-12);
  return -target * math.log(p) - (1 - target) * math.log(1 - p);
}

class TrainerConfig {
  const TrainerConfig({
    this.learningRate = .08,
    this.l2 = .01,
    this.maxIterations = 1200,
    this.tolerance = 1e-7,
  });
  final double learningRate, l2, tolerance;
  final int maxIterations;
}

class FitResult {
  const FitResult(
    this.coefficients,
    this.intercept,
    this.initialLoss,
    this.finalLoss,
    this.iterations,
    this.converged,
  );
  final List<double> coefficients;
  final double intercept, initialLoss, finalLoss;
  final int iterations;
  final bool converged;
}

class LogisticRegressionTrainer {
  double loss(
    List<List<double>> x,
    List<int> y,
    List<double> weights,
    double intercept,
    double l2,
  ) {
    var sum = 0.0;
    for (var i = 0; i < x.length; i++) {
      sum += binaryCrossEntropy(sigmoid(intercept + dot(weights, x[i])), y[i]);
    }
    return sum / x.length +
        l2 / 2 * weights.fold<double>(0, (s, w) => s + w * w);
  }

  ({List<double> weights, double intercept}) gradient(
    List<List<double>> x,
    List<int> y,
    List<double> weights,
    double intercept,
    double l2,
  ) {
    final g = List<double>.filled(weights.length, 0);
    var b = 0.0;
    for (var i = 0; i < x.length; i++) {
      final error = sigmoid(intercept + dot(weights, x[i])) - y[i];
      b += error;
      for (var j = 0; j < g.length; j++) {
        g[j] += error * x[i][j];
      }
    }
    for (var j = 0; j < g.length; j++) {
      g[j] = g[j] / x.length + l2 * weights[j];
    }
    return (weights: g, intercept: b / x.length);
  }

  FitResult train(
    List<List<double>> x,
    List<int> y, {
    TrainerConfig config = const TrainerConfig(),
  }) {
    if (x.isEmpty ||
        x.length != y.length ||
        config.learningRate <= 0 ||
        config.l2 < 0 ||
        config.maxIterations < 1) {
      throw ArgumentError('Entrenamiento inválido');
    }
    var weights = List<double>.filled(x.first.length, 0), intercept = 0.0;
    final initial = loss(x, y, weights, intercept, config.l2);
    var previous = initial, stable = 0, iterations = 0;
    for (var iteration = 0; iteration < config.maxIterations; iteration++) {
      final g = gradient(x, y, weights, intercept, config.l2);
      for (var j = 0; j < weights.length; j++) {
        weights[j] -= config.learningRate * g.weights[j];
      }
      intercept -= config.learningRate * g.intercept;
      final next = loss(x, y, weights, intercept, config.l2);
      iterations = iteration + 1;
      if (!next.isFinite) throw StateError('Entrenamiento no finito');
      stable = (previous - next).abs() < config.tolerance ? stable + 1 : 0;
      previous = next;
      if (stable >= 10) break;
    }
    return FitResult(
      weights,
      intercept,
      initial,
      previous,
      iterations,
      stable >= 10,
    );
  }
}

double dot(List<double> a, List<double> b) {
  var sum = 0.0;
  for (var i = 0; i < a.length; i++) {
    sum += a[i] * b[i];
  }
  return sum;
}

class ConfusionMatrix {
  const ConfusionMatrix(this.tp, this.fp, this.tn, this.fn);
  final int tp, fp, tn, fn;
  int get count => tp + fp + tn + fn;
  double? get accuracy => count == 0 ? null : (tp + tn) / count;
  double? get recall => tp + fn == 0 ? null : tp / (tp + fn);
  double? get precision => tp + fp == 0 ? null : tp / (tp + fp);
  double? get balancedAccuracy => tp + fn == 0 || tn + fp == 0
      ? null
      : (tp / (tp + fn) + tn / (tn + fp)) / 2;
  double? get f1 => 2 * tp + fp + fn == 0 ? null : 2 * tp / (2 * tp + fp + fn);
  Map<String, Object?> toJson() => {
    'tp': tp,
    'fp': fp,
    'tn': tn,
    'fn': fn,
    'n': count,
    'accuracy': accuracy,
    'balancedAccuracy': balancedAccuracy,
    'precision': precision,
    'recall': recall,
    'f1': f1,
  };
  factory ConfusionMatrix.fromJson(Map<String, dynamic> m) => ConfusionMatrix(
    m['tp'] as int,
    m['fp'] as int,
    m['tn'] as int,
    m['fn'] as int,
  );
}

class ModelEvaluationService {
  ConfusionMatrix evaluate(List<int> targets, List<int> predictions) {
    var tp = 0, fp = 0, tn = 0, fn = 0;
    for (var i = 0; i < targets.length; i++) {
      if (targets[i] == 1) {
        predictions[i] == 1 ? tp++ : fn++;
      } else {
        predictions[i] == 1 ? fp++ : tn++;
      }
    }
    return ConfusionMatrix(tp, fp, tn, fn);
  }
}

class TrainedModel {
  TrainedModel({
    required this.coefficients,
    required this.intercept,
    required this.featureNames,
    required this.normalization,
    required this.trainedAt,
    required this.sampleCount,
    required this.trainDateRange,
    required this.testDateRange,
    required this.metrics,
    required this.baseline,
    required this.fingerprint,
    required this.synthetic,
    required this.fit,
    required this.trainPositives,
    required this.trainCount,
    this.threshold = .5,
  });
  static const schemaVersion = 1, modelVersion = 'logistic-1';
  final List<double> coefficients;
  final double intercept, threshold;
  final List<String> featureNames, trainDateRange, testDateRange;
  final Normalization normalization;
  final DateTime trainedAt;
  final int sampleCount, trainPositives, trainCount;
  final ConfusionMatrix metrics, baseline;
  final String fingerprint;
  final bool synthetic;
  final FitResult fit;
  bool get beatsBaseline =>
      metrics.balancedAccuracy != null &&
      baseline.balancedAccuracy != null &&
      metrics.balancedAccuracy! > baseline.balancedAccuracy! + 1e-9;
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'modelVersion': modelVersion,
    'featureVersion': FeatureEngineeringService.version,
    'coefficients': coefficients,
    'intercept': intercept,
    'featureNames': featureNames,
    'normalizationMeans': normalization.means,
    'normalizationStd': normalization.std,
    'imputationMedians': normalization.medians,
    'threshold': threshold,
    'trainedAt': trainedAt.toIso8601String(),
    'sampleCount': sampleCount,
    'trainDateRange': trainDateRange,
    'testDateRange': testDateRange,
    'metrics': metrics.toJson(),
    'baseline': baseline.toJson(),
    'fingerprint': fingerprint,
    'synthetic': synthetic,
    'trainPositives': trainPositives,
    'trainCount': trainCount,
    'iterations': fit.iterations,
    'initialLoss': fit.initialLoss,
    'finalLoss': fit.finalLoss,
    'converged': fit.converged,
  };
  factory TrainedModel.fromJson(Map<String, dynamic> m) {
    if (m['schemaVersion'] != schemaVersion ||
        m['modelVersion'] != modelVersion ||
        m['featureVersion'] != FeatureEngineeringService.version) {
      throw const FormatException('Modelo incompatible');
    }
    List<double> numbers(String key) =>
        List<num>.from(m[key] as List).map((v) => v.toDouble()).toList();
    final weights = numbers('coefficients'),
        means = numbers('normalizationMeans'),
        std = numbers('normalizationStd'),
        medians = numbers('imputationMedians'),
        names = List<String>.from(m['featureNames']);
    if (weights.length != names.length ||
        means.length != names.length ||
        std.length != names.length ||
        medians.length != names.length ||
        [...weights, ...means, ...std, ...medians].any((v) => !v.isFinite) ||
        std.any((v) => v <= 0)) {
      throw const FormatException('Parámetros inválidos');
    }
    final intercept = (m['intercept'] as num).toDouble(),
        threshold = (m['threshold'] as num).toDouble();
    if (!intercept.isFinite || threshold <= 0 || threshold >= 1) {
      throw const FormatException('Modelo inválido');
    }
    return TrainedModel(
      coefficients: weights,
      intercept: intercept,
      featureNames: names,
      normalization: Normalization(medians, means, std),
      trainedAt: DateTime.parse(m['trainedAt']),
      sampleCount: m['sampleCount'],
      trainDateRange: List<String>.from(m['trainDateRange']),
      testDateRange: List<String>.from(m['testDateRange']),
      metrics: ConfusionMatrix.fromJson(m['metrics']),
      baseline: ConfusionMatrix.fromJson(m['baseline']),
      fingerprint: m['fingerprint'],
      synthetic: m['synthetic'],
      fit: FitResult(
        weights,
        intercept,
        (m['initialLoss'] as num).toDouble(),
        (m['finalLoss'] as num).toDouble(),
        m['iterations'],
        m['converged'],
      ),
      trainPositives: m['trainPositives'],
      trainCount: m['trainCount'],
      threshold: threshold,
    );
  }
}

class Prediction {
  const Prediction(
    this.probability,
    this.contributions,
    this.missing,
    this.date,
  );
  final double probability;
  final Map<String, double> contributions;
  final List<String> missing;
  final DateTime date;
}

class TrainingOutcome {
  const TrainingOutcome(this.model, this.message);
  final TrainedModel? model;
  final String message;
}

class TrainingRequest {
  const TrainingRequest(
    this.observations,
    this.now, {
    this.config = const TrainerConfig(),
  });
  final List<Observation> observations;
  final DateTime now;
  final TrainerConfig config;
}

TrainingOutcome trainLocalModel(TrainingRequest request) =>
    MoodPredictionService().train(
      request.observations,
      request.now,
      config: request.config,
    );

class MoodPredictionService {
  TrainingOutcome train(
    List<Observation> observations,
    DateTime now, {
    TrainerConfig config = const TrainerConfig(),
  }) {
    final all = [...observations]..sort((a, b) => a.date.compareTo(b.date));
    if (all.any((r) => r.synthetic) && all.any((r) => !r.synthetic)) {
      return const TrainingOutcome(
        null,
        'Separa datos personales y sintéticos antes de entrenar.',
      );
    }
    final data = all.length > 2001 ? all.sublist(all.length - 2001) : all;
    final n = data.length - 1;
    if (n < 30) {
      return const TrainingOutcome(
        null,
        'Se necesitan al menos 30 ejemplos (31 registros).',
      );
    }
    final split = (n * .8).floor(), engineering = FeatureEngineeringService();
    final vocabulary = engineering.vocabulary(data.take(split).toList());
    final examples = engineering.examples(data, vocabulary),
        train = examples.take(split).toList(),
        test = examples.skip(split).toList();
    final positives = train.where((e) => e.target == 1).length;
    if (positives < 3 || train.length - positives < 3) {
      return const TrainingOutcome(
        null,
        'Se necesitan al menos tres ejemplos de cada clase en entrenamiento.',
      );
    }
    final normalization = Normalization.fit(
          train.map((e) => e.values).toList(),
        ),
        x = train.map((e) => normalization.transform(e.values)).toList();
    final fit = LogisticRegressionTrainer().train(
      x,
      train.map((e) => e.target).toList(),
      config: config,
    );
    final evaluator = ModelEvaluationService(),
        targets = test.map((e) => e.target).toList();
    final metrics = evaluator.evaluate(
      targets,
      test
          .map(
            (e) =>
                sigmoid(
                      fit.intercept +
                          dot(
                            fit.coefficients,
                            normalization.transform(e.values),
                          ),
                    ) >=
                    .5
                ? 1
                : 0,
          )
          .toList(),
    );
    final baseline = evaluator.evaluate(
      targets,
      test.map((e) => e.currentClass).toList(),
    );
    final model = TrainedModel(
      coefficients: fit.coefficients,
      intercept: fit.intercept,
      featureNames: engineering.names(vocabulary),
      normalization: normalization,
      trainedAt: now,
      sampleCount: n,
      trainDateRange: [
        train.first.targetDate.toIso8601String(),
        train.last.targetDate.toIso8601String(),
      ],
      testDateRange: [
        test.first.targetDate.toIso8601String(),
        test.last.targetDate.toIso8601String(),
      ],
      metrics: metrics,
      baseline: baseline,
      fingerprint: dataFingerprint(all),
      synthetic: data.every((o) => o.synthetic),
      fit: fit,
      trainPositives: positives,
      trainCount: train.length,
    );
    return TrainingOutcome(
      model,
      n < 60
          ? 'Análisis experimental: entre 30 y 59 ejemplos.'
          : model.beatsBaseline
          ? 'Supera la referencia en esta prueba temporal.'
          : 'El modelo todavía no supera una referencia sencilla con los datos disponibles.',
    );
  }

  Prediction infer(TrainedModel model, List<Observation> observations) {
    if (observations.isEmpty ||
        dataFingerprint(
              [...observations]..sort((a, b) => a.date.compareTo(b.date)),
            ) !=
            model.fingerprint) {
      throw StateError('Modelo desactualizado');
    }
    final sorted = [...observations]..sort((a, b) => a.date.compareTo(b.date)),
        vocabulary = model.featureNames
            .where((s) => s.startsWith('activity:'))
            .map((s) => s.substring(9))
            .toList();
    final raw = FeatureEngineeringService().at(
          sorted,
          sorted.length - 1,
          vocabulary,
        ),
        x = model.normalization.transform(raw);
    final contributions = {
      for (var i = 0; i < x.length; i++)
        model.featureNames[i]: model.coefficients[i] * x[i],
    };
    return Prediction(
      sigmoid(
        model.intercept + contributions.values.fold<double>(0, (s, v) => s + v),
      ),
      contributions,
      [
        for (var i = 0; i < raw.length; i++)
          if (raw[i] == null) model.featureNames[i],
      ],
      sorted.last.date,
    );
  }
}
