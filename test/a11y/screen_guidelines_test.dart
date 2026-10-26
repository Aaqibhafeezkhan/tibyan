import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/features/audio/audio_downloads_screen.dart';
import 'package:tibyan/features/group_khatma/presentation/group_khatma_list_screen.dart';
import 'package:tibyan/features/hifz/presentation/hifz_map_screen.dart';
import 'package:tibyan/features/hifz/presentation/hifz_screen.dart';
import 'package:tibyan/features/khatma/presentation/khatma_screen.dart';
import 'package:tibyan/features/mushaf/presentation/downloads_center_screen.dart';
import 'package:tibyan/features/mushaf/presentation/index_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_edition_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_language_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_page_turn_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_style_screen.dart';
import 'package:tibyan/features/settings/player_settings_screen.dart';
import 'package:tibyan/features/share_image/share_preview_screen.dart';
import 'package:tibyan/features/tafsir/tafsir_screen.dart';
import 'package:tibyan/features/tasbih/presentation/tasbih_screen.dart';
import 'package:tibyan/features/tasmee/presentation/tasmee_setup_screen.dart';

import '../tasmee/tasmee_test_env.dart';

/// TalkBack / VoiceOver audit, screen by screen: every control has a
/// label and a large enough target, and text is readable, in the light
/// and dark modes; at twice the text size nothing overflows.
void main() {
  late TasmeeTestData data;
  setUpAll(() => data = TasmeeTestData.open());
  tearDownAll(() => data.close());

  final screens = <String, Widget Function()>{
    'tasbih': () => const TasbihScreen(),
    'tafsir': () => const TafsirScreen(surah: 1, ayah: 1),
    'khatma': () => const KhatmaScreen(),
    'group khatma': () => const GroupKhatmaListScreen(),
    'hifz': () => const HifzScreen(),
    'hifz map': () => const HifzMapScreen(),
    'tasmee setup': () => const TasmeeSetupScreen(),
    'downloads': () => const DownloadsCenterScreen(),
    'audio downloads': () => const AudioDownloadsScreen(),
    'player settings': () => const PlayerSettingsScreen(),
    'index': () => const IndexScreen(),
    'share': () => const SharePreviewScreen(range: [(surah: 1, ayah: 1)]),
    'onboarding language': () => const OnboardingLanguageScreen(),
    'onboarding style': () => const OnboardingStyleScreen(),
    'onboarding edition': () => const OnboardingEditionScreen(),
    'onboarding page turn': () => const OnboardingPageTurnScreen(),
  };

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    ThemeModeId mode = ThemeModeId.light,
    InterfaceStyle look = defaultInterfaceStyle,
    double scale = 1,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => data.root.path,
    );
    tester.view
      ..physicalSize = const Size(430, 932)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await tasmeeContainer(tester, data);
    await tester.pumpWidget(
      tasmeeApp(
        container,
        MediaQuery.withClampedTextScaling(
          minScaleFactor: scale,
          maxScaleFactor: scale,
          child: LookTheme(child: screen),
        ),
        theme: tasmeeTheme(container, mode: mode, interfaceStyle: look),
      ),
    );
    await settle(tester);
  }

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    for (final look in InterfaceStyle.values) {
      for (final mode in ThemeModeId.values) {
        testWidgets('$name (${look.name}, ${mode.name}): labelled, large, '
            'readable', (tester) async {
          final handle = tester.ensureSemantics();
          await pump(tester, screen(), mode: mode, look: look);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.pumpWidget(const SizedBox());
          handle.dispose();
        });
      }
      testWidgets('$name (${look.name}): no overflow at 200% text', (
        tester,
      ) async {
        await pump(tester, screen(), look: look, scale: 2);
        final error = tester.takeException();
        expect(
          error,
          isNull,
          reason: error is FlutterError ? error.toStringDeep() : '$error',
        );
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
