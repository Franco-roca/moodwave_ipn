import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/records/domain/record.dart';
import 'draft.dart';
import 'tokens.dart';

void main() => runApp(const DesignLabApp());

class DesignLabApp extends StatefulWidget {
  const DesignLabApp({super.key});
  @override
  State<DesignLabApp> createState() => _DesignLabAppState();
}

class _DesignLabAppState extends State<DesignLabApp> {
  final draft = LabDraft();
  int variant = 0;
  bool dark = false;
  double scale = 1;
  int? palette;

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LabTokens.variants[palette ?? variant];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: tokens.theme(dark),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            MediaQuery.textScalerOf(context).scale(1) * scale,
          ),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text(
              'MoodWave · Laboratorio',
              style: TextStyle(fontSize: 18),
            ),
            actions: [
              IconButton(
                tooltip: 'Opciones de comparación',
                icon: const Icon(Icons.tune),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => StatefulBuilder(
                    builder: (context, refresh) => SafeArea(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Comparar con el mismo borrador'),
                              SwitchListTile(
                                title: const Text('Tema oscuro'),
                                value: dark,
                                onChanged: (v) {
                                  setState(() => dark = v);
                                  refresh(() {});
                                },
                              ),
                              DropdownButtonFormField<double>(
                                initialValue: scale,
                                decoration: const InputDecoration(
                                  labelText: 'Escala adicional de texto',
                                ),
                                items: [1.0, 1.4, 2.0]
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text('${v}x'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  setState(() => scale = v!);
                                  refresh(() {});
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                initialValue: palette ?? -1,
                                decoration: const InputDecoration(
                                  labelText: 'Combinar paleta con composición',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: -1,
                                    child: Text('Propia de la variante'),
                                  ),
                                  for (var i = 0; i < 3; i++)
                                    DropdownMenuItem(
                                      value: i,
                                      child: Text(LabTokens.variants[i].name),
                                    ),
                                ],
                                onChanged: (v) {
                                  setState(() => palette = v == -1 ? null : v);
                                  refresh(() {});
                                },
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final entry in const {
                                    LabScenario.empty: 'Vacío',
                                    LabScenario.editing: 'Editando',
                                    LabScenario.saving: 'Guardando',
                                    LabScenario.error: 'Error',
                                    LabScenario.saved: 'Guardado',
                                  }.entries)
                                    ActionChip(
                                      label: Text(entry.value),
                                      onPressed: () {
                                        draft.selectScenario(entry.key);
                                        Navigator.pop(context);
                                      },
                                    ),
                                ],
                              ),
                              const Text(
                                'Vacío borra solo el borrador ficticio. Los demás estados lo conservan.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (var i = 0; i < 3; i++)
                        ChoiceChip(
                          key: ValueKey('variant-$i'),
                          label: Text(
                            '${String.fromCharCode(65 + i)} · ${LabTokens.variants[i].name}',
                          ),
                          selected: variant == i,
                          onSelected: (_) => setState(() => variant = i),
                        ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Vista experimental · datos ficticios · guardado en memoria',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: LabToday(
                    draft: draft,
                    variant: variant,
                    tokens: tokens,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LabToday extends StatefulWidget {
  const LabToday({
    super.key,
    required this.draft,
    required this.variant,
    required this.tokens,
  });
  final LabDraft draft;
  final int variant;
  final LabTokens tokens;
  @override
  State<LabToday> createState() => _LabTodayState();
}

class _LabTodayState extends State<LabToday> {
  LabDraft get d => widget.draft;
  bool details = false;
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  TextStyle title(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall!.copyWith(
        fontFamily: widget.variant == 1 ? 'serif' : null,
        fontWeight: widget.variant == 1 ? FontWeight.w400 : FontWeight.w700,
      );

  Widget section(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: title(context)),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget emotions() => LayoutBuilder(
    builder: (context, constraints) {
      final large = MediaQuery.textScalerOf(context).scale(16) > 22;
      final columns = large || constraints.maxWidth < 340 ? 2 : 3;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final mood in Mood.values)
            SizedBox(
              width: width,
              child: Semantics(
                selected: d.mood == mood,
                child: OutlinedButton(
                  key: ValueKey('mood-${mood.name}'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    backgroundColor: d.mood == mood
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    side: BorderSide(
                      color: d.mood == mood
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: d.mood == mood ? 2 : 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(widget.tokens.radius),
                    ),
                  ),
                  onPressed: () => d.update(() => d.mood = mood),
                  child: Column(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          const [
                            Icons.sentiment_very_dissatisfied,
                            Icons.sentiment_dissatisfied,
                            Icons.sentiment_neutral,
                            Icons.psychology_outlined,
                            Icons.horizontal_rule,
                            Icons.sentiment_satisfied,
                            Icons.sentiment_very_satisfied,
                            Icons.auto_awesome,
                          ][mood.index],
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(mood.name, textAlign: TextAlign.center),
                      if (d.mood == mood) const Icon(Icons.check, size: 16),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget feeling() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      section('¿Cómo te sientes hoy?', emotions()),
      section(
        'Tu energía · ${d.energy.round()} de 10',
        Column(
          children: [
            Slider(
              value: d.energy,
              min: 1,
              max: 10,
              divisions: 9,
              label: '${d.energy.round()} de 10',
              semanticFormatterCallback: (v) => '${v.round()} de 10',
              onChanged: (v) => d.update(() => d.energy = v),
            ),
            const Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [Text('Sin energía'), Text('Con energía')],
            ),
          ],
        ),
      ),
    ],
  );

  Widget field(
    String label,
    String value,
    ValueChanged<String> change, {
    bool numeric = false,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: value,
      keyboardType: numeric ? TextInputType.number : TextInputType.multiline,
      maxLines: numeric ? 1 : 3,
      maxLength: maxLength,
      decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
      onChanged: change,
    ),
  );

  Widget living() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      section(
        'Lo que formó parte de tu día',
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final activity in defaultActivities)
              FilterChip(
                label: Text(activity),
                selected: d.activities.contains(activity),
                onSelected: (selected) => d.update(() {
                  selected
                      ? d.activities.add(activity)
                      : d.activities.remove(activity);
                }),
              ),
          ],
        ),
      ),
      section(
        'Sueño y pasos · opcional',
        Column(
          children: [
            field('Horas de sueño', d.hours, (v) => d.hours = v, numeric: true),
            field(
              'Minutos adicionales',
              d.minutes,
              (v) => d.minutes = v,
              numeric: true,
            ),
            field('Pasos', d.steps, (v) => d.steps = v, numeric: true),
          ],
        ),
      ),
    ],
  );

  Widget remembering() => section(
    'Algo que quieras recordar',
    field(
      'Tu reflexión · opcional',
      d.reflection,
      (v) => d.reflection = v,
      maxLength: 300,
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: d,
    builder: (context, _) {
      final busy = d.scenario == LabScenario.saving;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LabTokens.maxWidth),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: scroll,
                  padding: const EdgeInsets.all(LabTokens.page),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MIÉRCOLES, 4 DE NOVIEMBRE · DEMOSTRACIÓN',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        [
                          'Un momento para ti.',
                          'Las páginas de tu día.',
                          'Haz una pausa. Registra tu día.',
                        ][widget.variant],
                        style: title(context),
                      ),
                      const SizedBox(height: 20),
                      if (d.scenario == LabScenario.saved) ...[
                        const Icon(Icons.check_circle_outline, size: 48),
                        section(
                          'Tu día está registrado',
                          Text(
                            '${d.mood?.name ?? 'Sin emoción'} · Energía ${d.energy.round()}/10\n${d.activities.join(' · ')}\n${d.reflection}',
                          ),
                        ),
                        const Text(
                          'Confirmación de ejemplo. No se escribió en la base de datos.',
                        ),
                        TextButton(
                          onPressed: () =>
                              d.selectScenario(LabScenario.editing),
                          child: const Text('Volver a editar'),
                        ),
                      ] else ...[
                        if (widget.variant == 0) ...[
                          Wrap(
                            spacing: 8,
                            children: [
                              for (var i = 0; i < 3; i++)
                                ChoiceChip(
                                  label: Text(
                                    '${i + 1}. ${['Sentir', 'Vivir', 'Recordar'][i]}',
                                  ),
                                  selected: d.stage == i,
                                  onSelected: (_) =>
                                      d.update(() => d.stage = i),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (d.stage == 0) feeling(),
                          if (d.stage == 1) living(),
                          if (d.stage == 2) remembering(),
                        ] else if (widget.variant == 1) ...[
                          const Divider(),
                          feeling(),
                          const Divider(),
                          living(),
                          const Divider(),
                          remembering(),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius: BorderRadius.circular(
                                widget.tokens.radius,
                              ),
                            ),
                            child: Text(
                              'TU REGISTRO\n${d.mood?.name ?? 'Elige una emoción'} · Energía ${d.energy.round()}/10',
                            ),
                          ),
                          feeling(),
                          OutlinedButton.icon(
                            onPressed: () => setState(() => details = !details),
                            icon: Icon(
                              details ? Icons.expand_less : Icons.expand_more,
                            ),
                            label: Text(
                              details
                                  ? 'Ocultar detalles opcionales'
                                  : 'Añadir actividades, salud y reflexión',
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (details) ...[living(), remembering()],
                        ],
                        if (d.scenario == LabScenario.error)
                          Semantics(
                            liveRegion: true,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer,
                              child: Text(
                                d.message ?? 'No se pudo guardar el ejemplo. Tu borrador se conserva; vuelve a intentarlo.',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              if (d.scenario != LabScenario.saved)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('primary-action'),
                      onPressed: busy
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              if (widget.variant == 0 && d.stage < 2) {
                                d.update(() => d.stage++);
                                scroll.jumpTo(0);
                              } else {
                                d.save();
                              }
                            },
                      icon: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              widget.variant == 0 && d.stage < 2
                                  ? Icons.arrow_forward
                                  : Icons.check,
                            ),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          busy
                              ? 'Guardando ejemplo…'
                              : widget.variant == 0 && d.stage < 2
                              ? 'Continuar'
                              : 'Guardar mi día',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
