"""Shared test setup: never reach the GitHub API from tests."""
import pytest

from app import releases


@pytest.fixture(autouse=True)
def _offline_releases(monkeypatch):
    releases.reset()

    def _no_network():
        raise OSError("network disabled in tests")

    monkeypatch.setattr(releases, "_fetch", _no_network)
    yield
    releases.reset()
