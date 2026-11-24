import datetime as dt
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from build_catalog import build, parse_territories, slugify  # noqa: E402


def ep(n):
    return {"n": n, "key": f"originals/x/{n}.mp4", "url": f"https://b2.example/{n}.mp4", "bytes": 1}


REGISTRY = {
    "series": [
        {"id": "1", "title": "Our Show", "expected": 2, "episodes": [ep(2), ep(1)]},
        {"id": "2", "title": "Partial", "expected": 5, "episodes": [ep(1), ep(2)]},
        {"id": "3", "title": "Their Show", "expected": 1, "episodes": [ep(1)]},
        {"id": "4", "title": "Expired", "expected": 1, "episodes": [ep(1)]},
        {"id": "5", "title": "Regional", "expected": 1, "episodes": [ep(1)]},
    ]
}


def row(archive_id, approved="yes", territories="WW", valid_until="", slug=""):
    return {"archive_id": archive_id, "approved": approved, "territories": territories,
            "valid_until": valid_until, "slug": slug, "title": ""}


class BuildCatalogTests(unittest.TestCase):
    def test_only_approved_current_complete_series_are_published(self):
        rights = [row("1"), row("2"), row("3", approved="no"), row("4", valid_until="2026-01-01"),
                  row("5", territories="us, ca"), row("99")]
        catalog, skipped = build(REGISTRY, rights, {}, dt.date(2026, 11, 24), allow_partial=False)
        self.assertEqual([s["id"] for s in catalog["series"]], ["our-show", "regional"])
        self.assertEqual([e["number"] for e in catalog["series"][0]["episodes"]], [1, 2])
        self.assertNotIn("regions", catalog["series"][0])
        self.assertEqual(catalog["series"][1]["regions"], ["CA", "US"])
        reasons = dict(skipped)
        self.assertIn("incomplete", reasons["2"])
        self.assertEqual(reasons["3"], "not approved")
        self.assertIn("expired", reasons["4"])
        self.assertIn("not in the archive", reasons["99"])

    def test_partial_series_allowed_on_request(self):
        catalog, _ = build(REGISTRY, [row("2")], {}, dt.date(2026, 11, 24), allow_partial=True)
        self.assertEqual(len(catalog["series"][0]["episodes"]), 2)

    def test_meta_overrides_and_custom_slug(self):
        meta = {"1": {"title": "Контракт на год", "genres": ["Романтика"], "poster": "posters/1.jpg"}}
        catalog, _ = build(REGISTRY, [row("1", slug="kontrakt")], meta, dt.date(2026, 11, 24), False)
        series = catalog["series"][0]
        self.assertEqual(series["id"], "kontrakt")
        self.assertEqual(series["title"], "Контракт на год")
        self.assertEqual(series["poster"], "posters/1.jpg")

    def test_helpers(self):
        self.assertEqual(slugify("Billionaire’s Bride: Part 2!"), "billionaires-bride-part-2")
        self.assertIsNone(parse_territories("WW"))
        with self.assertRaises(ValueError):
            parse_territories("USA")


if __name__ == "__main__":
    unittest.main()
