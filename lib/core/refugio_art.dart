import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/records/domain/record.dart';
import 'refugio.dart';

enum RefugioScene {
  calendar,
  summary,
  activities,
  trends,
  sleep,
  prediction,
  reports,
  profile,
  settings,
}

enum RefugioSymbol {
  home,
  calendar,
  summary,
  activities,
  trends,
  sleep,
  prediction,
  reports,
  profile,
  settings,
  privacy,
  export,
  fingerprint,
  delete,
  energy,
  support,
}

/// Decoded once per asset. No platform calls or network requests.
abstract final class RefugioAtlas {
  static final Map<String, Future<ui.Image>> _images = {};
  static final Map<String, ui.Image> _decoded = {};
  static ui.Image? decoded(String path) => _decoded[path];
  static Future<ui.Image> image(String path) =>
      _images.putIfAbsent(path, () async {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          targetWidth: path.contains('banners') ? 2304 : 1536,
          allowUpscaling: false,
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        _decoded[path] = frame.image;
        return frame.image;
      });
}

class RefugioTile extends StatelessWidget {
  const RefugioTile({
    super.key,
    required this.asset,
    required this.index,
    required this.columns,
    required this.rows,
    this.fit = BoxFit.contain,
  });
  final String asset;
  final int index, columns, rows;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final cached = RefugioAtlas.decoded(asset);
    if (cached != null) {
      return ExcludeSemantics(
        child: CustomPaint(
          painter: _AtlasPainter(cached, index, columns, rows, fit),
        ),
      );
    }
    return ExcludeSemantics(
      child: FutureBuilder<ui.Image>(
        future: RefugioAtlas.image(asset),
        builder: (context, snapshot) => snapshot.hasData
            ? CustomPaint(
                painter: _AtlasPainter(
                  snapshot.data!,
                  index,
                  columns,
                  rows,
                  fit,
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

class _AtlasPainter extends CustomPainter {
  const _AtlasPainter(
    this.image,
    this.index,
    this.columns,
    this.rows,
    this.fit,
  );
  final ui.Image image;
  final int index, columns, rows;
  final BoxFit fit;
  @override
  void paint(Canvas canvas, Size size) {
    final cell = Size(image.width / columns, image.height / rows);
    final fitted = applyBoxFit(fit, cell, size);
    final source = Alignment.center
        .inscribe(fitted.source, Offset.zero & cell)
        .shift(
          Offset(
            (index % columns) * cell.width,
            (index ~/ columns) * cell.height,
          ),
        );
    final destination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_AtlasPainter old) =>
      old.image != image ||
      old.index != index ||
      old.columns != columns ||
      old.rows != rows ||
      old.fit != fit;
}

class RefugioIllustration extends StatelessWidget {
  const RefugioIllustration(this.symbol, {super.key, this.size = 32});
  final RefugioSymbol symbol;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: RefugioTile(
      asset: 'assets/refugio/symbols.png',
      index: symbol.index,
      columns: 4,
      rows: 4,
    ),
  );
}

RefugioScene? sceneForTitle(String title) {
  final text = title.toLowerCase();
  if (text.contains('calendario')) return RefugioScene.calendar;
  if (text.contains('resumen') || text.contains('estad')) {
    return RefugioScene.summary;
  }
  if (text.contains('actividades')) return RefugioScene.activities;
  if (text.contains('tendencias')) return RefugioScene.trends;
  if (text.contains('sueño')) return RefugioScene.sleep;
  if (text.contains('predic')) return RefugioScene.prediction;
  if (text.contains('reporte') || text.contains('llevar')) {
    return RefugioScene.reports;
  }
  if (text.contains('espacio') || text.contains('perfil')) {
    return RefugioScene.profile;
  }
  if (text.contains('configura')) return RefugioScene.settings;
  return null;
}

class RefugioBanner extends StatelessWidget {
  const RefugioBanner({super.key, this.scene});
  final RefugioScene? scene;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: scene == null
          ? Image.asset(
              dark ? Refugio.nightHero : Refugio.hero,
              fit: BoxFit.contain,
              alignment: Alignment.centerRight,
              excludeFromSemantics: true,
            )
          : RefugioTile(
              asset: dark
                  ? 'assets/refugio/banners-night.png'
                  : 'assets/refugio/banners.png',
              index: scene!.index,
              columns: 3,
              rows: 3,
              fit: BoxFit.cover,
            ),
    );
  }
}

class RefugioMoodText extends StatelessWidget {
  const RefugioMoodText(
    this.mood, {
    super.key,
    this.text,
    this.style,
    this.size = 26,
  });
  final Mood mood;
  final String? text;
  final TextStyle? style;
  final double size;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: RefugioFace(mood: mood, size: size),
          ),
        ),
        TextSpan(text: text ?? mood.name),
      ],
    ),
    style: style,
  );
}

