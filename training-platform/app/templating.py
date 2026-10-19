from __future__ import annotations

from pathlib import Path

from fastapi.templating import Jinja2Templates

_templates_dir = Path(__file__).parent / "templates"
_static_dir = Path(__file__).parent / "static"

templates = Jinja2Templates(directory=str(_templates_dir))
STATIC_DIR = str(_static_dir)

# Official Facebook page (footer, follow lines, sameAs, e-mails).
FACEBOOK_URL = "https://www.facebook.com/tibyanapp/"
templates.env.globals["facebook_url"] = FACEBOOK_URL
# Official Instagram page (same places as Facebook).
INSTAGRAM_URL = "https://www.instagram.com/tibyanapp/"
templates.env.globals["instagram_url"] = INSTAGRAM_URL
# Bump when CSS/JS/brand assets change so browsers refetch them.
templates.env.globals["asset_v"] = "brand1"
