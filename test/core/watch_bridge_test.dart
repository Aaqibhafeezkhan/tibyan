import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/platform/watch_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.tibyan/watch');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('pushes the entries to the watch on phones', () async {
    for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = p;
      await WatchBridge.push({'tasbih_count': '33'});
    }
    expect(calls, hasLength(2));
    expect(calls.first.method, 'push');
    expect(calls.first.arguments, {'tasbih_count': '33'});
  });

  test('does nothing on macOS or with nothing to send', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await WatchBridge.push({'a': 'b'});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await WatchBridge.push({});
    expect(calls, isEmpty);
  });

  test('a missing watch side is not an error', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await WatchBridge.push({'a': 'b'});
  });
}
