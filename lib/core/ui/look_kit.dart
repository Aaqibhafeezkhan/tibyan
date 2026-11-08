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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/mushaf/mushaf_providers.dart'
    show readingPositionProvider;
import '../../features/tasbih/presentation/tasbih_screen.dart'
    show tasbihIcon, tasbihLocation;
import '../../features/tasmee/presentation/tasmee_setup_screen.dart'
    show showTasmeeSetup;
import '../settings/settings_controller.dart' show sharedPreferencesProvider;
import 'responsive.dart';

/// From this width, screens get the full side rail and two columns.
const wideBreakpoint = Breakpoints.expanded;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= wideBreakpoint;

/// The «تبيان» calligraphy (assets/brand/tibyan_logo.svg, traced from the
/// logo artwork), tinted in [color] (the style's gold text by default).
/// The app's name is never re-typeset in a font: wherever «تبيان» stands
/// as the brand, this widget draws it.
class TibyanWordmark extends StatelessWidget {
  const TibyanWordmark({super.key, this.color, this.height = 40});

  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    label: AppLocalizations.of(context).appTitle,
    child: ExcludeSemantics(
      child: SvgPicture.asset(
        'assets/brand/tibyan_logo.svg',
        height: height,
        colorFilter: ColorFilter.mode(
          color ?? context.look.goldText,
          BlendMode.srcIn,
        ),
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

/// The colours of the home screen's hero arch («هندسي», «ليلي ذهبي»): its
/// sky, rim, texts and button. Shared with the home screen widgets.
typedef HeroArchColors = ({
  List<Color> sky,
  Color rim,
  Color ink,
  Color sub,
  Color buttonBg,
  Color buttonFg,
});

HeroArchColors heroArchColors(UiLook look) {
  final layli = look.isLayli;
  return (
    sky: layli
        ? (look.night
              ? [const Color(0xFF1B2D50), look.surface]
              : [look.frame, Color.lerp(look.frame, Colors.white, .12)!])
        : (look.night
              ? [const Color(0xFF17403E), look.surface]
              : [look.accent, Color.lerp(look.accent, Colors.black, .25)!]),
    rim: layli
        ? (look.night ? look.gold : look.onFrame)
        : (look.night ? look.accent : look.gold.withValues(alpha: .9)),
    ink: layli ? const Color(0xFFF3E2B4) : const Color(0xFFFFFCF6),
    sub: layli ? const Color(0xFFD3D8E3) : const Color(0xFFDCEBE8),
    buttonBg: layli
        ? (look.night ? look.gold : look.onFrame)
        : (look.night ? look.accent : const Color(0xFFFFFCF6)),
    buttonFg: layli ? look.frame : (look.night ? look.bg : look.accent),
  );
}

/// The hero arch's ground: a pointed arch filled with the look's sky (a
/// star lattice for «هندسي», a night sky for «ليلي ذهبي») and its rim.
class HeroArch extends StatelessWidget {
  const HeroArch({super.key, this.spring = .34, this.inset = 7});

  final double spring, inset;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final c = heroArchColors(look);
    return ExcludeSemantics(
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: ArchClipper(spring: spring),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: c.sky,
                  ),
                ),
                child: CustomPaint(
                  painter: look.isLayli
                      ? SkyPainter(const Color(0xFFE6C47A))
                      : GirihPainter(
                          Colors.white.withValues(alpha: .10),
                          cell: 46,
                        ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: ArchBorder(c.rim, spring: spring, inset: inset),
            ),
          ),
        ],
      ),
    );
  }
}

/// A home section's icon in the look: a star medallion (مخطوطة), a tile
/// (هندسي) or an arch (ليلي ذهبي). [k] scales it (62 wide at 1).
class SectionIcon extends StatelessWidget {
  const SectionIcon(this.icon, {super.key, this.k = 1});

