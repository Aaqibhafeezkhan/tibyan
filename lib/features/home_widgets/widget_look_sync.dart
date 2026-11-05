// Draws the home screen widgets' pictures (widget_art.dart) and hands them
// to the widgets with their specs, and tells the widgets the app's own
// look (`wl_app`), which a widget set to «كما في التطبيق» follows.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings/settings_controller.dart';

import '../../core/theme/interface_style.dart';
import '../../core/theme/theme_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../khatma/khatma_providers.dart' show homeWidgetSyncProvider;
import '../khatma/services/home_widget_sync.dart';
import 'widget_art.dart';

final widgetLookSyncProvider = Provider<WidgetLookSync>((ref) {
  final widgets = ref.read(homeWidgetSyncProvider);
  return WidgetLookSync(
    widgets,
    ref.read(sharedPreferencesProvider),
    // No widgets here (tests, the web, Windows, Linux): nothing to draw.
    enabled:
        widgets is! NoHomeWidget &&
        !kIsWeb &&
        const {
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform),
    copyFonts:
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS,
  );
});

/// Draws [widget] at [size] into a PNG, off screen.
typedef WidgetPainter = Future<Uint8List?> Function(
  Widget widget,
  Size size,
  double ratio,
);

/// The fonts the Apple widgets draw the day's text in, copied to the App
/// Group (an extension cannot read the app's assets). Android's widgets
/// read them from the app's own assets.
const widgetFonts = {
  'wl_font_ui': 'assets/fonts/ofl/changa/Changa[wght].ttf',
  'wl_font_quran': 'assets/fonts/kfgqpc/uthmanic_hafs_v20.ttf',
};

/// The preference that says which pictures the widgets hold.
const widgetLooksDrawnKey = 'widget.looks.drawn';

/// What the pictures are drawn for: they are drawn again when it changes.
String widgetLooksStamp(String lang, List<(InterfaceStyle, ThemeModeId)> v) => [
  widgetArtVersion,
  lang,
  for (final (s, m) in v) widgetVariantKey(s, m),
].join('|');

class WidgetLookSync {
  WidgetLookSync(
    this._widgets,
    this._prefs, {
    WidgetPainter? painter,
    this.ratio = 2.5,
    this.copyFonts = false,
    this.enabled = true,
  }) : _paint = painter ?? paintWidgetPng;

  final HomeWidgetSync _widgets;
  final SharedPreferences _prefs;
  final WidgetPainter _paint;

  /// The pictures' pixels per point.
  final double ratio;

  /// Whether the widgets need [widgetFonts] (iOS, macOS).
  final bool copyFonts;

  final bool enabled;

  String? _last;
  Future<void> _running = Future.value();

  /// Follows the app's look: [style] in [mode], words in [l]. Called on
  /// every build of the app; does nothing when nothing changed.
  Future<void> follow({
    required InterfaceStyle style,
    required ThemeModeId mode,
    required AppLocalizations l,
  }) {
    final key = '${widgetVariantKey(style, mode)}|${l.localeName}';
    if (!enabled || key == _last) return _running;
    _last = key;
    // One drawing at a time, in the order asked.
    return _running = _running
        .then((_) => _draw(style, mode, l))
        .catchError((Object _) {});
  }

  Future<void> _draw(
    InterfaceStyle style,
    ThemeModeId mode,
    AppLocalizations l,
  ) async {
    final variants = widgetVariants(style, mode);
    final stamp = widgetLooksStamp(l.localeName, variants);
    final entries = <String, String>{'wl_app': widgetVariantKey(style, mode)};
    if (_prefs.getString(widgetLooksDrawnKey) != stamp) {
      if (copyFonts) {
        for (final MapEntry(key: k, value: asset) in widgetFonts.entries) {
          final data = await rootBundle.load(asset);
          await _widgets.saveFile(k, data.buffer.asUint8List(), 'ttf');
        }
      }
      for (final (s, m) in variants) {
        final look = widgetLook(s, m);
        for (final face in WidgetFace.values) {
          for (final shape in WidgetShape.values) {
            final art = buildWidgetArt(face, shape, look, l);
            final png = await _paint(art.art, art.size, ratio);
            if (png == null) continue;
            final key = widgetArtKey(face, shape, s, m);
            await _widgets.saveFile('${key}_png', png, 'png');
            entries[key] = art.spec('${key}_png.png');
            // Let the app's own frames through between pictures.
            await Future<void>.delayed(const Duration(milliseconds: 16));
          }
        }
      }
      await _prefs.setString(widgetLooksDrawnKey, stamp);
    }
    await _widgets.writeLooks(entries);
  }
}

/// [widget] drawn off screen at [size] (points) × [ratio] into a PNG; null
/// where there is no view to draw with.
Future<Uint8List?> paintWidgetPng(
  Widget widget,
  Size size,
  double ratio,
) async {
  final view = ui.PlatformDispatcher.instance.implicitView;
  if (view == null) return null;
  final boundary = RenderRepaintBoundary();
  final pipeline = PipelineOwner();
  final build = BuildOwner(focusManager: FocusManager());
  final root = RenderView(
    view: view,
    child: RenderPositionedBox(child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      devicePixelRatio: ratio,
    ),
  );
  pipeline.rootNode = root;
  root.prepareInitialFrame();
  final element = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: widget,
  ).attachToRenderTree(build);
  build
    ..buildScope(element)
    ..finalizeTree();
  pipeline
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();
  final image = await boundary.toImage(pixelRatio: ratio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
