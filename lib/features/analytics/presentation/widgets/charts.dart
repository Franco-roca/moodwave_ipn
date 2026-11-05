import '../../../../core/refugio_art.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../domain/analytics.dart';

class BarDatum {
  const BarDatum(this.label, this.value, this.count);
  final String label;
  final double? value;
  final int count;
}

class ValueBars extends StatelessWidget {
  const ValueBars({super.key, required this.data, required this.metric});
  final List<BarDatum> data;
  final Metric metric;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${metric.label} promedio · escala 1–${metric.maximum}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const Text('Desliza y toca una barra para ver sus datos.'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              height: 180,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('${metric.maximum}'), const Text('1')],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: PageStorageKey('bars-${metric.name}'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final d in data)
                      Semantics(
                        button: true,
                        label:
                            '${d.label}: ${d.value?.toStringAsFixed(1) ?? 'sin datos'}, ${d.count} registros',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: Text(d.label),
                              content: Text(
                                '${metric.label}: ${d.value?.toStringAsFixed(1) ?? 'Sin datos'} / ${metric.maximum}\n${d.count} registros\n${evidenceLabel(evidenceFor(d.count))}',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text('Cerrar'),
                                ),
                              ],
                            ),
                          ),
                          child: SizedBox(
                            width: 96,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    d.value?.toStringAsFixed(1) ?? '—',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(
                                    height: 154,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: d.value == null
                                          ? RefugioIcon(
                                              Icons.remove,
                                              color: scheme.outline,
                                            )
                                          : Container(
                                              width: 42,
                                              height:
                                                  ((d.value! - 1) /
                                                      (metric.maximum - 1) *
                                                      140 +
                                                  3),
                                              decoration: BoxDecoration(
                                                color: scheme.primary,
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(12),
                                                    ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(d.label, textAlign: TextAlign.center),
                                  Text(
                                    'n=${d.count}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.metric,
    required this.average,
    this.moving = const [],
  });
  final List<TrendPoint> points;
  final Metric metric;
  final double? average;
  final List<double?> moving;
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox();
    final width = points.length * 48.0 + 40;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${metric.label} · escala 1–${metric.maximum}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const Text('● Registro   — Media móvil   ··· Media general'),
        const SizedBox(height: 8),
        Semantics(
          label:
              'Evolución de ${metric.label.toLowerCase()}. Consulta Fechas y valores para leer cada registro.',
          child: SingleChildScrollView(
            key: PageStorageKey('trend-${metric.name}'),
            scrollDirection: Axis.horizontal,
            child: GestureDetector(
              onTapUp: (details) {
                final index = ((details.localPosition.dx - 28) / 48)
                    .round()
                    .clamp(0, points.length - 1);
                final p = points[index];
                final r = p.record;
                showDialog<void>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(DateFormat.yMMMMd('es_MX').format(p.date)),
                    content: Text(
                      r == null
                          ? 'Sin registro'
                          : metric == Metric.mood
                          ? '${r.mood.name}\nÁnimo ${r.mood.value}/8'
                          : 'Energía ${r.energy}/10',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                );
              },
              child: SizedBox(
                width: width,
                height: 220,
                child: CustomPaint(
                  painter: TrendCanvas(
                    points,
                    metric,
                    average,
                    scheme.primary,
                    scheme.onSurfaceVariant,
                    moving,
                  ),
                ),
              ),
            ),
          ),
        ),
        ExpansionTile(
          key: PageStorageKey('trend-details-${metric.name}'),
          title: const Text('Fechas y valores'),
          children: [
            for (final p in points.where((p) => p.record != null))
              ListTile(
                dense: true,
                title: Text(DateFormat.yMMMd('es_MX').format(p.date)),
                subtitle: Text(
                  '${p.record!.mood.name} · Ánimo ${p.record!.mood.value}/8 · Energía ${p.record!.energy}/10',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class TrendCanvas extends CustomPainter {
  TrendCanvas(
    this.points,
    this.metric,
    this.average,
    this.color,
    this.textColor,
    this.moving,
  );
  final List<TrendPoint> points;
  final Metric metric;
  final double? average;
  final Color color, textColor;
  final List<double?> moving;
  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0, top = 14.0, height = 166.0;
    double y(double value) =>
        top + height - (value - 1) / (metric.maximum - 1) * height;
    void label(String text, Offset at) {
      final p = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, at);
    }

    for (var value = 1; value <= metric.maximum; value++) {
      final py = y(value.toDouble());
      canvas.drawLine(
        Offset(left, py),
        Offset(size.width, py),
        Paint()..color = color.withValues(alpha: .1),
      );
      label('$value', Offset(0, py - 6));
    }
    if (average != null) {
      final py = y(average!);
      for (var x = left; x < size.width; x += 12) {
        canvas.drawLine(
          Offset(x, py),
          Offset(x + 6, py),
          Paint()
            ..color = textColor.withValues(alpha: .5)
            ..strokeWidth = 1,
        );
      }
    }
    Offset? previous;
    for (var i = 0; i < points.length; i++) {
      final p = points[i], x = left + i * 48.0;
      label(DateFormat('d/M').format(p.date), Offset(x - 10, 190));
      if (p.record == null) {
        previous = null;
        continue;
      }
      final current = Offset(x, y(metric.value(p.record!)));
      if (previous != null) {
        canvas.drawLine(
          previous,
          current,
          Paint()
            ..color = color
            ..strokeWidth = 2.5,
        );
      }
      canvas.drawCircle(current, 4, Paint()..color = color);
      previous = current;
    }
    Offset? priorAverage;
    for (var i = 0; i < moving.length; i++) {
      if (moving[i] == null) {
        priorAverage = null;
        continue;
      }
      final current = Offset(left + i * 48, y(moving[i]!));
      if (priorAverage != null) {
        canvas.drawLine(
          priorAverage,
          current,
          Paint()
            ..color = textColor
            ..strokeWidth = 3,
        );
      }
      priorAverage = current;
    }
  }

  @override
  bool shouldRepaint(covariant TrendCanvas old) =>
      old.points != points ||
      old.metric != metric ||
      old.average != average ||
      old.color != color ||
      old.textColor != textColor;
}

class ScatterDatum {
  const ScatterDatum(this.date, this.x, this.y);
  final DateTime date;
  final double x, y;
}

class HealthScatter extends StatelessWidget {
  const HealthScatter({super.key, required this.data, required this.steps});
  final List<ScatterDatum> data;
  final bool steps;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        steps
            ? 'Pasos × energía · n=${data.length}'
            : 'Sueño × ánimo · n=${data.length}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) => Semantics(
          label: 'Dispersión. Toca un punto o consulta las fechas y valores.',
          child: GestureDetector(
            onTapUp: (tap) {
              if (data.isEmpty) return;
              final width = constraints.maxWidth - 48;
              final maxX = data.fold<double>(
                steps ? 10000 : 10,
                (m, d) => d.x > m ? d.x : m,
              );
              final selected = [...data]
                ..sort((a, b) {
                  double distance(ScatterDatum d) =>
                      (Offset(
                                30 + d.x / maxX * width,
                                160 - (d.y - 1) / (steps ? 9 : 7) * 145,
                              ) -
                              tap.localPosition)
                          .distanceSquared;
                  return distance(a).compareTo(distance(b));
                });
              final d = selected.first;
              showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(DateFormat.yMMMd('es_MX').format(d.date)),
                  content: Text(
                    '${d.x.toStringAsFixed(steps ? 0 : 1)} ${steps ? 'pasos' : 'horas'} · ${d.y.toStringAsFixed(0)}/${steps ? 10 : 8}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            },
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: CustomPaint(
                painter: ScatterCanvas(
                  data,
                  steps,
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
      Text(
        steps
            ? 'X: pasos · Y: energía (1–10)'
            : 'X: horas de sueño · Y: ánimo (1–8)',
      ),
      ExpansionTile(
        key: PageStorageKey('scatter-values-$steps'),
        title: const Text('Fechas y valores'),
        children: [
          for (final d in data)
            ListTile(
              title: Text(DateFormat.yMMMd('es_MX').format(d.date)),
              subtitle: Text(
                '${d.x.toStringAsFixed(steps ? 0 : 1)} ${steps ? 'pasos' : 'h'} · ${d.y.toInt()}/${steps ? 10 : 8}',
              ),
            ),
        ],
      ),
    ],
  );
}

class ScatterCanvas extends CustomPainter {
  ScatterCanvas(this.data, this.steps, this.color, this.textColor);
  final List<ScatterDatum> data;
  final bool steps;
  final Color color, textColor;
  @override
  void paint(Canvas canvas, Size size) {
    final maxX = data.fold<double>(
      steps ? 10000 : 10,
      (m, d) => d.x > m ? d.x : m,
    );
    void label(String text, Offset at) {
      final p = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 11,
            color: textColor,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, at);
    }

    for (final v in [1, steps ? 5 : 4, steps ? 10 : 8]) {
      final y = 160 - (v - 1) / (steps ? 9 : 7) * 145;
      canvas.drawLine(
        Offset(30, y),
        Offset(size.width - 18, y),
        Paint()..color = color.withValues(alpha: .15),
      );
      label('$v', Offset(2, y - 5));
    }
    label('0', const Offset(30, 174));
    label(maxX.toStringAsFixed(0), Offset(size.width - 50, 174));
    for (final d in data) {
      canvas.drawCircle(
        Offset(
          30 + d.x / maxX * (size.width - 48),
          160 - (d.y - 1) / (steps ? 9 : 7) * 145,
        ),
        4,
        Paint()..color = color.withValues(alpha: .65),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScatterCanvas old) =>
      old.data != data || old.color != color || old.steps != steps;
}
