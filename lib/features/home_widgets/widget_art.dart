// The home screen widgets in the app's interface look («شكل الواجهة»).
//
// RemoteViews (Android) and WidgetKit (iOS, macOS) cannot run the look's
// painters, so the app draws each widget's frame as a picture with the
// home screen's own pieces (look_kit.dart): the ground, the hero arch or
// the manuscript's frame, the label, the buttons and the section tiles.
// What changes from day to day (the verse, the portion, the count) is not
// in the picture: each picture comes with a spec of slots, where and how
// that text goes, and the widget draws the day's text into them from the
// entries the app writes ahead. The day rolls over without the app, and
// the frame is drawn again only when the language or the look changes.
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/interface_style.dart';
import '../../core/theme/ornaments.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/ui/look_kit.dart';
import '../../l10n/app_localizations.dart';

/// The pictures' version: a change to the art draws them all again.
const widgetArtVersion = 1;

/// What a picture is drawn for. [actionsDone]: the shortcuts with today's
/// portion marked read.
enum WidgetFace { verse, khatma, tasbih, actions, actionsDone }

/// The two shapes drawn: a square (iOS small and large, Android 2×2) and a
/// wide one (iOS medium, Android 4×2). A widget of another size shows the
/// nearer one, scaled.
enum WidgetShape {
  small(Size(170, 170)),
  medium(Size(364, 170));

  const WidgetShape(this.size);
  final Size size;
}

/// The looks the pictures are drawn in: each interface style, light and
/// night (what a widget can be set to), and the app's own when it is
/// «أبيض زاهي» or black.
List<(InterfaceStyle, ThemeModeId)> widgetVariants(
  InterfaceStyle appStyle,
  ThemeModeId appMode,
) => [
  for (final s in InterfaceStyle.values)
    for (final m in const [ThemeModeId.light, ThemeModeId.night]) (s, m),
  if (appMode == ThemeModeId.white || appMode == ThemeModeId.black)
    (appStyle, appMode),
];

/// `handasi_night`: how the widgets name a look (`wl_app`, the pictures).
String widgetVariantKey(InterfaceStyle style, ThemeModeId mode) =>
    '${style.name}_${mode.name}';

/// The key a picture's spec is written under: `wl_verse_medium_handasi_light`.
String widgetArtKey(
  WidgetFace face,
  WidgetShape shape,
  InterfaceStyle style,
  ThemeModeId mode,
) => 'wl_${face.name}_${shape.name}_${widgetVariantKey(style, mode)}';

UiLook widgetLook(InterfaceStyle style, ThemeModeId mode) => UiLook.of(
  style,
  night: !mode.isLight,
  white: mode == ThemeModeId.white,
  black: mode == ThemeModeId.black,
);

/// Where the widget draws one piece of the day's text (or the progress
/// bar), in the picture's own units.
class WidgetSlot {
  const WidgetSlot(
    this.id,
    this.rect, {
    this.quran = false,
    this.size = 12,
    this.min = 8,
    this.weight = 400,
    required this.color,
    this.track,
    this.center = false,
    this.lines = 1,
  });

  /// `text`, `ref`, `surah`, `num`, `portion`, `day`, `bar`, `dhikr`,
  /// `count`: what the widget puts here.
  final String id;
  final Rect rect;

  /// The mushaf's face (UthmanicHafs) instead of the interface's (Changa).
  final bool quran;

  /// The text's size and the least it may shrink to so that it fits.
  final double size, min;
  final int weight;
  final Color color;

  /// The bar's track; set for the progress bar only.
  final Color? track;
  final bool center;
  final int lines;

  Map<String, Object> toJson(Size s) => {
    'id': id,
    'x': rect.left / s.width,
    'y': rect.top / s.height,
    'w': rect.width / s.width,
    'h': rect.height / s.height,
    'font': quran ? 'quran' : 'ui',
    // Sizes as a share of the height, so they scale with the picture.
    'size': size / s.height,
    'min': min / s.height,
    'weight': weight,
    'color': _hex(color),
    if (track != null) 'track': _hex(track!),
    'align': center ? 'center' : 'start',
    'lines': lines,
  };
}

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// One widget's picture: what to draw, the slots for the day's text, and
/// where its buttons are (`button`, `count`, `t0` … `t3`).
class WidgetArt {
  const WidgetArt({
    required this.size,
    required this.rtl,
    required this.art,
    required this.slots,
    required this.taps,
  });

