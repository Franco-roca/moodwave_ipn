import 'refugio_art.dart';

import 'package:flutter/material.dart';

import 'mood_style.dart';

import '../features/records/domain/record.dart';
import 'refugio.dart';

class WaveHeader extends StatelessWidget {
  const WaveHeader(this.title, this.subtitle, {super.key, this.scene});
  final RefugioScene? scene;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 168),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(Refugio.radius),
      gradient: const LinearGradient(
        colors: [Color(0xff204c3c), Color(0xff3b6247)],
      ),
      boxShadow: [
        BoxShadow(
          color: Refugio.forest.withValues(alpha: .12),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: RefugioBanner(scene: scene ?? sceneForTitle(title)),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xff183d2d).withValues(alpha: .96),
                  const Color(0xff183d2d).withValues(alpha: .82),
                  const Color(0xff183d2d).withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? .68
                        : .32,
                  ),
                ],
                stops: const [0, .52, 1],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xfffff8e9),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: const Color(0xfffff8e9)),
              ),
            ],
          ),
        ),
      ],
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
                      borderRadius: BorderRadius.circular(Refugio.radius),
                      border: Border.all(
                        color: value == mood ? mood.color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Refugio.radius),
                      onTap: () => onChanged(mood),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 6 : 12,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Center(
                                  child: RefugioFace(
                                    mood: mood,
                                    size: compact ? 54 : 62,
                                  ),
                                ),
                                if (value == mood)
                                  RefugioIcon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: BoxConstraints(minHeight: 20),
                              child: Text(
                                mood.name,
                                textAlign: TextAlign.center,
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
          const RefugioIcon(Icons.water_drop_outlined, size: 48),
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
