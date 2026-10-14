import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/settings/settings_controller.dart';
import 'model_manifest.dart';
import 'model_store.dart';
import 'tasmee_backend.dart';

/// The engines this build can run; a newer model on another engine is for
/// a newer app, never offered here.
const supportedModelEngines = {
  ModelEngine.sherpaNemoCtc,
  ModelEngine.sherpaWhisper,
};

/// Whether [offer] is a newer version of the [installed] model that this
/// build can run.
bool isModelUpdate(ModelManifest offer, ModelManifest installed) =>
    offer.id == installed.id &&
    supportedModelEngines.contains(offer.engine) &&
    compareModelVersions(offer.version, installed.version) > 0;

/// Finds out, quietly, whether the mirror has a newer version of the
/// installed recognition model.
///
/// The manifest is fetched at most once every [interval] (a check that
/// fails, offline, is not counted: the next opening tries again), and the
/// last one fetched is kept, so the offer stays shown between checks.
/// Any failure is silent: no update is offered. Nothing is downloaded
/// here; the reader chooses to, with the size shown first.
class ModelUpdateChecker {
  ModelUpdateChecker({
    required this.prefs,
    required this.installedModel,
    required this.fetchManifest,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SharedPreferences prefs;
  final Future<InstalledModel?> Function() installedModel;
  final Future<ModelManifest> Function() fetchManifest;
  final DateTime Function() _now;

  static const interval = Duration(days: 1);
  static const _kCheckedAt = 'tasmee.modelCheckedAt';
  static const _kLatest = 'tasmee.modelLatest';

  /// The newer manifest to offer, or null (none, no model installed yet, or
  /// the check failed).
  Future<ModelManifest?> check() async {
    final InstalledModel? model;
    try {
      model = await installedModel();
    } catch (_) {
      return null;
    }
    if (model == null) return null;
    var latest = _stored();
    if (_due()) {
      try {
        latest = await fetchManifest();
        await prefs.setString(_kLatest, jsonEncode(latest.toJson()));
        await prefs.setInt(_kCheckedAt, _now().millisecondsSinceEpoch);
      } catch (_) {
        // Offline or a bad manifest: quietly nothing new.
      }
    }
    return latest != null && isModelUpdate(latest, model.manifest)
        ? latest
        : null;
  }

  bool _due() {
    final at = prefs.getInt(_kCheckedAt);
    if (at == null) return true;
    final since = _now().difference(DateTime.fromMillisecondsSinceEpoch(at));
    // A clock set back counts as due.
    return since.isNegative || since >= interval;
  }

  ModelManifest? _stored() {
    final raw = prefs.getString(_kLatest);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      return json is Map<String, dynamic> ? ModelManifest.fromJson(json) : null;
    } on FormatException {
      return null;
    }
  }
}

/// A newer version of the installed model, checked on opening the tasmee
/// (at most once a day); null when there is none.
final tasmeeModelUpdateProvider = FutureProvider.autoDispose<ModelManifest?>((
  ref,
) {
  final backend = ref.watch(tasmeeBackendProvider);
  return ModelUpdateChecker(
    prefs: ref.watch(sharedPreferencesProvider),
    installedModel: backend.installedModel,
    fetchManifest: backend.fetchManifest,
  ).check();
});
