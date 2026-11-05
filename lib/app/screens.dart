import '../core/refugio_art.dart';

import 'dart:io';

import '../core/mood_style.dart';
import '../core/refugio.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'state.dart';
import '../core/widgets.dart';
import '../features/records/domain/record.dart';
import '../features/statistics/domain/statistics.dart';
import '../features/security/data/security.dart';
import '../features/privacy/presentation/data_controls.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month),
      selected = day(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final store = ref.read(storeProvider);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final r = store.at(selected);
        final count = DateTime(month.year, month.month + 1, 0).day;
        final offset = (month.weekday - 1);
        return page(
          context,
          'Tu calendario',
          'Cada emoción forma parte de tu historia.',
          [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mes anterior',
                  onPressed: () => setState(
                    () => month = DateTime(month.year, month.month - 1),
                  ),
                  icon: const RefugioIcon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', 'es_MX').format(month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Mes siguiente',
                  onPressed: () => setState(
                    () => month = DateTime(month.year, month.month + 1),
                  ),
                  icon: const RefugioIcon(Icons.chevron_right),
                ),
              ],
            ),
            LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: c.maxWidth < 360 ? 360 : c.maxWidth,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (final d in ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                            Expanded(child: Center(child: Text(d))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                          mainAxisExtent: MediaQuery.textScalerOf(context)
                              .scale(60),
                        ),
                        itemCount: offset + count,
                        itemBuilder: (context, i) {
                          if (i < offset) return const SizedBox();
                          final d = DateTime(
                            month.year,
                            month.month,
                            i - offset + 1,
                          );
                          final record = store.at(d);
                          final active = dateKey(d) == dateKey(selected);
                          final today = dateKey(d) == dateKey(DateTime.now());
                          return Semantics(
                            label:
                                '${DateFormat.yMMMMd('es_MX').format(d)}, ${record?.mood.accessible ?? 'sin registro'}${today ? ', hoy' : ''}',
                            selected: active,
                            button: true,
                            child: InkWell(
                              onTap: () => setState(() => selected = d),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      record?.mood.background(
                                        Theme.of(context).brightness ==
                                            Brightness.dark,
                                      ) ??
                                      Theme.of(context)
                                          .colorScheme
                                          .surfaceContainer,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: active
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${d.day}${today ? '·' : ''}',
                                      style: TextStyle(
                                        fontWeight: today
                                            ? FontWeight.w900
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    if (record != null)
                                      RefugioFace(mood: record.mood, size: 24),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    for (final mood in [
                      Mood.angry,
                      Mood.sad,
                      Mood.neutral,
                      Mood.good,
                      Mood.happy,
                      Mood.excellent,
                    ])
                      RefugioMoodText(mood, size: 24),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              DateFormat.yMMMMd('es_MX').format(selected),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (r == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Un día por descubrir. Aún no hay un registro.',
                      ),
                      TextButton(
                        onPressed: () =>
                            context.push('/edit/${dateKey(selected)}'),
                        child: const Text('Registrar este día'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RefugioMoodText(
                        r.mood,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text('Energía ${r.energy}/10'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: r.activities
                            .map((a) => Chip(label: Text(a)))
                            .toList(),
                      ),
                      Text(
                        r.reflection.isEmpty ? 'Sin reflexión' : r.reflection,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Actualizado ${DateFormat('d MMM · HH:mm', 'es_MX').format(r.updated)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                context.push('/edit/${dateKey(selected)}'),
                            icon: const RefugioIcon(Icons.edit_outlined),
                            label: const Text('Editar'),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              if (await confirmDelete(context)) {
                                try {
                                  await store.delete(r);
                                } catch (_) {
                                  if (context.mounted) {
                                    notice(
                                      context,
                                      'No se pudo eliminar. Intenta nuevamente.',
                                    );
                                  }
                                }
                              }
                            },
                            icon: const RefugioIcon(Icons.delete_outline),
                            label: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});
  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  bool monthly = false;
  DateTime anchor = day(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final store = ref.read(storeProvider);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final data = Statistics(
          Statistics.period(store.records, anchor, monthly),
        );
        final start = monthly
            ? DateTime(anchor.year, anchor.month)
            : shiftDay(anchor, 1 - anchor.weekday);
        final days = monthly
            ? DateTime(anchor.year, anchor.month + 1, 0).day
            : 7;
        return page(
          context,
          'Tus pequeñas olas',
          'Observa tu evolución, a tu ritmo.',
          [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Semanal')),
                ButtonSegment(value: true, label: Text('Mensual')),
              ],
              selected: {monthly},
              onSelectionChanged: (s) => setState(() => monthly = s.first),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Periodo anterior',
                  onPressed: () => setState(
                    () => anchor = monthly
                        ? DateTime(anchor.year, anchor.month - 1)
                        : shiftDay(anchor, -7),
                  ),
                  icon: const RefugioIcon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    monthly
                        ? DateFormat('MMMM yyyy', 'es_MX').format(anchor)
                        : '${DateFormat('d MMM', 'es_MX').format(start)} – ${DateFormat('d MMM', 'es_MX').format(shiftDay(start, 6))}',
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'Periodo siguiente',
                  onPressed: () => setState(
                    () => anchor = monthly
                        ? DateTime(anchor.year, anchor.month + 1)
                        : shiftDay(anchor, 7),
                  ),
                  icon: const RefugioIcon(Icons.chevron_right),
                ),
              ],
            ),
            if (data.records.isEmpty)
              EmptyState(onCreate: () => context.go('/today'))
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  metric(
                    'Ánimo promedio',
                    '${data.moodAverage.toStringAsFixed(1)} / 8',
                    Icons.mood,
                  ),
                  metric(
                    'Energía promedio',
                    '${data.energyAverage.toStringAsFixed(1)} / 10',
                    Icons.bolt,
                  ),
                  metric(
                    'Días registrados',
                    '${data.records.length} / $days',
                    Icons.calendar_today,
                  ),
                  metric(
                    'Más frecuente',
                    data.frequentMood!.name,
                    Icons.favorite_outline,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const RefugioIcon(Icons.auto_awesome),
                  title: const Text('Tu mejor día'),
                  subtitle: Text(
                    '${DateFormat('d MMM', 'es_MX').format(data.best!.date)} · ${data.best!.mood.name} · Energía ${data.best!.energy}/10',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Evolución del ánimo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Cada punto es un registro. Los espacios sin datos no se estiman.',
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: (days * 38.0).clamp(280, 1300),
                      height: 210,
                      child: CustomPaint(
                        painter: TrendPainter(
                          data.records,
                          start,
                          days,
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ExpansionTile(
                title: const Text('Ver fechas y valores'),
                children: [
                  for (final r in data.records)
                    ListTile(
                      title: Text(DateFormat.yMMMd('es_MX').format(r.date)),
                      subtitle: RefugioMoodText(
                        r.mood,
                        text:
                            '${r.mood.name} · Ánimo ${r.mood.value}/8 · Energía ${r.energy}/10',
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Estas observaciones son personales y no constituyen un diagnóstico médico ni psicológico.',
            ),
          ],
        );
      },
    );
  }
}

class TrendPainter extends CustomPainter {
  TrendPainter(this.records, this.start, this.days, this.color);
  final List<Record> records;
  final DateTime start;
  final int days;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const left = 26.0, top = 12.0;
    final w = size.width - 44, h = size.height - 44;
    for (var i = 1; i <= 8; i++) {
      final y = top + h - (i - 1) / 7 * h;
      canvas.drawLine(
        Offset(left, y),
        Offset(left + w, y),
        Paint()..color = color.withValues(alpha: .12),
      );
      label(canvas, '$i', Offset(0, y - 6));
    }
    Offset? previous;
    for (final r in records) {
      final index = DateTime.utc(
        r.date.year,
        r.date.month,
        r.date.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
      final p = Offset(
        left + index / (days - 1) * w,
        top + h - (r.mood.value - 1) / 7 * h,
      );
      if (previous != null) canvas.drawLine(previous, p, paint);
      canvas.drawCircle(p, 4, paint);
      label(canvas, '${r.date.day}', Offset(p.dx - 5, top + h + 12));
      previous = p;
    }
  }

  void label(Canvas c, String text, Offset at) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(c, at);
  }

  @override
  bool shouldRepaint(covariant TrendPainter old) => true;
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(storeProvider);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final stats = Statistics(store.records);
        return page(
          context,
          'Tu espacio',
          'Un día a la vez también es avanzar.',
          [
            Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 38,
                  child: store.name.isEmpty
                      ? const RefugioIcon(Icons.person_outline, size: 40)
                      : Text(
                          store.name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              store.name.isEmpty
                  ? 'Hola, qué bueno verte'
                  : 'Hola, ${store.name}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TextButton.icon(
              onPressed: () => editName(context, store),
              icon: const RefugioIcon(Icons.edit_outlined),
              label: const Text('Editar apodo'),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      child: RefugioIcon(
                        Icons.auto_graph_rounded,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tu historia',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            store.records.isEmpty
                                ? 'Comienza con tu primer registro'
                                : 'Cada registro ayuda a conocerte mejor',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (store.records.length / 30).clamp(0, 1),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                metric(
                  'Total de registros',
                  '${store.records.length}',
                  Icons.book_outlined,
                ),
                metric(
                  'Racha actual',
                  '${stats.currentStreak(DateTime.now())} días',
                  Icons.local_fire_department_outlined,
                ),
                metric(
                  'Mejor racha',
                  '${stats.bestStreak} días',
                  Icons.emoji_events_outlined,
                ),
                metric(
                  'Emoción frecuente',
                  stats.modes.isEmpty
                      ? 'Por descubrir'
                      : stats.modes.length > 1
                      ? '${stats.modes.length} empatadas'
                      : stats.modes.single.name,
                  Icons.mood,
                ),
              ],
            ),
            Card(
              child: ListTile(
                leading: const RefugioIcon(Icons.interests_outlined),
                title: const Text('Actividad más frecuente'),
                subtitle: Text(
                  stats.frequentActivity ?? 'Aún no hay actividades',
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => context.push('/settings'),
              icon: const RefugioIcon(Icons.settings_outlined),
              label: const Text('Configuración'),
            ),
          ],
        );
      },
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late Future<BioStatus> available;
  late Future<PackageInfo> info;
  @override
  void initState() {
    super.initState();
    available = ref.read(storeProvider).biometrics.availability();
    info = PackageInfo.fromPlatform();
  }

  Future<void> action(Future<void> Function() fn, String success) async {
    try {
      await fn();
      if (mounted) notice(context, success);
    } catch (_) {
      if (mounted) {
        notice(context, 'No se pudo completar la acción. Intenta nuevamente.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(storeProvider);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Configuración')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const WaveHeader(
              'Configuración',
              'Cuida tu espacio y tu privacidad.',
            ),
            const SizedBox(height: 12),
            section(context, 'Perfil'),
            ListTile(
              leading: const RefugioIcon(Icons.person_outline),
              title: const Text('Nombre o apodo'),
              subtitle: Text(store.name.isEmpty ? 'Agregar apodo' : store.name),
              onTap: () => editName(context, store),
            ),
            section(context, 'Seguridad'),
            ListTile(
              leading: const RefugioIcon(Icons.pin_outlined),
              title: const Text('Cambiar PIN'),
              onTap: () => context.push('/pin'),
            ),
            FutureBuilder(
              future: available,
              builder: (context, s) => ListTile(
                leading: const RefugioIcon(Icons.fingerprint),
                title: Text(
                  s.hasData ? bioLabel(s.data!) : 'Comprobando biometría…',
                ),
              ),
            ),
            SwitchListTile(
              title: const Text('Mostrar botón biométrico'),
              value: store.bioEnabled,
              onChanged: (v) => action(() async {
                await store.setBioEnabled(v);
              }, 'Preferencia guardada'),
            ),
            ListTile(
              leading: const RefugioIcon(Icons.lock_outline),
              title: const Text('Bloquear MoodWave ahora'),
              onTap: store.lock,
            ),
            section(context, 'Apariencia'),
            DropdownButtonFormField<ThemeMode>(
              initialValue: store.theme,
              decoration: const InputDecoration(labelText: 'Tema'),
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('Del sistema'),
                ),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Oscuro')),
              ],
              onChanged: (v) =>
                  action(() => store.setTheme(v!), 'Tema guardado'),
            ),
            if (kDebugMode) ...[
              section(context, 'Herramientas de demostración'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Datos de demostración',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Genera hasta 120 días sintéticos para probar gráficas, insights, predicción y PDF. Tus registros reales no se modifican.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const RefugioIcon(Icons.auto_graph),
                        label: const Text('Generar escenario de 120 días'),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text(
                                'Generar datos de demostración',
                              ),
                              content: const Text(
                                'Se agregarán aproximadamente 120 días de datos de demostración. Tus registros reales no se modificarán.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Generar'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true)
                            await action(
                              () => store.generate(
                                seed: 20261031,
                                replaceSynthetic: true,
                              ),
                              'Escenario generado. Revisa Patrones.',
                            );
                        },
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => action(
                              () => store.generate(
                                seed: 20261031,
                                emotional: true,
                                physical: false,
                              ),
                              'Datos emocionales generados',
                            ),
                            child: const Text('Solo emocionales'),
                          ),
                          OutlinedButton(
                            onPressed: () => action(
                              () => store.generate(
                                seed: 20261031,
                                emotional: false,
                                physical: true,
                              ),
                              'Sueño y pasos generados',
                            ),
                            child: const Text('Solo sueño y pasos'),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        icon: const RefugioIcon(Icons.delete_sweep_outlined),
                        label: const Text('Eliminar datos sintéticos'),
                        onPressed: () async {
                          final count =
                              store.records.where((r) => r.test).length +
                              store.healthData
                                  .where((h) => h.isSynthetic)
                                  .length;
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Eliminar datos sintéticos'),
                              content: Text(
                                'Se eliminarán $count registros sintéticos. Los registros reales permanecerán intactos.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true)
                            await action(() async {
                              await store.repository.deleteTests();
                              await store.refresh();
                            }, 'Datos sintéticos eliminados');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
            section(context, 'Privacidad y datos'),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Tus datos y la IA permanecen en el dispositivo, sin servidores. Sueño y pasos son opcionales. Health Connect requiere permiso explícito y revocable en equipos compatibles. El PDF y el JSON crean archivos externos; compartir es explícito. Reflexiones y predicción están excluidas del PDF por defecto. Puedes exportar o eliminar tus datos. Las predicciones son experimentales. MoodWave no realiza diagnósticos médicos ni sustituye atención profesional.',
                ),
              ),
            ),
            DataControls(store: store),
            const ListTile(
              leading: RefugioIcon(Icons.shield_outlined),
              title: Text('Tus datos viven en este dispositivo'),
              subtitle: Text(
                'No hay cuentas ni sincronización. La base SQLite está en el espacio privado de la aplicación.',
              ),
            ),
            ListTile(
              leading: const RefugioIcon(Icons.file_download_outlined),
              title: const Text('Exportar CSV local'),
              subtitle: const Text(
                'El archivo contiene tus reflexiones sin cifrar',
              ),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Exportar tus registros'),
                    content: const Text(
                      'Se guardará un CSV sin cifrar en la carpeta de documentos privada de la app. Puedes recuperarlo con las herramientas de desarrollo. ¿Continuar?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Exportar'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                await action(() async {
                  String cell(String s) => '"${s.replaceAll('"', '""')}"';
                  final lines = [
                    'fecha,animo,energia,actividades,reflexion',
                    ...store.records.map(
                      (r) => [
                        dateKey(r.date),
                        r.mood.name,
                        '${r.energy}',
                        r.activities.join(' · '),
                        r.reflection,
                      ].map(cell).join(','),
                    ),
                  ];
                  final dir = await getApplicationDocumentsDirectory();
                  final file = File(
                    '${dir.path}/moodwave-${DateTime.now().millisecondsSinceEpoch}.csv',
                  );
                  await file.writeAsString('\uFEFF${lines.join('\r\n')}');
                  if (context.mounted) {
                    await showDialog<void>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('CSV guardado'),
                        content: SelectableText(file.path),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('Aceptar'),
                          ),
                        ],
                      ),
                    );
                  }
                }, 'Exportación terminada');
              },
            ),
            if (kDebugMode)
              ListTile(
                leading: const RefugioIcon(Icons.science_outlined),
                title: const Text('Generar 90 días de prueba'),
                subtitle: const Text(
                  'Solo debug · no sobrescribe días existentes',
                ),
                onTap: () =>
                    action(store.generate, 'Datos de prueba generados'),
              ),
            ListTile(
              leading: const RefugioIcon(Icons.cleaning_services_outlined),
              title: const Text('Eliminar registros de prueba'),
              onTap: () async {
                if (await confirmDelete(
                  context,
                  title: '¿Eliminar registros de prueba?',
                )) {
                  await action(() async {
                    await store.repository.deleteTests();
                    await store.refresh();
                  }, 'Registros de prueba eliminados');
                }
              },
            ),
            ListTile(
              leading: const RefugioIcon(Icons.delete_forever_outlined),
              title: const Text('Eliminar todos los registros'),
              onTap: () async {
                if (!await confirmDelete(
                  context,
                  title: '¿Eliminar todos tus registros?',
                  body: 'Perderás tus registros emocionales, sueño y pasos. Tu PIN se conservará. Los PDF exportados no se borran.',
                )) {
                  return;
                }
                if (!context.mounted) return;
                if (await confirmDelete(
                  context,
                  title: 'Confirmación final',
                  body: '¿Confirmas que quieres borrar definitivamente todos los registros?',
                )) {
                  await action(() async {
                    await store.repository.deleteAll();
                    await store.refresh();
                  }, 'Registros eliminados');
                }
              },
            ),
            section(context, 'Acerca de'),
            FutureBuilder(
              future: info,
              builder: (context, s) => ListTile(
                title: const Text('MoodWave'),
                subtitle: Text(
                  s.hasData
                      ? 'Versión ${s.data!.version} (${s.data!.buildNumber})'
                      : 'Consultando versión…',
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Tu diario emocional privado. Las estadísticas no constituyen un diagnóstico. La cámara no se utiliza para autenticar rostros; la biometría depende del hardware y del sistema.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget section(BuildContext context, String title) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
  child: Text(title, style: Theme.of(context).textTheme.titleLarge),
);
Widget metric(String label, String value, IconData icon) => Builder(
  builder: (context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width.clamp(240, 720) - 44) / 2,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: RefugioIcon(
                icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            Text(label),
          ],
        ),
      ),
    ),
  ),
);
Widget page(
  BuildContext context,
  String title,
  String subtitle,
  List<Widget> children,
) => SafeArea(
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WaveHeader(title, subtitle),
          const SizedBox(height: 20),
          ...children,
          const SizedBox(height: 24),
        ],
      ),
    ),
  ),
);
Future<void> editName(BuildContext context, AppStore store) async {
  final controller = TextEditingController(text: store.name);
  final name = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('¿Cómo te llamamos?'),
      content: TextField(
        controller: controller,
        maxLength: 40,
        decoration: const InputDecoration(labelText: 'Nombre o apodo'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, controller.text),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  if (name != null) {
    try {
      await store.setName(name);
    } catch (_) {
      if (context.mounted) notice(context, 'No se pudo guardar el apodo.');
    }
  }
}
