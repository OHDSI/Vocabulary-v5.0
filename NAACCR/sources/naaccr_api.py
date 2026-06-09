"""
Source: NAACCR Data Dictionary API (api.seer.cancer.gov/rest/naaccr)

Fetches all NAACCR items (variables) for a given version, including their
allowed codes (permissible values where they exist).

Returns two lists:
  - variables : list of dicts, one per NAACCR item
  - values    : list of dicts, one per allowed code (item@code pairs)
"""

import requests
import sys
import os

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

    if verbose:
        print(f"[naaccr_api] Done. {len(variables)} variables, {len(values)} values.")

    return variables, values


if __name__ == "__main__":
    variables, values = fetch_all_variables()
    print(f"\nSample variables:")
    for v in variables[:5]:
        print(f"  {v['item_number']:>6}  {v['item_name']}")
    print(f"\nSample values:")
    for v in values[:10]:
        print(f"  {v['item_number']}@{v['code']:20}  {v['description'][:60]}")
