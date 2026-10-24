import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/db/content_database.dart';
import '../../tasmee/data/tasmee_backend.dart';
import '../../tasmee/data/tasmee_settings.dart';
import '../../tasmee/data/tasmee_words_repository.dart';
import '../../tasmee/domain/alignment_engine.dart';
import '../../tasmee/domain/recitation_range.dart';
import '../../tasmee/domain/tasmee_session_request.dart';
import '../../tasmee/presentation/tasmee_session_controller.dart';
import '../domain/memorize_session.dart';

/// Memorization mode's reveal by reciting: the tasmee's own session
/// (microphone, on-device recogniser, alignment engine) over the verses
/// being memorized; each word the engine reaches is revealed on the page.
/// Nothing is recorded or kept.
class MemorizeVoice extends ChangeNotifier {
  MemorizeVoice._(this._session, this._onWord) {
    _session.addListener(_changed);
  }

  final TasmeeSessionController _session;
  final void Function(MemoWord word) _onWord;
  final Set<int> _seen = {};
  bool _closed = false;

  TasmeePhase get phase => _session.phase;
  bool get listening => _session.phase == TasmeePhase.listening;

  /// Starts listening over [range]; null when the model is not on the
  /// device or the range has no words.
  static Future<MemorizeVoice?> open({
    required TasmeeBackend backend,
    required ContentDatabase db,
    required TasmeeSettings settings,
    required VerseRange range,
    required void Function(MemoWord word) onWord,
  }) async {
    final words = await TasmeeWordsRepository(db).expectedWords(range);
    if (words.isEmpty) return null;
    final session = TasmeeSessionController(
      request: TasmeeSessionRequest(
        range: range,
        words: words,
        mode: TasmeeMode.continuous,
        onError: ErrorBehavior.continueReading,
      ),
      backend: backend,
      onError: ErrorBehavior.continueReading,
      strictness: settings.strictness,
      toastSeconds: 0,
      vibration: false,
    );
    await session.load();
    if (!session.modelReady) {
      session.dispose();
      return null;
    }
    final voice = MemorizeVoice._(session, onWord);
    await session.listen();
    return voice;
  }

  void _changed() {
    if (_closed) return;
    for (final w in _session.words) {
      if (_seen.contains(w.index)) continue;
      if (_session.engine.statusOf(w.index) == WordStatus.hidden) continue;
      _seen.add(w.index);
      _onWord((w.surah, w.ayah, w.word));
    }
    notifyListeners();
  }

  Future<void> pause() => _session.pause();
  Future<void> resume() => _session.listen();

  /// Stops listening; words not reached stay hidden.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _session.removeListener(_changed);
    unawaited(_session.end().whenComplete(_session.dispose));
    dispose();
  }
}
