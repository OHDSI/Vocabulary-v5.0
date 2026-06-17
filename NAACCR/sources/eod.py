"""
Source: EOD (Extent of Disease) staging schemas
        Downloaded as a ZIP from the imsweb/staging-client-java GitHub releases.

Returns two lists:
  - schemas : list of dicts, one per EOD schema
  - values  : list of dicts, one per schema-specific code (schema@item@code triples)
"""

import io
import json
import os
import sys
import zipfile

import requests

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config

# GitHub release URL for EOD ZIP
EOD_ZIP_URL = (
    f"{config.STAGING_GITHUB_RELEASE}/eod_public-{config.EOD_VERSION}.zip"
)
EOD_ZIP_PATH = os.path.join(config.DOWNLOAD_DIR, f"eod_public-{config.EOD_VERSION}.zip")


def _download_zip(verbose=True):
    """Download the EOD ZIP if not already cached locally."""
    if os.path.exists(EOD_ZIP_PATH):
        if verbose:
            print(f"[eod] Using cached {EOD_ZIP_PATH}")
        return EOD_ZIP_PATH

    if verbose:
        print(f"[eod] Downloading EOD {config.EOD_VERSION} from GitHub...")
    r = requests.get(EOD_ZIP_URL, timeout=60, stream=True)
    r.raise_for_status()
    with open(EOD_ZIP_PATH, "wb") as f:
        for chunk in r.iter_content(chunk_size=65536):
            f.write(chunk)
    if verbose:
        size_mb = os.path.getsize(EOD_ZIP_PATH) / 1_000_000
        print(f"[eod] Downloaded {size_mb:.1f} MB -> {EOD_ZIP_PATH}")
    return EOD_ZIP_PATH


def fetch_all(verbose=True):
    """
    Parse the EOD ZIP and return schemas and their schema-specific values.

    Returns
    -------
    schemas : list[dict]
        One entry per schema with keys:
            schema_id, schema_name, algorithm, version,
            naaccr_items   (list of naaccr_item numbers used by this schema)
    values : list[dict]
        One entry per code row in a schema-specific table with keys:
            schema_id, table_id, table_name,
            item_number (from the input that references this table, or None),
            code, description
    """
    zip_path = _download_zip(verbose)

    schemas = []
    values = []

    with zipfile.ZipFile(zip_path) as zf:
        names = zf.namelist()
        schema_files = [n for n in names if n.startswith("schemas/") and n.endswith(".json")]
        table_files  = [n for n in names if n.startswith("tables/")  and n.endswith(".json")]

        if verbose:
            print(f"[eod] {len(schema_files)} schemas, {len(table_files)} tables in ZIP")

        # Load all tables into memory indexed by table id
        tables = {}
        for tname in table_files:
            data = json.loads(zf.read(tname))
            tables[data["id"]] = data

        # Process each schema
        for sname in schema_files:
            schema = json.loads(zf.read(sname))
            schema_id   = schema["id"]
            schema_name = schema.get("name") or schema.get("title", schema_id)

            # Build list of inputs: naaccr_item + table reference
            inputs = schema.get("inputs", [])
            item_by_table = {}   # table_id -> naaccr_item number
            naaccr_items = []
            input_names  = {}    # item_number -> schema-specific display name
            for inp in inputs:
                table_id    = inp.get("table")
                naaccr_item = inp.get("naaccr_item")
                if naaccr_item:
                    naaccr_items.append(str(naaccr_item))
                    inp_name = (inp.get("name") or "").strip()
                    if inp_name:
                        input_names[str(naaccr_item)] = inp_name
                if table_id and naaccr_item:
                    item_by_table[table_id] = str(naaccr_item)

            schemas.append({
                "schema_id":    schema_id,
                "schema_name":  schema_name,
                "algorithm":    schema.get("algorithm", "eod_public"),
                "version":      schema.get("version", config.EOD_VERSION),
                "naaccr_items": naaccr_items,
                "input_names":  input_names,
            })

            # Extract values from each referenced table
            for inp in inputs:
                table_id = inp.get("table")
                if not table_id or table_id not in tables:
                    continue
                table = tables[table_id]
                item_number = item_by_table.get(table_id)

                # The table has a definition row (column headers) and data rows
                definition = table.get("definition", [])
                rows = table.get("rows", [])

                # Find which column index is the code vs description
                code_col = next(
                    (i for i, d in enumerate(definition) if d.get("type") == "INPUT"),
                    0
                )
                desc_col = next(
                    (i for i, d in enumerate(definition) if d.get("type") == "DESCRIPTION"),
                    1
                )

                for row in rows:
                    if not row or len(row) < 2:
                        continue
                    code = str(row[code_col]).strip()
                    desc = str(row[desc_col]).strip() if len(row) > desc_col else ""
                    if code:
                        values.append({
                            "schema_id":   schema_id,
                            "table_id":    table_id,
                            "table_name":  table.get("name", table_id),
                            "item_number": item_number,
                            "code":        code,
                            "description": desc,
                        })

    if verbose:
        print(f"[eod] Extracted {len(schemas)} schemas, {len(values)} value rows.")
    return schemas, values


if __name__ == "__main__":
    schemas, values = fetch_all()
    print("\nSample schemas:")
    for s in schemas[:5]:
        print(f"  {s['schema_id']:40} {s['schema_name']}")
    print("\nSample values:")
    for v in values[:10]:
        code_str = f"{v['schema_id']}@{v['item_number']}@{v['code']}"
        print(f"  {code_str:55}  {v['description'][:50]}")
