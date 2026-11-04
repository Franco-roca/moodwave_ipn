import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/report_data.dart';
import '../domain/pdf_report_service.dart';

final reportPlatformProvider = Provider<ReportPlatform>(
  (ref) => ReportPlatform(),
);

class ReportPlatform {
  Future<String> version() async => (await PackageInfo.fromPlatform()).version;
  Future<ReportPdf> generate(MoodWaveReportData data) async {
    final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
        bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return compute(renderReport, (
      data: data,
      regular: regular.buffer.asUint8List(),
      bold: bold.buffer.asUint8List(),
    ));
  }

  Future<ui.Image> preview(ReportPdf pdf, int page) async {
    final raster = await Printing.raster(
      pdf.bytes,
      pages: [page],
      dpi: 72,
    ).first;
    return raster.toImage();
  }

  Future<String?> save(ReportPdf pdf, String name) async {
    if (Platform.isAndroid) {
      return const MethodChannel('com.example.moodwave/documents')
          .invokeMethod<String>('savePdf', {'bytes': pdf.bytes, 'name': name});
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(pdf.bytes, flush: true);
    return '${dir.path}/$name';
  }

  Future<bool> share(ReportPdf pdf, String name) => Printing.sharePdf(
    bytes: pdf.bytes,
    filename: name,
    subject: 'Mi reporte MoodWave',
  );
}
