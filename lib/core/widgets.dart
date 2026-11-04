import 'package:flutter/material.dart';

import 'mood_style.dart';

import '../features/records/domain/record.dart';
import 'wave_art.dart';

class WaveHeader extends StatelessWidget {
  const WaveHeader(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        colors: [const Color(0xff075e62), const Color(0xff0b716b)],
      ),
    ),
    child: CustomPaint(
      painter: const WaveArt(color: Colors.white),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.waves_rounded, size: 24, color: Color(0xffbcf6e7)),
                SizedBox(width: 8),
                Text(
                  'MOODWAVE',
                  style: TextStyle(
                    color: Color(0xffd2f5ec),
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}

class MoodSelector extends StatelessWidget {
  const MoodSelector({super.key, required this.value, required this.onChanged});
  final Mood? value;
  final ValueChanged<Mood> onChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth >= 300 &&
          MediaQuery.textScalerOf(context).scale(14) <= 16;
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final mood in Mood.values)
            SizedBox(
              width: compact
                  ? (constraints.maxWidth - 16) / 3
                  : (constraints.maxWidth - 8) / 2,
              child: Semantics(
                label: mood.accessible,
                selected: value == mood,
                button: true,
                child: AnimatedScale(
                  scale: value == mood ? 1 : .97,
                  duration: Duration(
                    milliseconds: MediaQuery.disableAnimationsOf(context)
                        ? 0
                        : 180,
                  ),
                  child: AnimatedContainer(
                    duration: Duration(
                      milliseconds: MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : 180,
                    ),
                    decoration: BoxDecoration(
                      color: mood.background(
                        Theme.of(context).brightness == Brightness.dark,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: value == mood ? mood.color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => onChanged(mood),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 6 : 12,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  mood.emoji,
                                  style: TextStyle(fontSize: compact ? 28 : 32),
                                ),
                                const Spacer(),
                                Icon(
                                  value == mood
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  size: compact ? 14 : 20,
                                  color: value == mood
                                      ? mood.color
                                      : Theme.of(context).colorScheme.outline
                                            .withValues(alpha: .4),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: BoxConstraints(minHeight: 20),
                              child: Text(
                                mood.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
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
      );
    },
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.onCreate});
  final VoidCallback? onCreate;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.water_drop_outlined, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Cada día cuenta',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Todavía no hay registros en este periodo. Dedica un momento a escuchar cómo te sientes.',
            textAlign: TextAlign.center,
          ),
          if (onCreate != null)
            TextButton(
              onPressed: onCreate,
              child: const Text('Crear mi primer registro'),
            ),
        ],
      ),
    ),
  );
}

Future<bool> confirmDelete(
  BuildContext context, {
  String title = '¿Eliminar este registro?',
  String body = 'Esta acción no se puede deshacer.',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ) ??
    false;
void notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
