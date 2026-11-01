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
  set onToggle(void Function()? handler) {}
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

  test('the channel: names and numbers only, toggle comes back', () async {
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
    var toggled = 0;
    host.onToggle = () => toggled++;
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
    });
    await m.handlePlatformMessage(
      name,
      const StandardMethodCodec().encodeMethodCall(const MethodCall('toggle')),
      (_) {},
    );
    expect(toggled, 1);
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
}
