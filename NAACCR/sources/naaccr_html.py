"""
sources/naaccr_html.py

Downloads NAACCR permissible-value lookup tables from the imsweb/layout
CSV lookup directory:

  https://github.com/imsweb/layout/tree/master/docs/naaccr-lookups/lookups

Each CSV file is named after the NAACCR XML field ID (camelCase), which
matches the `xml_naaccr_id` returned by the SEER API for each item.  The
files contain two columns: Code and Description.

This source replaced the earlier HTML scraper (which scraped 954 HTML
documentation files) because:
  1. Clean structured CSV — no HTML parsing needed.
  2. The CSV files naturally omit true SSDI items (site-specific data items
     whose code tables vary by schema).  The HTML files included them,
     requiring a post-hoc SSDI suppression filter.  The CSVs avoid that
     problem entirely.

Coverage (v26): 280 CSV files, ~6,000+ values.

Caching: CSV files are saved in downloads/naaccr_csv_lookups/ and a parsed
summary in downloads/naaccr_csv_values.json.  Delete either to force a
fresh download.
"""

import os
import csv
import json
import requests
from io import StringIO
from concurrent.futures import ThreadPoolExecutor, as_completed

import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config

GITHUB_API_URL  = (
    "https://api.github.com/repos/imsweb/layout/contents/"
    "docs/naaccr-lookups/lookups"
)
GITHUB_RAW_BASE = (
    "https://raw.githubusercontent.com/imsweb/layout/master/"
    "docs/naaccr-lookups/lookups"
)

CACHE_DIR    = os.path.join(config.DOWNLOAD_DIR, "naaccr_csv_lookups")
CACHE_INDEX  = os.path.join(config.DOWNLOAD_DIR, "naaccr_csv_index.json")
CACHE_VALUES = os.path.join(config.DOWNLOAD_DIR, "naaccr_csv_values.json")

_MAX_WORKERS = 20


# ── File listing ──────────────────────────────────────────────────────────────

def _get_csv_list():
    """
    Return list of (xml_naaccr_id, filename) tuples from the GitHub API.
    Cached in CACHE_INDEX.
    """
    if os.path.exists(CACHE_INDEX):
        with open(CACHE_INDEX, encoding='utf-8') as f:
            return json.load(f)

    r = requests.get(GITHUB_API_URL, params={'per_page': 300}, timeout=30)
    r.raise_for_status()
    entries = [
        (item['name'].replace('.csv', ''), item['name'])
        for item in r.json()
        if item.get('type') == 'file' and item['name'].endswith('.csv')
    ]

    os.makedirs(config.DOWNLOAD_DIR, exist_ok=True)
    with open(CACHE_INDEX, 'w', encoding='utf-8') as f:
        json.dump(entries, f)
    return entries


# ── CSV download ──────────────────────────────────────────────────────────────

def _fetch_one(filename):
    """Download a single CSV file; return (filename, text or None)."""
    cache_path = os.path.join(CACHE_DIR, filename)
    if os.path.exists(cache_path):
        with open(cache_path, encoding='utf-8') as f:
            return filename, f.read()
    url = f"{GITHUB_RAW_BASE}/{filename}"
    try:
        r = requests.get(url, timeout=20)
        r.raise_for_status()
        text = r.text
        with open(cache_path, 'w', encoding='utf-8') as f:
            f.write(text)
        return filename, text
    except Exception:
        return filename, None