class RefugioIcon extends StatelessWidget {
  const RefugioIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });
  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  static final Map<IconData, RefugioSymbol> symbols = {
    Icons.auto_awesome: RefugioSymbol.reports,
    Icons.auto_awesome_outlined: RefugioSymbol.reports,
    Icons.auto_graph: RefugioSymbol.trends,
    Icons.auto_graph_rounded: RefugioSymbol.trends,
    Icons.bedtime_outlined: RefugioSymbol.sleep,
    Icons.bolt: RefugioSymbol.energy,
    Icons.bolt_rounded: RefugioSymbol.energy,
    Icons.book_outlined: RefugioSymbol.reports,
    Icons.calendar_month: RefugioSymbol.calendar,
    Icons.calendar_month_outlined: RefugioSymbol.calendar,
    Icons.calendar_today: RefugioSymbol.calendar,
    Icons.calendar_today_outlined: RefugioSymbol.calendar,
    Icons.cleaning_services_outlined: RefugioSymbol.delete,
    Icons.data_object: RefugioSymbol.export,
    Icons.delete_forever_outlined: RefugioSymbol.delete,
    Icons.delete_outline: RefugioSymbol.delete,
    Icons.delete_sweep_outlined: RefugioSymbol.delete,
    Icons.directions_run: RefugioSymbol.activities,
    Icons.directions_walk: RefugioSymbol.activities,
    Icons.emoji_events_outlined: RefugioSymbol.energy,
    Icons.explore_outlined: RefugioSymbol.activities,
    Icons.favorite_border: RefugioSymbol.support,
    Icons.file_download_outlined: RefugioSymbol.export,
    Icons.fingerprint: RefugioSymbol.fingerprint,
    Icons.headphones: RefugioSymbol.activities,
    Icons.health_and_safety_outlined: RefugioSymbol.support,
    Icons.home_outlined: RefugioSymbol.home,
    Icons.insights: RefugioSymbol.summary,
    Icons.insights_rounded: RefugioSymbol.prediction,
    Icons.interests_outlined: RefugioSymbol.activities,
    Icons.local_fire_department_outlined: RefugioSymbol.energy,
    Icons.lock_outline: RefugioSymbol.privacy,
    Icons.menu_book_rounded: RefugioSymbol.reports,
    Icons.model_training: RefugioSymbol.prediction,
    Icons.mood: RefugioSymbol.home,
    Icons.nightlight_outlined: RefugioSymbol.sleep,
    Icons.people_outline: RefugioSymbol.activities,
    Icons.person_outline: RefugioSymbol.profile,
    Icons.picture_as_pdf_outlined: RefugioSymbol.reports,
    Icons.pin_outlined: RefugioSymbol.privacy,
    Icons.save_alt: RefugioSymbol.export,
    Icons.science_outlined: RefugioSymbol.prediction,
    Icons.settings_outlined: RefugioSymbol.settings,
    Icons.share_outlined: RefugioSymbol.export,
    Icons.shield_outlined: RefugioSymbol.privacy,
    Icons.shopping_bag_outlined: RefugioSymbol.activities,
    Icons.storage_outlined: RefugioSymbol.privacy,
    Icons.water_drop: RefugioSymbol.home,
    Icons.water_drop_outlined: RefugioSymbol.home,
    Icons.waves_rounded: RefugioSymbol.home,
    Icons.wb_sunny_outlined: RefugioSymbol.energy,
    Icons.work_outline: RefugioSymbol.activities,
  };
  @override
  Widget build(BuildContext context) {
    if (icon == Icons.mood) {
      return Semantics(
        label: semanticLabel,
        child: RefugioFace(
          mood: Mood.happy,
          size: size ?? IconTheme.of(context).size ?? 24,
        ),
      );
    }
    final symbol = symbols[icon];
    if (symbol == null) {
      return Icon(icon, size: size, color: color, semanticLabel: semanticLabel);
    }
    return Semantics(
      label: semanticLabel,
      child: RefugioIllustration(
        symbol,
        size: size ?? IconTheme.of(context).size ?? 24,
      ),
    );
  }
}
