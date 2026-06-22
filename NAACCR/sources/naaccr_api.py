"""
Source: NAACCR Data Dictionary API (api.seer.cancer.gov/rest/naaccr)

Fetches all NAACCR items (variables) for a given version, including their
allowed codes (permissible values where they exist).

Returns two lists:
  - variables : list of dicts, one per NAACCR item
  - values    : list of dicts, one per allowed code (item@code pairs)

Caching
-------
Results are cached in downloads/naaccr_api_v{version}.json.
Delete that file to force a fresh fetch from the API.
"""

import requests
import sys
import os
import json

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config

BASE = config.SEER_API_BASE
HEADERS = {"X-SEERAPI-Key": config.SEER_API_KEY}


def _get(path):
    url = f"{BASE}{path}"
    r = requests.get(url, headers=HEADERS, timeout=30)
    r.raise_for_status()
    return r.json()


def fetch_item_list(version=None):
    """Return the summary list of all items for a NAACCR version."""
    version = version or config.NAACCR_VERSION
    return _get(f"/naaccr/{version}")


def fetch_item_detail(item_number, version=None):
    """Return full detail for a single NAACCR item, including allowed_codes."""
    version = version or config.NAACCR_VERSION
    return _get(f"/naaccr/{version}/{item_number}")


def fetch_all_variables(version=None, verbose=True):
    """
    Fetch all NAACCR items and their allowed codes.

    Results are cached in downloads/naaccr_api_v{version}.json.
    Delete that file to force a fresh fetch from the API.

    Returns
    -------
    variables : list[dict]
        One entry per NAACCR item with keys:
            item_number, item_name, section, description,
            item_data_type, item_length, xml_naaccr_id
    values : list[dict]
        One entry per allowed code with keys:
            item_number, code, description
        Only items that have explicit allowed_codes are included.
    """
    version = version or config.NAACCR_VERSION
    cache_path = os.path.join(config.DOWNLOAD_DIR,
                              f"naaccr_api_v{version}.json")

    if os.path.exists(cache_path):
        with open(cache_path, encoding='utf-8') as f:
            cached = json.load(f)
        if verbose:
            print(f"[naaccr_api] Loaded {len(cached['variables'])} variables, "
                  f"{len(cached['values'])} values from cache.")
        return cached['variables'], cached['values']

    summary = fetch_item_list(version)
    total = len(summary)
    if verbose:
        print(f"[naaccr_api] Fetching {total} items for NAACCR v{version}...")

    variables = []
    values = []

    for i, entry in enumerate(summary, 1):
        item_number = entry["item"]
        detail = fetch_item_detail(item_number, version)

        variables.append({
            "item_number":    item_number,
            "item_name":      detail.get("item_name", ""),
            "section":        detail.get("section", ""),
            "description":    detail.get("description", ""),
            "item_data_type": detail.get("item_data_type", ""),
            "item_length":    detail.get("item_length", ""),
            "xml_naaccr_id":  detail.get("xml_naaccr_id", ""),
        })

        allowed = detail.get("allowed_codes") or []
        for code_entry in allowed:
            values.append({
                "item_number": item_number,
                "code":        code_entry.get("code", ""),
                "description": code_entry.get("description", ""),
            })

        if verbose and i % 50 == 0:
            print(f"  {i}/{total}")

    os.makedirs(config.DOWNLOAD_DIR, exist_ok=True)
    with open(cache_path, 'w', encoding='utf-8') as f:
        json.dump({'variables': variables, 'values': values}, f)

    if verbose:
        print(f"[naaccr_api] Done. {len(variables)} variables, "
              f"{len(values)} values. Cached to {cache_path}")

    return variables, values


def load_to_db(conn, verbose=True):
    """Fetch all NAACCR items and generic values, write to naaccr_items and
    naaccr_api_values in DB_SOURCES_SCHEMA.  Truncates before inserting."""
    import psycopg2.extras
    s = config.DB_SOURCES_SCHEMA
    variables, values = fetch_all_variables(verbose=verbose)
    cur = conn.cursor()
    cur.execute(f"TRUNCATE TABLE {s}.naaccr_items")
    psycopg2.extras.execute_values(cur,
        f"INSERT INTO {s}.naaccr_items "
        f"(item_number, item_name, section, xml_naaccr_id, item_data_type, item_length) "
        f"VALUES %s",
        [(v['item_number'], v['item_name'], v.get('section'), v.get('xml_naaccr_id'),
          v.get('item_data_type'), v.get('item_length')) for v in variables],
        page_size=500)
    cur.execute(f"TRUNCATE TABLE {s}.naaccr_api_values")
    psycopg2.extras.execute_values(cur,
        f"INSERT INTO {s}.naaccr_api_values (item_number, code, description) VALUES %s",
        [(v['item_number'], v['code'], v.get('description')) for v in values],
        page_size=500)
    if verbose:
        print(f"[naaccr_api] Loaded {len(variables)} rows -> {s}.naaccr_items, "
              f"{len(values)} rows -> {s}.naaccr_api_values")
    return len(variables), len(values)


if __name__ == "__main__":
    variables, values = fetch_all_variables()
    print(f"\nSample variables:")
    for v in variables[:5]:
        print(f"  {v['item_number']:>6}  {v['item_name']}")
    print(f"\nSample values:")
    for v in values[:10]:
        print(f"  {v['item_number']}@{v['code']:20}  {v['description'][:60]}")
