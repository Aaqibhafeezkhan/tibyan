import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ui/responsive.dart';
import 'core/router/app_router.dart';
import 'core/router/keyboard_dismiss.dart';
import 'core/settings/settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/mac_menu.dart';
import 'features/audio/global_player.dart';
import 'l10n/app_localizations.dart';

class TibyanApp extends ConsumerWidget {
  const TibyanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final registry = ref.watch(themeRegistryProvider);
    final style = registry.byId(settings.styleId);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final mode = settings.resolveMode(platformBrightness);

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      scrollBehavior: const AppScrollBehavior(),
      // A tap outside a text field closes the keyboard.
      actions: {...WidgetsApp.defaultActions, ...tapOutsideActions()},
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(
        style: style,
        mode: mode,
        uiFont: settings.uiFont,
        elderly: settings.elderlyMode,
        interfaceStyle: settings.interfaceStyle,
      ),
      // The player on every screen while a recitation plays; elderly
      // mode: text at least a quarter larger, whatever the device asks for
      // (a larger system size is kept).
      builder: (context, child) {
        final player = MacMenu(
          router: router,
          child: GlobalPlayer(router: router, child: child!),
        );
        if (!settings.elderlyMode) return player;
        final mq = MediaQuery.of(context);
        final scale = mq.textScaler.scale(1);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(
              scale < elderlyTextScale ? elderlyTextScale : scale,
            ),
          ),
          child: player,
        );
      },
    );
  }
}
