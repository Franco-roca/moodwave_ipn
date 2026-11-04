import '../../records/domain/record.dart';

enum HealthSource { manual, healthConnect, imported, synthetic }

class DailyHealthData {
  DailyHealthData({
    this.id,
    required DateTime date,
    this.sleepMinutes,
    this.steps,
    this.source = HealthSource.manual,
    DateTime? updatedAt,
    this.isTest = false,
  }) : date = day(date),
       updatedAt = updatedAt ?? DateTime.now() {
    if (sleepMinutes != null && (sleepMinutes! < 0 || sleepMinutes! > 1440)) {
      throw ArgumentError('El sueño debe estar entre 0 y 24 horas.');
    }
    if (steps != null && (steps! < 0 || steps! > 200000)) {
      throw ArgumentError('Los pasos deben estar entre 0 y 200,000.');
    }
  }
  final int? id, sleepMinutes, steps;
  final DateTime date, updatedAt;
  final HealthSource source;
  final bool isTest;
  bool get isSynthetic => isTest || source == HealthSource.synthetic;
  bool get isEmpty => sleepMinutes == null && steps == null;
  String get dateKeyValue => dateKey(date);
  Map<String, Object?> toMap() => {
    'dateKey': dateKeyValue,
    'fecha': date.millisecondsSinceEpoch,
    'sleepMinutes': sleepMinutes,
    'steps': steps,
    'source': source == HealthSource.healthConnect
        ? 'health_connect'
        : source.name,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'isTest': isTest ? 1 : 0,
  };
  factory DailyHealthData.fromMap(Map<String, Object?> m) => DailyHealthData(
    id: m['id'] as int,
    date: DateTime.parse(m['dateKey'] as String),
    sleepMinutes: m['sleepMinutes'] as int?,
    steps: m['steps'] as int?,
    source: m['source'] == 'health_connect'
        ? HealthSource.healthConnect
        : HealthSource.values.firstWhere(
            (s) => s.name == m['source'],
            orElse: () => HealthSource.manual,
          ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] as int),
    isTest: m['isTest'] == 1,
  );
}

int? parseSleep(String hours, String minutes) {
  if (hours.trim().isEmpty && minutes.trim().isEmpty) return null;
  int read(String s) {
    if (s.trim().isEmpty) return 0;
    if (!RegExp(r'^[0-9]+$').hasMatch(s.trim())) {
      throw const FormatException(
        'Introduce horas y minutos enteros, sin signos.',
      );
    }
    return int.parse(s.trim());
  }

  final h = read(hours), m = read(minutes);
  if (h > 24 || m > 59 || h * 60 + m > 1440) {
    throw const FormatException(
      'El sueño debe estar entre 0 y 24 horas; los minutos, entre 0 y 59.',
    );
  }
  return h * 60 + m;
}

int? parseSteps(String text) {
  if (text.trim().isEmpty) return null;
  if (!RegExp(r'^[0-9]+$').hasMatch(text.trim())) {
    throw const FormatException(
      'Introduce pasos enteros, sin signos ni decimales.',
    );
  }
  final n = int.parse(text.trim());
  if (n > 200000) throw const FormatException('El máximo es 200,000 pasos.');
  return n;
}

abstract class HealthDataSource {
  bool get available;
  String get description;
  Future<List<DailyHealthData>> read(DateTime start, DateTime end);
}

class ManualHealthDataSource implements HealthDataSource {
  ManualHealthDataSource(this.reader);
  final Future<List<DailyHealthData>> Function(DateTime, DateTime) reader;
  @override
  bool get available => true;
  @override
  String get description => 'Registro manual disponible, sin internet.';
  @override
  Future<List<DailyHealthData>> read(DateTime start, DateTime end) =>
      reader(start, end);
}

class UnavailableHealthConnect implements HealthDataSource {
  @override
  bool get available => false;
  @override
  String get description =>
      'Health Connect no está disponible en este dispositivo. Puedes registrar sueño y pasos manualmente.';
  String messageForSdk(int sdk) => sdk <= 27
      ? 'Health Connect no está disponible en este dispositivo. Puedes registrar sueño y pasos manualmente.'
      : description;
  @override
  Future<List<DailyHealthData>> read(DateTime start, DateTime end) async => [];
}
