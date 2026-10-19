"""Recording player, mistake annotations (tibyan.mistakes/1), peaks,
export and forced alignment. Synthetic tone audio only; verse text is a
fixture placeholder, never real Quran text."""
import io
import json
import math
import shutil
import struct
import tempfile
import unittest
import wave
from datetime import date, datetime, timedelta
from pathlib import Path
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from starlette.middleware.sessions import SessionMiddleware

from app import alignment, verses
from app import annotations as ann
from app.config import settings
from app.db import Base, migrate_annotation_columns
from app.deps import get_db
from app.export import build_export
from app.models import AnnotationMistake, AnnotationSet, Recording, User
from app.routes import admin, annotations, auth, pages, record, validate
from app.security import hash_password

from tests.test_platform_workflow import TEST_PASSWORD, csrf_from

VERSES = {
    "surahs": [{"number": 1, "name_ar": "سورة اختبار", "name_en": "Test", "ayah_count": 2}],
    "ayahs": [
        {"surah": 1, "number": 1, "text": "alpha beta gamma (1)"},
        {"surah": 1, "number": 2, "text": "delta epsilon (2)"},
    ],
}
# words: alpha beta gamma (1) delta epsilon (2) -> 7 words


def tone_wav(path: Path, seconds=2.0, rate=16000):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        frames = b"".join(
            struct.pack("<h", int(0.3 * 32767 * math.sin(2 * math.pi * 330 * i / rate)))
            for i in range(int(seconds * rate))
        )
        w.writeframes(frames)


class Base_(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.media = Path(self.tmp.name) / "media"
        (self.media / "recordings").mkdir(parents=True)
        self.old_media = settings.media_dir
        settings.media_dir = str(self.media)
        self.engine = create_engine(
            "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
        )
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine, autoflush=False)
        self.vp = patch.object(verses, "verses_data", return_value=VERSES)
        self.vp.start()
        self.app = FastAPI()
        self.app.add_middleware(SessionMiddleware, secret_key="test-only", same_site="lax", https_only=False)
        for r in (pages, auth, record, validate, admin, annotations):
            self.app.include_router(r.router)

        def override():
            db = self.Session()
            try:
                yield db
            finally:
                db.close()

        self.app.dependency_overrides[get_db] = override

    def tearDown(self):
        self.vp.stop()
        settings.media_dir = self.old_media
        self.engine.dispose()
        self.tmp.cleanup()

    def user(self, email, is_admin=False):
        with self.Session() as db:
            u = User(
                email=email, password_hash=hash_password(TEST_PASSWORD), birth_date=date(1990, 1, 1),
                consent_ccby=True, consent_version="t", is_admin=is_admin,
            )
            db.add(u)
            db.commit()
            return u.id

    def recording(self, owner, status="pending", seconds=2.0):
        with self.Session() as db:
            r = Recording(
                user_id=owner, surah=1, ayah=1, ayah_end=2, audio_path="",
                audio_duration_ms=int(seconds * 1000), status=status,
            )
            db.add(r)
            db.commit()
            r.audio_path = f"recordings/{r.id}.wav"
            db.commit()
            tone_wav(self.media / r.audio_path, seconds)
            return r.id

    def client(self, email):
        c = TestClient(self.app)
        page = c.get("/login")
        c.post("/login", data={"identifier": email, "password": TEST_PASSWORD, "csrf": csrf_from(page)})
        c.csrf = csrf_from(c.get("/record"))
        return c

    def save(self, c, rid, mistakes, base=0, token=None):
        return c.post(
            f"/recordings/{rid}/annotations",
            content=json.dumps({"base_version": base, "mistakes": mistakes}),
            headers={"Content-Type": "application/json", "X-CSRF-Token": c.csrf if token is None else token},
        )


SUB = {"word_index": 1, "type": "substitution", "start_ms": 300, "end_ms": 700, "said": "user text"}
TAJ = {"word_index": 4, "type": "tajweed", "subtype": "madd", "start_ms": 1200, "end_ms": 1500, "note": "short"}


