import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/platform/app_shortcuts.dart';
import 'package:tibyan/features/khatma/services/home_widget_sync.dart';
import 'package:tibyan/features/mushaf/presentation/navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the shortcuts are the existing links', () {
    expect(AppShortcut.dailyWird.link.toString(), 'tibyan://reader');
    expect(
      widgetActionOf(AppShortcut.continueReading.link),
      WidgetAction.continueReading,
    );
    expect(verseOfLink(surahShortcutLink(18)), (surah: 18, ayah: 1));
    expect(verseOfLink(surahShortcutLink(114)), (surah: 114, ayah: 1));
  });

  test('Google Assistant feature names', () {
    Uri? f(String name) =>
        assistantFeatureLink(Uri.parse('tibyan://action/feature?name=$name'));
    expect(f('wird'), AppShortcut.dailyWird.link);
    expect(f('continue'), AppShortcut.continueReading.link);
    expect(f('my daily wird'), AppShortcut.dailyWird.link);
    expect(
      f(Uri.encodeQueryComponent('وردي اليومي')),
      AppShortcut.dailyWird.link,
    );
    expect(f('Continue reading'), AppShortcut.continueReading.link);
    expect(
      f(Uri.encodeQueryComponent('متابعة القراءة')),
      AppShortcut.continueReading.link,
    );
    expect(f('weather'), isNull);
    expect(f(''), isNull);
    expect(assistantFeatureLink(Uri.parse('tibyan://action/continue')), isNull);
    expect(assistantFeatureLink(Uri.parse('tibyan://verse?s=1&a=1')), isNull);
    expect(assistantFeatureLink(null), isNull);
    // Not a feature: the widget's own action still works.
    expect(widgetActionOf(Uri.parse('tibyan://action/feature?name=x')), isNull);
  });

  test(
    'iOS channel: a launching shortcut opens, the surah names go over',
    () async {
      const name = 'app.tibyan/shortcuts';
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel(name), (c) async {
        calls.add(c);
        return c.method == 'ready' ? 'tibyan://verse?s=18&a=1' : null;
      });
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(const MethodChannel(name), null),
      );
      final opened = <Uri>[];
      await AppShortcutsChannel().attach(
        open: opened.add,
        surahs: () async => [(18, 'الكهف', 'Al-Kahf')],
      );
      expect(opened, [Uri.parse('tibyan://verse?s=18&a=1')]);
      expect(calls.map((c) => c.method), ['ready', 'setSurahs']);
      expect(calls.last.arguments, [
        {'n': 18, 'ar': 'الكهف', 'en': 'Al-Kahf'},
      ]);
    },
  );
}
