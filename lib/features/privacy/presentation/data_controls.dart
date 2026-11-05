import '../../../core/refugio_art.dart';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/state.dart';
import '../../../core/refugio.dart';
import '../../../core/widgets.dart';
import '../../records/domain/record.dart';
import '../../health/presentation/health_connection_card.dart';
import '../domain/data_export.dart';

class DataControls extends StatelessWidget {
  const DataControls({super.key, required this.store});
  final AppStore store;
  Future<void> export(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Exportar JSON'),
        content: const Text(
          'Incluye reflexiones y salud en un archivo externo sin cifrar. Nunca incluye PIN, hash, salt, biometría ni modelo. Tú eliges la ubicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Elegir ubicación'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final json = DataExportService().build(
        records: store.records,
        health: store.healthData,
        activities: [...defaultActivities, ...store.custom],
        theme: store.theme.name,
        now: DateTime.now(),
      );
      final path = await const MethodChannel('com.example.moodwave/documents')
          .invokeMethod<String>('saveJson', {
            'bytes': Uint8List.fromList(
              utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
            ),
            'name': 'moodwave-${dateKey(DateTime.now())}.json',
          });
      if (context.mounted) {
        notice(
          context,
          path == null ? 'Exportación cancelada' : 'JSON guardado',
        );
      }
    } catch (_) {
      if (context.mounted) {
        notice(context, 'No se pudo guardar. Tus datos se conservan.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        leading: const RefugioIcon(Icons.storage_outlined),
        title: const Text('Ver datos'),
        subtitle: Text(
          '${store.records.length} emociones · ${store.healthData.length} datos físicos',
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Tus datos locales')),
              body: ListView.builder(
                itemCount: store.records.length + store.healthData.length,
                itemBuilder: (c, i) {
                  if (i < store.records.length) {
                    final r = store.records[i];
                    return ExpansionTile(
                      leading: RefugioFace(mood: r.mood, size: 32),
                      title: Text('${dateKey(r.date)} · ${r.mood.value}/8'),
                      subtitle: Text(
                        'Energía ${r.energy}/10${r.test ? ' · SINTÉTICO' : ''}',
                      ),
                      children: [
                        ListTile(
                          title: Text(r.activities.join(' · ')),
                          subtitle: Text(
                            r.reflection.isEmpty
                                ? 'Sin reflexión'
                                : r.reflection,
                          ),
                        ),
                      ],
                    );
                  }
                  final h = store.healthData[i - store.records.length];
                  return ListTile(
                    title: Text(h.dateKeyValue),
                    subtitle: Text(
                      '${h.sleepMinutes ?? '—'} min · ${h.steps ?? '—'} pasos · ${h.source.name}${h.isSynthetic ? ' · SINTÉTICO' : ''}',
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      ListTile(
        leading: const RefugioIcon(Icons.data_object),
        title: const Text('Exportar JSON'),
        onTap: () => export(context),
      ),
      ListTile(
        leading: const RefugioIcon(Icons.model_training),
        title: const Text('Eliminar modelo local'),
        onTap: () async {
          if (await confirmDelete(
            context,
            title: '¿Eliminar el modelo?',
            body: 'Tus emociones, sueño y pasos se conservan.',
          )) {
            await store.deleteModel();
            if (context.mounted) notice(context, 'Modelo eliminado');
          }
        },
      ),
      if (kDebugMode)
        ListTile(
          leading: const RefugioIcon(Icons.refresh),
          title: const Text('Regenerar demostración'),
          subtitle: const Text(
            'Semilla reproducible · conserva datos personales',
          ),
          onTap: () async {
            final controller = TextEditingController(text: '42');
            final seed = await showDialog<int>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Regenerar datos sintéticos'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Se reemplazan únicamente datos marcados de prueba. Se invalida el modelo.',
                    ),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Semilla entera',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final n = int.tryParse(controller.text);
                      if (n != null) Navigator.pop(c, n);
                    },
                    child: const Text('Regenerar'),
                  ),
                ],
              ),
            );
            if (seed != null) {
              try {
                await store.generate(seed: seed, replaceSynthetic: true);
                if (context.mounted) notice(context, 'Demostración regenerada');
              } catch (_) {
                if (context.mounted) {
                  notice(context, 'No se pudo regenerar. Intenta nuevamente.');
                }
              }
            }
          },
        ),
      HealthConnectionCard(store: store),
    ],
  );
}
