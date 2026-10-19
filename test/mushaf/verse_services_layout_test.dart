import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/verse_services.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// The ayah tools panel keeps every label whole: at phone, tablet and
/// desktop widths, text scales 1.0 to 1.3 and in elderly mode, nothing
/// overflows and each button's label lies inside the button.
void main() {
  testWidgets('no label is clipped at any size or text scale', (tester) async {
    final registry = (await tester.runAsync(
      () => ThemeRegistry.load(rootBundle),
    ))!;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
      debugDefaultTargetPlatformOverride = platform;
      for (final w in [360.0, 393.0, 820.0, 1280.0]) {
        for (final (scale, elderly) in [
          (1.0, false),
          (1.15, false),
          (1.3, false),
          (elderlyTextScale, true),
        ]) {
          await tester.binding.setSurfaceSize(Size(w, 1400));
          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              locale: const Locale('ar'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: buildTheme(
                style: registry.byId('zakhrafa'),
                mode: ThemeModeId.light,
                uiFont: UiFont.plex,
                elderly: elderly,
                interfaceStyle: defaultInterfaceStyle,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: VerseServicesPanel(
                    verses: const [(surah: 2, ayah: 255)],
                    surahs: null,
                    onMark: (_) {},
                    onSaveToFasil: () {},
                    onClose: () {},
                    onMultiSelect: () {},
                    onTafsir: () {},
                    onListen: () {},
                    onWordStudy: () {},
                    onWordMeanings: () {},
                    onReflect: () {},
                    onCopy: () {},
                    onShareText: () {},
                    onShareImage: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final where = '$platform ${w}px ×$scale elderly=$elderly';
          expect(tester.takeException(), isNull, reason: where);
          for (final label in ['نسخ', 'مشاركة نصًا', 'مشاركة كصورة']) {
            final text = find.text(label);
            expect(text, findsOneWidget, reason: '$label $where');
            final button = tester.getRect(
              find.ancestor(of: text, matching: find.byType(OutlinedButton)),
            );
            final r = tester.getRect(text);
            expect(
              r.bottom,
              lessThanOrEqualTo(button.bottom - 4),
              reason: '$label $where',
            );
            expect(r.top, greaterThanOrEqualTo(button.top), reason: where);
          }
          for (final label in ['قراءة', 'مراجعة', 'حفظ', 'تدبر']) {
            final text = find.text(label);
            final button = tester.getRect(
              find.ancestor(of: text, matching: find.byType(InkWell)).first,
            );
            expect(
              tester.getRect(text).bottom,
              lessThanOrEqualTo(button.bottom),
              reason: '$label $where',
            );
          }
        }
      }
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
