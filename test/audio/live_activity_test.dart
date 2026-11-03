import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/audio/live_activity.dart';

class _Host implements RecitationActivityHost {
  final calls = <String>[];
  @override
  Future<void> update(RecitationActivityContent c) async =>
      calls.add('update ${c.verse} ${c.playing}');
  @override
  Future<void> end() async => calls.add('end');
  @override
  set onCommand(void Function(RecitationCommand command)? handler) {}
}

RecitationActivityContent _c(String verse, {bool playing = true}) =>
    RecitationActivityContent(
      reciter: 'R',
      surah: 'S',
      verse: verse,
      playing: playing,
      playLabel: 'Play',
      pauseLabel: 'Pause',
      rtl: false,
      ayah: int.tryParse(verse.split(' ').last) ?? 0,
      ayahCount: 286,
      previousLabel: 'Previous verse',
      nextLabel: 'Next verse',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('started, updated only on change, ended once', () async {
    final host = _Host();
    final sync = RecitationActivitySync(host);
    await sync.start();
    await sync.show(null);
    await sync.show(_c('Verse 1'));
    await sync.show(_c('Verse 1'));
    await sync.show(_c('Verse 2'));
    await sync.show(_c('Verse 2', playing: false));
    await sync.show(null);
    await sync.show(null);
    expect(host.calls, [
      'end',
      'update Verse 1 true',
      'update Verse 2 true',
      'update Verse 2 false',
      'end',
    ]);
  });

  test('the channel: names and numbers only, the buttons come back', () async {
    const name = 'app.tibyan/live_activity';
    final sent = <MethodCall>[];
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(const MethodChannel(name), (c) async {
      sent.add(c);
      return true;
    });
    addTearDown(
      () => m.setMockMethodCallHandler(const MethodChannel(name), null),
    );
    final host = ChannelRecitationActivity();
    final commands = <RecitationCommand>[];
    host.onCommand = commands.add;
    await host.update(_c('Verse 3'));
    await host.end();
    expect(sent.map((c) => c.method), ['update', 'end']);
    expect((sent.first.arguments as Map).keys.toSet(), {
      'reciter',
      'surah',
      'verse',
      'playing',
      'playLabel',
      'pauseLabel',
      'rtl',
      'ayah',
      'ayahCount',
      'previousLabel',
      'nextLabel',
    });
    expect((sent.first.arguments as Map)['ayah'], 3);
    expect((sent.first.arguments as Map)['ayahCount'], 286);
    for (final name in ['toggle', 'previous', 'next', 'unknown']) {
      await m.handlePlatformMessage(
        'app.tibyan/live_activity',
        const StandardMethodCodec().encodeMethodCall(MethodCall(name)),
        (_) {},
      );
    }
    expect(commands, [
      RecitationCommand.toggle,
      RecitationCommand.previous,
      RecitationCommand.next,
    ]);
  });

  test('a platform failure is ignored', () async {
    const name = 'app.tibyan/live_activity';
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      const MethodChannel(name),
      (c) async => throw PlatformException(code: 'x'),
    );
    addTearDown(
      () => m.setMockMethodCallHandler(const MethodChannel(name), null),
    );
    await ChannelRecitationActivity().update(_c('Verse 1'));
  });

  test('no Live Activity for recitation: the Now Playing card is enough', () {
    expect(RecitationActivitySync.showsRecitation, isFalse);
  });
}
