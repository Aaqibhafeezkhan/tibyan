import 'dart:convert';

import 'package:http/http.dart' as http;

/// «الختمة الجماعية» on altibyan.app: shared by link, no accounts.
/// The server returns secrets once; the app keeps them on the device
/// (GroupKhatmaStore) and sends them in `X-Khatma-Secret`.
final groupKhatmaOrigin = Uri.parse('https://altibyan.app');

enum PartState { open, taken, done }

class GroupPart {
  const GroupPart({
    required this.number,
    required this.state,
    this.name,
    this.claimedAt,
    this.doneAt,
  });

  factory GroupPart.fromJson(Map<String, dynamic> j) => GroupPart(
    number: j['number'] as int,
    state: PartState.values.firstWhere(
      (s) => s.name == j['state'],
      orElse: () => PartState.open,
    ),
    name: j['name'] as String?,
    claimedAt: DateTime.tryParse(j['claimed_at'] as String? ?? ''),
    doneAt: DateTime.tryParse(j['done_at'] as String? ?? ''),
  );

  final int number;
  final PartState state;
  final String? name;
  final DateTime? claimedAt;
  final DateTime? doneAt;
}

class GroupKhatma {
  const GroupKhatma({
    required this.id,
    required this.unit,
    required this.parts,
    this.title,
    this.organizer,
    this.targetDate,
    this.completedAt,
    this.raw = const {},
  });

  factory GroupKhatma.fromJson(Map<String, dynamic> j) => GroupKhatma(
    id: j['id'] as String,
    title: j['title'] as String?,
    organizer: j['organizer'] as String?,
    unit: j['unit'] as String? ?? 'juz',
    targetDate: DateTime.tryParse(j['target_date'] as String? ?? ''),
    completedAt: DateTime.tryParse(j['completed_at'] as String? ?? ''),
    parts: [
      for (final p in j['parts'] as List? ?? const [])
        GroupPart.fromJson(p as Map<String, dynamic>),
    ],
    raw: j,
  );

  final String id;
  final String? title;
  final String? organizer;

  /// `juz` (30 parts) or `hizb` (60 parts).
  final String unit;
  final List<GroupPart> parts;
  final DateTime? targetDate;
  final DateTime? completedAt;

  /// The server's JSON, cached on the device for offline viewing.
  final Map<String, dynamic> raw;

  bool get isHizb => unit == 'hizb';
  int get taken => parts.where((p) => p.state != PartState.open).length;
  int get done => parts.where((p) => p.state == PartState.done).length;
  Uri get link => groupKhatmaOrigin.replace(path: '/k/$id');
}

/// Why a call failed, for a message the user can act on.
enum GroupKhatmaFailure { offline, notFound, taken, forbidden, busy, invalid }

class GroupKhatmaException implements Exception {
  const GroupKhatmaException(this.failure);
  final GroupKhatmaFailure failure;
  @override
  String toString() => 'GroupKhatmaException($failure)';
}

class GroupKhatmaApi {
  GroupKhatmaApi({http.Client? client, Uri? origin})
    : _client = client ?? http.Client(),
      _origin = origin ?? groupKhatmaOrigin;

  final http.Client _client;
  final Uri _origin;

  Uri _u(String path) => _origin.replace(path: '/api/k$path');

  Future<({GroupKhatma khatma, String organizerSecret})> create({
    String? title,
    String? organizer,
    bool hizb = false,
    DateTime? targetDate,
  }) async {
    final body = await _send(
      'POST',
      '',
      body: {
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (organizer != null && organizer.trim().isNotEmpty)
          'organizer': organizer.trim(),
        'unit': hizb ? 'hizb' : 'juz',
        if (targetDate != null)
          'target_date': targetDate.toIso8601String().substring(0, 10),
      },
    );
    return (
      khatma: GroupKhatma.fromJson(body['khatma'] as Map<String, dynamic>),
      organizerSecret: body['organizer_secret'] as String,
    );
  }

  Future<GroupKhatma> fetch(String id) async =>
      GroupKhatma.fromJson(await _send('GET', '/${Uri.encodeComponent(id)}'));

  Future<({GroupKhatma khatma, String partSecret})> claim(
    String id,
    int part,
    String name,
  ) async {
    final body = await _send(
      'POST',
      '/${Uri.encodeComponent(id)}/parts/$part/claim',
      body: {'name': name.trim()},
    );
    return (
      khatma: GroupKhatma.fromJson(body['khatma'] as Map<String, dynamic>),
      partSecret: body['part_secret'] as String,
    );
  }

  Future<GroupKhatma> markDone(String id, int part, String secret) =>
      _part(id, part, 'done', secret);
  Future<GroupKhatma> undoDone(String id, int part, String secret) =>
      _part(id, part, 'undone', secret);
  Future<GroupKhatma> release(String id, int part, String secret) =>
      _part(id, part, 'release', secret);

  Future<GroupKhatma> rename(String id, String secret, String? title) async =>
      GroupKhatma.fromJson(
        await _send(
          'PATCH',
          '/${Uri.encodeComponent(id)}',
          secret: secret,
          body: {'title': title},
        ),
      );

  Future<void> delete(String id, String secret) =>
      _send('DELETE', '/${Uri.encodeComponent(id)}', secret: secret);

  Future<GroupKhatma> _part(
    String id,
    int part,
    String action,
    String secret,
  ) async => GroupKhatma.fromJson(
    await _send(
      'POST',
      '/${Uri.encodeComponent(id)}/parts/$part/$action',
      secret: secret,
    ),
  );

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? secret,
  }) async {
    final request = http.Request(method, _u(path));
    request.headers['Accept'] = 'application/json';
    if (secret != null) request.headers['X-Khatma-Secret'] = secret;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 15)),
      );
    } catch (_) {
      throw const GroupKhatmaException(GroupKhatmaFailure.offline);
    }
    switch (res.statusCode) {
      case >= 200 && < 300:
        if (res.body.isEmpty) return const {};
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      case 404:
        throw const GroupKhatmaException(GroupKhatmaFailure.notFound);
      case 409:
        throw const GroupKhatmaException(GroupKhatmaFailure.taken);
      case 403:
        throw const GroupKhatmaException(GroupKhatmaFailure.forbidden);
      case 429:
        throw const GroupKhatmaException(GroupKhatmaFailure.busy);
      case >= 400 && < 500:
        throw const GroupKhatmaException(GroupKhatmaFailure.invalid);
      default:
        throw const GroupKhatmaException(GroupKhatmaFailure.offline);
    }
  }
}

final _idPattern = RegExp(r'^[A-Za-z0-9_-]{16,32}$');

/// The khatma id in a shared link (`https://altibyan.app/k/<id>`,
/// `tibyan://group?id=<id>`) or a bare id; null when it is none.
String? groupKhatmaIdOf(String input) {
  final text = input.trim();
  if (_idPattern.hasMatch(text)) return text;
  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  String? id;
  if (uri.scheme == 'tibyan' && uri.host == 'group') {
    id = uri.queryParameters['id'];
  } else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
      const {'altibyan.app', 'www.altibyan.app'}.contains(uri.host) &&
      uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'k') {
    id = uri.pathSegments[1];
  }
  return id != null && _idPattern.hasMatch(id) ? id : null;
}
