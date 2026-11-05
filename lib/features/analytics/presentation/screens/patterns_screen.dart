import '../../../../core/refugio_art.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/state.dart';
import '../../../../core/widgets.dart';
import '../../../../core/refugio.dart';
import '../../../records/domain/record.dart';
import '../../../statistics/domain/statistics.dart';
import '../../../health/presentation/health_connection_card.dart';
import '../../../prediction/presentation/prediction_panel.dart';
import '../../domain/analytics.dart';
import '../../domain/statistical_relationship.dart';
import '../providers/analytics_provider.dart';
import '../widgets/charts.dart';

class PatternsScreen extends ConsumerStatefulWidget {
  const PatternsScreen({super.key});
  @override
  ConsumerState<PatternsScreen> createState() => _PatternsScreenState();
}

class _PatternsScreenState extends ConsumerState<PatternsScreen> {
  int section = 0;
  AnalyticsPeriod period = AnalyticsPeriod.week;
  DateTime anchor = day(DateTime.now());
  Metric activityMetric = Metric.mood, trendMetric = Metric.mood;
  int comparisonDays = 7;
  bool healthSteps = false;
  static const sections = [
    'Resumen',
    'Actividades',
    'Tendencias',
    'Sueño y pasos',
    'Predicción',
    'Reportes',
  ];
  static const periods = [
    'Semana seleccionada',
    'Mes seleccionado',
    'Últimos 7 días',
    'Últimos 30 días',
    'Últimos 90 días',
  ];
  @override
  Widget build(BuildContext context) {
    final store = ref.read(storeProvider),
        services = ref.read(analyticsServicesProvider);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final span = DateSpan.forPeriod(period, anchor);
        final data = services.build(
          store.records,
          store.healthData,
          span,
          trendMetric,
          comparisonDays,
        );
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: SingleChildScrollView(
                      key: const PageStorageKey('pattern-tabs'),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < sections.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                avatar: RefugioIllustration(
                                  const [
                                    RefugioSymbol.summary,
                                    RefugioSymbol.activities,
                                    RefugioSymbol.trends,
                                    RefugioSymbol.sleep,
                                    RefugioSymbol.prediction,
                                    RefugioSymbol.reports,
                                  ][i],
                                  size: 26,
                                ),
                                label: Text(sections[i]),
                                selected: section == i,
                                showCheckmark: false,
                                onSelected: (_) => setState(() {
                                  section = i;
                                  if (i == 2 && period.index < 2) {
                                    period = AnalyticsPeriod.last7;
                                  }
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/reports'),
                        icon: const RefugioIcon(Icons.picture_as_pdf_outlined),
                        label: const Text('Generar reporte PDF'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      key: PageStorageKey('patterns-$section'),
                      padding: const EdgeInsets.all(16),
                      children: [
                        WaveHeader(sections[section], switch (section) {
                          0 => 'Tu historia en una mirada.',
                          1 => 'Lo que acompaña a tus días.',
                          2 => 'Cada punto cuenta.',
                          3 => 'Tu ritmo, sin compararte.',
                          4 => 'Explora una estimación local.',
                          _ => 'Tu historia, para llevar.',
                        }),
                        const SizedBox(height: 16),
                        if (section < 4) ...[
                          if (section != 2)
                            DropdownButtonFormField<AnalyticsPeriod>(
                              key: ValueKey(period),
                              initialValue: period,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Periodo de tus datos',
                              ),
                              items: [
                                for (final p in AnalyticsPeriod.values)
                                  DropdownMenuItem(
                                    value: p,
                                    child: Text(periods[p.index]),
                                  ),
                              ],
                              onChanged: (p) {
                                if (p != null) setState(() => period = p);
                              },
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${DateFormat('d MMM', 'es_MX').format(span.start)} – ${DateFormat('d MMM yyyy', 'es_MX').format(shiftDay(span.end, -1))}',
                                ),
                              ),
                              IconButton(
                                tooltip: 'Elegir fecha de referencia',
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: anchor,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(DateTime.now().year + 5),
                                  );
                                  if (picked != null && mounted) {
                                    setState(() => anchor = picked);
                                  }
                                },
                                icon: const RefugioIcon(
                                  Icons.calendar_today_outlined,
                                ),
                              ),
                            ],
                          ),
                          Chip(
                            label: Text(
                              'n=${data.records.length} registros${data.records.any((r) => r.test) ? ' · contiene prueba' : ''}',
                            ),
                          ),
                        ],
                        ...switch (section) {
                          0 => summary(data, store),
                          1 => activities(data),
                          2 => trends(data),
                          3 => health(data, store),
                          4 => [PredictionPanel(store: store)],
                          _ => reports(),
                        },
                        const SizedBox(height: 16),
                        const Text(
                          'MoodWave no realiza diagnósticos médicos ni sustituye atención profesional.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> summary(AnalyticsSnapshot data, AppStore store) {
    final s = data.summary, all = Statistics(store.records);
    if (data.records.isEmpty) return [empty()];
    return [
      LayoutBuilder(
        builder: (context, c) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            metricCard(
              'Ánimo promedio',
              '${s.moodAverage.toStringAsFixed(1)}/8',
              Icons.mood,
              (c.maxWidth - 8) / 2,
            ),
            metricCard(
              'Energía promedio',
              '${s.energyAverage.toStringAsFixed(1)}/10',
              Icons.bolt_rounded,
              (c.maxWidth - 8) / 2,
            ),
            metricCard(
              'Días registrados',
              '${s.count}',
              Icons.calendar_month,
              (c.maxWidth - 8) / 2,
            ),
            metricCard(
              'Racha actual',
              '${all.currentStreak(DateTime.now())} días',
              Icons.local_fire_department_outlined,
              (c.maxWidth - 8) / 2,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: RefugioFace(mood: s.best!.mood, size: 40),
          title: const Text('Tu mejor día'),
          subtitle: Text(
            '${DateFormat.yMMMd('es_MX').format(s.best!.date)} · ${s.best!.mood.name}',
          ),
        ),
      ),
      ExpansionTile(
        key: const PageStorageKey('summary-statistics'),
        title: const Text('Estadísticas detalladas'),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          detail('Media', s.moodAverage.toStringAsFixed(2)),
          detail('Mediana', s.median!.toStringAsFixed(2)),
          detail(
            s.modes.length == 1 ? 'Moda' : 'Modas empatadas',
            s.modes.map((m) => '${m.value} · ${m.name}').join('\n'),
          ),
          detail('Desviación poblacional', s.populationStd!.toStringAsFixed(2)),
          detail('Mejor racha histórica', '${all.bestStreak} días'),
          detail('n', '${s.count}'),
          const Text(
            'Media = suma/n. Mediana = centro de los valores ordenados. Modas = todos los valores con frecuencia máxima. Desviación = √(Σ(x−media)²/n). Las rachas globales incluyen todos los registros; la actual termina hoy o ayer.',
          ),
        ],
      ),
      const SizedBox(height: 4),
      if (data.patterns.isEmpty)
        insufficient()
      else ...[
        Text(
          'Insights principales',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        for (final p in data.patterns.take(3)) insightCard(p),
      ],
      chart(
        TrendChart(
          points: data.points,
          metric: Metric.mood,
          average: s.moodAverage,
          moving: data.moodMoving,
        ),
      ),
    ];
  }

