"""Quick sanity checks for scraper helpers (run: python -m scraper.tests_smoke)."""

from __future__ import annotations

from scraper.normalize import IngredientNormalizer
from scraper.sitemap import parse_sitemap_xml


def test_normalize_units() -> None:
    n = IngredientNormalizer(cache_path="/tmp/mm_ing_test.json", api_key="")
    samples = n.normalize_many(
        [
            "1 cup olive oil",
            "3 Tbsp soy sauce",
            "1/4 tsp salt",
            "a pinch of salt",
            "2 cloves garlic",
            "1 lb chicken breast",
        ]
    )
    assert samples[0]["unit"] == "cup" and samples[0]["quantity"] == 1.0
    assert samples[1]["unit"] == "tbsp" and samples[1]["quantity"] == 3.0
    assert samples[2]["unit"] == "tsp"
    assert samples[3]["is_approximate"] is True
    assert samples[4]["unit"] == "count"
    assert samples[5]["unit"] == "lb"
    print("normalize OK", samples[3])


def test_sitemap_skips_image_loc() -> None:
    xml = """<?xml version="1.0"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
            xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">
      <url>
        <loc>https://www.budgetbytes.com/some-recipe/</loc>
        <image:image>
          <image:loc>https://www.budgetbytes.com/wp-content/uploads/x.jpg</image:loc>
        </image:image>
      </url>
    </urlset>
    """
    pages, nested = parse_sitemap_xml(xml)
    assert pages == ["https://www.budgetbytes.com/some-recipe/"]
    assert nested == []
    print("sitemap OK")


if __name__ == "__main__":
    test_normalize_units()
    test_sitemap_skips_image_loc()
    print("all smoke tests passed")
