import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/settings/settings_catalog.dart';

void main() {
  List<String> ids(String q) => [for (final (_, e) in searchSettings(q)) e.id];

  test('the misbaha has its own settings section', () {
    expect(SettingsSection.values, contains(SettingsSection.tasbih));
    final entries = [
      for (final g in SettingsSection.tasbih.groups)
        for (final e in g.entries) e.id,
    ];
    expect(
      entries,
      containsAll([
        'tasbihStyle',
        'tasbihRender',
        'tasbihMaterial',
        'tasbihHaptics',
        'tasbihSound',
        'tasbihKeepScreenOn',
        'tasbihVolumeKeys',
        'tasbihLockScreen',
      ]),
    );
  });

  test('search finds the misbaha settings in Arabic and English', () {
    expect(ids('مسبحة'), contains('tasbihStyle'));
    expect(ids('المسبحه'), contains('tasbihOpen'));
    expect(ids('أزرار الصوت'), contains('tasbihVolumeKeys'));
    expect(ids('volume'), contains('tasbihVolumeKeys'));
    expect(ids('كهرمان'), contains('tasbihMaterial'));
    expect(ids('3d'), contains('tasbihRender'));
    expect(ids('lock screen'), contains('tasbihLockScreen'));
  });
}
