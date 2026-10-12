import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assistant/assistant_screen.dart';
import '../../features/assistant/tajweed_marks_screen.dart';
import '../../features/hifz/presentation/hifz_map_screen.dart';
import '../../features/khatma/domain/khatmah.dart' show EntryPoint, enumNamed;
import '../../features/hifz/presentation/hifz_screen.dart';
import '../../features/hifz/presentation/progress_tabs.dart'
    show RecitationSessionScreen;
import '../../features/audio/audio_downloads_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/khatma/presentation/journal_screen.dart';
import '../../features/khatma/presentation/khatma_screen.dart';
import '../../features/khatma/presentation/new_khatma_screen.dart';
import '../../features/khatma/presentation/reports_screen.dart';
import '../../features/mushaf/presentation/about_mushaf_screen.dart';
import '../../features/mushaf/presentation/download_all_screen.dart';
import '../../features/mushaf/presentation/download_screen.dart';
import '../../features/mushaf/presentation/fawasil_screen.dart';
import '../../features/mushaf/presentation/index_screen.dart';
import '../../features/mushaf/data/tajweed.dart';
import '../../features/mushaf/presentation/mushaf_screen.dart';
import '../../features/onboarding/onboarding_edition_screen.dart';
import '../../features/onboarding/onboarding_language_screen.dart';
import '../../features/onboarding/onboarding_style_screen.dart';
import '../../features/settings/player_settings_screen.dart';
import '../../features/settings/settings_catalog.dart';
import '../../features/settings/settings_section_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/tafsir/tafsir_screen.dart';
import '../../features/reading/continuous_screen.dart';
import '../../features/reading/one_verse_screen.dart';
import '../../features/tasmee/domain/tasmee_session_request.dart';
import '../../features/tasmee/presentation/tasmee_session_screen.dart';
import '../../features/tasmee/presentation/tasmee_settings_screen.dart';
import '../../features/tasmee/presentation/tasmee_setup_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/storage_screen.dart';
import '../settings/app_settings.dart';
import '../ui/look_kit.dart';
import '../settings/settings_controller.dart';
import 'cover_observer.dart';
import 'keyboard_dismiss.dart';

final appRouterReadyProvider = Provider<Completer<void>>(
  (ref) => Completer<void>(),
);

void markAppRouterReady(Completer<void> ready) {
  if (!ready.isCompleted) ready.complete();
}

int? _int(GoRouterState s, String key) =>
    int.tryParse(s.uri.queryParameters[key] ?? '');

final appRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: '/splash',
    // A screen left or returned to never keeps the keyboard up.
    observers: [KeyboardDismissObserver(), coverObserver],
    // First launch: language, then style and colours, then the edition.
    redirect: (context, state) {
      final done = ref.read(settingsProvider).onboardingDone;
      if (state.matchedLocation == '/splash') return null;
      final inOnboarding = state.matchedLocation.startsWith('/onboarding');
      // «Download all» is offered on the edition step too.
      final downloads = state.matchedLocation == '/downloads';
      if (!done && !inOnboarding && !downloads) return '/onboarding/language';
      return null;
    },
    routes: [
      GoRoute(
        path: '/downloads',
        builder: (context, state) =>
            const LookTheme(child: DownloadAllScreen()),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const LookTheme(child: SplashScreen()),
      ),
      GoRoute(
        path: '/tasmee',
        builder: (context, state) =>
            const LookTheme(child: TasmeeSetupScreen()),
        routes: [
          GoRoute(
            path: 'session',
            builder: (context, state) {
              final request = state.extra;
              return request is TasmeeSessionRequest
                  ? TasmeeSessionScreen(request: request)
                  : const TasmeeSetupScreen();
            },
          ),
        ],
      ),
      GoRoute(
        path: '/onboarding/language',
        builder: (context, state) =>
            const LookTheme(child: OnboardingLanguageScreen()),
      ),
      GoRoute(
        path: '/onboarding/style',
        builder: (context, state) =>
            const LookTheme(child: OnboardingStyleScreen()),
      ),
      GoRoute(
        path: '/onboarding/edition',
        builder: (context, state) =>
            const LookTheme(child: OnboardingEditionScreen()),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'search',
            builder: (context, state) => const LookTheme(child: SearchScreen()),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              // Each tile of the settings grid; `focus=` scrolls to one
              // setting and lights it (from the settings search).
              GoRoute(
                path: 'section/:id',
                builder: (context, state) => LookTheme(
                  child: SettingsSectionScreen(
                    section:
                        SettingsSection.values
                            .asNameMap()[state.pathParameters['id']] ??
                        SettingsSection.appearance,
                    focus: state.uri.queryParameters['focus'],
                  ),
                ),
              ),
              // The old «شكل المصحف» screen now lives in the mushaf tile.
              GoRoute(
                path: 'appearance',
                redirect: (context, state) => '/settings/section/mushaf',
              ),
              GoRoute(
                path: 'storage',
                builder: (context, state) =>
                    const LookTheme(child: StorageScreen()),
              ),
              GoRoute(
                path: 'player',
                builder: (context, state) =>
                    const LookTheme(child: PlayerSettingsScreen()),
              ),
              GoRoute(
                path: 'tasmee',
                builder: (context, state) =>
                    const LookTheme(child: TasmeeSettingsScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/hifz',
        builder: (context, state) => LookTheme(
          child: HifzScreen(
            tab:
                HifzTab.values.asNameMap()[state.uri.queryParameters['tab']] ??
                HifzTab.today,
          ),
        ),
        routes: [
          GoRoute(
            path: 'map',
            builder: (context, state) =>
                const LookTheme(child: HifzMapScreen()),
          ),
          GoRoute(
            path: 'session/:uuid',
            builder: (context, state) => LookTheme(
              child: RecitationSessionScreen(
                uuid: state.pathParameters['uuid']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/khatma',
        builder: (context, state) => LookTheme(
          child: KhatmaScreen(
            selectedPlanId: state.uri.queryParameters['plan'],
          ),
        ),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) =>
                const LookTheme(child: NewKhatmaScreen()),
          ),
          GoRoute(
            path: 'reports',
            builder: (context, state) =>
                const LookTheme(child: ReportsScreen()),
          ),
          GoRoute(
            path: 'journal',
            builder: (context, state) =>
                const LookTheme(child: JournalScreen()),
          ),
        ],
      ),
      // The reader's helpers, one card each; the first is the tajweed
      // marks (the rules, their colours and places).
      GoRoute(
        path: assistantLocation,
        builder: (context, state) => const LookTheme(child: AssistantScreen()),
        routes: [
          GoRoute(
            path: 'tajweed',
            builder: (context, state) =>
                const LookTheme(child: TajweedMarksScreen()),
            routes: [
              GoRoute(
                path: 'rule',
                builder: (context, state) => LookTheme(
                  child: TajweedRuleScreen(
                    rule:
                        TajweedRule.byKey(
                          state.uri.queryParameters['rule'] ?? '',
                        ) ??
                        TajweedRule.madd6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/verse',
        builder: (context, state) => LookTheme(
          child: OneVerseScreen(
            surah: _int(state, 's') ?? 1,
            ayah: _int(state, 'a') ?? 1,
            entry:
                enumNamed(
                  EntryPoint.values,
                  state.uri.queryParameters['entry'],
                ) ??
                EntryPoint.other,
          ),
        ),
      ),
      GoRoute(
        path: '/read',
        builder: (context, state) => LookTheme(
          child: ContinuousScreen(
            key: ValueKey(state.uri.toString()),
            surah: _int(state, 's') ?? 1,
            ayah: _int(state, 'a') ?? 1,
            entry:
                enumNamed(
                  EntryPoint.values,
                  state.uri.queryParameters['entry'],
                ) ??
                EntryPoint.other,
          ),
        ),
      ),
      GoRoute(
        path: '/mushaf',
        builder: (context, state) => MushafScreen(
          key: ValueKey(state.uri.toString()),
          initialPage: _int(state, 'page'),
          selectSurah: _int(state, 's'),
          selectAyah: _int(state, 'a'),
          hifzUnit: state.uri.queryParameters['hifz'],
          hifzFrom: state.uri.queryParameters['from'],
          hifzTo: state.uri.queryParameters['to'],
          listen: state.uri.queryParameters['listen'] == '1',
          // `entry=`: where the reading was opened from (the reading
          // tracker counts only past the landing page for some).
          entry:
              enumNamed(
                EntryPoint.values,
                state.uri.queryParameters['entry'],
              ) ??
              EntryPoint.other,
        ),
        routes: [
          GoRoute(
            path: 'download',
            builder: (context, state) =>
                const LookTheme(child: DownloadScreen()),
          ),
          GoRoute(
            path: 'index',
            builder: (context, state) => IndexScreen(
              tab:
                  IndexTab.values
                      .asNameMap()[state.uri.queryParameters['tab']] ??
                  IndexTab.surahs,
              surah: _int(state, 's'),
              juz: _int(state, 'j'),
              hizb: _int(state, 'h'),
              page: _int(state, 'p'),
            ),
          ),
          GoRoute(
            path: 'fawasil',
            builder: (context, state) =>
                const LookTheme(child: FawasilScreen()),
          ),
          GoRoute(
            path: 'tafsir',
            builder: (context, state) => LookTheme(
              child: TafsirScreen(
                surah: _int(state, 's') ?? 1,
                ayah: _int(state, 'a') ?? 1,
                riwaya: Riwaya.values
                    .asNameMap()[state.uri.queryParameters['r']],
                riwayaAyah: _int(state, 'ra'),
              ),
            ),
          ),
          GoRoute(
            path: 'audio',
            builder: (context, state) =>
                const LookTheme(child: AudioDownloadsScreen()),
          ),
          GoRoute(
            path: 'about',
            builder: (context, state) =>
                const LookTheme(child: AboutMushafScreen()),
          ),
        ],
      ),
    ],
  ),
);
