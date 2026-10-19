"""Word timings for the player: CTC forced alignment with the tasmee model.

The model is the same NVIDIA Arabic FastConformer CTC export the app uses
(`model.int8.onnx` + `tokens.txt` from the Tibyan mirror). We compute NeMo
style log-mel features, run the encoder once on CPU with onnxruntime, then
force-align the verse words (taken verbatim from `verses.py`, split on
spaces) with a Viterbi pass over the CTC lattice.

Optional: everything here is off unless ALIGNMENT_ENABLED=true and the model
files exist. onnxruntime / kaldi-native-fbank / numpy are imported lazily so
the app runs without them (see requirements-alignment.txt).
"""
from __future__ import annotations

import json
import logging
import threading
import time
import wave
from datetime import datetime, timezone
from pathlib import Path

from .config import settings

logger = logging.getLogger(__name__)

FRAME_SHIFT_MS = 10
_lock = threading.Lock()
_model = None  # (session, vocab, blank_id, subsampling)

# Uthmani letters with a plain equivalent in the model vocabulary.
_CHAR_MAP = {"ٱ": "ا"}  # alef wasla -> alef


def enabled() -> bool:
    return bool(settings.alignment_enabled) and model_files_present()


def model_files_present() -> bool:
    d = Path(settings.alignment_model_dir)
    return (d / "model.int8.onnx").is_file() and (d / "tokens.txt").is_file()


def load_vocab(path: Path) -> tuple[dict[str, int], int]:
    vocab: dict[str, int] = {}
    blank = -1
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        piece, _, idx = line.rpartition(" ")
        vocab[piece] = int(idx)
        if piece == "<blk>":
            blank = int(idx)
    if blank < 0:
        blank = max(vocab.values())
    return vocab, blank


def tokenize_word(word: str, vocab: dict[str, int]) -> list[int]:
    """Greedy longest-match SentencePiece-style pieces for one word.

    Characters the vocabulary does not know (Uthmani pause and small marks)
    are dropped; the word may end up with no tokens, then it gets a
    proportional position between its neighbours."""
    chars = {p for p in vocab if len(p) == 1}
    clean = "".join(_CHAR_MAP.get(c, c) for c in word)
    clean = "".join(c for c in clean if c in chars)
    if not clean:
        return []
    text = "▁" + clean
    out: list[int] = []
    i = 0
    max_len = max(len(p) for p in vocab)
    while i < len(text):
        for size in range(min(max_len, len(text) - i), 0, -1):
            piece = text[i : i + size]
            if piece in vocab and piece not in ("<unk>", "<blk>"):
                out.append(vocab[piece])
                i += size
                break
        else:
            i += 1  # lone "▁" not in vocab
    return out


def read_wav_16k(path: Path):
    import numpy as np

    with wave.open(str(path), "rb") as w:
        if w.getframerate() != 16000 or w.getnchannels() != 1 or w.getsampwidth() != 2:
            raise ValueError("expected 16 kHz mono 16-bit WAV")
        data = w.readframes(w.getnframes())
    return np.frombuffer(data, dtype="<i2").astype("float32") / 32768.0


def features(samples):
    """80-bin log-mel, NeMo-like settings, per-feature normalised."""
    import kaldi_native_fbank as knf
    import numpy as np

    opts = knf.FbankOptions()
    opts.frame_opts.samp_freq = 16000
    opts.frame_opts.dither = 0
    opts.frame_opts.snip_edges = False
    opts.frame_opts.remove_dc_offset = False
    opts.frame_opts.window_type = "hann"
    opts.mel_opts.num_bins = 80
    opts.mel_opts.low_freq = 0
    opts.mel_opts.high_freq = 8000
    fb = knf.OnlineFbank(opts)
    fb.accept_waveform(16000, samples.tolist())
    fb.input_finished()
    feats = np.stack([fb.get_frame(i) for i in range(fb.num_frames_ready)])
    mean = feats.mean(axis=0, keepdims=True)
    std = feats.std(axis=0, keepdims=True) + 1e-5
    return ((feats - mean) / std).astype("float32")


def _load():
    global _model
    if _model is None:
        import onnxruntime as ort

        d = Path(settings.alignment_model_dir)
        so = ort.SessionOptions()
        so.intra_op_num_threads = max(1, settings.alignment_threads)
        so.inter_op_num_threads = 1
        session = ort.InferenceSession(
            str(d / "model.int8.onnx"), so, providers=["CPUExecutionProvider"]
        )
        meta = session.get_modelmeta().custom_metadata_map
        vocab, blank = load_vocab(d / "tokens.txt")
        _model = (session, vocab, blank, int(meta.get("subsampling_factor", 8)))
    return _model


def log_probs(samples):
    import numpy as np

    session, _, _, _ = _load()
    feats = features(samples)
    out = session.run(
        None,
        {
            "audio_signal": feats.T[None, :, :],
            "length": np.array([feats.shape[0]], dtype="int64"),
        },
    )[0][0]
    return out