  final Size size;
  final bool rtl;
  final Widget art;
  final List<WidgetSlot> slots;
  final Map<String, Rect> taps;

  /// The spec the widgets read; [file] is the picture's file name.
  String spec(String file) => jsonEncode({
    'v': widgetArtVersion,
    'file': file,
    'rtl': rtl,
    'aspect': size.width / size.height,
    'slots': [for (final s in slots) s.toJson(size)],
    'taps': {
      for (final MapEntry(key: k, value: r) in taps.entries)
        k: [
          r.left / size.width,
          r.top / size.height,
          r.width / size.width,
          r.height / size.height,
        ],
    },
  });
}

TextStyle _ui(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w600,
}) => TextStyle(
  fontFamily: 'Changa',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1.2,
);

/// The picture of [face] in [look], with its words in [l]. The verse
/// widget is always right to left (the verse is Arabic); the others follow
/// the app's language.
WidgetArt buildWidgetArt(
  WidgetFace face,
  WidgetShape shape,
  UiLook look,
  AppLocalizations l,
) {
  final rtl = face == WidgetFace.verse || l.localeName == 'ar';
  return _Builder(face, shape, look, l, rtl).build();
}

class _Builder {
  _Builder(this.face, this.shape, this.look, this.l, this.rtl);

  final WidgetFace face;
  final WidgetShape shape;
  final UiLook look;
  final AppLocalizations l;
  final bool rtl;

  final _layers = <Widget>[];
  final _slots = <WidgetSlot>[];
  final _taps = <String, Rect>{};

  Size get size => shape.size;
  bool get small => shape == WidgetShape.small;
  bool get arch => !look.isMakhtuta;
  late final HeroArchColors _c = heroArchColors(look);

  // The card's colours: on the arch, the home hero's; in the manuscript
  // frame, the look's own.
  Color get ink => arch ? _c.ink : look.ink;
  Color get sub => arch ? _c.sub : look.sub;
  Color get label => arch ? (look.isLayli ? _c.rim : _c.sub) : look.goldText;
  Color get buttonBg => arch ? _c.buttonBg : look.control;
  Color get buttonFg => arch ? _c.buttonFg : look.onControl;
  double get buttonRadius => arch ? (look.isLayli ? 24 : 12) : 4;

  /// [start] from the reading side: the right in Arabic.
  Rect _at(double start, double top, double width, double height) =>
      Rect.fromLTWH(
        rtl ? size.width - start - width : start,
        top,
        width,
        height,
      );

  /// [r], given as if the reading side were the left, mirrored for right
  /// to left.
  Rect _side(Rect r) => rtl
      ? Rect.fromLTRB(
          size.width - r.right,
          r.top,
          size.width - r.left,
          r.bottom,
        )
      : r;

  void _put(Rect r, Widget child) =>
      _layers.add(Positioned.fromRect(rect: r, child: child));

  static const _m = 6.0;

