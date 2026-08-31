"""Configuration loading for the scraper."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / "scraper" / "config.yaml"
EXAMPLE_CONFIG = ROOT / "scraper" / "config.example.yaml"


def _resolve_key(data: dict[str, Any], file_key: str, env_name: str) -> str:
    env_key = os.environ.get(env_name, "").strip()
    raw = str(data.get(file_key) or "").strip()
    if env_key:
        return env_key
    if not raw or raw.startswith("YOUR_"):
        return ""
    return raw


def load_config(path: Path | None = None) -> dict[str, Any]:
    cfg_path = path or DEFAULT_CONFIG
    if not cfg_path.exists():
        cfg_path = EXAMPLE_CONFIG
    with cfg_path.open(encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    # Prefer env vars over placeholders so keys never need to live in the file.
    data["anthropic_api_key"] = _resolve_key(data, "anthropic_api_key", "ANTHROPIC_API_KEY")
    data["openai_api_key"] = _resolve_key(data, "openai_api_key", "OPENAI_API_KEY")

    provider = str(data.get("ai_provider") or "anthropic").strip().lower()
    if provider not in {"anthropic", "openai"}:
        provider = "anthropic"
    data["ai_provider"] = provider

    data.setdefault("anthropic_model", "claude-sonnet-4-20250514")
    data.setdefault("openai_model", "gpt-4o-mini")

    # Resolve relative paths against repo root.
    paths = data.setdefault("paths", {})
    for key in ("cache_dir", "db_path", "json_export", "ingredient_cache"):
        p = Path(paths.get(key, f"data/{key}"))
        if not p.is_absolute():
            p = ROOT / p
        paths[key] = str(p)

    return data
