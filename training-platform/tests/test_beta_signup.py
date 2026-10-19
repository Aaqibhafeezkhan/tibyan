from __future__ import annotations

import os
import tempfile
import threading
import unittest
from datetime import date
from unittest.mock import MagicMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, inspect
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from starlette.middleware.sessions import SessionMiddleware

from app import db as app_db
from app import ratelimit
from app.db import Base
from app.deps import get_db
from app.models import Notification, NotifySignup, User
from app.routes import admin_requests, auth, beta, notify, pages
from app.security import hash_password
from test_platform_workflow import csrf_from

PASSWORD = "test-only-password-42"
ROOT = "https://altibyan.app"


class LaunchFormsBase(unittest.TestCase):
    def setUp(self):
        ratelimit.reset()
        self.engine = create_engine(
            "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
        )
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine, autoflush=False)
        self.app = FastAPI()
        self.app.add_middleware(SessionMiddleware, secret_key="test-only", https_only=False)
        for router in (pages.router, auth.router, notify.router, beta.router, admin_requests.router):
            self.app.include_router(router)

        def override_get_db():
            db = self.Session()
            try:
                yield db
            finally:
                db.close()

        self.app.dependency_overrides[get_db] = override_get_db
        self.mails = []
        for module, name in (
            (notify, "send_notify_confirmation"), (beta, "send_beta_confirmation"),
            (notify, "send_signup_alert"), (beta, "send_signup_alert"),
        ):
            p = patch.object(module, name, side_effect=lambda *a, _n=name: self.mails.append((_n, a)))
            p.start()
            self.addCleanup(p.stop)

    def tearDown(self):
        ratelimit.reset()
        self.engine.dispose()

    def client(self, ip="203.0.113.9"):
        return TestClient(self.app, base_url=ROOT, client=(ip, 50000))

    def rows(self):
        with self.Session() as db:
            return db.query(NotifySignup).order_by(NotifySignup.id).all()


class NotifyFormTests(LaunchFormsBase):
    def submit(self, c, **data):
        if not getattr(c, "csrf", None):
            c.csrf = csrf_from(c.get("/"))
        return c.post("/notify", data={"csrf": c.csrf, **data}, follow_redirects=False)

    def test_page_has_beta_button_not_checkbox(self):
        with self.client() as c:
            html = c.get("/").text
        self.assertIn('href="/beta"', html)
        self.assertIn("انضم لاختبار النسخة التجريبية", html)
        self.assertNotIn('name="beta"', html)

    def test_missing_csrf_is_rejected(self):
        with self.client() as c:
            c.get("/")
            r = c.post("/notify", data={"email": "a@example.test"})
        self.assertEqual(r.status_code, 400)
        self.assertEqual(self.rows(), [])

    def test_valid_signup_stored_once_and_confirmed_once(self):
        with self.client() as c:
            r = self.submit(c, email="  Someone@Example.TEST ")
            self.assertEqual(r.status_code, 303)
            self.assertIn("تم تسجيل بريدك", c.get("/").text)
            self.submit(c, email="someone@example.test")
        rows = self.rows()
        self.assertEqual([r.email for r in rows], ["someone@example.test"])
        self.assertEqual(rows[0].lang, "ar")
        self.assertEqual(
            sorted(m[0] for m in self.mails), ["send_notify_confirmation", "send_signup_alert"]
        )

    def test_invalid_email_shows_error_and_keeps_value(self):
        with self.client() as c:
            self.submit(c, email="not-an-email")
            html = c.get("/").text
        self.assertIn("أدخل بريدًا إلكترونيًا صحيحًا", html)
        self.assertIn('value="not-an-email"', html)
        self.assertEqual(self.rows(), [])

    def test_honeypot_looks_ok_but_stores_nothing(self):
        with self.client() as c:
            self.submit(c, email="bot@example.test", website="http://spam")
            self.assertIn("تم تسجيل بريدك", c.get("/").text)
        self.assertEqual(self.rows(), [])
        self.assertEqual(self.mails, [])

    def test_rate_limit_gives_friendly_message(self):
        with self.client() as c:
            for i in range(5):
                self.submit(c, email=f"u{i}@example.test")
            self.submit(c, email="late@example.test")
            self.assertIn("محاولات كثيرة", c.get("/").text)
        self.assertEqual(len(self.rows()), 5)

    def test_nginx_429_redirect_shows_message(self):
        with self.client() as c:
            self.assertIn("محاولات كثيرة", c.get("/?n=busy").text)


