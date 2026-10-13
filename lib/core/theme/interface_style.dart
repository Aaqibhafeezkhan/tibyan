import 'package:flutter/material.dart';

import 'contrast.dart';

/// «شكل الواجهة»: the look of the app's own screens (home, index,
/// settings) and of its dialogs, sheets, menus and notices. Separate from
/// the mushaf page styles (theme_tokens.dart), which dress the page.
enum InterfaceStyle {
  /// «مخطوطة»: an illuminated manuscript, dark frames and gold.
  makhtuta,

  /// «هندسي»: geometric star patterns, teal and copper (the default).
  handasi,

  /// «ليلي ذهبي»: night blue, gold and pointed arches.
  layli,
}

const defaultInterfaceStyle = InterfaceStyle.handasi;

/// The colours, faces and shapes of one interface style in one brightness.
/// Screens and overlays read these instead of hard-coding colours.
@immutable
class UiLook extends ThemeExtension<UiLook> {
  const UiLook({
    required this.style,
    required this.night,
    required this.bg,
    required this.surface,
    required this.row,
    required this.ink,
    required this.sub,
    required this.gold,
    required this.goldText,
    required this.accent,
    required this.accent2,
    required this.frame,
    required this.onFrame,
    required this.control,
    required this.onControl,
    required this.line,
    required this.headFont,
    required this.radius,
    this.elderly = false,
  });

  final InterfaceStyle style;

  /// The night palette (the night and black colour modes).
  final bool night;

  /// Screen ground.
  final Color bg;

  /// Cards, sheets and dialogs.
  final Color surface;

  /// List rows.
  final Color row;

  /// Primary text.
  final Color ink;

  /// Secondary text (4.5:1 on [bg] and [surface]; 7:1 in elderly mode).
  final Color sub;

  /// Ornament gold: rules, bands, outlines. Not for small text.
  final Color gold;

  /// Gold for text, at text contrast.
  final Color goldText;

  /// The style's main colour (icons, highlights).
  final Color accent;

  /// The style's second colour (page chips, juz labels).
  final Color accent2;

  /// Dark frames (the manuscript's border, the side rail).
  final Color frame;

  /// What is drawn on [frame].
  final Color onFrame;

  /// Selected controls: switches, chips, primary buttons.
  final Color control;

  /// What is drawn on [control].
  final Color onControl;

  /// Hairlines and card outlines.
  final Color line;

  /// Display face for titles (Arabic); null for the interface face in
  /// bold («هندسي»: the Kufi display face lacks some joined forms).
  final String? headFont;

  /// Corner radius of cards and sheets.
  final double radius;

  /// Elderly mode: stronger contrast, larger targets.
  final bool elderly;

  bool get isMakhtuta => style == InterfaceStyle.makhtuta;
  bool get isHandasi => style == InterfaceStyle.handasi;
  bool get isLayli => style == InterfaceStyle.layli;

  /// «أبيض زاهي»: the light look on pure white grounds.
  bool get isWhite => !night && bg == _white;

  /// Smallest touch target.
  double get target => elderly ? 56 : 48;

  /// The look of [style]; [night] for the night and black modes, [white]
  /// for «أبيض زاهي» (pure white grounds instead of the cream paper).
  factory UiLook.of(
    InterfaceStyle style, {
    required bool night,
    bool white = false,
    bool elderly = false,
  }) {
    final base = _palette(style, night, white && !night);
    return elderly ? base._strong() : base;
  }

