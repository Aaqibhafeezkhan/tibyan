// The macOS menu bar: the app's own menus beside the system's, so the
// main places and the recitation are a menu or a shortcut away, as in any
// Mac app.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assistant/assistant_screen.dart' show assistantLocation;
import '../../features/audio/recitation.dart';
import '../../l10n/app_localizations.dart';
import 'responsive.dart';

class MacMenu extends ConsumerStatefulWidget {
  const MacMenu({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<MacMenu> createState() => _MacMenuState();
}

class _MacMenuState extends ConsumerState<MacMenu> {
  // Sent to macOS once per language: sending the menus again (on every
  // verse, every navigation) closes a menu the reader has open. So the
  // items never change while the app runs; each reads the recitation's
  // state when chosen.
  static const _native = MethodChannel('app.tibyan/widget');
  List<PlatformMenuItem>? _menus;
  String? _lang;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopPlatform || defaultTargetPlatform != TargetPlatform.macOS) {
      return widget.child;
    }
    final l = AppLocalizations.of(context);
    if (_menus == null || _lang != l.localeName) {
      _lang = l.localeName;
      _menus = _build(l);
      // macOS names the app (the bold first menu) in the language it is
      // told, from the next launch: «التبيان» in Arabic.
      _native
          .invokeMethod<void>('appLanguage', l.localeName)
          .catchError((_) {});
    }
    return PlatformMenuBar(menus: _menus!, child: widget.child);
  }

  List<PlatformMenuItem> _build(AppLocalizations l) {
    final router = widget.router;
    RecitationState s() => ref.read(recitationProvider);
    RecitationController c() => ref.read(recitationProvider.notifier);
    void go(String to) => router.go(to);
    void push(String to) => router.push(to);
    PlatformMenuItem item(
      String label,
      VoidCallback? onSelected, [
      MenuSerializableShortcut? shortcut,
    ]) => PlatformMenuItem(
      label: label,
      onSelected: onSelected,
      shortcut: shortcut,
    );
    bool provided(PlatformProvidedMenuItemType t) =>
        PlatformProvidedMenuItem.hasMenu(t);
    PlatformProvidedMenuItem? system(PlatformProvidedMenuItemType t) =>
        provided(t) ? PlatformProvidedMenuItem(type: t) : null;

    return [
      PlatformMenu(
        label: l.appTitle,
        menus: [
          PlatformMenuItemGroup(
            members: [item(l.aboutApp, () => push('/mushaf/about'))],
          ),
          PlatformMenuItemGroup(
            members: [
              item(
                '${l.settingsTitle}…',
                () => go('/settings'),
                const SingleActivator(LogicalKeyboardKey.comma, meta: true),
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              for (final t in [PlatformProvidedMenuItemType.servicesSubmenu])
                ?system(t),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              for (final t in [
                PlatformProvidedMenuItemType.hide,
                PlatformProvidedMenuItemType.hideOtherApplications,
                PlatformProvidedMenuItemType.showAllApplications,
              ])
                ?system(t),
            ],
          ),
          PlatformMenuItemGroup(
            members: [?system(PlatformProvidedMenuItemType.quit)],
          ),
        ],
      ),
      PlatformMenu(
        label: l.menuGo,
        menus: [
          PlatformMenuItemGroup(
            members: [
              item(
                l.homeTitle,
                () => go('/'),
                const SingleActivator(LogicalKeyboardKey.digit1, meta: true),
              ),
              item(
                l.sectionMushaf,
                () => go('/mushaf?entry=home'),
                const SingleActivator(LogicalKeyboardKey.digit2, meta: true),
              ),
              item(
                l.indexTitle,
                () => push('/mushaf/index'),
                const SingleActivator(LogicalKeyboardKey.digit3, meta: true),
              ),
              item(
                l.sectionListen,
                () => push('/mushaf/audio'),
                const SingleActivator(LogicalKeyboardKey.digit4, meta: true),
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              item(l.sectionKhatma, () => push('/khatma')),
              item(l.sectionHifz, () => push('/hifz')),
              item(
                l.sectionSearch,
                () => go('/search'),
                const SingleActivator(LogicalKeyboardKey.keyK, meta: true),
              ),
            ],
          ),
        ],
      ),
      PlatformMenu(
        label: l.menuPlayback,
        menus: [
          PlatformMenuItemGroup(
            members: [
              item(
                l.playPause,
                () => s().active ? c().toggle() : null,
                const SingleActivator(LogicalKeyboardKey.enter, meta: true),
              ),
              item(
                l.previousVerse,
                () => s().active && s().timed ? c().step(-1) : null,
                const SingleActivator(
                  LogicalKeyboardKey.arrowLeft,
                  meta: true,
                  alt: true,
                ),
              ),
              item(
                l.nextVerse,
                () => s().active && s().timed ? c().step(1) : null,
                const SingleActivator(
                  LogicalKeyboardKey.arrowRight,
                  meta: true,
                  alt: true,
                ),
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              item(
                l.stopListening,
                () => s().active ? c().stop() : null,
                const SingleActivator(LogicalKeyboardKey.period, meta: true),
              ),
            ],
          ),
        ],
      ),
      PlatformMenu(
        label: l.menuView,
        menus: [?system(PlatformProvidedMenuItemType.toggleFullScreen)],
      ),
      PlatformMenu(
        label: l.menuWindow,
        menus: [
          PlatformMenuItemGroup(
            members: [
              for (final t in [
                PlatformProvidedMenuItemType.minimizeWindow,
                PlatformProvidedMenuItemType.zoomWindow,
              ])
                ?system(t),
            ],
          ),
          ?system(PlatformProvidedMenuItemType.arrangeWindowsInFront),
        ],
      ),
      PlatformMenu(
        label: l.menuHelp,
        menus: [item(l.assistantTitle, () => push(assistantLocation))],
      ),
    ];
  }
}
