import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/records/data/record_repository.dart';
import '../features/records/domain/record.dart';
import '../features/security/data/security.dart';
import '../features/health/domain/daily_health.dart';
import '../features/health/data/health_repository.dart';
import '../features/prediction/domain/learning.dart';
import '../features/prediction/data/model_repository.dart';

final storeProvider = Provider<AppStore>((ref) => throw UnimplementedError());

class AppStore extends ChangeNotifier {
  late RecordRepository repository;
  late SharedPreferences preferences;
  final pin = PinService();
  BiometricService biometrics = DeviceBiometricService();
  List<Record> records = [];
  List<DailyHealthData> healthData = [];
  HealthRepository? healthRepository;
  ModelRepository? modelRepository;
  TrainedModel? predictionModel;
  TrainedModel? demoPredictionModel;
  bool predictionBusy = false;
  String predictionMessage = '';
  int dataRevision = 0;
  bool unlocked = false,
      hasPin = false,
      authenticating = false,
      bioEnabled = true;
  String? startupError;
  int lockVersion = 0;
  ThemeMode theme = ThemeMode.system;
  String name = '';
  List<String> custom = [];
  Future<void> initialize() async {
    try {
      preferences = await SharedPreferences.getInstance();
      theme = ThemeMode.values[preferences.getInt('theme') ?? 0];
      name = preferences.getString('name') ?? '';
      custom = preferences.getStringList('activities') ?? [];
      repository = await RecordRepository.open();
      healthRepository = HealthRepository(repository.db);
      modelRepository = ModelRepository(repository.db);
      await refresh();
      predictionModel = await modelRepository!.load();
      demoPredictionModel = await modelRepository!.load(synthetic: true);
      if (demoPredictionModel != null &&
          dataFingerprint(
                observationsFrom(records, healthData, synthetic: true),
              ) !=
              demoPredictionModel!.fingerprint) {
        demoPredictionModel = null;
        await modelRepository!.db.delete('prediction_model', where: 'id=2');
      }
      if (predictionModel != null &&
          dataFingerprint(
                observationsFrom(
                  records,
                  healthData,
                  synthetic: predictionModel!.synthetic,
                ),
              ) !=
              predictionModel!.fingerprint) {
        predictionModel = null;
        await modelRepository!.db.delete('prediction_model', where: 'id=1');
      }
      hasPin = await pin.exists();
      bioEnabled = await pin.biometricEnabled();
    } catch (_) {
      startupError = 'No se pudo abrir el almacenamiento local. Cierra y vuelve a abrir MoodWave; tus datos no se han eliminado.';
    }
  }

  Future<void> refresh() async {
    dataRevision++;
    predictionModel = null;
    demoPredictionModel = null;
    records = await repository.all();
    if (healthRepository != null) {
      healthData = await healthRepository!.all();
      healthRepository!.changed();
    }
    notifyListeners();
  }

  Future<void> trainPrediction({bool synthetic = false}) async {
    if (predictionBusy) return;
    final revision = dataRevision,
        observations = observationsFrom(
          records,
          healthData,
          synthetic: synthetic,
        );
    predictionBusy = true;
    predictionMessage = '';
    notifyListeners();
    try {
      final outcome = await compute(
        trainLocalModel,
        TrainingRequest(observations, DateTime.now()),
      );
      if (revision != dataRevision) {
        predictionMessage = 'Los datos cambiaron. Vuelve a entrenar.';
        return;
      }
      if (synthetic) {
        demoPredictionModel = outcome.model;
      } else {
        predictionModel = outcome.model;
      }
      predictionMessage = outcome.message;
      if (outcome.model != null) await modelRepository?.save(outcome.model!);
    } catch (_) {
      predictionMessage = 'No se pudo entrenar. Tus registros se conservan.';
    } finally {
      predictionBusy = false;
      notifyListeners();
    }
  }

  Future<void> deleteModel() async {
    dataRevision++;
    await modelRepository?.delete();
    predictionModel = null;
    demoPredictionModel = null;
    predictionMessage = 'Modelo eliminado';
    notifyListeners();
  }

  Record? at(DateTime d) {
    for (final r in records) {
      if (dateKey(r.date) == dateKey(d)) return r;
    }
    return null;
  }

  void unlock() {
    unlocked = true;
    notifyListeners();
  }

  void lock() {
    unlocked = false;
    lockVersion++;
    notifyListeners();
  }

  void pinConfigured() {
    hasPin = true;
    notifyListeners();
  }

  Future<void> setBioEnabled(bool value) async {
    await pin.setBiometric(value);
    bioEnabled = value;
    notifyListeners();
  }

  DailyHealthData? healthAt(DateTime date) {
    for (final h in healthData) {
      if (h.dateKeyValue == dateKey(date)) return h;
    }
    return null;
  }

  Future<void> save(
    Record r, {
    DailyHealthData? health,
    bool updateHealth = false,
  }) async {
    await repository.save(r, health: health, updateHealth: updateHealth);
    await refresh();
  }

  Future<void> delete(Record r) async {
    await repository.delete(r.id!);
    await refresh();
  }

  Future<void> setName(String value) async {
    await preferences.setString('name', value.trim());
    name = value.trim();
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode value) async {
    await preferences.setInt('theme', value.index);
    theme = value;
    notifyListeners();
  }

  Future<String> addActivity(String input) async {
    final value = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty || value.characters.length > 30) {
      throw ArgumentError('Escribe entre 1 y 30 caracteres');
    }
    for (final a in [...defaultActivities, ...custom]) {
      if (a.toLowerCase() == value.toLowerCase()) return a;
    }
    await preferences.setStringList('activities', [...custom, value]);
    custom = [...custom, value];
    notifyListeners();
    return value;
  }

  Future<void> generate({int seed = 42, bool replaceSynthetic = false, bool emotional = true, bool physical = true}) async {
    if (!kDebugMode) return;
    await repository.generate(
      DateTime.now(),
      withGaps: true,
      seed: seed,
      replaceSynthetic: replaceSynthetic,
      emotional: emotional,
      physical: physical,
    );
    await refresh();
  }
}