  static UiLook _palette(InterfaceStyle style, bool night, bool white) {
    switch (style) {
      case InterfaceStyle.makhtuta:
        return night
            ? _make(
                style,
                night,
                bg: const Color(0xFF16110D),
                surface: const Color(0xFF221A13),
                row: const Color(0xFF2A2018),
                ink: const Color(0xFFF1E4CC),
                sub: const Color(0xFFC2AE92),
                gold: const Color(0xFFD6A94E),
                accent: const Color(0xFFC98B5A),
                accent2: const Color(0xFF6E9BD1),
                frame: const Color(0xFF0C0806),
                onFrame: const Color(0xFFE2B95E),
                control: const Color(0xFFD6A94E),
                head: 'ArefRuqaa',
                radius: 4,
              )
            : _make(
                style,
                night,
                white: white,
                bg: const Color(0xFFEFE2CB),
                surface: const Color(0xFFF7EDDE),
                row: const Color(0xFFF7EDDE),
                ink: const Color(0xFF1E1915),
                sub: const Color(0xFF6A5644),
                gold: const Color(0xFFA9781F),
                accent: const Color(0xFF7A4A26),
                accent2: const Color(0xFF23466E),
                frame: const Color(0xFF4A2B15),
                onFrame: const Color(0xFFF0CF83),
                control: const Color(0xFF7A4A26),
                head: 'ArefRuqaa',
                radius: 4,
              );
      case InterfaceStyle.handasi:
        return night
            ? _make(
                style,
                night,
                bg: const Color(0xFF0E1A1B),
                surface: const Color(0xFF152627),
                row: const Color(0xFF152627),
                ink: const Color(0xFFE7EFEC),
                sub: const Color(0xFF9DB6B1),
                gold: const Color(0xFFD9B266),
                accent: const Color(0xFF55BDB2),
                accent2: const Color(0xFFE59A62),
                frame: const Color(0xFF0A1314),
                onFrame: const Color(0xFF55BDB2),
                control: const Color(0xFF55BDB2),
                head: null,
                radius: 18,
              )
            : _make(
                style,
                night,
                white: white,
                bg: const Color(0xFFF6F1E8),
                surface: const Color(0xFFFFFCF6),
                row: const Color(0xFFFFFCF6),
                ink: const Color(0xFF1E1915),
                sub: const Color(0xFF5E5A52),
                gold: const Color(0xFF9A7428),
                accent: const Color(0xFF0F6660),
                accent2: const Color(0xFFB4561F),
                frame: const Color(0xFF0F6660),
                onFrame: const Color(0xFFFFFCF6),
                control: const Color(0xFF0F6660),
                head: null,
                radius: 18,
              );
      case InterfaceStyle.layli:
        return night
            ? _make(
                style,
                night,
                bg: const Color(0xFF0B1424),
                surface: const Color(0xFF13203A),
                row: const Color(0xFF111D33),
                ink: const Color(0xFFF3EAD6),
                sub: const Color(0xFFAFB6C6),
                gold: const Color(0xFFDDB665),
                accent: const Color(0xFFDDB665),
                accent2: const Color(0xFF4FA37C),
                frame: const Color(0xFF070D18),
                onFrame: const Color(0xFFDDB665),
                control: const Color(0xFFDDB665),
                head: 'ArefRuqaa',
                radius: 16,
              )
            : _make(
                style,
                night,
                white: white,
                bg: const Color(0xFFF8F1E1),
                surface: const Color(0xFFFFFAEE),
                row: const Color(0xFFFFFAEE),
                ink: const Color(0xFF14203A),
                sub: const Color(0xFF545E73),
                gold: const Color(0xFF9C7524),
                accent: const Color(0xFF14203A),
                accent2: const Color(0xFF2E7D5B),
                frame: const Color(0xFF14203A),
                onFrame: const Color(0xFFE6C47A),
                control: const Color(0xFF14203A),
                head: 'ArefRuqaa',
                radius: 16,
              );
    }
  }