def _download_all(entries, verbose=True):
    """Download all CSVs concurrently. Returns {filename: text}."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    filenames = [fn for _, fn in entries]

    cached  = [fn for fn in filenames if os.path.exists(os.path.join(CACHE_DIR, fn))]
    missing = [fn for fn in filenames if fn not in cached]

    if verbose and missing:
        print(f"[naaccr_csv] Downloading {len(missing)} CSV files "
              f"({len(cached)} already cached)...")

    results = {}
    for fn in cached:
        with open(os.path.join(CACHE_DIR, fn), encoding='utf-8') as f:
            results[fn] = f.read()

    if missing:
        with ThreadPoolExecutor(max_workers=_MAX_WORKERS) as pool:
            futures = {pool.submit(_fetch_one, fn): fn for fn in missing}
            done = 0
            for fut in as_completed(futures):
                fn, text = fut.result()
                if text:
                    results[fn] = text
                done += 1
                if verbose and done % 50 == 0:
                    print(f"  {done}/{len(missing)} downloaded...")

    return results


# ── CSV parsing ───────────────────────────────────────────────────────────────

def _parse_csv(text):
    """
    Parse a lookup CSV.  Returns list of (code, description) pairs.
    Handles both quoted and unquoted values; skips header row.
    """
    reader = csv.reader(StringIO(text))
    rows = []
    for i, row in enumerate(reader):
        if i == 0:
            continue   # header
        if len(row) >= 2:
            code = row[0].strip()
            desc = row[1].strip()
            if code:
                rows.append((code, desc))
    return rows


# ── Main entry point ──────────────────────────────────────────────────────────

def fetch_all_values(verbose=True):
    """
    Fetch all NAACCR CSV lookup tables and return coded values.

    The csv files are matched to NAACCR item numbers via the xml_naaccr_id
    field from the SEER API.  Items whose xml_naaccr_id has no matching CSV
    have no discrete code table (free-text or continuous numeric fields).

    Uses a parsed-values cache (CACHE_VALUES) so subsequent calls are instant.
    Delete that file to force a full re-parse.

    Returns
    -------
    list of dicts with keys: item_number, code, description
    """
    if os.path.exists(CACHE_VALUES):
        with open(CACHE_VALUES, encoding='utf-8') as f:
            values = json.load(f)
        if verbose:
            print(f"[naaccr_csv] Loaded {len(values)} values from cache.")
        return values

    # Items whose CSV files contain external vocabulary codes rather than NAACCR
    # permissible values — excluded to avoid polluting the NAACCR vocabulary.
    _EXCLUDE_ITEMS = {
        '1910',   # Cause of Death — 93,000+ ICD-10 codes; belongs in ICD10 vocabulary
        '1960',   # Site (73-91) ICD-O-1 — historical ICD-O-1 topography codes
    }

    # Build xml_naaccr_id → item_number map from the SEER API.
    # All sections are included — the CSV files cover whatever sections imsweb has
    # published lookup tables for (Demographic, Treatment, Radiation, etc.).
    # The _ssdi_items filter in build_concepts.py ensures that any SSDI item
    # accidentally covered by a CSV file does not produce spurious generic 2-part
    # values.
    from sources.naaccr_api import fetch_all_variables
    if verbose:
        print("[naaccr_csv] Building xml_naaccr_id -> item_number map from API...")
    variables, _ = fetch_all_variables(verbose=False)
    xml_to_item = {
        v['xml_naaccr_id']: v['item_number']
        for v in variables
        if v.get('xml_naaccr_id') and v['item_number'] not in _EXCLUDE_ITEMS
    }

    entries = _get_csv_list()
    csv_texts = _download_all(entries, verbose=verbose)

    if verbose:
        print(f"[naaccr_csv] Parsing {len(csv_texts)} CSV files...")

    values   = []
    skipped  = 0
    no_match = 0

    for xml_id, filename in entries:
        text = csv_texts.get(filename)
        if not text:
            skipped += 1
            continue

        item_number = xml_to_item.get(xml_id)
        if not item_number:
            no_match += 1
            continue

        for code, desc in _parse_csv(text):
            values.append({
                'item_number': item_number,
                'code':        code,
                'description': desc,
            })

    os.makedirs(config.DOWNLOAD_DIR, exist_ok=True)
    with open(CACHE_VALUES, 'w', encoding='utf-8') as f:
        json.dump(values, f)

    if verbose:
        unique_items = len({v['item_number'] for v in values})
        print(f"[naaccr_csv] Done. {len(values)} values from {unique_items} items "
              f"({skipped} download failures, {no_match} CSVs with no API match).")

    return values


def load_to_db(conn, verbose=True):
    """Fetch all CSV lookup values, write to naaccr_csv_values in
    DB_SOURCES_SCHEMA.  Truncates before inserting."""
    import psycopg2.extras
    s = config.DB_SOURCES_SCHEMA
    values = fetch_all_values(verbose=verbose)
    cur = conn.cursor()
    cur.execute(f"TRUNCATE TABLE {s}.naaccr_csv_values")
    psycopg2.extras.execute_values(cur,
        f"INSERT INTO {s}.naaccr_csv_values (item_number, code, description) VALUES %s",
        [(v['item_number'], v['code'], v.get('description')) for v in values],
        page_size=500)
    if verbose:
        print(f"[naaccr_csv] Loaded {len(values)} rows -> {s}.naaccr_csv_values")
    return len(values)


if __name__ == "__main__":
    vals = fetch_all_values(verbose=True)
    from collections import Counter
    top = Counter(v['item_number'] for v in vals).most_common(10)
    print("\nTop 10 items by value count:")
    for item, cnt in top:
        print(f"  item {item:>6}: {cnt} codes")