class BetaFormTests(LaunchFormsBase):
    def join(self, c, platforms=("ios",), **data):
        if not getattr(c, "csrf", None):
            c.csrf = csrf_from(c.get("/beta"))
        body = {"csrf": c.csrf, "email": "tester@example.test", **data}
        body["platform"] = list(platforms)
        return c.post("/beta/join", data=body, follow_redirects=False)

    def _admin(self):
        with self.Session() as db:
            db.add(User(
                email="admin@example.test", password_hash=hash_password(PASSWORD),
                birth_date=date(1990, 1, 1), consent_ccby=True, consent_parental=False,
                consent_version="test", is_admin=True,
            ))
            db.commit()

    def _login(self, c):
        page = c.get("/login")
        c.post("/login", data={"identifier": "admin@example.test", "password": PASSWORD, "csrf": csrf_from(page)})

    def test_page_shows_links_and_steps_without_signup(self):
        with self.client() as c:
            html = c.get("/beta").text
        self.assertIn("https://play.google.com/apps/internaltest/4701465992904267136", html)
        self.assertIn("https://testflight.apple.com/join/gxJ4rrdd", html)
        self.assertIn("أصبح مختبِرًا", html)
        self.assertIn("الإبلاغ عن مشكلة", html)

    def test_nginx_429_redirect_shows_message(self):
        with self.client() as c:
            self.assertIn("محاولات كثيرة", c.get("/beta?n=busy").text)

    def test_english_page(self):
        with self.client() as c:
            c.cookies.set("lang", "en")
            html = c.get("/beta").text
        self.assertIn("Join the beta test", html)
        self.assertIn("Become a tester", html)

    def test_join_stores_platforms_notifies_and_emails(self):
        self._admin()
        with self.client() as c:
            r = self.join(c, platforms=("android", "mac"), email=" Tester@Example.test")
            self.assertEqual(r.status_code, 303)
            self.assertEqual(r.headers["location"], "/beta#install")
            html = c.get("/beta").text
        self.assertIn("تم تسجيل طلبك", html)
        self.assertIn("من اختيارك", html)
        row = self.rows()[0]
        self.assertEqual(row.email, "tester@example.test")
        self.assertTrue(row.wants_beta)
        self.assertEqual(row.platforms, ["android", "mac"])
        self.assertIsNotNone(row.beta_requested_at)
        self.assertIn(("send_beta_confirmation", ("tester@example.test", "ar", ["android", "mac"])), self.mails)
        self.assertIn(("send_signup_alert", ("beta", "tester@example.test", "ar", ["android", "mac"])), self.mails)
        with self.Session() as db:
            self.assertEqual(db.query(Notification).one().kind, "beta_request")

    def test_repeat_merges_platforms_and_only_new_ones_notify(self):
        with self.client() as c:
            self.join(c, platforms=("ios",))
            self.join(c, platforms=("ios",))
            self.join(c, platforms=("android",))
        self.assertEqual(self.rows()[0].platforms, ["ios", "android"])
        self.assertEqual(len(self.mails), 4)  # confirmation + alert, twice

    def test_existing_notify_signup_is_upgraded(self):
        with self.Session() as db:
            db.add(NotifySignup(email="tester@example.test", lang="en"))
            db.commit()
        with self.client() as c:
            self.join(c, platforms=("ios",))
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertTrue(rows[0].wants_beta)

    def test_validation(self):
        with self.client() as c:
            bad_email = self.join(c, email="nope")
            self.assertEqual(bad_email.status_code, 422)
            self.assertIn("أدخل بريدًا إلكترونيًا صحيحًا", bad_email.text)
            no_platform = self.join(c, platforms=())
            self.assertEqual(no_platform.status_code, 422)
            self.assertIn("اختر جهازًا واحدًا على الأقل", no_platform.text)
            self.assertIn('value="tester@example.test"', no_platform.text)
            junk = self.join(c, platforms=("windows",))
            self.assertEqual(junk.status_code, 422)
            r = c.post("/beta/join", data={"email": "a@example.test", "platform": "ios"})
            self.assertEqual(r.status_code, 400)
        self.assertEqual(self.rows(), [])

    def test_honeypot(self):
        with self.client() as c:
            r = self.join(c, website="spam")
        self.assertEqual(r.status_code, 303)
        self.assertEqual(self.rows(), [])
        self.assertEqual(self.mails, [])

    def test_rate_limit(self):
        with self.client() as c:
            for i in range(5):
                self.join(c, email=f"t{i}@example.test")
            r = self.join(c, email="late@example.test")
        self.assertEqual(r.status_code, 429)
        self.assertIn("محاولات كثيرة", r.text)
        self.assertEqual(len(self.rows()), 5)

    def test_admin_list_filters_and_csv(self):
        self._admin()
        with self.client(ip="198.51.100.1") as c:
            self.join(c, email="ios@example.test", platforms=("ios",))
            self.join(c, email="droid@example.test", platforms=("android",))
            self.join(c, email="both@example.test", platforms=("android", "mac"))
        with self.Session() as db:
            db.add(NotifySignup(email="plain@example.test", lang="ar"))
            db.commit()
        with self.client(ip="198.51.100.2") as c:
            self._login(c)
            page = c.get("/admin/requests?tab=beta")
            self.assertEqual(page.status_code, 200)
            for email in ("ios@example.test", "droid@example.test", "both@example.test"):
                self.assertIn(email, page.text)
            self.assertNotIn("plain@example.test", page.text)
            android = c.get("/admin/requests?tab=beta&platform=android").text
            self.assertIn("droid@example.test", android)
            self.assertIn("both@example.test", android)
            self.assertNotIn("ios@example.test", android)
            csv = c.get("/admin/requests/notify.csv?beta=1&platform=mac")
            self.assertEqual(csv.status_code, 200)
            self.assertIn("beta_platforms", csv.text)
            self.assertIn("both@example.test", csv.text)
            self.assertIn("android mac", csv.text)
            self.assertNotIn("droid@example.test", csv.text)
            row_id = next(r.id for r in self.rows() if r.email == "ios@example.test")
            c.post(f"/admin/requests/beta/{row_id}", data={"platform": "testflight", "value": "1", "csrf": csrf_from(page)})
            pending = c.get("/admin/requests?tab=beta&status=pending").text
            self.assertNotIn("ios@example.test", pending)
            added = c.get("/admin/requests?tab=beta&status=added").text
            self.assertIn("ios@example.test", added)


