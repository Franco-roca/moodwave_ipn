import '../../../core/refugio_art.dart';

import 'package:flutter/material.dart';

import '../../../core/mood_style.dart';
import '../../../core/refugio.dart';

import 'package:intl/intl.dart';

import '../../../core/widgets.dart';
import '../domain/record.dart';
import '../../health/domain/daily_health.dart';

String moodMessage(Mood? mood) => switch (mood) {
  Mood.angry => 'Aquí también hay espacio para el enojo.',
  Mood.sad => 'No tienes que sentirte bien para estar aquí.',
  Mood.down => 'Hoy puedes ir a tu propio ritmo.',
  Mood.worried => 'Dale un poco de espacio a lo que te preocupa.',
  Mood.neutral => 'Los días tranquilos también cuentan.',
  Mood.good => 'Quédate un momento con esa sensación.',
  Mood.happy => '¿Qué le dio luz a tu día?',
  Mood.excellent => 'Un momento que vale la pena recordar.',
  null => 'No hay respuestas correctas. Solo tu manera de sentir.',
};

class MoodOrb extends StatelessWidget {
  const MoodOrb({super.key, required this.mood, this.size = 108});
  final Mood? mood;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedSwitcher(
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
      ),
      child: mood == null
          ? Image.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? Refugio.nightHero
                  : Refugio.hero,
              key: ValueKey('sanctuary-${Theme.of(context).brightness.name}'),
              width: size * 2.1,
              height: size * 1.75,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            )
          : RefugioFace(key: ValueKey(mood), mood: mood!, size: size * 1.3),
    ),
  );
}

class JourneySteps extends StatelessWidget {
  const JourneySteps({
    super.key,
    required this.current,
    required this.onSelected,
  });
  final int current;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
              child: Semantics(
                selected: current == i,
                label: 'Paso ${i + 1} de 3',
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSelected(i),
                  child: AnimatedContainer(
                    duration: Duration(
                      milliseconds: MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : 180,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: current == i
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? scheme.primaryContainer
                                : Refugio.apricot)
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        RefugioIcon(
                          [
                            Icons.favorite_outline,
                            Icons.wb_sunny_outlined,
                            Icons.auto_awesome_outlined,
                          ][i],
                          size: 20,
                          color: current == i
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ['Sentir', 'Vivir', 'Recordar'][i],
                          style: TextStyle(
                            fontWeight: current == i
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class EnergyIsland extends StatelessWidget {
  const EnergyIsland({super.key, required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = value <= 3
        ? 'En modo pausa'
        : value <= 6
        ? 'A mi ritmo'
        : 'Con toda la energía';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mi batería de hoy',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Text(label),
                  ],
                ),
              ),
              Text(
                '${value.round()}',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                ),
              ),
              const Text(' / 10'),
            ],
          ),
          const SizedBox(height: 20),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 1; i <= 10; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: Duration(
                        milliseconds: MediaQuery.disableAnimationsOf(context)
                            ? 0
                            : 180,
                      ),
                      height: 16 + i * 3.0,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= value.round()
                            ? scheme.primary
                            : scheme.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Slider(
            value: value,
            min: 1,
            max: 10,
            divisions: 9,
            label: '${value.round()} de 10',
            semanticFormatterCallback: (v) => 'Energía ${v.round()} de 10',
            onChanged: onChanged,
          ),
          const Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 8,
            children: [Text('Necesito recargar'), Text('Batería llena')],
          ),
        ],
      ),
    );
  }
}

IconData activityIcon(String activity) => switch (activity) {
  'Trabajo' => Icons.work_outline,
  'Estudio' => Icons.menu_book_rounded,
  'Ejercicio' => Icons.directions_run,
  'Familia' => Icons.home_outlined,
  'Amigos' => Icons.people_outline,
  'Entretenimiento' => Icons.headphones,
  'Descanso' => Icons.nightlight_outlined,
  'Viaje' => Icons.explore_outlined,
  'Compras' => Icons.shopping_bag_outlined,
  'Tareas domésticas' => Icons.cleaning_services_outlined,
  _ => Icons.auto_awesome_outlined,
};

class WeekRibbon extends StatelessWidget {
  const WeekRibbon({super.key, required this.records, required this.date});
  final List<Record> records;
  final DateTime date;
  @override
  Widget build(BuildContext context) {
    final start = shiftDay(day(date), 1 - date.weekday);
    final lookup = {for (final r in records) dateKey(r.date): r};
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      foregroundPainter: BotanicalArt(
        dark: Theme.of(context).brightness == Brightness.dark,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu semana, a tu manera',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final d = shiftDay(start, i);
                        final record = lookup[dateKey(d)];
                        final today = dateKey(d) == dateKey(date);
                        return Semantics(
                          label:
                              '${DateFormat.yMMMMd('es_MX').format(d)}: ${record?.mood.name ?? 'sin registro'}',
                          child: ExcludeSemantics(
                            child: Column(
                              children: [
                                Text(
                                  ['L', 'M', 'M', 'J', 'V', 'S', 'D'][i],
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        record?.mood.background(
                                          Theme.of(context).brightness ==
                                              Brightness.dark,
                                        ) ??
                                        scheme.surfaceContainer,
                                    border: today
                                        ? Border.all(
                                            color: scheme.primary,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: record == null
                                      ? Text(
                                          '${d.day}',
                                          style: const TextStyle(fontSize: 12),
                                        )
                                      : RefugioFace(
                                          mood: record.mood,
                                          size: 28,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SavedMoment extends StatelessWidget {
  const SavedMoment({
    super.key,
    required this.record,
    required this.onEdit,
    this.onCalendar,
    this.health,
  });
  final Record record;
  final VoidCallback onEdit;
  final VoidCallback? onCalendar;
  final DailyHealthData? health;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const WaveHeader(
        'Un momento para ti',
        'Tu día ya tiene un lugar en tu historia.',
      ),
      const SizedBox(height: 24),
      MoodOrb(mood: record.mood, size: 124),
      const SizedBox(height: 16),
      Semantics(
        liveRegion: true,
        child: Text(
          'Tu día está guardado',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 8),
      Text(moodMessage(record.mood), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: RefugioMoodText(
                    record.mood,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const RefugioIcon(Icons.bolt_rounded, size: 20),
                Text('${record.energy}/10'),
              ],
            ),
            if (record.activities.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final a in record.activities)
                    Chip(
                      avatar: RefugioIcon(activityIcon(a), size: 16),
                      label: Text(a),
                    ),
                ],
              ),
            ],
            if (record.reflection.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '“${record.reflection}”',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            if (health != null && !health!.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Bienestar físico · ${health!.source == HealthSource.manual
                    ? 'Manual'
                    : health!.source == HealthSource.imported
                    ? 'Importado'
                    : health!.isSynthetic
                    ? 'Prueba sintética'
                    : 'Health Connect'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (health!.sleepMinutes != null)
                Text(
                  'Sueño: ${health!.sleepMinutes! ~/ 60} h ${health!.sleepMinutes! % 60} min',
                ),
              if (health!.steps != null)
                Text(
                  'Pasos: ${NumberFormat.decimalPattern('es_MX').format(health!.steps!)}',
                ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const RefugioIcon(Icons.edit_outlined),
              label: const Text('Cambiar algo de mi día'),
            ),
          ],
        ),
      ),
      if (onCalendar != null)
        TextButton.icon(
          onPressed: onCalendar,
          icon: const RefugioIcon(Icons.calendar_month_outlined),
          label: const Text('Explorar mis días'),
        ),
    ],
  );
}
