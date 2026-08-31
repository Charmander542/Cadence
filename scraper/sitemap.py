"""Sitemap URL discovery for configured sites."""

from __future__ import annotations

import logging
import re
import xml.etree.ElementTree as ET
from typing import Iterable
from urllib.parse import urlparse

from scraper.fetch import Fetcher

log = logging.getLogger(__name__)

# Paths that look like /recipes/… but are not individual recipe pages (Food Network).
NON_RECIPE_PATH_FRAGMENTS = (
    "/tag/",
    "/category/",
    "/author/",
    "/page/",
    "/about",
    "/contact",
    "/privacy",
    "/shop",
    "/product",
    "/work-with",
    "/start-here",
    "/wp-content/",
    "/recipes/photos",
    "/recipes/packages",
    "/recipes/articles",
    "/recipes/menus",
    "/recipes/topics",
    "/recipes/recipes",
    "playlist",
    "/recipes/fn-dish",
)


def _local(tag: str) -> str:
    if "}" in tag:
        return tag.rsplit("}", 1)[-1]
    return tag


def parse_sitemap_xml(xml_text: str) -> tuple[list[str], list[str]]:
    """Return (page_urls, nested_sitemap_urls).

    Only reads <url><loc> / <sitemap><loc> — NOT nested image:loc entries.
    """
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError:
        locs = re.findall(r"<loc>\s*([^<\s]+)\s*</loc>", xml_text, flags=re.I)
        sitemaps = [
            u
            for u in locs
            if "sitemap" in u.lower() and (".xml" in u.lower())
        ]
        pages = [u for u in locs if u not in sitemaps and not _is_media_url(u)]
        return pages, sitemaps

    root_name = _local(root.tag).lower()
    pages: list[str] = []
    sitemaps: list[str] = []

    for child in list(root):
        child_name = _local(child.tag).lower()
        if root_name == "sitemapindex" and child_name == "sitemap":
            for sub in child:
                if _local(sub.tag).lower() == "loc" and sub.text:
                    sitemaps.append(sub.text.strip())
        elif child_name == "url":
            for sub in child:
                if _local(sub.tag).lower() == "loc" and sub.text:
                    loc = sub.text.strip()
                    if not _is_media_url(loc):
                        pages.append(loc)
                    break

    if root_name == "sitemapindex":
        return [], sitemaps
    return pages, []


def _is_media_url(url: str) -> bool:
    path = urlparse(url).path.lower()
    if "/wp-content/uploads/" in path:
        return True
    return path.endswith((".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg", ".mp4", ".pdf"))


def _looks_like_recipe_page(url: str) -> bool:
    path = urlparse(url).path.lower().rstrip("/")
    if any(x in path for x in NON_RECIPE_PATH_FRAGMENTS):
        return False
    # Food Network chef/recipe pages end with a numeric id, or are /recipes/slug-id
    if "foodnetwork.com" in urlparse(url).netloc.lower():
        if "/recipes/" not in path:
            return False
        # Exclude shallow index paths
        parts = [p for p in path.split("/") if p]
        if len(parts) < 2:
            return False
        # /recipes/photos/... already excluded; require a leaf that isn't a known section
        leaf = parts[-1]
        if leaf in {"recipes", "photos", "packages", "articles", "menus"}:
            return False
        return True
    return True


def discover_urls(
    fetcher: Fetcher,
    sitemap_urls: Iterable[str],
    recipe_url_contains: list[str] | None = None,
    max_urls: int | None = None,
) -> list[str]:
    recipe_url_contains = recipe_url_contains or []
    seen: set[str] = set()
    out: list[str] = []
    queue = list(sitemap_urls)

    while queue:
        sm_url = queue.pop(0)
        if sm_url in seen:
            continue
        seen.add(sm_url)
        text = fetcher.get_text(sm_url, suffix=".xml")
        if not text:
            continue
        pages, nested = parse_sitemap_xml(text)
        for n in nested:
            if n not in seen:
                queue.append(n)
        for url in pages:
            if url in seen:
                continue
            seen.add(url)
            if _is_media_url(url):
                continue
            path = urlparse(url).path.lower().rstrip("/")
            if path in ("", "/"):
                continue
            if not _looks_like_recipe_page(url):
                continue
            if recipe_url_contains and not any(s in url for s in recipe_url_contains):
                continue
            out.append(url)
            if max_urls and len(out) >= max_urls:
                return out
    return out
