// Shared pieces of the interface styles («شكل الواجهة»): the brand mark,
// medallions, bands, the screen frame with its wide-window rail, top bars,
// grouped sections and overlay headers. Every colour comes from [UiLook].
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/contrast.dart';
import '../theme/interface_style.dart';
import '../theme/ornaments.dart';
import '../theme/theme_tokens.dart';

/// Wider than this, screens get the side rail and two columns.
const wideBreakpoint = 900.0;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width > wideBreakpoint;

/// The «تبيان» calligraphy (assets/brand/tibyan_logo.svg, traced from the
/// logo artwork), tinted in [color]. Never re-typeset in a font.
class TibyanLogo extends StatelessWidget {
  const TibyanLogo({super.key, required this.color, this.height = 40});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    label: AppLocalizations.of(context).appTitle,
    child: ExcludeSemantics(
      child: SvgPicture.asset(
        'assets/brand/tibyan_logo.svg',
        height: height,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    ),
  );
}

/// An 8-point star medallion holding a number.
class StarBadge extends StatelessWidget {
  const StarBadge({
    super.key,
    required this.text,
    required this.fill,
    required this.line,
    required this.textColor,
    this.size = 40,
  });

  final String text;
  final Color fill, line, textColor;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: StarPainter(fill, line),
      child: Center(
        child: Text(
          text,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: size * (text.length > 2 ? .28 : .32),
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    ),
  );
}

/// Kaaba for a Meccan surah, the green dome for a Medinan one.
class RevelationMark extends StatelessWidget {
  const RevelationMark({super.key, required this.meccan, this.size = 30});

  final bool meccan;
  final double size;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final outline = look.night ? look.gold.withValues(alpha: .6) : null;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: meccan
            ? KaabaPainter(outline: outline)
            : DomePainter(outline: outline),
      ),
    );
  }
}

/// A tazhib band in the look's gold.
class TazhibBand extends StatelessWidget {
  const TazhibBand({super.key, this.height = 14});

  final double height;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: TazhibPainter(look.gold, look.accent2)),
    );
  }
}

/// The ground pattern behind a screen. [hero]: the home's fuller pattern.
class LookBackground extends StatelessWidget {
  const LookBackground({super.key, this.hero = false});

  final bool hero;