  static UiLook _make(
    InterfaceStyle style,
    bool night, {
    required Color bg,
    required Color surface,
    required Color row,
    required Color ink,
    required Color sub,
    required Color gold,
    required Color accent,
    required Color accent2,
    required Color frame,
    required Color onFrame,
    required Color control,
    required String? head,
    required double radius,
    bool white = false,
  }) {
    if (white) {
      // «أبيض زاهي»: pure white grounds and neutral hairlines, no cream.
      bg = surface = row = _white;
      if (onFrame.computeLuminance() > .8) onFrame = _white;
    }
    final grounds = [bg, surface, row];
    return UiLook(
      style: style,
      night: night,
      bg: bg,
      surface: surface,
      row: row,
      ink: ink,
      sub: towardContrast(sub, ink, grounds, 4.5),
      gold: gold,
      goldText: towardContrast(gold, ink, grounds, 4.5),
      accent: accent,
      accent2: towardContrast(accent2, ink, grounds, 4.5),
      frame: frame,
      onFrame: onFrame,
      control: control,
      onControl: strongPair(control, night ? bg : surface, 4.5).$2,
      line: white
          ? Color.alphaBlend(const Color(0x29000000), _white)
          : style == InterfaceStyle.handasi
          ? Color.alphaBlend(ink.withValues(alpha: .10), surface)
          : Color.alphaBlend(gold.withValues(alpha: .55), surface),
      headFont: head,
      radius: radius,
    );
  }

  static const _white = Color(0xFFFFFFFF);

  /// Elderly mode: text 7:1, hairlines 3:1, controls 4.5:1.
  UiLook _strong() {
    final grounds = [bg, surface, row];
    final (c, onC) = strongPair(
      towardContrast(control, ink, grounds, 4.5),
      onControl,
      7,
    );
    return copyWith(
      ink: towardContrast(ink, extremeAgainst(surface), grounds, 7),
      sub: towardContrast(sub, ink, grounds, 7),
      goldText: towardContrast(goldText, ink, grounds, 7),
      accent2: towardContrast(accent2, ink, grounds, 7),
      line: towardContrast(line, ink, grounds, 3),
      control: c,
      onControl: onC,
      elderly: true,
    );
  }

  @override
  UiLook copyWith({
    Color? ink,
    Color? sub,
    Color? goldText,
    Color? accent2,
    Color? line,
    Color? control,
    Color? onControl,
    bool? elderly,
  }) => UiLook(
    style: style,
    night: night,
    bg: bg,
    surface: surface,
    row: row,
    ink: ink ?? this.ink,
    sub: sub ?? this.sub,
    gold: gold,
    goldText: goldText ?? this.goldText,
    accent: accent,
    accent2: accent2 ?? this.accent2,
    frame: frame,
    onFrame: onFrame,
    control: control ?? this.control,
    onControl: onControl ?? this.onControl,
    line: line ?? this.line,
    headFont: headFont,
    radius: radius,
    elderly: elderly ?? this.elderly,
  );

  @override
  UiLook lerp(ThemeExtension<UiLook>? other, double t) =>
      t < 0.5 ? this : (other as UiLook? ?? this);