class SignupAlertTests(unittest.TestCase):
    def test_alert_goes_to_every_configured_address(self):
        from app import launch_mail
        from app.config import settings

        saved = settings.signup_notify_emails
        settings.signup_notify_emails = "noreply@example.test, info@example.test"
        try:
            with patch.object(launch_mail, "send_mail", return_value=True) as sm:
                launch_mail.send_signup_alert("beta", "x@example.test", "ar", ["ios", "mac"])
            kwargs = sm.call_args.kwargs
            self.assertEqual(kwargs["to"], "noreply@example.test, info@example.test")
            self.assertIn("x@example.test", kwargs["body"])
            self.assertIn("ios, mac", kwargs["body"])
            self.assertIn("/admin/requests?tab=beta", kwargs["body"])
            settings.signup_notify_emails = ""
            with patch.object(launch_mail, "send_mail") as sm:
                launch_mail.send_signup_alert("notify", "x@example.test", "ar")
            sm.assert_not_called()
        finally:
            settings.signup_notify_emails = saved


class MigrationTests(unittest.TestCase):
    def setUp(self):
        fd, self.path = tempfile.mkstemp(suffix=".db")
        os.close(fd)
        os.unlink(self.path)
        self.engine = create_engine(f"sqlite:///{self.path}")

    def tearDown(self):
        self.engine.dispose()
        if os.path.exists(self.path):
            os.unlink(self.path)

    def test_run_migrations_is_idempotent(self):
        app_db.run_migrations(self.engine)
        app_db.run_migrations(self.engine)
        cols = {c["name"] for c in inspect(self.engine).get_columns("notify_signups")}
        self.assertTrue({"beta_platforms", "beta_requested_at"} <= cols)

    def test_concurrent_workers_do_not_crash(self):
        errors = []

        def worker():
            try:
                app_db.run_migrations(self.engine)
            except Exception as exc:  # pragma: no cover - reported below
                errors.append(exc)

        threads = [threading.Thread(target=worker) for _ in range(4)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        self.assertEqual(errors, [])

    def test_table_already_exists_1050_is_tolerated(self):
        real = Base.metadata.create_all
        calls = []

        def flaky(*args, **kwargs):
            calls.append(1)
            if len(calls) == 1:
                real(*args, **kwargs)
                raise OperationalError("CREATE TABLE x", {}, Exception(1050, "Table 'platform_settings' already exists"))
            return real(*args, **kwargs)

        with patch.object(Base.metadata, "create_all", side_effect=flaky):
            app_db.run_migrations(self.engine)
        self.assertEqual(len(calls), 2)

    def test_other_operational_errors_still_raise(self):
        err = OperationalError("CREATE TABLE x", {}, Exception(1045, "Access denied"))
        with patch.object(Base.metadata, "create_all", side_effect=err):
            with self.assertRaises(OperationalError):
                app_db.run_migrations(self.engine)

    def test_mysql_takes_and_releases_named_lock(self):
        bind = MagicMock()
        bind.dialect.name = "mysql"
        conn = bind.connect.return_value.__enter__.return_value
        conn.execute.return_value.scalar.return_value = 1
        with app_db.migration_lock(bind):
            pass
        sql = [str(call.args[0]) for call in conn.execute.call_args_list]
        self.assertIn("GET_LOCK", sql[0])
        self.assertIn("RELEASE_LOCK", sql[-1])

    def test_mysql_lock_timeout_raises(self):
        bind = MagicMock()
        bind.dialect.name = "mysql"
        conn = bind.connect.return_value.__enter__.return_value
        conn.execute.return_value.scalar.return_value = 0
        with self.assertRaises(RuntimeError):
            with app_db.migration_lock(bind):
                pass


if __name__ == "__main__":
    unittest.main()
