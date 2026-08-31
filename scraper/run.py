"""CLI entry: python -m scraper.run --sites budgetbytes,cookieandkate."""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

from scraper.config import load_config
from scraper.db import RecipeDB
from scraper.fetch import Fetcher
from scraper.normalize import IngredientNormalizer
from scraper.parse import parse_recipe_from_html
from scraper.sitemap import discover_urls

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
log = logging.getLogger("scraper.run")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="MuscleMeal recipe scraper")
    parser.add_argument(
        "--sites",
        default="",
        help="Comma-separated site keys (default: all enabled in config)",
    )
    parser.add_argument("--limit", type=int, default=0, help="Max recipes to store this run (0=unlimited)")
    parser.add_argument("--max-urls-per-site", type=int, default=800, help="Cap discovered URLs per site")
    parser.add_argument("--config", type=Path, default=None, help="Path to config.yaml")
    parser.add_argument("--force-fetch", action="store_true", help="Bypass HTML cache")
    parser.add_argument("--skip-existing", action="store_true", default=True, help="Skip URLs already in DB")
    args = parser.parse_args(argv)

    cfg = load_config(args.config)
    paths = cfg["paths"]
    sites_cfg = cfg.get("sites") or {}

    if args.sites.strip():
        wanted = {s.strip().lower() for s in args.sites.split(",") if s.strip()}
    else:
        wanted = {k for k, v in sites_cfg.items() if v.get("enabled")}

    fetcher = Fetcher(
        cache_dir=paths["cache_dir"],
        user_agent=cfg.get("user_agent", "MuscleMealScraper/1.0"),
        delay_min=float(cfg.get("request_delay_min_s", 1.0)),
        delay_max=float(cfg.get("request_delay_max_s", 3.0)),
    )
    normalizer = IngredientNormalizer(
        cache_path=paths["ingredient_cache"],
        provider=cfg.get("ai_provider") or "anthropic",
        anthropic_api_key=cfg.get("anthropic_api_key") or "",
        openai_api_key=cfg.get("openai_api_key") or "",
        anthropic_model=cfg.get("anthropic_model", "claude-sonnet-4-20250514"),
        openai_model=cfg.get("openai_model", "gpt-4o-mini"),
        batch_size=int(cfg.get("ingredient_batch_size", 20)),
    )
    if normalizer.has_llm:
        log.info("Ingredient normalization: %s", normalizer._backend)
    else:
        log.info(
            "Ingredient normalization: local heuristic "
            "(set ANTHROPIC_API_KEY or OPENAI_API_KEY, and ai_provider in config)"
        )

    db = RecipeDB(paths["db_path"])
    stored = 0
    skipped = 0
    failed = 0

    try:
        for site_key in sorted(wanted):
            site = sites_cfg.get(site_key)
            if not site:
                log.warning("Unknown site key: %s", site_key)
                continue
            if not site.get("enabled", False) and site_key not in {
                s.strip().lower() for s in (args.sites or "").split(",") if s.strip()
            }:
                log.info("Skipping disabled site %s", site_key)
                continue
            # Allow explicit --sites to override enabled:false for testing licensed use.
            if not site.get("enabled", False):
                log.warning(
                    "Site %s is disabled in config (ToS/robots). Proceeding because it was listed in --sites.",
                    site_key,
                )

            log.info("=== Site: %s ===", site_key)
            urls = discover_urls(
                fetcher,
                site.get("sitemap_urls") or [],
                recipe_url_contains=site.get("recipe_url_contains") or [],
                max_urls=args.max_urls_per_site,
            )
            log.info("Discovered %d candidate URLs for %s", len(urls), site_key)

            for url in urls:
                if args.limit and stored >= args.limit:
                    break
                if args.skip_existing and db.has_url(url):
                    skipped += 1
                    continue

                html = fetcher.get_text(url, force=args.force_fetch)
                if not html:
                    failed += 1
                    continue

                recipe = parse_recipe_from_html(url, html)
                if not recipe:
                    skipped += 1
                    continue

                norms = normalizer.normalize_many(recipe.ingredients)
                db.upsert_recipe(recipe, norms)
                stored += 1
                if stored % 25 == 0:
                    log.info("Stored %d recipes so far (db total=%d)", stored, db.count_recipes())

            if args.limit and stored >= args.limit:
                break
    finally:
        normalizer.save_cache()
        db.export_json(paths["json_export"])
        total = db.count_recipes()
        db.close()

    log.info(
        "Done. newly_stored=%d skipped=%d failed=%d db_total=%d export=%s",
        stored,
        skipped,
        failed,
        total,
        paths["json_export"],
    )
    return 0 if total > 0 or stored > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
