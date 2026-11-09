import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/audio/keep_alive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/keep_alive');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('the work runs inside a background task, ended after it', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add('${call.method}:${call.arguments}');
      return call.method == 'begin' ? 7 : null;
    });
    final keep = RecitationKeepAlive(channel: channel, enabled: true);
    final value = await keep.during(() async {
      calls.add('work');
      return 42;
    });
    await pumpEventQueue();
    expect(value, 42);
    expect(calls, ['begin:null', 'work', 'end:7']);
  });

  test('ended even when the work fails', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'begin' ? 1 : null;
    });
    final keep = RecitationKeepAlive(channel: channel, enabled: true);
    await expectLater(
      keep.during<void>(() async => throw StateError('x')),
      throwsStateError,
    );
    await pumpEventQueue();
    expect(calls, ['begin', 'end']);
  });

  test('a missing or failing channel never stops the work', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'x'),
    );
    final keep = RecitationKeepAlive(channel: channel, enabled: true);
    expect(await keep.during(() async => 'ok'), 'ok');
  });

  test('off the iPhone, nothing is asked of the platform', () async {
    var asked = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      asked = true;
      return 1;
    });
    final keep = RecitationKeepAlive(channel: channel, enabled: false);
    expect(await keep.during(() async => 1), 1);
    expect(asked, isFalse);
  });
}
