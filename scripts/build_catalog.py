#!/usr/bin/env python3
"""Build the app's catalog.json from the video archive registry and the rights list.

Only series that are approved in content/rights.csv, whose license has not expired,
and whose episodes are all present in the archive go into the catalog. Everything
else is left out and listed in the report, so nothing reaches the app by accident.

Usage:
    python3 scripts/build_catalog.py --registry registry.json \
        --rights content/rights.csv [--meta content/series-meta.json] \
        [--today 2026-11-24] [--allow-partial] --out catalog.json

registry.json  the archive's "Реестр .json" (series → episodes with url/key/bytes)
rights.csv     one row per series we may show: archive_id, approved=yes, territories, valid_until
series-meta    optional extra fields per archive_id: title, synopsis, genres, poster, badge
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import re
import sys
import unicodedata
from pathlib import Path

WORLDWIDE = {"", "WW", "WORLD", "WORLDWIDE", "ALL"}


def slugify(text: str) -> str:
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-") or "series"


def parse_territories(value: str) -> list[str] | None:
    """None = worldwide; otherwise ISO 3166-1 alpha-2 codes, upper-case."""
    codes = [c.strip().upper() for c in re.split(r"[,; ]+", value or "") if c.strip()]
    if not codes or any(c in WORLDWIDE for c in codes):
        return None
    bad = [c for c in codes if not re.fullmatch(r"[A-Z]{2}", c)]
    if bad:
        raise ValueError(f"territories must be 2-letter country codes or WW, got {bad}")
    return sorted(set(codes))


def load_rights(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8-sig") as f:
        return [row for row in csv.DictReader(f) if (row.get("archive_id") or "").strip()]


def build(registry: dict, rights: list[dict], meta: dict, today: dt.date, allow_partial: bool):
    by_id = {str(s["id"]): s for s in registry.get("series", [])}
    series_out, skipped, used_slugs = [], [], set()

    for row in rights:
        archive_id = row["archive_id"].strip()
        label = f"{archive_id} {row.get('title', '').strip()}".strip()
        if (row.get("approved") or "").strip().lower() not in {"yes", "y", "да", "true", "1"}:
            skipped.append((label, "not approved"))
            continue
        valid_until = (row.get("valid_until") or "").strip()
        if valid_until and dt.date.fromisoformat(valid_until) < today:
            skipped.append((label, f"license expired {valid_until}"))
            continue
        source = by_id.get(archive_id)
        if source is None:
            skipped.append((label, "not in the archive registry"))
            continue
        episodes = sorted(source.get("episodes", []), key=lambda e: e["n"])
        expected = int(source.get("expected") or len(episodes))
        numbers = [e["n"] for e in episodes]
        complete = numbers == list(range(1, expected + 1))
        if not episodes or (not complete and not allow_partial):
            skipped.append((label, f"incomplete: {len(episodes)} of {expected} episodes"))
            continue
        try:
            territories = parse_territories(row.get("territories", ""))
        except ValueError as error:
            skipped.append((label, str(error)))
            continue

        extra = meta.get(archive_id, {})
        title = extra.get("title") or row.get("title") or source.get("title") or archive_id
        slug = (row.get("slug") or "").strip() or slugify(title)
        if slug in used_slugs:
            slug = f"{slug}-{archive_id}"
        used_slugs.add(slug)

        item = {
            "id": slug,
            "title": title,
            "synopsis": extra.get("synopsis", ""),
            "genres": extra.get("genres", []),
            "episodes": [
                {"number": e["n"], "video": e.get("url") or e["key"], **({"duration": e["duration"]} if "duration" in e else {})}
                for e in episodes
            ],
        }
        for key in ("poster", "badge", "views"):
            if key in extra:
                item[key] = extra[key]
        if territories:
            item["regions"] = territories
        series_out.append(item)

    return {"version": 1, "series": series_out}, skipped


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--registry", required=True, type=Path)
    parser.add_argument("--rights", required=True, type=Path)
    parser.add_argument("--meta", type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--today", type=dt.date.fromisoformat, default=dt.date.today())
    parser.add_argument("--allow-partial", action="store_true", help="keep series with missing episodes")
    args = parser.parse_args(argv)

    registry = json.loads(args.registry.read_text(encoding="utf-8"))
    rights = load_rights(args.rights)
    meta = json.loads(args.meta.read_text(encoding="utf-8")) if args.meta else {}
    catalog, skipped = build(registry, rights, meta, args.today, args.allow_partial)

    print(f"catalog: {len(catalog['series'])} series, {sum(len(s['episodes']) for s in catalog['series'])} episodes")
    for label, reason in skipped:
        print(f"  skipped {label}: {reason}")
    if not catalog["series"]:
        print("error: no approved series, catalog.json not written", file=sys.stderr)
        return 1
    args.out.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