  @override
  Widget build(BuildContext context) {
    final l = context.look;
    final Widget art = switch (l.style) {
      InterfaceStyle.makhtuta => CustomPaint(
        painter: GirihPainter(
          l.gold.withValues(alpha: l.night ? .06 : .09),
          cell: 72,
        ),
      ),
      InterfaceStyle.handasi =>
        hero
            ? Align(
                alignment: AlignmentDirectional.topStart,
                child: SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: GirihPainter(
                      l.accent.withValues(alpha: l.night ? .16 : .10),
                      cell: 44,
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      InterfaceStyle.layli =>
        l.night
            ? CustomPaint(painter: SkyPainter(l.gold))
            : hero
            ? CustomPaint(
                painter: GirihPainter(l.gold.withValues(alpha: .07), cell: 80),
              )
            : const SizedBox.shrink(),
    };
    return ExcludeSemantics(child: RepaintBoundary(child: art));
  }
}

/// A destination of the wide-window rail.
enum RailItem { home, contents, listen, settings }

/// The frame of the app's own screens in the interface style: the style's
/// controls and ground, and on a wide window a side rail with the brand
/// and the main destinations.
class LookScaffold extends StatelessWidget {
  const LookScaffold({
    super.key,
    required this.body,
    this.selected,
    this.hero = false,
    this.rail = true,
  });

  final Widget body;
  final RailItem? selected;
  final bool hero;

  /// Show the side rail on wide windows.
  final bool rail;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final content = Stack(
      children: [
        Positioned.fill(child: LookBackground(hero: hero)),
        body,
      ],
    );
    return Theme(
      data: look.screens(Theme.of(context)),
      child: Scaffold(
        backgroundColor: look.bg,
        body: rail && isWide(context)
            ? Row(
                children: [
                  _Rail(selected: selected),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({this.selected});

  final RailItem? selected;

  @override
  Widget build(BuildContext context) {
    final l = context.look;
    final s = AppLocalizations.of(context);
    final items = [
      (RailItem.home, s.navHome, Icons.home_outlined, '/'),
      (RailItem.contents, s.indexTitle, Icons.list_alt, '/mushaf/index'),
      (RailItem.listen, s.sectionListen, Icons.headphones_outlined, null),
      (RailItem.settings, s.settingsTitle, Icons.tune, '/settings'),
    ];
    return Container(
      width: 248,
      color: l.frame,
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: GirihPainter(
                  l.onFrame.withValues(alpha: .07),
                  cell: 64,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: TibyanLogo(color: l.onFrame, height: 64)),
                  const SizedBox(height: 28),
                  for (final (item, label, icon, route) in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Semantics(
                        selected: item == selected,
                        button: true,
                        child: Material(
                          color: item == selected
                              ? l.onFrame.withValues(alpha: .14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            l.isMakhtuta ? 4 : 12,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              l.isMakhtuta ? 4 : 12,
                            ),
                            onTap: item == selected
                                ? null
                                : () => route == null
                                      ? context.push('/mushaf/audio')
                                      : context.go(route),
                            child: SizedBox(
                              height: 52,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Icon(icon, color: l.onFrame, size: 22),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: l.onFrame,
                                          fontWeight: item == selected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A screen title in the style's display face (the interface face in
/// English).
TextStyle lookTitleStyle(BuildContext context, {double? size}) {
  final l = context.look;
  final arabic = Localizations.localeOf(context).languageCode == 'ar';
  return TextStyle(
    fontFamily: arabic ? l.headFont : null,
    fontSize: size ?? (l.isHandasi || !arabic ? 20 : 26),
    fontWeight: arabic && l.headFont != null ? null : FontWeight.w700,
    color: l.isLayli ? l.goldText : l.ink,
    height: 1.3,
  );
}

/// The top bar of a pushed screen: back (pointing to the reading
/// direction's start), the title centred, and [actions].
class LookTopBar extends StatelessWidget {
  const LookTopBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.back = true,
  });

  final String title;
  final List<Widget> actions;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final l = context.look;
    final canPop = back && (Navigator.of(context).canPop());
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            if (canPop)
              // Icons.arrow_back mirrors itself: it points right in Arabic.
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: l.ink,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
              )
            else
              SizedBox(width: actions.isEmpty ? 16 : 48),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: lookTitleStyle(context),
                ),
              ),
            ),
            if (actions.isEmpty)
              SizedBox(width: back ? 48 : 16)
            else
              ...actions,
          ],
        ),
      ),
    );
  }
}

/// A titled group of settings rows: a framed head band in «مخطوطة», an
/// icon chip in «هندسي», a small arch in «ليلي ذهبي».
class LookGroup extends StatelessWidget {
  const LookGroup({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l = context.look;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final divided = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        divided.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
      divided.add(children[i]);
    }
    final Widget head = switch (l.style) {
      InterfaceStyle.makhtuta => Container(
        constraints: const BoxConstraints(minHeight: 46),
        decoration: BoxDecoration(
          color: l.frame,
          border: Border(bottom: BorderSide(color: l.gold, width: 1.2)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            ExcludeSemantics(
              child: StarBadge(
                text: '',
                fill: l.frame,
                line: l.gold,
                textColor: l.gold,
                size: 26,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontFamily: arabic ? 'ArefRuqaa' : null,
                fontWeight: arabic ? null : FontWeight.w700,
                fontSize: arabic ? 19 : 16,
                color: l.onFrame,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: ExcludeSemantics(child: TazhibBand(height: 8)),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
      InterfaceStyle.handasi => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: l.control,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: l.onControl),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontFamily: arabic ? l.headFont : null,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: l.ink,
              ),
            ),
          ],
        ),
      ),
      InterfaceStyle.layli => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            ExcludeSemantics(
              child: SizedBox(
                width: 26,
                height: 32,
                child: CustomPaint(
                  painter: ArchBorder(l.gold, spring: .5, inset: 3),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontFamily: arabic ? 'ArefRuqaa' : null,
                fontWeight: arabic ? null : FontWeight.w700,
                fontSize: arabic ? 21 : 17,
                color: l.goldText,
              ),
            ),
          ],
        ),
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: l.surface,
        borderRadius: BorderRadius.circular(l.radius),
        border: Border.all(
          color: l.isMakhtuta ? l.gold : l.line,
          width: l.isMakhtuta ? 1.4 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: head),
            ...divided,
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

/// The head of a sheet or dialog in the interface style: an ornament (a
/// tazhib band, a star, or an arch), then the title.
class LookSheetHeader extends StatelessWidget {
  const LookSheetHeader({super.key, required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final l = context.look;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final ornament = switch (l.style) {
      InterfaceStyle.makhtuta => const TazhibBand(height: 10),
      InterfaceStyle.handasi => SizedBox.square(
        dimension: 40,
        child: CustomPaint(
          painter: StarPainter(l.control.withValues(alpha: .12), l.control),
          child: icon == null ? null : Icon(icon, size: 20, color: l.control),
        ),
      ),
      InterfaceStyle.layli => SizedBox(
        width: 34,
        height: 42,
        child: CustomPaint(
          painter: ArchBorder(l.gold, spring: .5, inset: 3),
          child: icon == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Icon(icon, size: 18, color: l.goldText),
                ),
        ),
      ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: ornament),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: arabic ? l.headFont : null,
              fontWeight: arabic && l.headFont != null ? null : FontWeight.w700,
              fontSize: (l.isHandasi ? 20 : 24) + (l.elderly ? 4 : 0),
              color: l.isLayli ? l.goldText : l.ink,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// [base]'s colours re-read from [l], for widgets that still read the
/// mushaf style's [TibyanTokens]: inside a [LookTheme] they take the
/// interface style's colours. The highlight and the art tint stay.
ModeTokens lookModeTokens(UiLook l, ModeTokens base) {
  final (accent, accentFg) = strongPair(
    l.isLayli && !l.night ? l.accent2 : l.accent,
    l.night ? l.bg : l.surface,
    4.5,
  );
  return ModeTokens(
    bg: l.bg,
    paper: l.surface,
    ink: l.ink,
    muted: l.sub,
    border: l.line,
    frame: l.isHandasi ? l.accent : l.gold,
    marker: l.gold,
    goldText: l.goldText,
    headBg: l.frame,
    headFg: l.onFrame,
    accent: accent,
    accentFg: accentFg,
    player: l.frame,
    playerFg: l.onFrame,
    highlight: base.highlight,
    control: l.control,
    onControl: l.onControl,
    artTint: base.artTint,
  );
}

/// Dresses [child] in the interface style: its controls, cards, overlays
/// and the colours read through [TibyanTokens]. For the app's own screens
/// and the chrome over the mushaf (bars, panels, sheets), never the page.
class LookTheme extends StatelessWidget {
  const LookTheme({super.key, required this.child});

  final Widget child;

  /// [theme] dressed in its interface style.
  static ThemeData of(ThemeData theme) {
    final look =
        theme.extension<UiLook>() ??
        UiLook.of(
          defaultInterfaceStyle,
          night: theme.brightness == Brightness.dark,
        );
    final tokens = theme.extension<TibyanTokens>();
    final dressed = look.screens(theme);
    final (accent, onAccent) = strongPair(
      look.isLayli && !look.night ? look.accent2 : look.accent,
      look.night ? look.bg : look.surface,
      4.5,
    );
    return dressed.copyWith(
      // The roles [UiLook.screens] leaves to the page style: segmented
      // buttons, containers and accents.
      colorScheme: dressed.colorScheme.copyWith(
        tertiary: accent,
        onTertiary: onAccent,
        secondaryContainer: Color.alphaBlend(
          look.control.withValues(alpha: look.night ? .30 : .16),
          look.surface,
        ),
        onSecondaryContainer: look.ink,
        primaryContainer: Color.alphaBlend(
          look.control.withValues(alpha: look.night ? .30 : .16),
          look.surface,
        ),
        onPrimaryContainer: look.ink,
        surfaceContainerLowest: look.surface,
        surfaceContainerLow: look.surface,
        surfaceContainer: look.row,
        surfaceContainerHigh: look.row,
        surfaceContainerHighest: Color.alphaBlend(
          look.ink.withValues(alpha: .06),
          look.surface,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: look.control,
        linearTrackColor: look.line,
        circularTrackColor: look.line,
      ),
      sliderTheme: dressed.sliderTheme.copyWith(
        activeTrackColor: look.control,
        thumbColor: look.control,
        inactiveTrackColor: look.line,
      ),
      extensions: [
        look,
        if (tokens != null)
          tokens.copyWith(colors: lookModeTokens(look, tokens.colors)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) =>
      Theme(data: LookTheme.of(Theme.of(context)), child: child);
}
