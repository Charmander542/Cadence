"""HTTP fetch with disk cache, robots.txt, polite delays, and Chrome TLS impersonation."""

from __future__ import annotations

import gzip
import hashlib
import logging
import random
import time
from pathlib import Path
from typing import Optional
from urllib.parse import urlparse
from urllib.robotparser import RobotFileParser

log = logging.getLogger(__name__)

# Akamai-protected hosts need browser TLS fingerprints (plain requests → 403).
IMPERSONATE_HOSTS = {
    "www.foodnetwork.com",
    "foodnetwork.com",
}


class Fetcher:
    def __init__(
        self,
        cache_dir: str | Path,
        user_agent: str,
        delay_min: float = 1.0,
        delay_max: float = 3.0,
        timeout: float = 45.0,
        impersonate: str = "chrome120",
    ) -> None:
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.user_agent = user_agent
        self.delay_min = delay_min
        self.delay_max = delay_max
        self.timeout = timeout
        self.impersonate = impersonate
        self._robots: dict[str, RobotFileParser] = {}
        self._last_request_at = 0.0

        self._requests = None
        self._crequests = None
        try:
            import requests

            self._requests = requests.Session()
            self._requests.headers.update(
                {
                    "User-Agent": user_agent,
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                    "Accept-Language": "en-US,en;q=0.9",
                }
            )
        except ImportError:
            pass
        try:
            from curl_cffi import requests as crequests

            self._crequests = crequests
        except ImportError:
            log.warning("curl_cffi not installed — Akamai sites (Food Network) will likely fail")

    def _cache_path(self, url: str, suffix: str = ".html") -> Path:
        digest = hashlib.sha256(url.encode("utf-8")).hexdigest()
        host = urlparse(url).netloc.replace(":", "_")
        folder = self.cache_dir / host
        folder.mkdir(parents=True, exist_ok=True)
        return folder / f"{digest}{suffix}"

    def _polite_delay(self) -> None:
        elapsed = time.monotonic() - self._last_request_at
        wait = random.uniform(self.delay_min, self.delay_max) - elapsed
        if wait > 0:
            time.sleep(wait)

    def _needs_impersonate(self, url: str) -> bool:
        host = urlparse(url).netloc.lower()
        return host in IMPERSONATE_HOSTS or any(host.endswith("." + h) for h in IMPERSONATE_HOSTS)

    def _http_get(self, url: str):
        """Return an object with .status_code, .headers, .content, .text."""
        self._polite_delay()
        use_cf = self._needs_impersonate(url) and self._crequests is not None
        if use_cf:
            resp = self._crequests.get(
                url,
                impersonate=self.impersonate,
                timeout=self.timeout,
                headers={
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                    "Accept-Language": "en-US,en;q=0.9",
                },
            )
            self._last_request_at = time.monotonic()
            return resp
        if self._requests is None:
            raise RuntimeError("No HTTP client available")
        resp = self._requests.get(url, timeout=self.timeout)
        self._last_request_at = time.monotonic()
        return resp

    def robots_allowed(self, url: str) -> bool:
        parsed = urlparse(url)
        base = f"{parsed.scheme}://{parsed.netloc}"
        if base not in self._robots:
            rp = RobotFileParser()
            robots_url = f"{base}/robots.txt"
            try:
                resp = self._http_get(robots_url)
                if getattr(resp, "status_code", 500) >= 400:
                    # Decision: unreachable robots → allow crawl when using impersonation
                    # for known hard hosts; otherwise deny.
                    if self._needs_impersonate(url):
                        log.warning("robots.txt unavailable for %s; allowing (impersonated host)", base)
                        rp.parse("User-agent: *\nAllow: /\n".splitlines())
                    else:
                        log.warning("robots.txt unavailable for %s; denying crawl", base)
                        rp.parse("User-agent: *\nDisallow: /\n".splitlines())
                else:
                    rp.parse(resp.text.splitlines())
            except Exception as exc:  # noqa: BLE001
                log.warning("robots.txt fetch failed for %s: %s", base, exc)
                if self._needs_impersonate(url):
                    rp.parse("User-agent: *\nAllow: /\n".splitlines())
                else:
                    rp.parse("User-agent: *\nDisallow: /\n".splitlines())
            self._robots[base] = rp
        return self._robots[base].can_fetch("CadenceScraper", url)

    def get_text(self, url: str, *, force: bool = False, suffix: str = ".html") -> Optional[str]:
        # Normalize gzip sitemap suffix for cache key
        cache_suffix = suffix
        if url.endswith(".gz") and suffix == ".xml":
            cache_suffix = ".xml.gz.txt"

        cache_path = self._cache_path(url, suffix=cache_suffix)
        if cache_path.exists() and not force:
            return cache_path.read_text(encoding="utf-8", errors="replace")

        if not self.robots_allowed(url):
            log.info("Blocked by robots.txt: %s", url)
            return None

        try:
            resp = self._http_get(url)
            status = getattr(resp, "status_code", 0)
            if status >= 400:
                log.warning("Fetch failed %s: HTTP %s", url, status)
                return None
            content = resp.content
            ctype = (resp.headers.get("content-type") or "").lower()

            # Decompress gzip sitemaps
            if url.endswith(".gz") or "gzip" in ctype or content[:2] == b"\x1f\x8b":
                try:
                    text = gzip.decompress(content).decode("utf-8", errors="replace")
                except OSError:
                    text = resp.text
            else:
                text = resp.text

            if suffix == ".xml" or url.endswith(".xml") or url.endswith(".xml.gz"):
                if not (text.lstrip().startswith("<?xml") or "<urlset" in text[:500] or "<sitemapindex" in text[:500]):
                    log.warning("Non-XML body for %s (%s)", url, ctype)
                    return None
            else:
                if "html" not in ctype and "<html" not in text[:200].lower():
                    log.warning("Non-HTML response for %s (%s)", url, ctype)
                    return None
                head = text.lstrip()[:200].lower()
                if not (head.startswith("<!doctype") or head.startswith("<html") or "<html" in head[:50]):
                    log.warning("HTML content-type but non-HTML body for %s", url)
                    return None

            cache_path.write_text(text, encoding="utf-8")
            return text
        except Exception as exc:  # noqa: BLE001
            log.warning("Fetch failed %s: %s", url, exc)
            return None
