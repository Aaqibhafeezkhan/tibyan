import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/theme_registry.dart';

Future<bool> _kahf(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      themeRegistryProvider.overrideWithValue(
        await ThemeRegistry.load(rootBundle),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c.read(settingsProvider).kahfReminder;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('new installs and untouched switches: on', () async {
    expect(await _kahf({}), isTrue);
    expect(await _kahf({'settings.weeklyReminder': true}), isTrue);
  });

  test('an explicit choice is kept', () async {
    expect(await _kahf({'settings.kahfReminder': false}), isFalse);
    expect(await _kahf({'settings.kahfReminder': true}), isTrue);
  });
}
