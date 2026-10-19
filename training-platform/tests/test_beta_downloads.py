from __future__ import annotations

import unittest
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from starlette.middleware.sessions import SessionMiddleware

from app import releases
from app.routes import beta

GH = "https://github.com/helalrules7/tibyan/releases/download"


def asset(tag, name, size=262_717_575):
    return {"name": name, "size": size, "browser_download_url": f"{GH}/{tag}/{name}"}


RELEASES = [
    {"tag_name": "v0.6.0", "draft": True, "prerelease": True,
     "assets": [asset("v0.6.0", "tibyan-0.6.0-universal.apk")]},
    {"tag_name": "v0.5.0", "draft": False, "prerelease": True, "assets": [
        asset("v0.5.0", "SHA256SUMS.txt", 651),
        asset("v0.5.0", "tibyan-0.5.0-arm64-v8a.apk"),
        asset("v0.5.0", "tibyan-0.5.0-universal.apk"),
        asset("v0.5.0", "tibyan-0.5.0-macos.zip", 141_878_800),
        asset("v0.5.0", "tibyan-0.5.0-windows-x64.zip"),
    ]},
    {"tag_name": "v0.4.0", "draft": False, "prerelease": False, "assets": [
        asset("v0.4.0", "app-release.apk"),
        asset("v0.4.0", "tibyan-0.4.0-linux-x64.tar.gz"),
    ]},
]


class DownloadsTest(unittest.TestCase):
    def setUp(self):
        releases.reset()
        app = FastAPI()
        app.add_middleware(SessionMiddleware, secret_key="test-only", https_only=False)
        app.include_router(beta.router)
        self.client = TestClient(app, base_url="https://altibyan.app")

    def tearDown(self):
        releases.reset()

    def get(self, platform):
        return self.client.get(f"/download/{platform}", follow_redirects=False)

    def test_redirects_to_newest_prerelease_assets(self):
        with patch.object(releases, "_fetch", return_value=RELEASES):
            want = {
                "android": f"{GH}/v0.5.0/tibyan-0.5.0-universal.apk",
                "macos": f"{GH}/v0.5.0/tibyan-0.5.0-macos.zip",
                "windows": f"{GH}/v0.5.0/tibyan-0.5.0-windows-x64.zip",
                "linux": f"{GH}/v0.4.0/tibyan-0.4.0-linux-x64.tar.gz",  # older release fills the gap
            }
            for platform, url in want.items():
                r = self.get(platform)
                self.assertEqual(r.status_code, 302, platform)
                self.assertEqual(r.headers["location"], url)

    def test_unknown_platform_404(self):
        self.assertEqual(self.get("ios").status_code, 404)

    def test_cache_hits_api_once(self):
        with patch.object(releases, "_fetch", return_value=RELEASES) as fetch:
            for _ in range(3):
                self.get("android")
                self.get("macos")
            self.assertEqual(fetch.call_count, 1)

    def test_cache_expires(self):
        with patch.object(releases, "_fetch", return_value=RELEASES) as fetch, \
                patch.object(releases, "_now", side_effect=[1000.0, 1000.0 + releases.CACHE_TTL + 1]):
            self.get("android")
            self.get("android")
            self.assertEqual(fetch.call_count, 2)

    def test_api_failure_falls_back_to_releases_page(self):
        with patch.object(releases, "_fetch", side_effect=OSError("down")):
            r = self.get("windows")
        self.assertEqual(r.status_code, 302)
        self.assertEqual(r.headers["location"], releases.RELEASES_PAGE)

    def test_failure_keeps_last_good_data(self):
        with patch.object(releases, "_fetch", return_value=RELEASES):
            self.get("android")
        releases._cache["at"] = 1.0  # force expiry
        with patch.object(releases, "_fetch", side_effect=OSError("down")):
            r = self.get("android")
        self.assertTrue(r.headers["location"].endswith("tibyan-0.5.0-universal.apk"))

    def test_no_matching_asset_falls_back(self):
        with patch.object(releases, "_fetch", return_value=[RELEASES[2]]):
            self.assertEqual(self.get("macos").headers["location"], releases.RELEASES_PAGE)

    def test_beta_page_shows_buttons_version_and_size(self):
        with patch.object(releases, "_fetch", return_value=RELEASES):
            html = self.client.get("/beta").text
        for href in ("/download/android", "/download/macos", "/download/windows", "/download/linux",
                     "https://testflight.apple.com/join/gxJ4rrdd",
                     "https://play.google.com/apps/internaltest/4701465992904267136"):
            self.assertIn(f'href="{href}"', html)
        self.assertIn("v0.5.0 · 142 MB", html)
        self.assertLess(html.index('class="downloads"'), html.index('class="beta-form"'))

    def test_beta_page_renders_when_api_down(self):
        r = self.client.get("/beta")
        self.assertEqual(r.status_code, 200)
        self.assertIn('href="/download/android"', r.text)
        self.assertNotIn("dl-meta", r.text)


class HeadTest(DownloadsTest):
    def test_head_redirects(self):
        with patch.object(releases, "_fetch", return_value=RELEASES):
            r = self.client.head("/download/macos", follow_redirects=False)
        self.assertEqual(r.status_code, 302)
        self.assertTrue(r.headers["location"].endswith("tibyan-0.5.0-macos.zip"))