  List<Widget> activities(AnalyticsSnapshot data) => [
    toggle(activityMetric, (m) => setState(() => activityMetric = m)),
    const SizedBox(height: 16),
    if (data.activities.isEmpty)
      empty()
    else
      chart(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${activityMetric.label} por actividad · 1–${activityMetric.maximum}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final a in data.activities)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => activityDetail(a, data),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              a.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${a.average(activityMetric).toStringAsFixed(1)} · ${signed(a.difference(activityMetric))}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value:
                            a.average(activityMetric) / activityMetric.maximum,
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'n=${a.count} · ${a.percentage.toStringAsFixed(0)} % · ${a.count < 5 || data.records.length < 14 ? 'descriptivo' : 'ver detalle'}',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    if (data.patterns.isEmpty) insufficient(),
    const ExpansionTile(
      key: PageStorageKey('activity-method'),
      title: Text('¿Cómo se calculó?'),
      childrenPadding: EdgeInsets.all(16),
      children: [
        Text(
          'Se compara la media de cada actividad con la media general. Cada actividad cuenta una vez por fecha. Se requieren 14 días totales y 5 observaciones por actividad para señalar relaciones. Diferencia absoluta: <0.30 pequeña; 0.30–0.69 moderada; ≥0.70 relevante dentro de estos datos. Son umbrales de diseño, no médicos ni pruebas de significancia. Comparar muchas actividades puede producir diferencias por azar. No demuestra causalidad.',
        ),
      ],
    ),
  ];
  void activityDetail(ActivitySummary a, AnalyticsSnapshot data) {
    final rows = data.records.where(
      (r) => r.activities.any(
        (n) => n.trim().toLowerCase() == a.name.toLowerCase(),
      ),
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => FractionallySizedBox(
        heightFactor: .8,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(a.name, style: Theme.of(c).textTheme.headlineSmall),
            detail('Muestra', 'n=${a.count}/${data.records.length}'),
            detail(
              'Ánimo',
              '${a.moodAverage.toStringAsFixed(2)} · Δ ${signed(a.moodDifference)}',
            ),
            detail(
              'Energía',
              '${a.energyAverage.toStringAsFixed(2)} · Δ ${signed(a.energyDifference)}',
            ),
            detail('Mejor / peor', '${a.best}/8 · ${a.worst}/8'),
            Text(
              'Media general: ánimo ${data.summary.moodAverage.toStringAsFixed(2)}, energía ${data.summary.energyAverage.toStringAsFixed(2)}. Diferencia = media de actividad − media general. ${StatisticalRelationshipService().classify(a.difference(activityMetric)).name}. n<5 o menos de 14 días: solo descriptivo. No demuestra causalidad ni significancia; las comparaciones múltiples pueden reflejar azar.',
            ),
            for (final r in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(DateFormat.yMMMd('es_MX').format(r.date)),
                subtitle: RefugioMoodText(
                  r.mood,
                  text: '${r.mood.value}/8 · energía ${r.energy}/10',
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> trends(AnalyticsSnapshot data) => [
    Wrap(
      spacing: 8,
      children: [
        for (final e in {
          AnalyticsPeriod.last7: 7,
          AnalyticsPeriod.last30: 30,
          AnalyticsPeriod.last90: 90,
        }.entries)
          ChoiceChip(
            label: Text('${e.value} días'),
            selected: period == e.key,
            onSelected: (_) => setState(() => period = e.key),
          ),
      ],
    ),
    toggle(trendMetric, (m) => setState(() => trendMetric = m)),
    const SizedBox(height: 12),
    if (data.records.isEmpty)
      empty()
    else
      chart(
        TrendChart(
          points: data.points,
          metric: trendMetric,
          average: trendMetric == Metric.mood
              ? data.summary.moodAverage
              : data.summary.energyAverage,
          moving: trendMetric == Metric.mood
              ? data.moodMoving
              : data.energyMoving,
        ),
      ),
    const SizedBox(height: 12),
    SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 7, label: Text('7 contra 7')),
        ButtonSegment(value: 30, label: Text('30 contra 30')),
      ],
      selected: {comparisonDays},
      onSelectionChanged: (s) => setState(() => comparisonDays = s.first),
    ),
    Card(
      child: ListTile(
        leading: RefugioIcon(switch (data.comparison.direction) {
          TrendDirection.ascending => Icons.trending_up,
          TrendDirection.descending => Icons.trending_down,
          _ => Icons.trending_flat,
        }, size: 32),
        title: Text(
          data.comparison.direction == TrendDirection.insufficient
              ? 'Faltan registros'
              : '${data.comparison.label} · ${signed(data.comparison.difference!)}',
        ),
        subtitle: Text(
          'Actual ${data.comparison.recent?.toStringAsFixed(1) ?? '—'} (n=${data.comparison.recentCount}) · anterior ${data.comparison.previous?.toStringAsFixed(1) ?? '—'} (n=${data.comparison.previousCount})',
        ),
      ),
    ),
    ExpansionTile(
      key: const PageStorageKey('trend-method'),
      title: const Text('¿Cómo se calculó?'),
      childrenPadding: const EdgeInsets.all(16),
      children: [
        Text(
          'Media móvil de ${period == AnalyticsPeriod.last7 ? 3 : 7} días de calendario, usando solo el día actual y anteriores. Ausencias excluidas y huecos conservados. Mínimo 3 registros en cada periodo para comparar; ascendente ≥+0.25, descendente ≤−0.25, estable entre ambos. No demuestra causalidad.',
        ),
      ],
    ),
  ];
  List<Widget> health(AnalyticsSnapshot data, AppStore store) {
    final h = data.health;
    final byDate = {for (final r in data.records) dateKey(r.date): r};
    final scatter = <ScatterDatum>[];
    for (final v in store.healthData) {
      final r = byDate[v.dateKeyValue];
      final x = healthSteps
          ? v.steps?.toDouble()
          : v.sleepMinutes == null
          ? null
          : v.sleepMinutes! / 60;
      if (r != null && x != null) {
        scatter.add(
          ScatterDatum(
            v.date,
            x,
            healthSteps ? r.energy.toDouble() : r.mood.value.toDouble(),
          ),
        );
      }
    }
    return [
      HealthConnectionCard(store: store),
      const SizedBox(height: 12),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            label: Text('Sueño'),
            icon: RefugioIcon(Icons.bedtime_outlined),
          ),
          ButtonSegment(
            value: true,
            label: Text('Pasos'),
            icon: RefugioIcon(Icons.directions_walk),
          ),
        ],
        selected: {healthSteps},
        onSelectionChanged: (s) => setState(() => healthSteps = s.first),
      ),
      if (h.pairedDays == 0)
        empty()
      else ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            healthSteps
                ? '${h.stepsAverage?.round() ?? '—'} pasos · n=${h.stepDays}'
                : '${h.sleepAverage == null ? '—' : (h.sleepAverage! / 60).toStringAsFixed(1)} h · n=${h.sleepDays}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        chart(
          ValueBars(
            data: (healthSteps ? h.steps : h.sleep)
                .map((g) => BarDatum(g.label, g.moodAverage, g.count))
                .toList(),
            metric: Metric.mood,
          ),
        ),
        chart(HealthScatter(data: scatter, steps: healthSteps)),
        for (final p in h.patterns.where(
          (p) => healthSteps
              ? p.label.contains('pasos')
              : !p.label.contains('pasos'),
        ))
          Card(
            child: ExpansionTile(
              key: PageStorageKey('health-pattern-${p.label}'),
              title: Text(p.message),
              childrenPadding: const EdgeInsets.all(16),
              children: [Text(p.explanation)],
            ),
          ),
        ExpansionTile(
          key: const PageStorageKey('health-method'),
          title: const Text('Rangos y método'),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            for (final g in healthSteps ? h.steps : h.sleep)
              ListTile(
                title: Text(g.label),
                subtitle: Text(
                  'n=${g.count} · ánimo ${g.moodAverage?.toStringAsFixed(1) ?? '—'}/8 · energía ${g.energyAverage?.toStringAsFixed(1) ?? '—'}/10 · Δ ${g.differenceFrom(h.baseline(healthSteps))?.toStringAsFixed(1) ?? '—'}',
                ),
              ),
            const Text(
              'Cruce por fecha local. Los faltantes se excluyen, nunca valen cero. Patrones: 14 días totales y 5 observaciones del rango. Diferencia contra la media de los días emparejados con esa medida. Relaciones personales, sin causalidad ni diagnóstico.',
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> reports() => [
    Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            RefugioIcon(
              Icons.picture_as_pdf_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Tu historia, para llevar',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Semana o mes · privado por defecto',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 12),
    FilledButton.icon(
      onPressed: () => context.push('/reports'),
      icon: const RefugioIcon(Icons.picture_as_pdf_outlined),
      label: const Text('Generar reporte'),
    ),
  ];
  Widget empty() => EmptyState(onCreate: () => context.go('/today'));
  Widget insufficient() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const RefugioIcon(Icons.waves_rounded, size: 32),
          const Text(
            'Tu historia sigue creciendo',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'Aún no hay datos suficientes para identificar un patrón confiable.',
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: () => context.go('/today'),
            child: const Text('Ir al registro de hoy'),
          ),
        ],
      ),
    ),
  );
  Widget detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
  Widget metricCard(String label, String value, IconData icon, double width) =>
      SizedBox(
        width: width,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RefugioIcon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(label),
              ],
            ),
          ),
        ),
      );
  Widget chart(Widget child) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: RepaintBoundary(child: child),
    ),
  );
  Widget toggle(Metric metric, ValueChanged<Metric> changed) =>
      SegmentedButton<Metric>(
        segments: const [
          ButtonSegment(
            value: Metric.mood,
            label: Text('Ánimo'),
            icon: RefugioIcon(Icons.mood),
          ),
          ButtonSegment(
            value: Metric.energy,
            label: Text('Energía'),
            icon: RefugioIcon(Icons.bolt),
          ),
        ],
        selected: {metric},
        onSelectionChanged: (s) => changed(s.first),
      );
  Widget pattern(DetectedPattern p) => Card(
    child: ExpansionTile(
      key: PageStorageKey('pattern-${p.activity}-${p.metric.name}'),
      title: Text(p.message),
      childrenPadding: const EdgeInsets.all(16),
      children: [
        Text(
          '${p.explanation} Comparar varias actividades puede producir diferencias por azar.',
        ),
      ],
    ),
  );

  Widget insightCard(DetectedPattern p) {
    final positive = p.difference >= .30, negative = p.difference <= -.30;
    final icon = switch (p.activity.toLowerCase()) {
      'caminata' || 'aire libre' => '🚶',
      'ejercicio' => '🏃',
      'trabajo' => '💼',
      'estudio' => '📚',
      'descanso' => '🌙',
      'amigos' => '🫶',
      _ => '✨',
    };
    final color = positive
        ? Colors.teal
        : negative
        ? Colors.deepOrange
        : Theme.of(context).colorScheme.secondary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showInsightExplanation(p),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.activity,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p.metric.label} promedio: ${p.activityAverage.toStringAsFixed(1)}/${p.metric.maximum}',
                    ),
                    Text(
                      positive
                          ? '↑ ${p.difference.abs().toStringAsFixed(1)} puntos'
                          : negative
                          ? '↓ ${p.difference.abs().toStringAsFixed(1)} puntos'
                          : '→ Diferencia pequeña',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'n = ${p.sampleCount} registros',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showInsightExplanation(p),
                child: const Text('Ver explicación'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInsightExplanation(DetectedPattern p) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cómo se calculó', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(p.explanation),
            const SizedBox(height: 8),
            const Text(
              'La diferencia es descriptiva: no demuestra causalidad, cura ni diagnóstico. Las comparaciones múltiples pueden reflejar azar.',
            ),
          ],
        ),
      ),
    );
  }
}
