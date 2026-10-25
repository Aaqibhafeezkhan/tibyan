from __future__ import annotations

import unittest
from datetime import timedelta

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from starlette.middleware.sessions import SessionMiddleware

from app import group_khatma as gk
from app import ratelimit
from app.db import Base
from app.deps import get_db
from app.models import GroupKhatma, GroupKhatmaPart
from app.routes import khatma, pages


class GroupKhatmaTests(unittest.TestCase):
    def setUp(self):
        ratelimit.reset()
        gk.reset_cleanup_clock()
        self.engine = create_engine(
            "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
        )
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine, autoflush=False)
        app = FastAPI()
        app.add_middleware(SessionMiddleware, secret_key="test-only", https_only=False)
        app.include_router(khatma.router)
        app.include_router(pages.router)

        def override_get_db():
            db = self.Session()
            try:
                yield db
            finally:
                db.close()

        app.dependency_overrides[get_db] = override_get_db
        self.client = TestClient(app, base_url="https://altibyan.app")

    def tearDown(self):
        ratelimit.reset()

    def create(self, **body):
        r = self.client.post("/api/k", json=body)
        self.assertEqual(r.status_code, 201, r.text)
        return r.json()

    def claim(self, kid, n, name="Ahmed"):
        return self.client.post(f"/api/k/{kid}/parts/{n}/claim", json={"name": name})

    # ---------- create ----------
    def test_create_defaults_to_30_juz_with_unguessable_id(self):
        body = self.create(title="  ختمة رمضان ", organizer="أحمد")
        k = body["khatma"]
        self.assertEqual(k["parts_count"], 30)
        self.assertEqual(len(k["parts"]), 30)
        self.assertEqual(k["title"], "ختمة رمضان")
        self.assertEqual(k["url"], f"https://altibyan.app/k/{k['id']}")
        self.assertGreaterEqual(len(k["id"]), 22)
        self.assertRegex(k["id"], r"^[A-Za-z0-9_-]+$")
        self.assertGreaterEqual(len(body["organizer_secret"]), 40)
        # Only the hash is stored.
        with self.Session() as db:
            row = db.get(GroupKhatma, k["id"])
            self.assertNotEqual(row.organizer_hash, body["organizer_secret"])
            self.assertEqual(row.organizer_hash, gk.hash_secret(body["organizer_secret"]))

    def test_create_hizb_and_target_date(self):
        target = (gk.now().date() + timedelta(days=20)).isoformat()
        k = self.create(unit="hizb", target_date=target)["khatma"]
        self.assertEqual(k["parts_count"], 60)
        self.assertEqual(k["target_date"], target)

    def test_create_validation(self):
        for body in (
            {"unit": "page"},
            {"title": "x" * 81},
            {"organizer": "y" * 41},
            {"target_date": "tomorrow"},
            {"target_date": "1990-01-01"},
            {"title": 5},
        ):
            r = self.client.post("/api/k", json=body)
            self.assertEqual(r.status_code, 422, body)
        self.assertEqual(self.client.post("/api/k", content="[]").status_code, 400)
        self.assertEqual(self.client.post("/api/k", content="x" * 5000).status_code, 413)

    def test_create_is_rate_limited(self):
        for _ in range(10):
            self.create()
        r = self.client.post("/api/k", json={})
        self.assertEqual(r.status_code, 429)
        self.assertEqual(r.json()["error"], "rate_limited")

    def test_no_cors_headers(self):
        r = self.client.post("/api/k", json={}, headers={"Origin": "https://evil.example"})
        self.assertNotIn("access-control-allow-origin", r.headers)

    # ---------- claim / done / release ----------
    def test_claim_done_flow(self):
        k = self.create()["khatma"]
        r = self.claim(k["id"], 3, "  فاطمة  ")
        self.assertEqual(r.status_code, 200)
        secret = r.json()["part_secret"]
        part = r.json()["khatma"]["parts"][2]
        self.assertEqual((part["state"], part["name"]), ("taken", "فاطمة"))
        self.assertEqual(r.json()["khatma"]["taken"], 1)

        # Taken parts cannot be claimed again.
        self.assertEqual(self.claim(k["id"], 3, "Other").status_code, 409)

        # Done needs the part's secret.
        self.assertEqual(
            self.client.post(f"/api/k/{k['id']}/parts/3/done").status_code, 403
        )
        self.assertEqual(
            self.client.post(
                f"/api/k/{k['id']}/parts/3/done", headers={"X-Khatma-Secret": "wrong"}
            ).status_code,
            403,
        )
        r = self.client.post(
            f"/api/k/{k['id']}/parts/3/done", headers={"X-Khatma-Secret": secret}
        )
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["done"], 1)
        self.assertEqual(r.json()["parts"][2]["state"], "done")

        r = self.client.post(
            f"/api/k/{k['id']}/parts/3/undone", headers={"X-Khatma-Secret": secret}
        )
        self.assertEqual(r.json()["parts"][2]["state"], "taken")

        # The claimer releases.
        r = self.client.post(
            f"/api/k/{k['id']}/parts/3/release", headers={"X-Khatma-Secret": secret}
        )
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["parts"][2], {**r.json()["parts"][2], "state": "open", "name": None})

    def test_claim_validation(self):
        k = self.create()["khatma"]
        self.assertEqual(self.claim(k["id"], 1, "   ").status_code, 422)
        self.assertEqual(self.claim(k["id"], 1, "n" * 41).status_code, 422)
        self.assertEqual(self.claim(k["id"], 1, "n" * 40).status_code, 200)
        self.assertEqual(self.claim(k["id"], 31, "A").status_code, 404)
        self.assertEqual(self.claim(k["id"], 0, "A").status_code, 404)
        self.assertEqual(self.claim("nope", 1, "A").status_code, 404)
        # Control characters are dropped.
        r = self.claim(k["id"], 2, "Ali\u0000‮")
        self.assertEqual(r.json()["khatma"]["parts"][1]["name"], "Ali")

    def test_claim_is_rate_limited(self):
        k = self.create(unit="hizb")["khatma"]
        for n in range(1, 31):
            self.assertEqual(self.claim(k["id"], n).status_code, 200)
        self.assertEqual(self.claim(k["id"], 31).status_code, 429)

    def test_completion_sets_completed_at(self):
        k = self.create()["khatma"]
        secrets = {}
        for n in range(1, 31):
            secrets[n] = self.claim(k["id"], n).json()["part_secret"]
            ratelimit.reset()
        for n, s in secrets.items():
            r = self.client.post(
                f"/api/k/{k['id']}/parts/{n}/done", headers={"X-Khatma-Secret": s}
            )
        self.assertIsNotNone(r.json()["completed_at"])
        self.assertEqual(r.json()["done"], 30)
        r = self.client.post(
            f"/api/k/{k['id']}/parts/1/undone", headers={"X-Khatma-Secret": secrets[1]}
        )
        self.assertIsNone(r.json()["completed_at"])

    # ---------- organizer ----------
    def test_organizer_actions(self):
        body = self.create(title="A")
        kid, org = body["khatma"]["id"], body["organizer_secret"]
        part_secret = self.claim(kid, 5, "Sara").json()["part_secret"]

        # A part secret is not an organizer secret.
        self.assertEqual(
            self.client.patch(
                f"/api/k/{kid}", json={"title": "B"}, headers={"X-Khatma-Secret": part_secret}
            ).status_code,
            403,
        )
        r = self.client.patch(
            f"/api/k/{kid}", json={"title": "B"}, headers={"X-Khatma-Secret": org}
        )
        self.assertEqual(r.json()["title"], "B")

        # The organizer releases anyone's part.
        r = self.client.post(
            f"/api/k/{kid}/parts/5/release", headers={"X-Khatma-Secret": org}
        )
        self.assertEqual(r.json()["parts"][4]["state"], "open")
        # The old claimer's secret no longer works.
        self.assertEqual(
            self.client.post(
                f"/api/k/{kid}/parts/5/done", headers={"X-Khatma-Secret": part_secret}
            ).status_code,
            403,
        )
        # Organizer cannot mark someone's part done.
        self.claim(kid, 6, "Omar")
        self.assertEqual(
            self.client.post(
                f"/api/k/{kid}/parts/6/done", headers={"X-Khatma-Secret": org}
            ).status_code,
            403,
        )

        self.assertEqual(
            self.client.delete(f"/api/k/{kid}", headers={"X-Khatma-Secret": "x"}).status_code,
            403,
        )
        self.assertEqual(
            self.client.delete(f"/api/k/{kid}", headers={"X-Khatma-Secret": org}).status_code,
            204,
        )
        self.assertEqual(self.client.get(f"/api/k/{kid}").status_code, 404)
        with self.Session() as db:
            self.assertEqual(db.query(GroupKhatmaPart).count(), 0)

    # ---------- retention ----------
    def test_cleanup_deletes_expired(self):
        old = self.create()["khatma"]["id"]
        done = self.create()["khatma"]["id"]
        fresh = self.create()["khatma"]["id"]
        at = gk.now()
        with self.Session() as db:
            db.get(GroupKhatma, old).last_activity_at = at - timedelta(days=181)
            row = db.get(GroupKhatma, done)
            row.completed_at = at - timedelta(days=31)
            db.commit()
            self.assertEqual(gk.cleanup(db), 2)
            self.assertIsNone(db.get(GroupKhatma, old))
            self.assertIsNone(db.get(GroupKhatma, done))
            self.assertIsNotNone(db.get(GroupKhatma, fresh))
            self.assertEqual(db.query(GroupKhatmaPart).count(), 30)

    def test_expired_khatma_is_gone_on_read(self):
        kid = self.create()["khatma"]["id"]
        with self.Session() as db:
            db.get(GroupKhatma, kid).last_activity_at = gk.now() - timedelta(days=200)
            db.commit()
        gk.reset_cleanup_clock()
        self.assertEqual(self.client.get(f"/api/k/{kid}").status_code, 404)
        with self.Session() as db:
            self.assertIsNone(db.get(GroupKhatma, kid))

    def test_activity_keeps_it_alive(self):
        kid = self.create()["khatma"]["id"]
        with self.Session() as db:
            db.get(GroupKhatma, kid).last_activity_at = gk.now() - timedelta(days=170)
            db.commit()
        self.claim(kid, 1)
        with self.Session() as db:
            self.assertLess(gk.now() - db.get(GroupKhatma, kid).last_activity_at, timedelta(minutes=1))

    # ---------- web ----------
    def test_page_and_association_files(self):
        k = self.create(title="</script><b>x")["khatma"]
        self.claim(k["id"], 1, "</script>")
        r = self.client.get(f"/k/{k['id']}")
        self.assertEqual(r.status_code, 200)
        self.assertIn("noindex", r.headers["x-robots-tag"])
        self.assertNotIn("</script><b>", r.text)
        self.assertIn("ختمة جماعية", r.text)
        self.assertIn("Group khatma", self.client.get(f"/k/{k['id']}?lang=en").text)
        self.assertEqual(self.client.get("/k/missing").status_code, 404)

        aasa = self.client.get("/.well-known/apple-app-site-association").json()
        detail = aasa["applinks"]["details"][0]
        self.assertEqual(detail["appIDs"], ["T958VWM76Z.app.tibyan.tibyan"])
        self.assertEqual(detail["components"][0]["/"], "/k/*")
        links = self.client.get("/.well-known/assetlinks.json").json()
        self.assertEqual(links[0]["target"]["package_name"], "app.tibyan.tibyan")
        self.assertEqual(len(links[0]["target"]["sha256_cert_fingerprints"]), 2)


if __name__ == "__main__":
    unittest.main()