  /// Overlays (dialogs, sheets, menus, snackbars, tooltips) dressed in
  /// this look, merged into [base].
  ThemeData overlays(ThemeData base) {
    // Keep the interface face: a bare TextStyle here would replace it.
    TextStyle f(TextStyle t) =>
        (base.textTheme.bodyMedium ?? const TextStyle()).merge(t);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(isMakhtuta ? 6 : radius + 6),
      side: isHandasi ? BorderSide.none : BorderSide(color: line, width: 1.2),
    );
    final sheetShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(isMakhtuta ? 8 : radius + 10),
      ),
      side: isHandasi ? BorderSide.none : BorderSide(color: line, width: 1.2),
    );
    final title = TextStyle(
      fontSize: elderly ? 24 : 20,
      fontWeight: FontWeight.w700,
      color: ink,
    );
    return base.copyWith(
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        titleTextStyle: f(title),
        contentTextStyle: f(TextStyle(fontSize: elderly ? 18 : 15, color: ink)),
        barrierColor: frame.withValues(alpha: .55),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: sheetShape,
        dragHandleColor: isHandasi ? accent.withValues(alpha: .45) : gold,
        dragHandleSize: const Size(40, 4),
        modalBarrierColor: frame.withValues(alpha: .45),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: frame,
        contentTextStyle: f(
          TextStyle(color: onFrame, fontSize: elderly ? 18 : 15),
        ),
        actionTextColor: isHandasi ? onFrame : gold,
        closeIconColor: onFrame,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMakhtuta ? 4 : 14),
          side: isHandasi ? BorderSide.none : BorderSide(color: gold),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMakhtuta ? 4 : 14),
          side: BorderSide(color: line),
        ),
        textStyle: f(TextStyle(color: ink, fontSize: elderly ? 18 : 15)),
        iconColor: accent,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isMakhtuta ? 4 : 14),
              side: BorderSide(color: line),
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: frame,
          borderRadius: BorderRadius.circular(isMakhtuta ? 3 : 8),
          border: isHandasi ? null : Border.all(color: gold),
        ),
        textStyle: f(TextStyle(color: onFrame, fontSize: elderly ? 16 : 13)),
      ),
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        contentTextStyle: f(TextStyle(color: ink)),
        dividerColor: line,
      ),
    );
  }

  /// Controls and cards of the app's own screens in this look, merged
  /// into [base] (the mushaf theme stays on the reading screens).
  ThemeData screens(ThemeData base) {
    // Keep the interface face (as [overlays] does).
    TextStyle f(TextStyle t) =>
        (base.textTheme.bodyMedium ?? const TextStyle()).merge(t);
    final scheme = base.colorScheme.copyWith(
      primary: control,
      onPrimary: onControl,
      secondary: goldText,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: sub,
      outline: line,
      outlineVariant: line,
    );
    return overlays(base).copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: bg,
        foregroundColor: ink,
        titleTextStyle: (base.textTheme.titleLarge ?? const TextStyle())
            .copyWith(
              fontFamily: headFont,
              fontSize: isHandasi ? 20 : 26,
              color: isLayli ? goldText : ink,
            ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: line, width: isMakhtuta ? 1.4 : 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: line,
        space: 1,
        thickness: elderly ? 1.5 : 1,
      ),
      listTileTheme: base.listTileTheme.copyWith(
        iconColor: accent,
        textColor: ink,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? control : sub,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? control : null,
        ),
        checkColor: WidgetStatePropertyAll(onControl),
        side: BorderSide(color: sub, width: 2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? onControl : sub,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? control : surface,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? control : sub,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: control,
        secondarySelectedColor: control,
        checkmarkColor: onControl,
        backgroundColor: surface,
        side: BorderSide(color: line),
        // Merged into the interface face: a bare TextStyle lost it.
        labelStyle: f(TextStyle(color: ink)),
        secondaryLabelStyle: f(TextStyle(color: onControl)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: isMakhtuta
            ? onFrame
            : (isLayli && !night ? onFrame : control),
        unselectedLabelColor: sub,
        indicatorColor: control,
        dividerColor: isHandasi ? line : Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        prefixIconColor: sub,
        hintStyle: TextStyle(color: sub),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isMakhtuta ? 4 : 14),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isMakhtuta ? 4 : 14),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isMakhtuta ? 4 : 14),
          borderSide: BorderSide(color: control, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: control,
          foregroundColor: onControl,
          minimumSize: Size(48, target),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMakhtuta ? 4 : 12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isLayli && night ? goldText : control,
          minimumSize: Size(48, target),
          side: BorderSide(color: isLayli && night ? gold : control),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMakhtuta ? 4 : 12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isLayli && night ? goldText : control,
          minimumSize: Size(48, target),
        ),
      ),
    );
  }
}

extension UiLookX on BuildContext {
  /// The interface style's look ([UiLook]) of the current theme.
  UiLook get look =>
      Theme.of(this).extension<UiLook>() ??
      UiLook.of(
        defaultInterfaceStyle,
        night: Theme.of(this).brightness == Brightness.dark,
      );
}