  final IconData icon;
  final double k;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final glyph = 24 * k;
    return switch (look.style) {
      InterfaceStyle.makhtuta => SizedBox.square(
        dimension: 62 * k,
        child: CustomPaint(
          painter: StarPainter(look.surface, look.gold),
          child: Icon(icon, color: look.accent, size: glyph),
        ),
      ),
      InterfaceStyle.handasi => Container(
        width: 62 * k,
        height: 62 * k,
        decoration: BoxDecoration(
          color: look.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: look.line),
        ),
        child: CustomPaint(
          painter: StarPainter(
            look.accent.withValues(alpha: .10),
            Colors.transparent,
          ),
          child: Icon(icon, color: look.accent, size: glyph),
        ),
      ),
      InterfaceStyle.layli => SizedBox(
        width: 64 * k,
        height: 78 * k,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipPath(
                clipper: const ArchClipper(spring: .5),
                child: ColoredBox(color: look.surface),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: ArchBorder(
                  look.gold.withValues(alpha: .8),
                  spring: .5,
                  inset: 4,
                ),
              ),
            ),
            Positioned.fill(
              top: 20 * k,
              child: Icon(icon, color: look.goldText, size: glyph),
            ),
          ],
        ),
      ),
    };
  }
}

/// A destination of the wide-window sidebar, in its order.
enum RailItem {
  home,
  mushaf,
  contents,
  tafsir,
  search,
  listen,
  tasmee,
  khatma,
  hifz,
  tasbih,
  settings,
}

/// The icon of each destination: the home's section tiles use the same.
IconData railIcon(RailItem item) => switch (item) {
  RailItem.home => Icons.home_outlined,
  RailItem.mushaf => Icons.menu_book_outlined,
  RailItem.contents => Icons.list_alt,
  RailItem.tafsir => Icons.auto_stories_outlined,
  RailItem.search => Icons.search,
  RailItem.listen => Icons.headphones_outlined,
  RailItem.tasmee => Icons.graphic_eq,
  RailItem.khatma => Icons.flag_outlined,
  RailItem.hifz => Icons.task_alt_outlined,
  RailItem.tasbih => tasbihIcon,
  RailItem.settings => Icons.tune,
};

String railLabel(AppLocalizations s, RailItem item) => switch (item) {
  RailItem.home => s.navHome,
  RailItem.mushaf => s.sectionMushaf,
  RailItem.contents => s.indexTitle,
  RailItem.tafsir => s.sectionTafsir,
  RailItem.search => s.sectionSearch,
  RailItem.listen => s.sectionListen,
  RailItem.tasmee => s.tasmeeTileLabel,
  RailItem.khatma => s.sectionKhatma,
  RailItem.hifz => s.sectionHifz,
  RailItem.tasbih => s.sectionTasbih,
  RailItem.settings => s.settingsTitle,
};

/// Opens [item] the way the home's section tile does.
void openRailItem(BuildContext context, RailItem item) {
  switch (item) {
    case RailItem.home:
      context.go('/');
    case RailItem.mushaf:
      // The reading, where it was left: like «تابع القراءة» on the home.
      context.go('/mushaf?entry=home');
    case RailItem.contents:
      context.go('/mushaf/index');
    case RailItem.tafsir:
      final at = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(readingPositionProvider).value;
      context.push('/mushaf/tafsir?s=${at?.surah ?? 1}&a=${at?.ayah ?? 1}');
    case RailItem.search:
      context.go('/search');
    case RailItem.listen:
      context.push('/mushaf/audio');
    case RailItem.tasmee:
      showTasmeeSetup(context);
    case RailItem.khatma:
      context.push('/khatma');
    case RailItem.hifz:
      context.push('/hifz');
    case RailItem.tasbih:
      context.push(tasbihLocation);
    case RailItem.settings:
      context.go('/settings');
  }
}

/// The destination a route belongs to, for screens that name none.
RailItem? railItemFor(String path) {
  if (path == '/') return RailItem.home;
  const prefixes = [
    ('/mushaf/index', RailItem.contents),
    ('/mushaf/tafsir', RailItem.tafsir),
    ('/mushaf/audio', RailItem.listen),
    ('/search', RailItem.search),
    ('/tasmee', RailItem.tasmee),
    ('/khatma', RailItem.khatma),
    ('/hifz', RailItem.hifz),
    ('/tasbih', RailItem.tasbih),
    ('/settings', RailItem.settings),
  ];
  for (final (prefix, item) in prefixes) {
    if (path.startsWith(prefix)) return item;
  }
  return null;
}

