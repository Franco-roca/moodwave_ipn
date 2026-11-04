import 'package:flutter/services.dart';

import '../../records/domain/record.dart';
import '../domain/daily_health.dart';

class HealthConnectDataSource implements HealthDataSource {
  static const channel = MethodChannel('com.example.moodwave/health');
  String state = 'unsupported';
  @override
  bool get available => state == 'connected';
  @override
  String get description => switch (state) {
    'connected' => 'Conectado · importación a petición',
    'available' => 'Disponible · tú decides si conectarlo',
    'denied' => 'Permiso no concedido. La captura manual sigue disponible.',
    'update_required' =>
      'Instala o actualiza Health Connect desde la tienda de tu dispositivo.',
    _ => 'Health Connect no está disponible en este dispositivo. Puedes registrar sueño y pasos manualmente.',
  };
  Future<String> status() async {
    try {
      state = await channel.invokeMethod<String>('status') ?? 'unsupported';
    } on MissingPluginException {
      state = 'unsupported';
    } on PlatformException {
      state = 'unavailable';
    }
    return state;
  }

  Future<void> connect() async {
    state = await channel.invokeMethod<String>('connect') ?? 'denied';
  }

  Future<void> disconnect() async {
    state = await channel.invokeMethod<String>('disconnect') ?? 'unsupported';
  }

  @override
  Future<List<DailyHealthData>> read(DateTime start, DateTime end) async {
    if (await status() != 'connected') throw StateError(description);
    if (day(end).difference(day(start)).inDays > 30 || !end.isAfter(start)) {
      throw ArgumentError('Elige entre 1 y 30 días.');
    }
    final rows =
        await channel.invokeListMethod<dynamic>('read', {
          'start': dateKey(start),
          'end': dateKey(end),
        }) ??
        [];
    return rows.map((v) {
      final m = Map<String, dynamic>.from(v as Map);
      return DailyHealthData(
        date: DateTime.parse(m['date'] as String),
        sleepMinutes: m['sleepMinutes'] as int?,
        steps: m['steps'] as int?,
        source: HealthSource.healthConnect,
      );
    }).toList();
  }
}