class ModelsAndMigration(Base_):
    def test_tables_and_columns_exist(self):
        names = inspect(self.engine).get_table_names()
        for t in ("annotation_sets", "annotation_mistakes", "platform_settings"):
            self.assertIn(t, names)

    def test_additive_migration_on_old_table(self):
        eng = create_engine("sqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False})
        with eng.begin() as c:
            c.execute(text("CREATE TABLE recordings (id INTEGER PRIMARY KEY, status VARCHAR(16))"))
            c.execute(text("INSERT INTO recordings (id, status) VALUES (1, 'accepted')"))
        migrate_annotation_columns(eng)
        migrate_annotation_columns(eng)  # idempotent
        cols = {c["name"] for c in inspect(eng).get_columns("recordings")}
        self.assertTrue({"annotation_status", "has_mistakes", "alignment_status", "word_timings", "aligned_at"} <= cols)
        with eng.begin() as c:
            self.assertEqual(c.execute(text("SELECT status FROM recordings")).scalar(), "accepted")

    def test_words_come_from_verses_split_on_spaces(self):
        owner = self.user("o@x.test")
        rid = self.recording(owner)
        with self.Session() as db:
            words = ann.words_for(db.get(Recording, rid))
        self.assertEqual([w["text"] for w in words], "alpha beta gamma (1) delta epsilon (2)".split())
        self.assertEqual([w["ayah"] for w in words], [1, 1, 1, 1, 2, 2, 2])


class Validation(unittest.TestCase):
    def test_rules(self):
        ok = ann.clean_mistakes([SUB, TAJ, {"word_index": 7, "type": "insertion", "start_ms": 0, "end_ms": 100}], 7, 2000, "reciter")
        self.assertEqual(ok[0]["said"], "user text")
        self.assertEqual(ok[1]["subtype"], "madd")
        self.assertIsNone(ok[0]["review"])
        bad = [
            ({**SUB, "type": "nope"}, "bad_type"),
            ({**SUB, "word_index": 7}, "bad_word"),       # insertion only may use slot == count
            ({**SUB, "word_index": True}, "bad_word"),
            ({**SUB, "start_ms": 700, "end_ms": 700}, "bad_time"),
            ({**SUB, "end_ms": 9000}, "bad_time"),
            ({**TAJ, "subtype": "x"}, "bad_subtype"),
            ({**SUB, "note": "n" * 501}, "bad_note"),
            ({**SUB, "said": "s" * 201}, "bad_said"),
        ]
        for item, code in bad:
            with self.assertRaises(ann.AnnotationError) as e:
                ann.clean_mistakes([item], 7, 2000, "reciter")
            self.assertEqual(str(e.exception), code)
        # said is dropped for non-substitution; subtype dropped for non-tajweed
        out = ann.clean_mistakes([{**TAJ, "type": "haraka", "said": "x"}], 7, 2000, "reciter")[0]
        self.assertIsNone(out["subtype"])
        self.assertIsNone(out["said"])
        with self.assertRaises(ann.AnnotationError):
            ann.clean_mistakes([SUB] * 301, 7, 2000, "reciter")
        rv = ann.clean_mistakes([{**SUB, "marked_by": "reciter", "review": "not_mistake"}], 7, 2000, "reviewer")
        self.assertEqual(rv[0]["review"], "not_mistake")
        with self.assertRaises(ann.AnnotationError):
            ann.clean_mistakes([{**SUB, "review": "maybe"}], 7, 2000, "reviewer")


class ApiAndStateMachine(Base_):
    def setUp(self):
        super().setUp()
        self.owner = self.user("owner@x.test")
        self.rev1 = self.user("rev1@x.test")
        self.rev2 = self.user("rev2@x.test")
        self.adm = self.user("admin@x.test", is_admin=True)
        self.rid = self.recording(self.owner)

    def test_auth_csrf_and_permissions(self):
        anon = TestClient(self.app)
        self.assertEqual(anon.get(f"/recordings/{self.rid}/annotations.json").status_code, 401)
        self.assertEqual(anon.post(f"/recordings/{self.rid}/annotations", json={}).status_code, 401)
        o = self.client("owner@x.test")
        self.assertEqual(self.save(o, self.rid, [SUB], token="wrong").status_code, 403)
        # accepted recording with reviewed marks: an outsider may not view or save
        with self.Session() as db:
            db.get(Recording, self.rid).status = "accepted"
            db.commit()
        out = self.client("rev1@x.test")
        self.assertEqual(out.get(f"/recordings/{self.rid}/annotations.json").status_code, 404)
        self.assertEqual(self.save(out, self.rid, [SUB]).status_code, 403)
        self.assertEqual(out.get(f"/recordings/{self.rid}/peaks.json").status_code, 404)
        self.assertEqual(out.get(f"/recordings/{self.rid}", follow_redirects=False).headers["location"], "/dashboard")
        # the owner and an admin may
        self.assertEqual(o.get(f"/recordings/{self.rid}").status_code, 200)
        a = self.client("admin@x.test")
        self.assertEqual(a.get(f"/recordings/{self.rid}/annotations.json").status_code, 200)

    def test_validation_and_body_limits(self):
        o = self.client("owner@x.test")
        self.assertEqual(self.save(o, self.rid, [{**SUB, "type": "x"}]).status_code, 422)
        r = o.post(f"/recordings/{self.rid}/annotations", content=b"{not json",
                   headers={"X-CSRF-Token": o.csrf, "Content-Type": "application/json"})
        self.assertEqual(r.status_code, 400)
        big = json.dumps({"base_version": 0, "mistakes": [], "pad": "x" * (ann.MAX_BODY_BYTES + 1)})
        r = o.post(f"/recordings/{self.rid}/annotations", content=big,
                   headers={"X-CSRF-Token": o.csrf, "Content-Type": "application/json"})
        self.assertEqual(r.status_code, 413)

    def test_rate_limit(self):
        o = self.client("owner@x.test")
        old = settings.annotation_saves_per_minute
        settings.annotation_saves_per_minute = 2
        try:
            self.assertEqual(self.save(o, self.rid, [SUB], 0).status_code, 201)
            self.assertEqual(self.save(o, self.rid, [SUB], 1).status_code, 201)
            self.assertEqual(self.save(o, self.rid, [SUB], 2).status_code, 429)
        finally:
            settings.annotation_saves_per_minute = old

    def test_full_state_machine(self):
        o = self.client("owner@x.test")
        # 1. reciter saves -> pending_review, has_mistakes
        r = self.save(o, self.rid, [SUB, TAJ])
        self.assertEqual(r.status_code, 201, r.text)
        self.assertEqual(r.json()["version"], 1)
        self.assertEqual(r.json()["annotation_status"], "pending_review")
        self.assertTrue(r.json()["has_mistakes"])
        # stale base -> 409
        self.assertEqual(self.save(o, self.rid, [SUB], base=0).status_code, 409)

        # 2. reviewer 1: reject one reciter mark, add one
        r1 = self.client("rev1@x.test")
        page = r1.get("/validate")
        self.assertIn("player-data", page.text)
        reviewed = [
            {**SUB, "marked_by": "reciter", "review": "confirmed"},
            {**TAJ, "marked_by": "reciter", "review": "not_mistake"},
            {"word_index": 5, "type": "haraka", "start_ms": 1500, "end_ms": 1700},
        ]
        r = self.save(r1, self.rid, reviewed, base=1)
        self.assertEqual(r.status_code, 201, r.text)
        self.assertEqual((r.json()["version"], r.json()["author_role"], r.json()["mistake_count"]), (2, "reviewer", 2))
        self.assertEqual(r.json()["annotation_status"], "reviewed")

        # 3. reviewer 2 says no mistakes at all -> latest reviewer wins
        r2 = self.client("rev2@x.test")
        r = self.save(r2, self.rid, [{**SUB, "marked_by": "reciter", "review": "not_mistake"}], base=2)
        self.assertEqual(r.json()["mistake_count"], 0)
        self.assertFalse(r.json()["has_mistakes"])
        with self.Session() as db:
            self.assertEqual(ann.authoritative_set(db, self.rid).version, 3)
            self.assertEqual(len(ann.history(db, self.rid)), 3)  # history kept

        # 4. audio accepted by votes, annotations unchanged
        for c in (r1, r2):
            c.post(f"/validate/{self.rid}", data={"verdict": "accept", "csrf": c.csrf})
        with self.Session() as db:
            rec = db.get(Recording, self.rid)
            self.assertEqual((rec.status, rec.annotation_status), ("accepted", "reviewed"))

        # 5. reciter edits after review -> back to review, audio stays accepted
        r = self.save(o, self.rid, [SUB], base=3)
        self.assertEqual(r.json()["annotation_status"], "pending_review")
        self.assertTrue(r.json()["has_mistakes"])  # pending claim keeps it out of clean data
        with self.Session() as db:
            rec = db.get(Recording, self.rid)
            self.assertEqual(rec.status, "accepted")
            # authoritative stays the latest reviewer version until re-review
            self.assertEqual(ann.authoritative_set(db, self.rid).version, 3)

        # 6. it reappears in /validate (marks only, no voting) for reviewers
        page = r1.get("/validate").text
        self.assertIn(f'/recordings/{self.rid}/annotations', page)
        self.assertNotIn(f'action="/validate/{self.rid}"', page)
        r = self.save(r1, self.rid, [{**SUB, "marked_by": "reciter", "review": "confirmed"}], base=4)
        self.assertEqual(r.json()["annotation_status"], "reviewed")
        # reviewed the latest -> no longer offered to rev1
        self.assertNotIn(f"/recordings/{self.rid}/annotations", r1.get("/validate").text)

        # 7. JSON document
        doc = o.get(f"/recordings/{self.rid}/annotations.json").json()
        self.assertEqual(doc["schema"], "tibyan.mistakes/1")
        self.assertEqual(doc["version"]["number"], 5)
        self.assertTrue(doc["version"]["authoritative"])
        self.assertEqual(len(doc["words"]), 7)
        self.assertEqual(doc["words"][0]["text"], "alpha")
        self.assertEqual(doc["word_timing"]["source"], "proportional")
        self.assertEqual([h["author_role"] for h in doc["history"]], ["reciter", "reviewer", "reviewer", "reciter", "reviewer"])
        old = o.get(f"/recordings/{self.rid}/annotations.json?version=2&download=1")
        self.assertIn("tibyan-rec-%d-mistakes-v2.json" % self.rid, old.headers["content-disposition"])
        self.assertEqual(len(old.json()["rejected"]), 1)
        self.assertEqual(o.get(f"/recordings/{self.rid}/annotations.json?version=99").status_code, 404)

    def test_owner_cannot_review_or_vote_own(self):
        o = self.client("owner@x.test")
        self.assertNotIn(f"/recordings/{self.rid}/annotations", o.get("/validate").text)

    def test_delete_removes_annotations(self):
        o = self.client("owner@x.test")
        self.save(o, self.rid, [SUB])
        o.get(f"/recordings/{self.rid}/peaks.json")
        self.assertTrue((self.media / "peaks" / f"{self.rid}.json").is_file())
        o.post(f"/recordings/{self.rid}/delete", data={"csrf": o.csrf})
        with self.Session() as db:
            self.assertEqual(db.query(AnnotationSet).count(), 0)
            self.assertEqual(db.query(AnnotationMistake).count(), 0)
        self.assertFalse((self.media / "peaks" / f"{self.rid}.json").exists())


class PeaksAndPages(Base_):
    def test_peaks_and_pages(self):
        owner = self.user("owner@x.test")
        rid = self.recording(owner, seconds=1.5)
        o = self.client("owner@x.test")
        p = o.get(f"/recordings/{rid}/peaks.json").json()
        self.assertEqual(p["duration_ms"], 1500)
        self.assertEqual(len(p["peaks"]), 800)
        self.assertAlmostEqual(max(p["peaks"]), 1.0)
        page = o.get(f"/recordings/{rid}?new=1")
        self.assertEqual(page.status_code, 200)
        self.assertIn('data-start-mode="mark"', page.text)
        self.assertIn("/static/vendor/wavesurfer/wavesurfer.min.js", page.text)
        self.assertNotIn("unpkg", page.text)
        self.assertNotIn("cdn.jsdelivr", page.text)
        dash = o.get("/dashboard").text
        self.assertIn(f'data-id="{rid}"', dash)
        self.assertIn(f'href="/recordings/{rid}"', dash)

    def test_vendor_license_shipped(self):
        root = Path(__file__).resolve().parents[1] / "app" / "static" / "vendor" / "wavesurfer"
        self.assertIn("BSD 3-Clause", (root / "LICENSE").read_text())
        for f in ("wavesurfer.min.js", "regions.min.js"):
            self.assertTrue((root / f).is_file())

    def test_english_strings(self):
        owner = self.user("owner@x.test")
        rid = self.recording(owner)
        o = self.client("owner@x.test")
        o.cookies.set("lang", "en")
        self.assertIn("Mark a mistake", o.get(f"/recordings/{rid}").text)


@unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"), "needs ffmpeg")
class RecordFlow(Base_):
    def test_upload_redirects_to_player_and_queues_alignment(self):
        self.user("owner@x.test")
        o = self.client("owner@x.test")
        buf = io.BytesIO()
        tone_wav(Path(self.tmp.name) / "in.wav", 1.2)
        data = (Path(self.tmp.name) / "in.wav").read_bytes()
        with patch.object(alignment, "enabled", return_value=True), \
             patch.object(alignment, "run_for_recording") as run:
            r = o.post("/record", data={"surah": "1", "ayah": "1", "ayah_end": "2", "csrf": o.csrf},
                       files={"audio": ("t.wav", data, "audio/wav")}, follow_redirects=False)
        self.assertEqual(r.status_code, 303)
        with self.Session() as db:
            rec = db.query(Recording).one()
            self.assertEqual(rec.alignment_status, "pending")
        self.assertEqual(r.headers["location"], f"/recordings/{rec.id}?new=1")
        run.assert_called_once_with(rec.id)
        del buf


class Export(Base_):
    def test_export_annotations_and_split(self):
        owner = self.user("owner@x.test")
        clean = self.recording(owner, "accepted")
        marked = self.recording(owner, "accepted")
        plain = self.recording(owner, "accepted")
        with self.Session() as db:
            u = db.get(User, owner)
            ann.save_version(db, db.get(Recording, clean), u, "reciter", [], 0)
            ann.save_version(db, db.get(Recording, marked), u, "reciter",
                             ann.clean_mistakes([SUB], 7, 2000, "reciter"), 0)
            build_export(db)
        root = self.media / "export"
        rows = [json.loads(l) for l in (root / "manifest.jsonl").read_text().splitlines()]
        mrows = [json.loads(l) for l in (root / "manifest_mistakes.jsonl").read_text().splitlines()]
        self.assertEqual(sorted(r["audio_filepath"] for r in rows), sorted([f"wavs/{clean}.wav", f"wavs/{plain}.wav"]))
        self.assertEqual(mrows[0]["annotation_file"], f"annotations/{marked}.json")
        self.assertTrue(mrows[0]["has_mistakes"])
        self.assertNotIn("annotation_file", next(r for r in rows if r["audio_filepath"] == f"wavs/{plain}.wav"))
        doc = json.loads((root / "annotations" / f"{marked}.json").read_text())
        self.assertEqual(doc["schema"], "tibyan.mistakes/1")
        sums = (root / "SHA256SUMS").read_text()
        self.assertIn(f"annotations/{marked}.json", sums)
        self.assertIn(f"annotations/{clean}.json", sums)

        # admin turns the split off -> everything in the clean manifest
        self.user("admin@x.test", is_admin=True)
        a = self.client("admin@x.test")
        r = a.post("/admin/settings/mistakes-split", data={"csrf": a.csrf}, follow_redirects=False)
        self.assertEqual(r.status_code, 303)
        with self.Session() as db:
            self.assertFalse(ann.mistakes_split(db))
            build_export(db)
        self.assertEqual(len((root / "manifest.jsonl").read_text().splitlines()), 3)
        self.assertFalse((root / "manifest_mistakes.jsonl").exists())

    def test_non_admin_cannot_change_split(self):
        self.user("v@x.test")
        v = self.client("v@x.test")
        r = v.post("/admin/settings/mistakes-split", data={"csrf": v.csrf, "enabled": "0"}, follow_redirects=False)
        self.assertEqual(r.headers["location"], "/dashboard")


class Alignment(Base_):
    VOCAB = {"<unk>": 0, "a": 1, "b": 2, "▁": 3, "▁a": 4, "▁b": 5, "ab": 6, "<blk>": 7}

    def test_tokenize(self):
        self.assertEqual(alignment.tokenize_word("ab", self.VOCAB), [4, 2])
        self.assertEqual(alignment.tokenize_word("ba", self.VOCAB), [5, 1])
        self.assertEqual(alignment.tokenize_word("(1)", self.VOCAB), [])

    def test_force_align_on_synthetic_lattice(self):
        import numpy as np

        # 12 frames: blank, A x3, blank, blank, B x2, blank, A, blank, blank
        frames = [7, 4, 4, 4, 7, 7, 5, 5, 7, 4, 7, 7]
        logp = np.full((12, 8), -10.0)
        for t, k in enumerate(frames):
            logp[t, k] = -0.01
        self.assertEqual(alignment.ctc_force_align(logp, [4, 5, 4], 7), [1, 6, 9])
        with self.assertRaises(ValueError):
            alignment.ctc_force_align(logp[:2], [4, 5, 4], 7)

    def test_align_words_and_background_task(self):
        import numpy as np

        frames = [7, 4, 7, 7, 5, 7, 7, 7]  # word0 at frame 1, word2 at frame 4
        logp = np.full((8, 8), -10.0)
        for t, k in enumerate(frames):
            logp[t, k] = -0.01
        samples = np.zeros(16000, dtype="float32")  # 1000 ms
        with patch.object(alignment, "_load", return_value=(None, self.VOCAB, 7, 8)), \
             patch.object(alignment, "log_probs", return_value=logp):
            out = alignment.align_words(samples, ["a", "(1)", "b"])
        self.assertEqual([w["start_ms"] for w in out], [80, 200, 320])
        self.assertEqual(out[-1]["end_ms"], 1000)

        owner = self.user("o@x.test")
        rid = self.recording(owner)
        fake = [{"index": i, "start_ms": i * 100, "end_ms": i * 100 + 100} for i in range(7)]
        with patch.object(alignment, "enabled", return_value=True), \
             patch.object(alignment, "align_words", return_value=fake):
            alignment.run_for_recording(rid, session_factory=self.Session)
        with self.Session() as db:
            rec = db.get(Recording, rid)
            self.assertEqual(rec.alignment_status, "done")
            words = [w["text"] for w in ann.words_for(rec)]
            self.assertEqual(alignment.word_timings(rec, words)["source"], "ctc")
        with patch.object(alignment, "enabled", return_value=True), \
             patch.object(alignment, "align_words", side_effect=ValueError("short")):
            alignment.run_for_recording(rid, session_factory=self.Session)
        with self.Session() as db:
            rec = db.get(Recording, rid)
            self.assertEqual(rec.alignment_status, "failed")
            t = alignment.word_timings(rec, ["x"] * 7)
            self.assertEqual(t["source"], "proportional")
            self.assertEqual(t["words"][-1]["end_ms"], 2000)

    def test_disabled_by_default(self):
        self.assertFalse(settings.alignment_enabled)
        self.assertFalse(alignment.enabled())


if __name__ == "__main__":
    unittest.main()
