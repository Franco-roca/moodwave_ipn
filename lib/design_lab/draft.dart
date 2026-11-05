import 'package:flutter/material.dart';

import '../features/records/domain/record.dart';
import '../features/health/domain/daily_health.dart';

enum LabScenario { editing, empty, saving, error, saved }

/// Ephemeral fixture: deliberately has no storage or platform dependencies.
class LabDraft extends ChangeNotifier {
  Mood? mood = Mood.good;
  double energy = 6;
  final activities = <String>{'Estudio', 'Descanso'};
  String reflection = 'Hoy me di tiempo para hacer una pausa.';
  String hours = '7', minutes = '30', steps = '4200';
  int stage = 0;
  LabScenario scenario = LabScenario.editing;
  String? message;

  void update(VoidCallback change) {
    change();
    scenario = LabScenario.editing;
    message = null;
    notifyListeners();
  }

  void selectScenario(LabScenario value) {
    scenario = value;
    message = null;
    if (value == LabScenario.empty) {
      mood = null;
      energy = 5;
      activities.clear();
      reflection = hours = minutes = steps = '';
      stage = 0;
    }
    notifyListeners();
  }

  bool validate() {
    try {
      if (mood == null) {
        throw const FormatException('Elige una emoción para continuar.');
      }
      parseSleep(hours, minutes);
      parseSteps(steps);
      if (reflection.characters.length > 300) {
        throw const FormatException(
          'La reflexión admite hasta 300 caracteres.',
        );
      }
      message = null;
      return true;
    } on FormatException catch (e) {
      message = e.message;
      scenario = LabScenario.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> save() async {
    if (!validate()) return;
    selectScenario(LabScenario.saving);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (scenario == LabScenario.saving) selectScenario(LabScenario.saved);
  }
}
