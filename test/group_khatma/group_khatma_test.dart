import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/group_khatma/data/group_khatma_api.dart';
import 'package:tibyan/features/group_khatma/data/group_khatma_store.dart';
import 'package:tibyan/features/group_khatma/group_khatma_providers.dart';
import 'package:tibyan/features/group_khatma/presentation/group_khatma_list_screen.dart';
import 'package:tibyan/features/group_khatma/presentation/group_khatma_screen.dart';
import 'package:tibyan/features/khatma/khatma_providers.dart';
import 'package:tibyan/features/khatma/services/reminder_scheduler.dart';
import 'package:tibyan/l10n/app_localizations.dart';

const _id = 'AbCdEfGhIjKlMnOpQrStUv';

/// A small stand-in for altibyan.app's /api/k.
class FakeServer {
  final khatmas = <String, Map<String, dynamic>>{};
  final secrets = <String, String>{};
  final requests = <http.Request>[];
  bool offline = false;

  Map<String, dynamic> _new(Map body) {
    final hizb = body['unit'] == 'hizb';
    return {
      'id': _id,
      'url': 'https://altibyan.app/k/$_id',
      'title': body['title'],
      'organizer': body['organizer'],
      'unit': hizb ? 'hizb' : 'juz',
      'parts_count': hizb ? 60 : 30,
      'target_date': body['target_date'],
      'completed_at': null,
      'parts': [
        for (var n = 1; n <= (hizb ? 60 : 30); n++)
          {'number': n, 'state': 'open', 'name': null},
      ],
    };
  }

