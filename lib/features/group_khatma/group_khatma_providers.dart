import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_controller.dart';
import 'data/group_khatma_api.dart';
import 'data/group_khatma_store.dart';

final groupKhatmaApiProvider = Provider<GroupKhatmaApi>(
  (ref) => GroupKhatmaApi(),
);

final groupKhatmaStoreProvider = Provider<GroupKhatmaStore>(
  (ref) => GroupKhatmaStore(ref.watch(sharedPreferencesProvider)),
);

/// The group khatmas this device follows, newest first.
final groupKhatmasProvider =
    NotifierProvider<GroupKhatmas, List<SavedGroupKhatma>>(GroupKhatmas.new);

/// Every network action goes through here: the server's answer replaces
/// the cached copy, and secrets are saved before anything is shown. A
/// failed call changes nothing on the device (nothing is queued).
class GroupKhatmas extends Notifier<List<SavedGroupKhatma>> {
  GroupKhatmaApi get _api => ref.read(groupKhatmaApiProvider);
  GroupKhatmaStore get _store => ref.read(groupKhatmaStoreProvider);

  @override
  List<SavedGroupKhatma> build() => _store.all();

  SavedGroupKhatma? saved(String id) => _store.get(id);

  Future<void> _save(SavedGroupKhatma k) async {
    await _store.put(k);
    state = _store.all();
  }

  Future<SavedGroupKhatma> _cache(
    GroupKhatma k, {
    SavedGroupKhatma? base,
  }) async {
    final s = (base ?? _store.get(k.id) ?? SavedGroupKhatma(id: k.id)).copyWith(
      cached: k,
      cachedAt: DateTime.now(),
    );
    await _save(s);
    return s;
  }

  Future<SavedGroupKhatma> create({
    String? title,
    String? organizer,
    bool hizb = false,
    DateTime? targetDate,
  }) async {
    final r = await _api.create(
      title: title,
      organizer: organizer,
      hizb: hizb,
      targetDate: targetDate,
    );
    return _cache(
      r.khatma,
      base: SavedGroupKhatma(
        id: r.khatma.id,
        organizerSecret: r.organizerSecret,
      ),
    );
  }

  /// The latest state from the server; saves it to "my group khatmas".
  Future<SavedGroupKhatma> refresh(String id) async {
    try {
      return await _cache(await _api.fetch(id));
    } on GroupKhatmaException catch (e) {
      // Deleted on the server (by its organizer or after it expired).
      if (e.failure == GroupKhatmaFailure.notFound) await forget(id);
      rethrow;
    }
  }

  Future<SavedGroupKhatma> claim(String id, int part, String name) async {
    final r = await _api.claim(id, part, name);
    final base = _store.get(id) ?? SavedGroupKhatma(id: id);
    return _cache(
      r.khatma,
      base: base.copyWith(
        partSecrets: {...base.partSecrets, part: r.partSecret},
      ),
    );
  }

  String _secretFor(String id, int part) {
    final s = _store.get(id);
    final secret = s?.partSecrets[part] ?? s?.organizerSecret;
    if (secret == null) {
      throw const GroupKhatmaException(GroupKhatmaFailure.forbidden);
    }
    return secret;
  }

  Future<SavedGroupKhatma> markDone(String id, int part) async =>
      _cache(await _api.markDone(id, part, _secretFor(id, part)));

  Future<SavedGroupKhatma> undoDone(String id, int part) async =>
      _cache(await _api.undoDone(id, part, _secretFor(id, part)));

  Future<SavedGroupKhatma> release(String id, int part) async {
    final k = await _api.release(id, part, _secretFor(id, part));
    final base = _store.get(id) ?? SavedGroupKhatma(id: id);
    return _cache(
      k,
      base: base.copyWith(
        partSecrets: {...base.partSecrets}..remove(part),
        reminders: {...base.reminders}..remove(part),
      ),
    );
  }

  Future<SavedGroupKhatma> rename(String id, String? title) async {
    final secret = _store.get(id)?.organizerSecret;
    if (secret == null) {
      throw const GroupKhatmaException(GroupKhatmaFailure.forbidden);
    }
    return _cache(await _api.rename(id, secret, title));
  }

  Future<void> delete(String id) async {
    final secret = _store.get(id)?.organizerSecret;
    if (secret == null) {
      throw const GroupKhatmaException(GroupKhatmaFailure.forbidden);
    }
    await _api.delete(id, secret);
    await forget(id);
  }

  Future<void> setReminder(String id, int part, DateTime? at) async {
    final base = _store.get(id);
    if (base == null) return;
    final reminders = {...base.reminders};
    if (at == null) {
      reminders.remove(part);
    } else {
      reminders[part] = at;
    }
    await _save(base.copyWith(reminders: reminders));
  }

  Future<void> forget(String id) async {
    await _store.remove(id);
    state = _store.all();
  }
}

/// A stable notification id for a part's reminder (outside the khatma
/// reminders' range, 7100..7519).
int groupReminderId(String khatmaId, int part) {
  var h = 0;
  for (final c in khatmaId.codeUnits) {
    h = (h * 31 + c) & 0x3fffffff;
  }
  return 8000 + (h % 1000) * 61 + part % 61;
}
