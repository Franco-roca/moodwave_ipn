import '../../../core/refugio_art.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/state.dart';
import '../data/model_repository.dart';
import '../domain/learning.dart';

class PredictionPanel extends StatefulWidget {
  const PredictionPanel({super.key, required this.store});
  final AppStore store;
  @override
  State<PredictionPanel> createState() => _PredictionPanelState();
}

class _PredictionPanelState extends State<PredictionPanel> {
  bool synthetic = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final data = observationsFrom(
      s.records,
      s.healthData,
      synthetic: synthetic,
    );
    final model = synthetic ? s.demoPredictionModel : s.predictionModel;
    final result = model == null
        ? null
        : MoodPredictionService().infer(model, data);
    String percent(double? v) =>
        v == null ? 'No disponible' : '${(v * 100).toStringAsFixed(1)} %';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kDebugMode)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Modo demostración'),
            subtitle: const Text(
              'Solo datos sintéticos · separado de tus registros',
            ),
            value: synthetic,
            onChanged: s.predictionBusy
                ? null
                : (v) => setState(() => synthetic = v),
          ),
        if (synthetic)
          const Chip(
            avatar: RefugioIcon(Icons.science_outlined),
            label: Text('DEMOSTRACIÓN · sin validez personal'),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const RefugioIcon(Icons.insights_rounded, size: 36),
                const SizedBox(height: 16),
                if (result == null) ...[
                  Text(
                    '${(data.length - 1).clamp(0, 2000)} / 30',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const Text('Ejemplos para comenzar'),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: ((data.length - 1) / 30).clamp(0, 1),
                  ),
                ] else ...[
                  SizedBox(
                    height: 132,
                    width: 132,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: result.probability,
                            strokeWidth: 12,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          ),
                        ),
                        Text(
                          percent(result.probability),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Ánimo de 1–4 en el próximo registro',
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Entrada: ${DateFormat.yMMMd('es_MX').format(result.date)}',
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Experimental · no es un diagnóstico',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: s.predictionBusy
              ? null
              : () => s.trainPrediction(synthetic: synthetic),
          icon: s.predictionBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const RefugioIcon(Icons.play_arrow_rounded),
          label: Text(
            s.predictionBusy
                ? 'Entrenando en tu dispositivo…'
                : model == null
                ? 'Entrenar modelo local'
                : 'Volver a entrenar',
          ),
        ),
        if (s.predictionMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(s.predictionMessage),
          ),
        if (model != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prueba temporal · n=${model.metrics.count}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _qualityBar('Modelo', model.metrics.balancedAccuracy),
                  _qualityBar('Referencia', model.baseline.balancedAccuracy),
                  Text(
                    model.beatsBaseline
                        ? 'Supera la referencia en esta prueba'
                        : 'No supera la referencia',
                  ),
                ],
              ),
            ),
          ),
          ExpansionTile(
            key: PageStorageKey('model-metrics-$synthetic'),
            title: const Text('Métricas y método'),
            childrenPadding: const EdgeInsets.all(16),
            children: [
              Table(
                columnWidths: const {0: FlexColumnWidth(1.5)},
                children: [
                  const TableRow(
                    children: [
                      Text('Métrica'),
                      Text('Modelo'),
                      Text('Referencia'),
                    ],
                  ),
                  for (final entry in <String, List<double?>>{
                    'Accuracy': [
                      model.metrics.accuracy,
                      model.baseline.accuracy,
                    ],
                    'Balanceada': [
                      model.metrics.balancedAccuracy,
                      model.baseline.balancedAccuracy,
                    ],
                    'Precision': [
                      model.metrics.precision,
                      model.baseline.precision,
                    ],
                    'Recall': [model.metrics.recall, model.baseline.recall],
                    'F1': [model.metrics.f1, model.baseline.f1],
                  }.entries)
                    TableRow(
                      children: [
                        Text(entry.key),
                        Text(percent(entry.value[0])),
                        Text(percent(entry.value[1])),
                      ],
                    ),
                ],
              ),
              Text(
                'Modelo: TP ${model.metrics.tp} · FP ${model.metrics.fp} · TN ${model.metrics.tn} · FN ${model.metrics.fn}\nReferencia: TP ${model.baseline.tp} · FP ${model.baseline.fp} · TN ${model.baseline.tn} · FN ${model.baseline.fn}',
              ),
              Text(
                'Entrenamiento: ${model.trainCount} ejemplos (${model.trainPositives} clase 1). ${model.trainDateRange.map((v) => v.substring(0, 10)).join(' → ')}\nPrueba: ${model.testDateRange.map((v) => v.substring(0, 10)).join(' → ')}\nReferencia: repetir clase del registro actual. División cronológica 80/20, sin barajar. Umbral 0.5. Mediana y normalización solo del entrenamiento.\n${model.fit.iterations} iteraciones · pérdida ${model.fit.initialLoss.toStringAsFixed(4)} → ${model.fit.finalLoss.toStringAsFixed(4)} · ${model.fit.converged ? 'convergencia numérica' : 'límite de iteraciones alcanzado'}. ${model.sampleCount < 60 ? 'Muestra pequeña: 30–59 ejemplos.' : 'Más datos no garantizan generalización.'}',
              ),
            ],
          ),
        ],
        if (result != null && model != null)
          ExpansionTile(
            key: PageStorageKey('model-why-$synthetic'),
            title: const Text('¿Por qué veo esto?'),
            childrenPadding: const EdgeInsets.all(16),
            children: [
              Text(
                'Probabilidad = sigmoide(intercepto + Σ peso × valor normalizado). Intercepto ${model.intercept.toStringAsFixed(3)}. Cada barra representa una contribución exacta al logit, no una causa.',
              ),
              for (final e
                  in (result.contributions.entries.toList()..sort(
                        (a, b) => b.value.abs().compareTo(a.value.abs()),
                      ))
                      .take(8))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_featureLabel(e.key)),
                  subtitle: LinearProgressIndicator(
                    value: (e.value.abs() / 4).clamp(0, 1),
                  ),
                  trailing: Text(
                    '${e.value >= 0 ? '+' : ''}${e.value.toStringAsFixed(3)}',
                  ),
                ),
              Text(
                result.missing.isEmpty
                    ? 'Sin datos faltantes en esta entrada.'
                    : 'Imputados con la mediana de entrenamiento: ${result.missing.map(_featureLabel).join(', ')}.',
              ),
              const Text(
                'Se estima el siguiente día registrado, aunque haya un intervalo entre fechas. No predice una fecha exacta ni una condición clínica. Las actividades concurrentes, el registro irregular y las muestras pequeñas limitan el resultado.',
              ),
            ],
          ),
        const ExpansionTile(
          key: PageStorageKey('prediction-about'),
          title: Text('Privacidad y límites'),
          childrenPadding: EdgeInsets.all(16),
          children: [
            Text(
              'Entrenamiento e inferencia en el dispositivo, sin servidores. Se usan ánimo, energía, sueño, pasos, promedios previos de 3/7 días, tendencia, día de semana, actividades y marcas de ausencia. Nunca se usan reflexiones ni datos de seguridad. Un cambio en los datos invalida el modelo. Mínimo 30 ejemplos y dos clases con al menos 3 ejemplos de cada una en entrenamiento. No sustituye atención profesional.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _qualityBar(String label, double? value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        SizedBox(width: 86, child: Text(label)),
        Expanded(
          child: LinearProgressIndicator(
            value: value ?? 0,
            minHeight: 10,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 8),
        Text(value == null ? '—' : '${(value * 100).round()} %'),
      ],
    ),
  );
  String _featureLabel(String name) =>
      const {
        'mood': 'Ánimo actual',
        'energy': 'Energía actual',
        'sleep': 'Sueño',
        'steps': 'Pasos',
        'moodMean3': 'Ánimo · media 3 días',
        'moodMean7': 'Ánimo · media 7 días',
        'energyMean7': 'Energía · media 7 días',
        'trend3': 'Tendencia reciente',
        'weekdaySin': 'Día semanal (seno)',
        'weekdayCos': 'Día semanal (coseno)',
        'daysSincePrevious': 'Intervalo entre registros',
        'missingSleep': 'Sueño ausente',
        'missingSteps': 'Pasos ausentes',
        'unknownActivities': 'Actividad fuera de vocabulario',
      }[name] ??
      name.replaceFirst('activity:', 'Actividad: ');
}
