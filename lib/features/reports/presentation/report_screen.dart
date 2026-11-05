import '../../../core/refugio_art.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/report_platform.dart';

import '../../../app/state.dart';
import '../../../core/widgets.dart';
import '../../analytics/domain/analytics.dart';
import '../../records/domain/record.dart';
import '../domain/report_data.dart';
import '../domain/pdf_report_service.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});
  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  bool monthly = false,
      includeReflections = false,
      includeHealth = true,
      includePrediction = false,
      busy = false;
  DateTime anchor = day(DateTime.now());
  ReportPdf? pdf;
  ui.Image? image;
  int page = 0, request = 0;
  DateSpan get span => DateSpan.forPeriod(
    monthly ? AnalyticsPeriod.month : AnalyticsPeriod.week,
    anchor,
  );
  String get filename =>
      'moodwave-${monthly ? 'mes' : 'semana'}-${dateKey(span.start)}.pdf';
  void clear() {
    request++;
    final old = image;
    image = null;
    pdf = null;
    page = 0;
    old?.dispose();
  }

  @override
  void dispose() {
    request++;
    image?.dispose();
    super.dispose();
  }

  Future<void> reflections(bool value) async {
    if (value) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text(
            'Las reflexiones pueden contener información personal',
          ),
          content: const Text(
            'Se incluirán en el PDF y serán visibles para quien reciba el archivo. ¿Quieres incluirlas?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('No incluir'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Incluir reflexiones'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    setState(() {
      includeReflections = value;
      clear();
    });
  }

  Future<void> chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: anchor,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 5),
      helpText: monthly ? 'Elige un día del mes' : 'Elige un día de la semana',
    );
    if (picked != null && mounted) {
      setState(() {
        anchor = picked;
        clear();
      });
    }
  }

  Future<ReportPdf?> generate() async {
    if (pdf != null) return pdf;
    final store = ref.read(storeProvider);
    final data = ReportDataService().build(
      records: store.records,
      health: store.healthData,
      span: span,
      now: DateTime.now(),
      monthly: monthly,
      includeReflections: includeReflections,
      includePrediction: includePrediction,
      model: store.predictionModel,
      includeHealth:
          includeHealth && store.healthData.any((h) => span.contains(h.date)),
      version: await ref.read(reportPlatformProvider).version(),
    );
    final result = await ref.read(reportPlatformProvider).generate(data);
    if (!mounted) return null;
    pdf = result;
    return result;
  }

  Future<void> run(Future<void> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        notice(
          context,
          'No se pudo completar la acción del PDF. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> preview([int? index]) async {
    await run(() async {
      final output = await generate();
      if (output == null) return;
      final target = index ?? 0, id = ++request;
      final next = await ref
          .read(reportPlatformProvider)
          .preview(output, target);
      if (!mounted || request != id) {
        next.dispose();
        return;
      }
      final old = image;
      setState(() {
        image = next;
        page = target;
      });
      old?.dispose();
    });
  }

  Future<void> save() async => run(() async {
    final output = await generate();
    if (output == null) return;
    final destination = await ref
        .read(reportPlatformProvider)
        .save(output, filename);
    if (!mounted) return;
    notice(
      context,
      destination == null
          ? 'Guardado cancelado'
          : 'PDF guardado en la ubicación elegida',
    );
  });
  Future<void> share() async => run(() async {
    final output = await generate();
    if (output == null) return;
    final ok = await ref.read(reportPlatformProvider).share(output, filename);
    if (!ok && mounted) {
      notice(context, 'No se compartió el PDF. Puedes intentarlo de nuevo.');
    }
  });
  @override
  Widget build(BuildContext context) {
    final store = ref.read(storeProvider),
        format = DateFormat('d MMM yyyy', 'es_MX');
    final hasHealth = store.healthData.any(
      (h) => span.contains(h.date) && !h.isEmpty,
    );
    final hasRecords = span.select(store.records).isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Generar reporte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const WaveHeader(
            'Tu historia, para llevar',
            'Un reporte local que tú decides si compartir.',
          ),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Semanal')),
              ButtonSegment(value: true, label: Text('Mensual')),
            ],
            selected: {monthly},
            onSelectionChanged: busy
                ? null
                : (v) => setState(() {
                    monthly = v.first;
                    clear();
                  }),
          ),
          ListTile(
            title: const Text('Periodo del reporte'),
            subtitle: Text(
              '${format.format(span.start)} - ${format.format(shiftDay(span.end, -1))}',
            ),
            trailing: const RefugioIcon(Icons.calendar_month),
            onTap: busy ? null : chooseDate,
          ),
          SwitchListTile(
            title: const Text('Incluir reflexiones'),
            subtitle: const Text('Desactivado por privacidad'),
            value: includeReflections,
            onChanged: busy ? null : reflections,
          ),
          SwitchListTile(
            title: const Text('Incluir sueño y pasos'),
            subtitle: Text(
              hasHealth
                  ? 'Hay datos en este periodo'
                  : 'Sin datos físicos en este periodo',
            ),
            value: hasHealth && includeHealth,
            onChanged: busy || !hasHealth
                ? null
                : (v) => setState(() {
                    includeHealth = v;
                    clear();
                  }),
          ),
          SwitchListTile(
            title: const Text('Incluir predicción experimental'),
            subtitle: Text(
              store.predictionModel == null
                  ? 'Entrena primero el modelo en Patrones'
                  : 'Estimación del próximo registro · desactivada por defecto',
            ),
            value: includePrediction && store.predictionModel != null,
            onChanged: busy || store.predictionModel == null
                ? null
                : (v) => setState(() {
                    includePrediction = v;
                    clear();
                  }),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'El PDF contiene información personal y crea un archivo fuera de la base privada. Compartir abre el menú del sistema: tú eliges el destino. No hay envío automático ni sincronización.',
              ),
            ),
          ),
          if (!hasRecords)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No hay registros emocionales en este periodo. Puedes generar un reporte vacío identificado como tal.',
              ),
            ),
          const SizedBox(height: 12),
          if (busy) const LinearProgressIndicator(),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : () => preview(),
                icon: const RefugioIcon(Icons.picture_as_pdf_outlined),
                label: const Text('Vista previa'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : save,
                icon: const RefugioIcon(Icons.save_alt),
                label: const Text('Guardar'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : share,
                icon: const RefugioIcon(Icons.share_outlined),
                label: const Text('Compartir'),
              ),
            ],
          ),
          if (image != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  tooltip: 'Página anterior',
                  onPressed: busy || page == 0 ? null : () => preview(page - 1),
                  icon: const RefugioIcon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    'Página ${page + 1} de ${pdf!.pageCount}',
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'Página siguiente',
                  onPressed: busy || page + 1 >= pdf!.pageCount
                      ? null
                      : () => preview(page + 1),
                  icon: const RefugioIcon(Icons.chevron_right),
                ),
              ],
            ),
            const Text(
              'Vista previa ligera: una página a la vez. El archivo guardado conserva calidad vectorial.',
            ),
            const SizedBox(height: 8),
            Container(
              color: Colors.white,
              child: AspectRatio(
                aspectRatio: image!.width / image!.height,
                child: RawImage(image: image, fit: BoxFit.contain),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
