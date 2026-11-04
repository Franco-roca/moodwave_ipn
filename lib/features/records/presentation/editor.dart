import 'package:flutter/material.dart';

import '../../../core/mood_style.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/state.dart';
import '../../../core/widgets.dart';
import '../domain/record.dart';
import 'journey_widgets.dart';
import '../../health/domain/daily_health.dart';
import '../../health/presentation/health_fields.dart';
import '../../support/domain/risk_support.dart';
import '../../support/presentation/support_screen.dart';

class Editor extends ConsumerStatefulWidget {
  const Editor({super.key, this.date});
  final DateTime? date;
  @override
  ConsumerState<Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<Editor> {
  late DateTime date;
  Mood? mood;
  double energy = 5;
  final selected = <String>{};
  final reflection = TextEditingController();
  final sleepHours = TextEditingController(),
      sleepMinutes = TextEditingController(),
      steps = TextEditingController();
  final scroll = ScrollController();
  bool busy = false, dirty = false, editing = false;
  int step = 0;
  Record? original;

  @override
  void initState() {
    super.initState();
    date = day(widget.date ?? DateTime.now());
    editing = widget.date != null;
    load();
  }

  void load() {
    original = ref.read(storeProvider).at(date);
    mood = original?.mood;
    energy = (original?.energy ?? 5).toDouble();
    selected
      ..clear()
      ..addAll(original?.activities ?? []);
    reflection.text = original?.reflection ?? '';
    final health = ref.read(storeProvider).healthAt(date);
    sleepHours.text = health?.sleepMinutes == null
        ? ''
        : '${health!.sleepMinutes! ~/ 60}';
    sleepMinutes.text = health?.sleepMinutes == null
        ? ''
        : '${health!.sleepMinutes! % 60}';
    steps.text = health?.steps?.toString() ?? '';
    dirty = false;
  }

  @override
  void dispose() {
    reflection.dispose();
    sleepHours.dispose();
    sleepMinutes.dispose();
    steps.dispose();
    scroll.dispose();
    super.dispose();
  }

  void goStep(int value) {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    HapticFeedback.selectionClick();
    setState(() => step = value);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void editMoment() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      editing = true;
      step = 0;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> addActivity() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Dale nombre a tu momento'),
        content: TextField(
          controller: controller,
          maxLength: 30,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tu actividad',
            hintText: 'Por ejemplo: pasear con mi perro',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (value == null) return;
    try {
      final activity = await ref.read(storeProvider).addActivity(value);
      if (mounted) {
        setState(() {
          selected.add(activity);
          dirty = true;
        });
      }
    } catch (_) {
      if (mounted) notice(context, 'Escribe un nombre de 1 a 30 caracteres.');
    }
  }

  Future<void> save() async {
    if (mood == null) {
      goStep(0);
      notice(context, 'Elige la emoción que más se acerque a tu día.');
      return;
    }
    if (RiskSupportService().shouldOffer(reflection.text)) {
      await showSupport(context);
      if (!mounted) return;
    }
    DailyHealthData? health;
    try {
      final sleep = parseSleep(sleepHours.text, sleepMinutes.text),
          dailySteps = parseSteps(steps.text);
      final previous = ref.read(storeProvider).healthAt(date);
      health = DailyHealthData(
        date: date,
        sleepMinutes: sleep,
        steps: dailySteps,
        source:
            previous != null &&
                previous.sleepMinutes == sleep &&
                previous.steps == dailySteps
            ? previous.source
            : HealthSource.manual,
      );
    } on FormatException catch (error) {
      goStep(1);
      notice(context, error.message);
      return;
    }
    setState(() => busy = true);
    try {
      await ref
          .read(storeProvider)
          .save(
            Record(
              date: date,
              mood: mood!,
              energy: energy.round(),
              activities: selected.toList()..sort(),
              reflection: reflection.text.trim(),
              test: false,
            ),
            health: health,
            updateHealth: true,
          );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        original = ref.read(storeProvider).at(date);
        dirty = false;
        editing = false;
        step = 0;
      });
      if (scroll.hasClients) scroll.jumpTo(0);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (_) {
      if (mounted) {
        notice(
          context,
          'No se pudo guardar. Tu texto sigue aquí; intenta otra vez.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget footer() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .4),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          if (step > 0) ...[
            IconButton.filledTonal(
              tooltip: 'Paso anterior',
              onPressed: busy ? null : () => goStep(step - 1),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton.icon(
              onPressed: busy
                  ? null
                  : () {
                      if (step == 0 && mood == null) {
                        notice(
                          context,
                          'Elige la emoción que más se acerque a tu día.',
                        );
                        return;
                      }
                      if (step < 2) {
                        goStep(step + 1);
                      } else {
                        save();
                      }
                    },
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      step == 2
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                    ),
              label: Text(
                step == 2
                    ? (original == null
                          ? 'Guardar mi momento'
                          : 'Guardar cambios')
                    : 'Continuar',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(storeProvider);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!dirty && store.at(date) != original) load();
        final saved = original != null && !editing && !dirty;
        return Scaffold(
          bottomNavigationBar: saved
              ? null
              : SafeArea(
                  top: false,
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: footer(),
                    ),
                  ),
                ),
          appBar: widget.date != null
              ? AppBar(title: const Text('Un día en tu historia'))
              : null,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        children: [
                          const WaveHeader('MoodWave', 'Un momento para ti.'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  store.name.isEmpty
                                      ? 'Este momento es tuyo'
                                      : 'Hola, ${store.name}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Tooltip(
                                message: 'Tu diario es privado y local',
                                child: Icon(
                                  Icons.shield_outlined,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat(
                              "EEEE, d 'de' MMMM",
                              'es_MX',
                            ).format(date),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (saved) ...[
                            SavedMoment(
                              record: original!,
                              health: store.healthAt(date),
                              onEdit: editMoment,
                              onCalendar: GoRouter.maybeOf(context) == null
                                  ? null
                                  : () => context.go('/calendar'),
                            ),
                            const SizedBox(height: 20),
                            WeekRibbon(records: store.records, date: date),
                          ] else ...[
                            JourneySteps(
                              current: step,
                              onSelected: busy ? (_) {} : goStep,
                            ),
                            const SizedBox(height: 24),
                            AnimatedSwitcher(
                              duration: Duration(
                                milliseconds:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? 0
                                    : 220,
                              ),
                              child: Column(
                                key: ValueKey(step),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (step == 0) ...[
                                    Center(
                                      child: MoodOrb(mood: mood, size: 84),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      mood == null
                                          ? '¿Qué onda con tu día?'
                                          : 'Hoy me siento ${mood!.name.toLowerCase()}',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -.5,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        moodMessage(mood),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    MoodSelector(
                                      value: mood,
                                      onChanged: (value) {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          mood = value;
                                          dirty = true;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    WeekRibbon(
                                      records: store.records,
                                      date: date,
                                    ),
                                  ] else if (step == 1) ...[
                                    const JourneyTitle(
                                      'Las pequeñas cosas cuentan',
                                      '¿Qué formó parte de tu día? Puedes elegir varias actividades o crear la tuya.',
                                    ),
                                    const SizedBox(height: 20),
                                    EnergyIsland(
                                      value: energy,
                                      onChanged: (value) {
                                        if (energy.round() != value.round()) {
                                          HapticFeedback.selectionClick();
                                        }
                                        setState(() {
                                          energy = value;
                                          dirty = true;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Mi mezcla de hoy',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      selected.isEmpty
                                          ? 'Toca lo que estuvo presente.'
                                          : '${selected.length} ${selected.length == 1 ? 'actividad elegida' : 'actividades elegidas'} · puedes cambiar tu selección',
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final a in {
                                          ...defaultActivities,
                                          ...store.custom,
                                          ...selected,
                                        })
                                          FilterChip(
                                            avatar: Icon(
                                              activityIcon(a),
                                              size: 19,
                                            ),
                                            label: Text(a),
                                            selected: selected.contains(a),
                                            showCheckmark: false,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize.padded,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 10,
                                            ),
                                            onSelected: (value) {
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                value
                                                    ? selected.add(a)
                                                    : selected.remove(a);
                                                dirty = true;
                                              });
                                            },
                                          ),
                                        ActionChip(
                                          avatar: const Icon(Icons.add_rounded),
                                          label: const Text(
                                            'Mi propia actividad',
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 10,
                                          ),
                                          onPressed: addActivity,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    HealthFields(
                                      hours: sleepHours,
                                      minutes: sleepMinutes,
                                      steps: steps,
                                      onChanged: () =>
                                          setState(() => dirty = true),
                                    ),
                                  ] else ...[
                                    const JourneyTitle(
                                      'Una nota para tu yo de después',
                                      'Una frase, una idea o nada por ahora. Escribir es opcional.',
                                    ),
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.format_quote_rounded,
                                            size: 32,
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            '¿Qué te gustaría recordar?',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ReflectionField(
                                            controller: reflection,
                                            onChanged: (_) {
                                              dirty = true;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Una idea para empezar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        for (final prompt in [
                                          'Hoy me sorprendió…',
                                          'Necesito darme…',
                                          'Quiero recordar…',
                                        ])
                                          ActionChip(
                                            label: Text(prompt),
                                            onPressed: () {
                                              if (reflection.text
                                                  .trim()
                                                  .isNotEmpty) {
                                                notice(
                                                  context,
                                                  'Tu texto está a salvo. Usa esta idea como inspiración.',
                                                );
                                                return;
                                              }
                                              reflection.text =
                                                  '${prompt.substring(0, prompt.length - 1)} ';
                                              reflection.selection =
                                                  TextSelection.collapsed(
                                                    offset:
                                                        reflection.text.length,
                                                  );
                                              setState(() => dirty = true);
                                            },
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    if (mood != null)
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: mood!.background(
                                            theme.brightness == Brightness.dark,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              mood!.emoji,
                                              style: const TextStyle(
                                                fontSize: 30,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                '${mood!.name} · Energía ${energy.round()}/10\n${selected.isEmpty ? 'Sin actividades seleccionadas' : selected.join(' · ')}',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class JourneyTitle extends StatelessWidget {
  const JourneyTitle(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

class ReflectionField extends StatelessWidget {
  const ReflectionField({super.key, required this.controller, this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLength: 300,
    maxLines: 4,
    onChanged: onChanged,
    textCapitalization: TextCapitalization.sentences,
    decoration: const InputDecoration(
      labelText: 'Tu reflexión',
      hintText: 'Hoy, en mis propias palabras…',
      alignLabelWithHint: true,
    ),
  );
}
