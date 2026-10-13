import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/theme/interface_style.dart';
import '../../core/theme/ornaments.dart';
import '../../core/ui/look_kit.dart';
import '../../l10n/app_localizations.dart';
import 'settings_catalog.dart';

export 'settings_widgets.dart'
    show InterfaceStylePicker, LightModePicker, appVersionProvider;

/// The settings: a search over every setting, then eight ornamented
/// tiles (two columns on a phone, four on a wide window), each opening its
/// own section.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final query = _query.text.trim();
    return LookScaffold(
      selected: RailItem.settings,
      body: SafeArea(
        child: Column(
          children: [
            LookTopBar(title: l.settingsTitle),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        sliver: SliverToBoxAdapter(
                          child: TextField(
                            key: const ValueKey('settings-search'),
                            controller: _query,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: l.settingsSearchHint,
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: MaterialLocalizations.of(context)
                                          .deleteButtonTooltip,
                                      icon: const Icon(Icons.close),
                                      onPressed: _query.clear,
                                    ),
                              filled: true,
                              fillColor: look.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  look.radius,
                                ),
                                borderSide: BorderSide(color: look.line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  look.radius,
                                ),
                                borderSide: BorderSide(color: look.line),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (query.isEmpty)
                        const _Grid()
                      else
                        _Results(query: query),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final hits = searchSettings(query);
    if (hits.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(32),
        sliver: SliverToBoxAdapter(
          child: Semantics(
            liveRegion: true,
            child: Text(
              l.settingsSearchEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(color: look.sub),
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      sliver: SliverList.list(
        children: [
          for (final (section, e) in hits)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                key: ValueKey('settings-hit.${e.id}'),
                leading: Icon(section.icon, color: look.goldText),
                title: Text(e.title(l)),
                subtitle: Text(
                  section.title(l),
                  style: TextStyle(color: look.sub),
                ),
                trailing: Icon(Icons.chevron_right, color: look.sub),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  if (e.link case final link?) {
                    context.push(link);
                  } else {
                    context.go('${section.location}?focus=${e.id}');
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  const _Grid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elderly = ref.watch(settingsProvider.select((s) => s.elderlyMode));
    final wide = isWide(context);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: wide ? 4 : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: elderly ? 196 : 156,
        ),
        delegate: SliverChildListDelegate([
          for (final s in SettingsSection.values)
            _Tile(section: s, elderly: elderly),
        ]),
      ),
    );
  }
}

/// A large tile: the section's emblem in the style's medallion, a corner
/// ornament, its name and what it holds.
class _Tile extends StatelessWidget {
  const _Tile({required this.section, required this.elderly});

  final SettingsSection section;
  final bool elderly;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final radius = BorderRadius.circular(look.radius);
    final Widget emblem = switch (look.style) {
      InterfaceStyle.makhtuta => SizedBox.square(
        dimension: 48,
        child: CustomPaint(
          painter: StarPainter(look.frame, look.gold),
          child: Icon(section.icon, size: 22, color: look.onFrame),
        ),
      ),
      InterfaceStyle.handasi => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: look.control,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(section.icon, size: 24, color: look.onControl),
      ),
      InterfaceStyle.layli => SizedBox(
        width: 40,
        height: 50,
        child: CustomPaint(
          painter: ArchBorder(look.gold, spring: .5, inset: 2),
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Icon(section.icon, size: 22, color: look.goldText),
          ),
        ),
      ),
    };
    final ornament = switch (look.style) {
      InterfaceStyle.makhtuta => StarPainter(
        look.gold.withValues(alpha: .08),
        look.gold.withValues(alpha: .35),
      ),
      InterfaceStyle.handasi => GirihPainter(
        look.accent.withValues(alpha: look.night ? .22 : .16),
        cell: 26,
      ),
      InterfaceStyle.layli => StarPainter(
        Colors.transparent,
        look.gold.withValues(alpha: .35),
      ),
    };
    return Semantics(
      button: true,
      label: '${section.title(l)}، ${section.hint(l)}',
      excludeSemantics: true,
      onTap: () => context.go(section.location),
      child: Material(
        color: look.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: look.isMakhtuta ? look.gold : look.line,
            width: look.isMakhtuta ? 1.4 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('settings-tile.${section.name}'),
          onTap: () => context.go(section.location),
          child: Stack(
            children: [
              PositionedDirectional(
                top: -26,
                end: -26,
                width: 96,
                height: 96,
                child: ExcludeSemantics(
                  // The pattern fades out from the corner.
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => const RadialGradient(
                      colors: [Colors.white, Colors.transparent],
                      stops: [.45, 1],
                    ).createShader(rect),
                    child: ClipRect(child: CustomPaint(painter: ornament)),
                  ),
                ),
              ),
              if (look.isMakhtuta)
                const PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: 0,
                  child: ExcludeSemantics(child: TazhibBand(height: 6)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    emblem,
                    const Spacer(),
                    Text(
                      section.title(l),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: arabic ? look.headFont : null,
                        fontWeight: arabic && look.headFont != null
                            ? null
                            : FontWeight.w700,
                        fontSize:
                            (elderly ? 20 : 16) +
                            (arabic && look.headFont != null ? 2 : 0),
                        height: 1.25,
                        color: look.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      section.hint(l),
                      maxLines: elderly ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: elderly ? 14 : 12,
                        height: 1.35,
                        color: look.sub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