  WidgetArt build() {
    _layers
      ..add(Positioned.fill(child: ColoredBox(color: look.bg)))
      ..add(const Positioned.fill(child: LookBackground(hero: true)));
    // The shortcuts stand on the ground, like the home's section tiles.
    final body = face == WidgetFace.actions || face == WidgetFace.actionsDone
        ? Rect.zero
        : _card();
    switch (face) {
      case WidgetFace.verse:
        _verse(body);
      case WidgetFace.khatma:
        _khatma(body);
      case WidgetFace.tasbih:
        _tasbih(body);
      case WidgetFace.actions:
      case WidgetFace.actionsDone:
        _actions();
    }
    final art = MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Theme(
          data: ThemeData(extensions: [look]),
          child: SizedBox.fromSize(
            size: size,
            child: Stack(children: _layers),
          ),
        ),
      ),
    );
    return WidgetArt(
      size: size,
      rtl: rtl,
      art: art,
      slots: _slots,
      taps: _taps,
    );
  }

  String get _title => switch (face) {
    WidgetFace.verse => l.verseOfDayTitle,
    WidgetFace.khatma => l.widgetTodayWird,
    WidgetFace.tasbih => l.sectionTasbih,
    _ => '',
  };

  /// The card (the hero arch, or the manuscript's frame with its band) and
  /// its label; returns the room left for the rest.
  Rect _card() {
    final card = Rect.fromLTRB(_m, _m, size.width - _m, size.height - _m);
    if (arch) {
      // A low arch: the widget is short beside the home's hero card.
      final sy = card.height * .30;
      _put(card, HeroArch(spring: sy / card.width, inset: 5));
      final top = _m + sy * .38;
      _put(
        Rect.fromCenter(
          center: Offset(size.width / 2, top + 8),
          width: card.width * .6,
          height: 16,
        ),
        Text(
          _title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _ui(11.5, label),
        ),
      );
      return Rect.fromLTRB(
        card.left + 16,
        top + 18,
        card.right - 16,
        card.bottom - 10,
      );
    }
    _put(
      card,
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: look.frame,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: look.surface,
            border: Border.all(color: look.gold, width: 1.4),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
    final inner = card.deflate(5);
    _put(
      Rect.fromLTWH(inner.left + 8, inner.top + 6, inner.width - 16, 9),
      const TazhibBand(height: 9),
    );
    _put(
      _at(10 + inner.left, inner.top + 18, inner.width - 20, 16),
      Text(
        _title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _ui(11.5, label),
      ),
    );
    return Rect.fromLTRB(
      inner.left + 10,
      inner.top + 36,
      inner.right - 10,
      inner.bottom - 8,
    );
  }

  /// A pill button at [r]: the home hero's, with [icon] before [text].
  void _button(Rect r, String text, {IconData? icon}) => _put(
    r,
    DecoratedBox(
      decoration: BoxDecoration(
        color: buttonBg,
        borderRadius: BorderRadius.circular(buttonRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: buttonFg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _ui(12, buttonFg, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );

  static const _foot = 26.0;

  void _verse(Rect b) {
    final foot = b.bottom - _foot;
    final Rect button;
    if (small) {
      button = Rect.fromCenter(
        center: Offset(size.width / 2, foot + _foot / 2),
        width: 96,
        height: _foot,
      );
      _slots.add(
        WidgetSlot(
          'ref',
          Rect.fromLTRB(b.left, foot - 19, b.right, foot - 3),
          size: 10.5,
          color: sub,
          center: true,
        ),
      );
      _slots.add(
        WidgetSlot(
          'text',
          Rect.fromLTRB(b.left + 2, b.top, b.right - 2, foot - 21),
          quran: true,
          size: 15,
          color: ink,
          center: true,
          lines: 5,
        ),
      );
    } else {
      const width = 88.0;
      // The reference on the reading side, the button at the end.
      button = _side(Rect.fromLTWH(b.right - width, foot, width, _foot));
      final ref = _side(
        Rect.fromLTRB(b.left, foot, b.right - width - 8, b.bottom),
      );
      final middle = Rect.fromLTRB(b.left, b.top, b.right, foot - 4);
      if (arch) {
        _slots.add(WidgetSlot('ref', ref, size: 11.5, color: sub));
        _slots.add(
          WidgetSlot(
            'text',
            middle.deflate(6),
            quran: true,
            size: 17,
            color: ink,
            center: true,
            lines: 5,
          ),
        );
      } else {
        // The manuscript: the verse's number in a star medallion beside it,
        // and the surah's name below.
        const star = 44.0;
        final badge = _at(b.left, middle.center.dy - star / 2, star, star);
        _put(
          badge,
          CustomPaint(
            painter: StarPainter(look.gold.withValues(alpha: .14), look.gold),
          ),
        );
        _slots.add(
          WidgetSlot(
            'num',
            badge.deflate(9),
            size: 13,
            weight: 600,
            color: look.accent,
            center: true,
          ),
        );
        _slots.add(WidgetSlot('surah', ref, size: 12, color: sub));
        _slots.add(
          WidgetSlot(
            'text',
            _side(
              Rect.fromLTRB(
                middle.left + star + 10,
                middle.top,
                middle.right,
                middle.bottom,
              ),
            ),
            quran: true,
            size: 17,
            color: ink,
            lines: 5,
          ),
        );
      }
    }
    _button(button, l.widgetListen, icon: Icons.play_arrow);
    _taps['button'] = button;
  }

  void _khatma(Rect b) {
    final foot = b.bottom - _foot;
    final fill = arch ? _c.buttonBg : look.control;
    final track = arch ? _c.ink.withValues(alpha: .22) : look.line;
    final Rect button;
    final Rect bar;
    if (small) {
      button = Rect.fromCenter(
        center: Offset(size.width / 2, foot + _foot / 2),
        width: 112,
        height: _foot,
      );
      _slots.add(
        WidgetSlot(
          'day',
          Rect.fromLTRB(b.left, foot - 18, b.right, foot - 3),
          size: 10.5,
          color: sub,
          center: true,
        ),
      );
      bar = Rect.fromLTRB(b.left + 4, foot - 26, b.right - 4, foot - 21);
      _slots.add(
        WidgetSlot(
          'portion',
          Rect.fromLTRB(b.left, b.top, b.right, bar.top - 4),
          size: 14,
          weight: 700,
          color: ink,
          center: true,
          lines: 3,
        ),
      );
    } else {
      const width = 100.0;
      button = _side(Rect.fromLTWH(b.right - width, foot, width, _foot));
      _slots.add(
        WidgetSlot(
          'day',
          _side(Rect.fromLTRB(b.left, foot, b.right - width - 8, b.bottom)),
          size: 11.5,
          color: sub,
        ),
      );
      bar = Rect.fromLTRB(b.left + 4, foot - 12, b.right - 4, foot - 6);
      _slots.add(
        WidgetSlot(
          'portion',
          Rect.fromLTRB(b.left, b.top, b.right, bar.top - 4),
          size: 17,
          weight: 700,
          color: ink,
          center: true,
          lines: 2,
        ),
      );
    }
    _slots.add(WidgetSlot('bar', bar, color: fill, track: track));
    _button(button, l.widgetStartWird);
    _taps['button'] = button;
  }

  void _tasbih(Rect b) {
    final count = look.isLayli
        ? look.goldText
        : arch
        ? _c.ink
        : look.accent;
    final Rect bead;
    if (small) {
      bead = Rect.fromCenter(
        center: Offset(size.width / 2, b.bottom - 17),
        width: 34,
        height: 34,
      );
      _slots.add(
        WidgetSlot(
          'count',
          Rect.fromLTRB(b.left, bead.top - 32, b.right, bead.top - 2),
          size: 24,
          weight: 700,
          color: count,
          center: true,
        ),
      );
      _slots.add(
        WidgetSlot(
          'dhikr',
          Rect.fromLTRB(b.left, b.top, b.right, bead.top - 34),
          quran: true,
          size: 15,
          color: ink,
          center: true,
          lines: 2,
        ),
      );
    } else {
      bead = _at(b.right - 60, b.center.dy - 26, 52, 52);
      final text = _side(Rect.fromLTRB(b.left, b.top, b.right - 76, b.bottom));
      _slots.add(
        WidgetSlot(
          'dhikr',
          Rect.fromLTRB(text.left, text.top, text.right, text.bottom - 38),
          quran: true,
          size: 17,
          color: ink,
          center: true,
          lines: 2,
        ),
      );
      _slots.add(
        WidgetSlot(
          'count',
          Rect.fromLTRB(text.left, text.bottom - 36, text.right, text.bottom),
          size: 26,
          weight: 700,
          color: count,
          center: true,
        ),
      );
    }
    _put(
      bead,
      DecoratedBox(
        decoration: BoxDecoration(color: buttonBg, shape: BoxShape.circle),
        child: Icon(Icons.add, size: bead.width * .55, color: buttonFg),
      ),
    );
    _taps['count'] = bead;
  }

  void _actions() {
    final done = face == WidgetFace.actionsDone;
    // The home screen's own icons for these sections.
    final tiles = [
      (Icons.menu_book_outlined, l.widgetTileContinue),
      (Icons.headphones_outlined, l.widgetTileListen),
      (Icons.search, l.widgetTileSearch),
      done
          ? (Icons.task_alt, l.widgetTileDone)
          : (Icons.task_alt_outlined, l.widgetTileRead),
    ];
    final columns = small ? 2 : 4;
    final rows = small ? 2 : 1;
    final w = size.width / columns;
    final h = size.height / rows;
    final k = small ? .5 : .72;
    for (var i = 0; i < 4; i++) {
      final cell = _at((i % columns) * w, (i ~/ columns) * h, w, h);
      _taps['t$i'] = cell;
      _put(
        cell.deflate(2),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SectionIcon(tiles[i].$1, k: k),
            SizedBox(height: small ? 3 : 6),
            Text(
              tiles[i].$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _ui(small ? 10 : 11.5, look.ink),
            ),
          ],
        ),
      );
    }
  }
}