const _sidebarCollapsedKey = 'ui.sidebarCollapsed';

/// Whether the user folded the sidebar to icons; remembered.
final sidebarCollapsedProvider = NotifierProvider<SidebarCollapsed, bool>(
  SidebarCollapsed.new,
);

class SidebarCollapsed extends Notifier<bool> {
  SharedPreferences? get _prefs {
    try {
      return ref.read(sharedPreferencesProvider);
    } catch (_) {
      return null; // no preferences in this scope (a bare widget test)
    }
  }

  @override
  bool build() => _prefs?.getBool(_sidebarCollapsedKey) ?? false;

  void toggle() {
    state = !state;
    _prefs?.setBool(_sidebarCollapsedKey, state);
  }
}

/// From this width the sidebar may show its labels (if not folded);
/// narrower windows get icons only.
const sidebarLabelsBreakpoint = 1100.0;

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
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
    this.maxWidth = ContentWidth.wide,
  });

  /// How wide the screen's content may grow on a big window before it is
  /// centred (the ground pattern still fills the window). Infinity for a
  /// screen that lays itself out across any width.
  final double maxWidth;

  final Widget body;
  final RailItem? selected;
  final bool hero;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;

  /// Show the side rail on wide windows.
  final bool rail;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final content = Stack(
      children: [
        Positioned.fill(child: LookBackground(hero: hero)),
        if (maxWidth.isFinite)
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: body,
            ),
          )
        else
          body,
      ],
    );
    return Theme(
      data: look.screens(Theme.of(context)),
      child: Scaffold(
        backgroundColor: look.bg,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        // The rail follows the room the screen really has.
        body: !rail
            ? content
            : LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth;
                  final show =
                      w >= wideBreakpoint ||
                      (w >= Breakpoints.medium &&
                          (isDesktopPlatform ||
                              box.biggest.shortestSide >= Breakpoints.medium));
                  if (!show) return content;
                  final roomy = w >= sidebarLabelsBreakpoint;
                  return Consumer(
                    builder: (context, ref, _) {
                      final folded =
                          !roomy || ref.watch(sidebarCollapsedProvider);
                      final railWidth = folded
                          ? _Rail.compactWidth
                          : _Rail.fullWidth;
                      final mq = MediaQuery.of(context);
                      return Row(
                        children: [
                          _Rail(
                            selected: selected ?? _currentItem(context),
                            compact: folded,
                            onToggle: roomy
                                ? ref
                                      .read(sidebarCollapsedProvider.notifier)
                                      .toggle
                                : null,
                          ),
                          // Layouts that size themselves from the window
                          // see the room beside the sidebar.
                          Expanded(
                            child: MediaQuery(
                              data: mq.copyWith(
                                size: Size(w - railWidth, box.maxHeight),
                              ),
                              child: content,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

RailItem? _currentItem(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return null;
  return railItemFor(router.routeInformationProvider.value.uri.path);
}

class _Rail extends StatelessWidget {
  const _Rail({this.selected, this.compact = false, this.onToggle});

  final RailItem? selected;

  /// Icons only (folded, or a narrow window).
  final bool compact;

  /// Folds or unfolds the sidebar; null when the window is too narrow
  /// for labels.
  final VoidCallback? onToggle;

  static const compactWidth = 80.0;
  static const fullWidth = 248.0;

  @override
  Widget build(BuildContext context) {
    final l = context.look;
    final s = AppLocalizations.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final radius = BorderRadius.circular(l.isMakhtuta ? 4 : 12);

    Widget tile(RailItem item) {
      final label = railLabel(s, item);
      final on = item == selected;
      final icon = railIcon(item);
      return Padding(
        key: ValueKey('rail-${item.name}'),
        padding: const EdgeInsets.only(bottom: 4),
        child: Semantics(
          selected: on,
          button: true,
          label: compact ? label : null,
          child: Tooltip(
            message: compact ? label : '',
            child: Material(
              color: on ? l.onFrame.withValues(alpha: .14) : Colors.transparent,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: on ? null : () => openRailItem(context, item),
                child: SizedBox(
                  // Elderly mode keeps every tap target at 56 or more.
                  height: compact ? 56 : (l.elderly ? 56 : 46),
                  child: compact
                      ? Icon(icon, color: l.onFrame, size: 24)
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Icon(icon, color: l.onFrame, size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: l.onFrame,
                                    fontWeight: on
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
      );
    }

    Widget heading(String text) => compact
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Divider(height: 1, color: l.onFrame.withValues(alpha: .25)),
          )
        : Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 6),
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: arabic ? l.headFont : null,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: arabic ? 0 : .6,
                  color: l.isLayli ? l.gold : l.onFrame.withValues(alpha: .72),
                ),
              ),
            ),
          );

    final groups = [
      (
        s.navGroupReading,
        [RailItem.mushaf, RailItem.contents, RailItem.tafsir, RailItem.search],
      ),
      (s.navGroupListening, [RailItem.listen, RailItem.tasmee]),
      (s.navGroupWird, [RailItem.khatma, RailItem.hifz, RailItem.tasbih]),
    ];

    final toggle = onToggle == null
        ? null
        : IconButton(
            key: const ValueKey('rail-toggle'),
            tooltip: compact ? s.navExpand : s.navCollapse,
            onPressed: onToggle,
            color: l.onFrame,
            // Points into the window when folded, out of it when open
            // (mirrored in Arabic).
            icon: Icon(
              compact
                  ? Icons.keyboard_double_arrow_right
                  : Icons.keyboard_double_arrow_left,
            ),
          );

    return Container(
      width: compact ? compactWidth : fullWidth,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A short window has less height than every destination:
                // the list scrolls, settings stay pinned below it.
                Expanded(
                  child: SingleChildScrollView(
                    padding: compact
                        ? const EdgeInsets.fromLTRB(12, 20, 12, 8)
                        : const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: TibyanWordmark(
                            color: l.onFrame,
                            height: compact ? 32 : 56,
                          ),
                        ),
                        SizedBox(height: compact ? 16 : 20),
                        tile(RailItem.home),
                        for (final (title, items) in groups) ...[
                          heading(title),
                          for (final item in items) tile(item),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: compact
                      ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
                      : const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(
                        height: 12,
                        color: l.onFrame.withValues(alpha: .25),
                      ),
                      // Open: the fold arrow sits on the settings row.
                      // Folded: no room beside the icon, so it goes below.
                      if (toggle != null && !compact)
                        Row(
                          children: [
                            Expanded(child: tile(RailItem.settings)),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: toggle,
                            ),
                          ],
                        )
                      else ...[
                        tile(RailItem.settings),
                        if (toggle != null) Center(child: toggle),
                      ],
                    ],
                  ),
                ),
              ],
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
    this.title = '',
    this.titleWidget,
    this.leading,
    this.actions = const [],
    this.back = true,
  });

  final String title;

  /// In place of [title], for a title that is more than words.
  final Widget? titleWidget;

  /// In place of the back button (a wizard's previous step).
  final Widget? leading;
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
            if (leading != null)
              leading!
            else if (canPop)
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
                child: DefaultTextStyle.merge(
                  style: lookTitleStyle(context),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: Center(child: titleWidget ?? Text(title)),
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
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: arabic ? 'ArefRuqaa' : null,
                  fontWeight: arabic ? null : FontWeight.w700,
                  fontSize: arabic ? 19 : 16,
                  color: l.onFrame,
                ),
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
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: arabic ? l.headFont : null,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: l.ink,
                ),
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
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: arabic ? 'ArefRuqaa' : null,
                  fontWeight: arabic ? null : FontWeight.w700,
                  fontSize: arabic ? 21 : 17,
                  color: l.goldText,
                ),
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
