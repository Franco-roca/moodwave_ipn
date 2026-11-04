import 'package:flutter/material.dart';

import '../../../app/state.dart';
import '../../../core/widgets.dart';
import '../../records/domain/record.dart';
import '../data/health_connect.dart';

class HealthConnectionCard extends StatefulWidget {
  const HealthConnectionCard({super.key, required this.store});
  final AppStore store;
  @override
  State<HealthConnectionCard> createState() => _HealthConnectionCardState();
}

class _HealthConnectionCardState extends State<HealthConnectionCard> {
  final source = HealthConnectDataSource();
  bool busy = false;
  @override
  void initState() {
    super.initState();
    source.status().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> run(Future<void> Function() task) async {
    setState(() => busy = true);
    try {
      await task();
    } catch (_) {
      if (mounted) {
        notice(
          context,
          'No se pudo completar. La captura manual sigue disponible.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> import() async {
    final now = day(DateTime.now());
    final range = await showDateRangePicker(
      context: context,
      firstDate: shiftDay(now, -29),
      lastDate: now,
      initialDateRange: DateTimeRange(start: shiftDay(now, -6), end: now),
      helpText: 'Importar hasta 30 días',
    );
    if (range == null || !mounted) return;
    await run(() async {
      final rows = await source.read(range.start, shiftDay(range.end, 1));
      final conflicts = rows.where((h) {
        final old = widget.store.healthAt(h.date);
        return old != null && old.source.name != 'healthConnect';
      }).length;
      var replace = false;
      if (conflicts > 0 && mounted) {
        replace =
            await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Conservar tus datos'),
                content: Text(
                  '$conflicts fechas ya tienen datos manuales, importados o de prueba. ¿Quieres reemplazarlos?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Conservar existentes'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Reemplazar'),
                  ),
                ],
              ),
            ) ??
            false;
      }
      final count =
          await widget.store.healthRepository?.importRange(
            rows,
            replaceManual: replace,
          ) ??
          0;
      if (count > 0) await widget.store.refresh();
      if (mounted) notice(context, '$count días importados · sin duplicados');
    });
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: const PageStorageKey('health-connection'),
      leading: const Icon(Icons.health_and_safety_outlined),
      title: const Text('Health Connect'),
      subtitle: Text(
        source.available
            ? 'Conectado · importación a petición'
            : source.state == 'available'
            ? 'Disponible para conectar'
            : 'Captura manual disponible',
      ),
      childrenPadding: const EdgeInsets.all(16),
      children: [
        Text(source.description),
        const Text(
          'Solo sueño y pasos, al importar el rango elegido. Permisos revocables. Tus datos se guardan localmente. La captura manual siempre está disponible.',
        ),
        const SizedBox(height: 8),
        if (source.state == 'available' || source.state == 'denied')
          FilledButton(
            onPressed: busy ? null : () => run(source.connect),
            child: const Text('Conectar'),
          ),
        if (source.available) ...[
          FilledButton(
            onPressed: busy ? null : import,
            child: const Text('Importar por rango'),
          ),
          TextButton(
            onPressed: busy ? null : () => run(source.disconnect),
            child: const Text('Desconectar y revocar permisos'),
          ),
        ],
        TextButton(
          onPressed: busy ? null : () => run(source.status),
          child: const Text('Comprobar disponibilidad'),
        ),
        if (busy) const LinearProgressIndicator(),
      ],
    ),
  );
}
