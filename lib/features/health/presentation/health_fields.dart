import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/daily_health.dart';

class HealthFields extends StatelessWidget {
  const HealthFields({
    super.key,
    required this.hours,
    required this.minutes,
    required this.steps,
    required this.onChanged,
  });
  final TextEditingController hours, minutes, steps;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: const PageStorageKey('daily-health-fields'),
      maintainState: true,
      leading: const Icon(Icons.favorite_border),
      title: const Text('Bienestar físico'),
      subtitle: const Text('Sueño y pasos · opcional'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const Text(
          'Registra el sueño asociado a este día. Estos datos son opcionales y se utilizan únicamente para observar relaciones personales.',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: hours,
                keyboardType: TextInputType.number,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'Horas de sueño',
                  errorMaxLines: 4,
                  counterText: '',
                ),
                onChanged: (_) => onChanged(),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (_) {
                  try {
                    parseSleep(hours.text, minutes.text);
                    return null;
                  } on FormatException catch (e) {
                    return e.message;
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: minutes,
                keyboardType: TextInputType.number,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'Minutos',
                  errorMaxLines: 4,
                  counterText: '',
                ),
                onChanged: (_) => onChanged(),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (_) {
                  try {
                    parseSleep(hours.text, minutes.text);
                    return null;
                  } on FormatException catch (e) {
                    return e.message;
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: steps,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: 'Pasos del día',
            errorMaxLines: 3,
            hintText: 'Por ejemplo: 7840',
            helperText: steps.text.isEmpty
                ? 'Puedes dejarlo vacío'
                : '${NumberFormat.decimalPattern('es_MX').format(int.tryParse(steps.text) ?? 0)} pasos',
            counterText: '',
          ),
          onChanged: (_) => onChanged(),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            try {
              parseSteps(value ?? '');
              return null;
            } on FormatException catch (e) {
              return e.message;
            }
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Captura manual. Puedes importar desde Health Connect en Patrones, si tu dispositivo es compatible.',
        ),
      ],
    ),
  );
}
