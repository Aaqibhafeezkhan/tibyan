from __future__ import annotations

import json
import unittest
from datetime import date
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from starlette.middleware.sessions import SessionMiddleware

from app.config import settings
from app.db import Base
from app.deps import get_db
from app.models import AppReport, Notification, User
from app.routes import admin_requests, auth, reports
from app.security import hash_password
from test_platform_workflow import csrf_from

PASSWORD = "test-only-password-42"
VALID = {
    "type": "bug",
    "description": "The audio stops after the third ayah.",
    "phone": "+20 100-123 4567",
    "email": "Someone@Example.test",
    "app_version": "1.4.0+12",
    "platform": "android",
    "os_version": "14",
    "client_id": "abc-123",
    "website": "",
}


class AppReportTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
        )
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine, autoflush=False)
        self.app = FastAPI()
        self.app.add_middleware(SessionMiddleware, secret_key="test-only", https_only=False)
        for router in (auth.router, admin_requests.router, reports.router):
            self.app.include_router(router)

        def override_get_db():
            db = self.Session()
            try:
                yield db
            finally:
                db.close()

        self.app.dependency_overrides[get_db] = override_get_db
        self.saved = {
            k: getattr(settings, k)
            for k in ("smtp_host", "smtp_from", "smtp_to", "admin_report_email")
        }

    def tearDown(self):
        for k, v in self.saved.items():
            setattr(settings, k, v)
        self.engine.dispose()

    def client(self, ip="203.0.113.7"):
        return TestClient(self.app, client=(ip, 50000))

    def post(self, c, body=None, **extra):
        payload = dict(VALID if body is None else body, **extra)
        return c.post("/api/reports", json=payload)

    def count(self):
        with self.Session() as db:
            return db.query(AppReport).count()

    # -- storage ------------------------------------------------------------
    def test_valid_report_is_stored(self):
        with patch.object(reports, "send_mail", return_value=False):
            with self.client() as c:
                r = self.post(c)
        self.assertEqual(r.status_code, 201)
        with self.Session() as db:
            row = db.get(AppReport, r.json()["id"])
            self.assertEqual(row.type, "bug")
            self.assertEqual(row.email, "someone@example.test")
            self.assertEqual(row.phone, "+20 100-123 4567")
            self.assertEqual(row.platform, "android")
            self.assertNotIn("203.0.113.7", row.ip_hash)
            self.assertIsNone(row.handled_at)

    def test_optional_fields_may_be_missing(self):
        with patch.object(reports, "send_mail", return_value=False):
            with self.client() as c:
                r = self.post(c, {"type": "suggestion", "description": "Add dark mode"})
        self.assertEqual(r.status_code, 201)

    # -- validation ---------------------------------------------------------
    def test_validation_errors(self):
        cases = [
            {"type": "spam"},
            {"description": "hey"},
            {"description": "x" * 4001},
            {"description": None},
            {"phone": "call me 0100"},
            {"phone": "1" * 33},
            {"email": "not-an-email"},
            {"email": "a@" + "b" * 250 + ".com"},
            {"app_version": "v" * 65},
            {"platform": "p" * 65},
        ]
        with self.client() as c:
            for extra in cases:
                with self.subTest(extra=extra):
                    self.assertEqual(self.post(c, **extra).status_code, 422)
            self.assertEqual(c.post("/api/reports", content=b"not json").status_code, 422)
        self.assertEqual(self.count(), 0)

    def test_oversized_body_is_413(self):
        with self.client() as c:
            r = c.post(
                "/api/reports",
                content=json.dumps(dict(VALID, client_id="x" * 20000)),
                headers={"content-type": "application/json"},
            )
        self.assertEqual(r.status_code, 413)
        self.assertEqual(self.count(), 0)

    # -- honeypot -----------------------------------------------------------
    def test_honeypot_looks_successful_but_is_not_stored(self):
        with patch.object(reports, "send_mail") as mail:
            with self.client() as c:
                r = self.post(c, website="http://spam.example")
        self.assertEqual(r.status_code, 202)
        self.assertEqual(self.count(), 0)
        mail.assert_not_called()

    # -- rate limit ---------------------------------------------------------
    def test_rate_limit_per_ip(self):
        with patch.object(reports, "send_mail", return_value=False):
            with self.client("198.51.100.1") as c:
                codes = [self.post(c).status_code for _ in range(6)]
            with self.client("198.51.100.2") as other:
                other_code = self.post(other).status_code
        self.assertEqual(codes, [201] * 5 + [429])
        self.assertEqual(other_code, 201)
        self.assertEqual(self.count(), 6)

    def test_daily_limit(self):
        with self.client("198.51.100.9") as c:
            ip_hash = reports._ip_hash(type("R", (), {"client": type("C", (), {"host": "198.51.100.9"})})())
            with self.Session() as db:
                from datetime import timedelta
                old = reports.utcnow() - timedelta(hours=2)
                for _ in range(30):
                    db.add(AppReport(type="other", description="older", ip_hash=ip_hash, created_at=old))
                db.commit()
            self.assertEqual(self.post(c).status_code, 429)

    # -- email ---------------------------------------------------------------
    def test_email_sent_to_admin_report_address(self):
        settings.smtp_host = "smtp.example.test"
        settings.smtp_from = "Tibyan <no-reply@example.test>"
        settings.admin_report_email = "reports@example.test"
        with patch.object(reports, "send_mail", return_value=True) as mail:
            with self.client() as c:
                r = self.post(c)
        self.assertEqual(r.status_code, 201)
        mail.assert_called_once()
        kwargs = mail.call_args.kwargs
        self.assertEqual(kwargs["to"], "reports@example.test")
        self.assertEqual(kwargs["reply_to"], "someone@example.test")
        self.assertIn("The audio stops", kwargs["body"])
        self.assertIn("bug", kwargs["subject"])

    def test_mail_failure_does_not_fail_request(self):
        with patch.object(reports, "send_mail", side_effect=OSError("down")):
            with self.client() as c:
                r = self.post(c)
        self.assertEqual(r.status_code, 201)
        self.assertEqual(self.count(), 1)

    def test_mail_not_configured_still_stores_and_notifies_admins(self):
        settings.smtp_host = ""
        with self.Session() as db:
            db.add(self._admin())
            db.commit()
        with self.assertLogs(reports.logger, "WARNING"):
            with self.client() as c:
                r = self.post(c)
        self.assertEqual(r.status_code, 201)
        with self.Session() as db:
            self.assertEqual(db.query(AppReport).count(), 1)
            note = db.query(Notification).one()
            self.assertEqual(note.kind, "app_report")

    # -- admin list -----------------------------------------------------------
    def _admin(self, is_admin=True, email="admin@example.test"):
        return User(
            email=email, password_hash=hash_password(PASSWORD), birth_date=date(1990, 1, 1),
            consent_ccby=True, consent_parental=False, consent_version="test", is_admin=is_admin,
        )

    def _login(self, c, email):
        page = c.get("/login")
        c.post("/login", data={"identifier": email, "password": PASSWORD, "csrf": csrf_from(page)})

    def test_admin_list_requires_admin(self):
        with self.Session() as db:
            db.add(self._admin(is_admin=False, email="user@example.test"))
            db.commit()
        with self.client() as c:
            anon = c.get("/admin/requests?tab=reports", follow_redirects=False)
            self.assertEqual(anon.status_code, 303)
            self.assertEqual(anon.headers["location"], "/login")
            self._login(c, "user@example.test")
            user = c.get("/admin/requests?tab=reports", follow_redirects=False)
            self.assertEqual(user.status_code, 303)
            self.assertEqual(user.headers["location"], "/dashboard")

    def test_admin_lists_newest_first_and_marks_handled(self):
        with self.Session() as db:
            db.add(self._admin())
            db.commit()
        with patch.object(reports, "send_mail", return_value=False):
            with self.client() as c:
                self.post(c, description="first report text")
                second = self.post(c, description="second report text").json()["id"]
                self._login(c, "admin@example.test")
                page = c.get("/admin/requests?tab=reports")
                self.assertEqual(page.status_code, 200)
                self.assertLess(page.text.index("second report text"), page.text.index("first report text"))
                done = c.post(
                    f"/admin/requests/reports/{second}",
                    data={"state": "handled", "csrf": csrf_from(page)},
                    follow_redirects=False,
                )
                self.assertEqual(done.status_code, 303)
        with self.Session() as db:
            self.assertIsNotNone(db.get(AppReport, second).handled_at)


if __name__ == "__main__":
    unittest.main()
