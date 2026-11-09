import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/crash/native_diagnostics.dart';

void main() {
  test('with the reader agreeing, each kept report is sent', () async {
    final sent = <String>[];
    await forwardNativeDiagnostics(
      send: true,
      take: () async => ['{"a":1}', '{"b":2}'],
      capture: (j) async => sent.add(j),
    );
    expect(sent, ['{"a":1}', '{"b":2}']);
  });

  test(
    'without agreement, they are taken off the device and not sent',
    () async {
      var taken = false;
      final sent = <String>[];
      await forwardNativeDiagnostics(
        send: false,
        take: () async {
          taken = true;
          return ['{"a":1}'];
        },
        capture: (j) async => sent.add(j),
      );
      expect(taken, isTrue);
      expect(sent, isEmpty);
    },
  );

  test('a failing channel or send stops nothing', () async {
    await forwardNativeDiagnostics(
      send: true,
      take: () async => throw StateError('no channel'),
    );
    final sent = <String>[];
    await forwardNativeDiagnostics(
      send: true,
      take: () async => ['1', '2'],
      capture: (j) async {
        if (j == '1') throw StateError('offline');
        sent.add(j);
      },
    );
    expect(sent, ['2']);
  });

  test('the report kinds are named from the payload', () {
    expect(
      diagnosticKinds('{"crashDiagnostics":[{}],"hangDiagnostics":[{}]}'),
      'crash, hang',
    );
    expect(diagnosticKinds('{"timeStampBegin":"x"}'), 'other');
    expect(diagnosticKinds('not json'), 'unreadable');
  });
}
