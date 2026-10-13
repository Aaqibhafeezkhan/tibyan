import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/features/onboarding/background_downloads.dart';
import 'package:tibyan/features/onboarding/onboarding_tasmee_screen.dart';
import 'package:tibyan/features/tasmee/data/model_manifest.dart';
import 'package:tibyan/features/tasmee/presentation/tasmee_settings_screen.dart'
    show tasmeeModelInfoProvider;
import 'package:tibyan/l10n/app_localizations.dart';

/// First run, step 6: the model step always offers something to do: the
/// download (with its size), a retry when the manifest cannot be fetched,
/// or a clear note when this platform cannot run the check.
void main() {
  final manifest = ModelManifest(
    id: recitationModelId,
    version: '1',
    license: 'CC-BY-4.0',
    files: [
      ModelFileSpec(
        name: 'model.onnx',
        url: Uri.parse('https://example.com/model.onnx'),
        sha256: 'x',
        bytes: 120 * 1024 * 1024,
      ),
    ],
  );

  Future<void> pump(
    WidgetTester tester, {
    required Future<ModelManifest?> Function() fetch,
    bool supported = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final (registry, sp) = (await tester.runAsync(
      () async => (
        await ThemeRegistry.load(rootBundle),
        await SharedPreferences.getInstance(),
      ),
    ))!;
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          themeRegistryProvider.overrideWithValue(registry),
          sharedPreferencesProvider.overrideWithValue(sp),
          tasmeeSupportedProvider.overrideWithValue(supported),
          // As the app's provider: a failed fetch reads as no manifest.
          tasmeeManifestProvider.overrideWith((ref) async {
            try {
              return await fetch();
            } catch (_) {
              return null;
            }
          }),
          tasmeeModelInfoProvider.overrideWith((ref) async => (null, 0)),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(
            style: registry.byId(registry.defaultStyleId),
            mode: ThemeModeId.light,
            uiFont: UiFont.changa,
          ),
          home: const LookTheme(child: OnboardingTasmeeScreen()),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  FilledButton next(WidgetTester tester) => tester.widget<FilledButton>(
    find.byKey(const ValueKey('onboarding-next')),
  );

  testWidgets('with the manifest: size, download, skip and the credits', (
    tester,
  ) async {
    await pump(tester, fetch: () async => manifest);
    expect(find.text('نزّل النموذج'), findsOneWidget);
    expect(next(tester).onPressed, isNotNull);
    expect(find.textContaining('١٢٠'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-skip-step')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-model-sources')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('onboarding-tasmee-retry')), findsNothing);
  });

  testWidgets('manifest fails: the error and a retry that fetches again', (
    tester,
  ) async {
    var calls = 0;
    await pump(
      tester,
      fetch: () async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return manifest;
      },
    );
    expect(find.textContaining('تعذّر جلب معلومات النموذج'), findsOneWidget);
    // The download button is shown but greyed out, never silently a no-op.
    expect(find.text('نزّل النموذج'), findsOneWidget);
    expect(next(tester).onPressed, isNull);
    expect(find.byKey(const ValueKey('onboarding-skip-step')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-tasmee-retry')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(calls, 2);
    expect(find.textContaining('تعذّر جلب معلومات النموذج'), findsNothing);
    expect(next(tester).onPressed, isNotNull);
  });

  testWidgets('a null manifest is a failure too', (tester) async {
    await pump(tester, fetch: () async => null);
    expect(find.byKey(const ValueKey('onboarding-tasmee-retry')), findsOne);
    expect(next(tester).onPressed, isNull);
  });

  testWidgets('unsupported platform: says so and lets the reader start', (
    tester,
  ) async {
    await pump(tester, fetch: () async => manifest, supported: false);
    expect(find.textContaining('غير متاح على هذا الجهاز'), findsOneWidget);
    expect(find.text('ابدأ القراءة'), findsOneWidget);
    expect(next(tester).onPressed, isNotNull);
  });
}