  late final client = MockClient((r) async {
    requests.add(r);
    if (offline) throw const SocketLike();
    final seg = r.url.pathSegments; // api, k, id, parts, n, action
    http.Response json(Object body, [int code = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      code,
      headers: {'content-type': 'application/json'},
    );
    if (r.method == 'POST' && seg.length == 2) {
      final k = _new(jsonDecode(r.body) as Map);
      khatmas[_id] = k;
      secrets['org'] = 'org-secret';
      return json({'organizer_secret': 'org-secret', 'khatma': k}, 201);
    }
    final k = khatmas[seg[2]];
    if (k == null) return json({'error': 'not_found'}, 404);
    if (seg.length == 3) {
      if (r.method == 'DELETE') {
        if (r.headers['X-Khatma-Secret'] != 'org-secret') {
          return json({'error': 'forbidden'}, 403);
        }
        khatmas.remove(seg[2]);
        return http.Response('', 204);
      }
      return json(k);
    }
    final n = int.parse(seg[4]);
    final part = (k['parts'] as List)[n - 1] as Map<String, dynamic>;
    switch (seg[5]) {
      case 'claim':
        if (part['state'] != 'open') return json({'error': 'taken'}, 409);
        part['state'] = 'taken';
        part['name'] = (jsonDecode(r.body) as Map)['name'];
        secrets['$n'] = 'part-$n';
        return json({'part_secret': 'part-$n', 'khatma': k});
      case 'done':
        if (r.headers['X-Khatma-Secret'] != secrets['$n']) {
          return json({'error': 'forbidden'}, 403);
        }
        part['state'] = 'done';
      case 'release':
        part['state'] = 'open';
        part['name'] = null;
    }
    return json(k);
  });
}

class SocketLike implements Exception {
  const SocketLike();
}

void main() {
  group('links', () {
    test('reads the id from a shared link, the app scheme or a bare id', () {
      expect(groupKhatmaIdOf('https://altibyan.app/k/$_id'), _id);
      expect(groupKhatmaIdOf('  https://www.altibyan.app/k/$_id '), _id);
      expect(groupKhatmaIdOf('tibyan://group?id=$_id'), _id);
      expect(groupKhatmaIdOf(_id), _id);
      expect(groupKhatmaIdOf('https://evil.example/k/$_id'), isNull);
      expect(groupKhatmaIdOf('https://altibyan.app/beta'), isNull);
      expect(groupKhatmaIdOf('short'), isNull);
    });
  });

  group('GroupKhatmaApi', () {
    test('creates, claims and marks done with the secret header', () async {
      final server = FakeServer();
      final api = GroupKhatmaApi(client: server.client);
      final created = await api.create(title: ' أسرتنا ', hizb: true);
      expect(created.organizerSecret, 'org-secret');
      expect(created.khatma.parts, hasLength(60));
      expect(jsonDecode(server.requests.last.body), {
        'title': 'أسرتنا',
        'unit': 'hizb',
      });
      final claimed = await api.claim(_id, 2, 'Sara');
      expect(claimed.partSecret, 'part-2');
      expect(claimed.khatma.taken, 1);
      final done = await api.markDone(_id, 2, 'part-2');
      expect(server.requests.last.headers['X-Khatma-Secret'], 'part-2');
      expect(done.done, 1);
    });

    test('maps errors to failures', () async {
      final server = FakeServer();
      final api = GroupKhatmaApi(client: server.client);
      await expectLater(
        api.fetch(_id),
        throwsA(
          isA<GroupKhatmaException>().having(
            (e) => e.failure,
            'failure',
            GroupKhatmaFailure.notFound,
          ),
        ),
      );
      await api.create();
      await api.claim(_id, 1, 'A');
      await expectLater(
        api.claim(_id, 1, 'B'),
        throwsA(
          isA<GroupKhatmaException>().having(
            (e) => e.failure,
            'f',
            GroupKhatmaFailure.taken,
          ),
        ),
      );
      await expectLater(
        api.markDone(_id, 1, 'wrong'),
        throwsA(
          isA<GroupKhatmaException>().having(
            (e) => e.failure,
            'f',
            GroupKhatmaFailure.forbidden,
          ),
        ),
      );
      server.offline = true;
      await expectLater(
        api.fetch(_id),
        throwsA(
          isA<GroupKhatmaException>().having(
            (e) => e.failure,
            'f',
            GroupKhatmaFailure.offline,
          ),
        ),
      );
    });
  });

  group('GroupKhatmas (device state)', () {
    late SharedPreferences prefs;
    late FakeServer server;
    late ProviderContainer c;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      server = FakeServer();
      c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          groupKhatmaApiProvider.overrideWithValue(
            GroupKhatmaApi(client: server.client),
          ),
        ],
      );
      addTearDown(c.dispose);
    });

    test('keeps secrets and the last state on the device', () async {
      final n = c.read(groupKhatmasProvider.notifier);
      await n.create(title: 'T');
      await n.claim(_id, 4, 'Omar');
      final saved = GroupKhatmaStore(prefs).get(_id)!;
      expect(saved.organizerSecret, 'org-secret');
      expect(saved.partSecrets, {4: 'part-4'});
      expect(saved.cached!.taken, 1);
      await n.markDone(_id, 4);
      expect(c.read(groupKhatmasProvider).single.cached!.done, 1);
      await n.release(_id, 4);
      expect(GroupKhatmaStore(prefs).get(_id)!.partSecrets, isEmpty);
    });

    test('offline: refresh fails and the cached copy stays', () async {
      final n = c.read(groupKhatmasProvider.notifier);
      await n.create();
      server.offline = true;
      await expectLater(n.refresh(_id), throwsA(isA<GroupKhatmaException>()));
      expect(c.read(groupKhatmasProvider).single.cached, isNotNull);
    });

    test('a khatma deleted on the server leaves the list', () async {
      final n = c.read(groupKhatmasProvider.notifier);
      await n.create();
      server.khatmas.clear();
      await expectLater(n.refresh(_id), throwsA(isA<GroupKhatmaException>()));
      expect(c.read(groupKhatmasProvider), isEmpty);
    });

    test('organizer deletes', () async {
      final n = c.read(groupKhatmasProvider.notifier);
      await n.create();
      await n.delete(_id);
      expect(server.khatmas, isEmpty);
      expect(c.read(groupKhatmasProvider), isEmpty);
    });

    test('reminder ids stay out of the khatma reminders range', () {
      for (final n in [1, 30, 60]) {
        final id = groupReminderId(_id, n);
        expect(id, greaterThanOrEqualTo(8000));
        expect(id, lessThan(1 << 31));
      }
      expect(groupReminderId(_id, 1), isNot(groupReminderId(_id, 2)));
    });
  });

  group('screens', () {
    late ThemeRegistry registry;
    setUpAll(() async => registry = await ThemeRegistry.load(rootBundle));

    Future<(FakeServer, NoReminders)> pump(
      WidgetTester tester,
      Widget home, {
      Map<String, Object> prefs = const {},
      FakeServer? server,
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      final sp = await SharedPreferences.getInstance();
      final s = server ?? FakeServer();
      final reminders = NoReminders();
      tester.view
        ..physicalSize = const Size(420, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sp),
            themeRegistryProvider.overrideWithValue(registry),
            groupKhatmaApiProvider.overrideWithValue(
              GroupKhatmaApi(client: s.client),
            ),
            reminderSchedulerProvider.overrideWithValue(reminders),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildTheme(
              style: registry.byId(registry.defaultStyleId),
              mode: ThemeModeId.light,
              uiFont: UiFont.changa,
              elderly: false,
              interfaceStyle: defaultInterfaceStyle,
            ),
            home: home,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (s, reminders);
    }

    testWidgets('the list offers create and join, and is empty at first', (
      tester,
    ) async {
      await pump(tester, const GroupKhatmaListScreen());
      expect(find.text('إنشاء ختمة جماعية'), findsWidgets);
      expect(find.text('الانضمام برابط'), findsOneWidget);
      expect(find.text('لم تنضمّ إلى ختمة جماعية بعد.'), findsOneWidget);
    });

    testWidgets('join rejects a link that is not a khatma link', (
      tester,
    ) async {
      await pump(tester, const GroupKhatmaListScreen());
      await tester.tap(find.byKey(const Key('gk-join')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'https://example.com');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(find.text('هذا ليس رابط ختمة جماعية.'), findsOneWidget);
    });

    testWidgets('create sheet sends the form', (tester) async {
      final (server, _) = await pump(
        tester,
        const Scaffold(body: CreateGroupKhatmaSheet()),
      );
      await tester.enterText(find.byKey(const Key('gk-title')), 'ختمة البيت');
      await tester.tap(find.text('٦٠ حزبًا'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gk-create-submit')));
      await tester.pumpAndSettle();
      expect(server.khatmas[_id]!['title'], 'ختمة البيت');
      expect(server.khatmas[_id]!['parts_count'], 60);
    });

    testWidgets('claim a part, mark it done, set a reminder', (tester) async {
      final server = FakeServer();
      await GroupKhatmaApi(client: server.client).create(title: 'العائلة');
      final (_, reminders) = await pump(
        tester,
        const GroupKhatmaScreen(id: _id),
        server: server,
      );
      expect(find.text('العائلة'), findsOneWidget);
      expect(find.text('محجوز 0 من 30 · تمّ 0'), findsOneWidget);

      await tester.tap(find.byKey(const Key('gk-claim-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'مريم');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('مريم (أنت)'), findsOneWidget);
      expect(find.text('محجوز 1 من 30 · تمّ 0'), findsOneWidget);

      await tester.tap(find.byKey(const Key('gk-mine-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ذكّرني بجزئي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حسنًا').last);
      await tester.pumpAndSettle();
      expect(reminders.once.keys, [groupReminderId(_id, 1)]);

      await tester.tap(find.byKey(const Key('gk-mine-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تمّت قراءته'));
      await tester.pumpAndSettle();
      expect(find.text('محجوز 1 من 30 · تمّ 1'), findsOneWidget);
    });

    testWidgets('offline shows the saved copy and hides actions', (
      tester,
    ) async {
      final server = FakeServer();
      final api = GroupKhatmaApi(client: server.client);
      final k = (await api.create(title: 'محفوظة')).khatma;
      final saved = SavedGroupKhatma(id: _id, cached: k);
      server.offline = true;
      await pump(
        tester,
        const GroupKhatmaScreen(id: _id),
        server: server,
        prefs: {
          'group_khatmas_v1': jsonEncode([saved.toJson()]),
        },
      );
      expect(find.text('محفوظة'), findsOneWidget);
      expect(
        find.text('لا اتصال بالإنترنت. هذه آخر حالة محفوظة.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('gk-claim-1')), findsNothing);
    });

    testWidgets('a missing khatma says so', (tester) async {
      await pump(tester, const GroupKhatmaScreen(id: _id));
      expect(find.text('هذه الختمة غير موجودة؛ ربما حُذفت.'), findsOneWidget);
    });
  });
}
