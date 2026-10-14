import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/khatma/domain/day.dart';
import 'package:tibyan/features/khatma/domain/interval_set.dart';
import 'package:tibyan/features/khatma/domain/khatmah.dart';
import 'package:tibyan/features/khatma/domain/khatmah_engine.dart';
import 'package:tibyan/features/khatma/domain/quran_index.dart';

import 'support.dart';

final day1 = Day(2026, 10, 1);

void main() {
  late QuranIndex index;
  late KhatmahEngine engine;

  setUpAll(() async {
    index = await realIndex();
    engine = KhatmahEngine(index);
  });

  test('CountingMode.wirdConfirm skips passive dwell attribution in attribute()', () {
    final wirdConfirmKhatma = Khatmah(
      uuid: 'k_confirm',
      title: 'Khatma Confirm',
      startDate: day1,
      targetDate: day1.add(29),
      isPrimary: true,
      counting: CountingMode.wirdConfirm,
    );
    final autoKhatma = Khatmah(
      uuid: 'k_auto',
      title: 'Khatma Auto',
      startDate: day1,
      targetDate: day1.add(29),
      isPrimary: true,
      counting: CountingMode.auto,
    );

    final verses = IntervalSet.range(1, 20);

    // wirdConfirm is ignored by passive dwell attribution
    final decisionsConfirm = engine.attribute(
      verses,
      [wirdConfirmKhatma],
      (_) => IntervalSet.empty,
    );
    expect(decisionsConfirm, isEmpty);

    // auto mode is attributed automatically
    final decisionsAuto = engine.attribute(
      verses,
      [autoKhatma],
      (_) => IntervalSet.empty,
    );
    expect(decisionsAuto.length, 1);
    expect(decisionsAuto.first.khatmaUuid, 'k_auto');
    expect(decisionsAuto.first.decidedBy, DecidedBy.auto);
  });

  test('markRead directly credits a CountingMode.wirdConfirm khatma', () {
    final wirdConfirmKhatma = Khatmah(
      uuid: 'k_confirm',
      title: 'Khatma Confirm',
      startDate: day1,
      targetDate: day1.add(29),
      isPrimary: true,
      counting: CountingMode.wirdConfirm,
    );

    final verses = IntervalSet.range(1, 50);
    final attr = engine.markRead(verses, wirdConfirmKhatma, IntervalSet.empty);

    expect(attr, isNotNull);
    expect(attr!.khatmaUuid, 'k_confirm');
    expect(attr.decidedBy, DecidedBy.manual);
    expect(attr.ranges, verses);
  });

  test('Android notification icons ic_stat_tibyan.png exist across all densities', () {
    const densities = [
      'drawable-mdpi',
      'drawable-hdpi',
      'drawable-xhdpi',
      'drawable-xxhdpi',
      'drawable-xxxhdpi',
    ];
    for (final density in densities) {
      final file = File('android/app/src/main/res/$density/ic_stat_tibyan.png');
      expect(file.existsSync(), isTrue, reason: 'Missing $density/ic_stat_tibyan.png');
      expect(file.lengthSync(), greaterThan(100), reason: '$density icon file is empty');
    }
  });
}