def ctc_force_align(logp, tokens: list[int], blank: int) -> list[int]:
    """Viterbi over the CTC lattice. Returns, per token, the first output
    frame where it is emitted. Raises ValueError when the audio is too short
    for the token sequence."""
    import numpy as np

    T = logp.shape[0]
    L = len(tokens)
    if L == 0:
        return []
    states = [blank]
    for tok in tokens:
        states += [tok, blank]
    S = len(states)
    st = np.array(states)
    # A state may skip the preceding blank when its token differs from the
    # token two states back.
    can_skip = np.zeros(S, dtype=bool)
    for s in range(2, S):
        can_skip[s] = st[s] != blank and st[s] != st[s - 2]
    neg = -1e30
    dp = np.full(S, neg, dtype="float64")
    back = np.zeros((T, S), dtype="int8")  # 0 stay, 1 from s-1, 2 from s-2
    dp[0] = logp[0, st[0]]
    if S > 1:
        dp[1] = logp[0, st[1]]
    for t in range(1, T):
        stay = dp
        one = np.concatenate(([neg], dp[:-1]))
        two = np.concatenate(([neg, neg], dp[:-2]))
        two = np.where(can_skip, two, neg)
        stacked = np.stack([stay, one, two])
        choice = stacked.argmax(axis=0)
        dp = stacked[choice, np.arange(S)] + logp[t, st]
        back[t] = choice
    end = S - 1 if dp[S - 1] >= dp[S - 2] else S - 2
    if dp[end] <= neg / 2:
        raise ValueError("audio too short for the text")
    path = np.empty(T, dtype=np.int64)
    s = end
    for t in range(T - 1, -1, -1):
        path[t] = s
        s -= int(back[t, s])
    first = [-1] * L
    for t in range(T):
        s = int(path[t])
        if s % 2 == 1:
            k = s // 2
            if first[k] < 0:
                first[k] = t
    return first


def proportional_words(words: list[str], duration_ms: int) -> list[dict]:
    """Fallback: share the clip by word length (letters), like the mockup."""
    weights = [max(1, len(w)) for w in words]
    total = sum(weights) or 1
    out, acc = [], 0
    for i, w in enumerate(weights):
        start = round(acc / total * duration_ms)
        acc += w
        end = round(acc / total * duration_ms)
        out.append({"index": i, "start_ms": start, "end_ms": end})
    return out


def align_words(samples, words: list[str]) -> list[dict]:
    session, vocab, blank, sub = _load()
    logp = log_probs(samples)
    frame_ms = FRAME_SHIFT_MS * sub
    duration_ms = int(len(samples) / 16)
    per_word = [tokenize_word(w, vocab) for w in words]
    flat = [t for toks in per_word for t in toks]
    firsts = ctc_force_align(logp, flat, blank)
    starts: list[int | None] = []
    k = 0
    for toks in per_word:
        starts.append(firsts[k] * frame_ms if toks else None)
        k += len(toks)
    # Words with no known letters: interpolate between neighbours.
    for i, s in enumerate(starts):
        if s is None:
            prev = next((starts[j] for j in range(i - 1, -1, -1) if starts[j] is not None), 0)
            nxt = next((starts[j] for j in range(i + 1, len(starts)) if starts[j] is not None), duration_ms)
            starts[i] = (prev + nxt) // 2
    out = []
    for i, s in enumerate(starts):
        end = starts[i + 1] if i + 1 < len(starts) else duration_ms
        out.append({"index": i, "start_ms": int(s), "end_ms": int(max(end, s))})
    return out


def run_for_recording(recording_id: int, session_factory=None) -> None:
    """Background task: align one recording and store its word timings."""
    from . import verses
    from .db import SessionLocal
    from .models import Recording

    if not enabled():
        return
    db = (session_factory or SessionLocal)()
    try:
        rec = db.get(Recording, recording_id)
        if rec is None or not rec.audio_path:
            return
        text = verses.ayah_range_text(rec.surah, rec.ayah, rec.ayah_end or rec.ayah) or ""
        words = text.split()
        rec.alignment_status = "running"
        db.commit()
        path = Path(settings.media_dir).resolve() / rec.audio_path
        try:
            started = time.perf_counter()
            with _lock:  # one alignment at a time per worker: bounded CPU
                timings = align_words(read_wav_16k(path), words)
            rec.word_timings = json.dumps(
                {"source": "ctc", "model": settings.model_name, "words": timings}
            )
            rec.alignment_status = "done"
            logger.info(
                "aligned recording %s (%d words) in %.2fs",
                recording_id, len(words), time.perf_counter() - started,
            )
        except Exception as exc:  # noqa: BLE001 — fall back to proportional
            logger.warning("alignment failed for %s: %s", recording_id, exc)
            rec.alignment_status = "failed"
        rec.aligned_at = datetime.now(timezone.utc).replace(tzinfo=None)
        db.commit()
    finally:
        db.close()


def word_timings(rec, words: list[str]) -> dict:
    """Timings for the player: stored CTC timings when done, otherwise the
    proportional fallback (status tells the client which)."""
    status = rec.alignment_status or ("pending" if enabled() else "off")
    if status == "done" and rec.word_timings:
        try:
            data = json.loads(rec.word_timings)
            if len(data.get("words", [])) == len(words):
                return {"source": "ctc", "status": "done", "words": data["words"]}
        except ValueError:
            pass
    return {
        "source": "proportional",
        "status": status,
        "words": proportional_words(words, rec.audio_duration_ms or 0),
    }


def backfill(limit: int = 0) -> int:
    """Align recordings that never finished (worker restarts lose queued
    background tasks). `python -m app.alignment [limit]`."""
    from .db import SessionLocal
    from .models import Recording

    if not enabled():
        raise SystemExit("ALIGNMENT_ENABLED is off or the model files are missing.")
    db = SessionLocal()
    try:
        query = (
            db.query(Recording.id)
            .filter(Recording.audio_path != "")
            .filter(
                (Recording.alignment_status.is_(None))
                | (Recording.alignment_status.in_(("pending", "running", "failed")))
            )
            .order_by(Recording.id)
        )
        ids = [row[0] for row in (query.limit(limit) if limit else query)]
    finally:
        db.close()
    for rid in ids:
        run_for_recording(rid)
    return len(ids)


if __name__ == "__main__":
    import sys

    logging.basicConfig(level=logging.INFO)
    print(backfill(int(sys.argv[1]) if len(sys.argv) > 1 else 0))
