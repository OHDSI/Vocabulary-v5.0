"""
Source: TNM staging schemas
        Downloaded as a ZIP from the imsweb/staging-client-java GitHub releases.

Structure is identical to EOD — same ZIP format, same JSON layout.
We reuse the EOD parsing logic with a different ZIP URL/path.
"""

import json
import os
import sys
import zipfile

import requests

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config

TNM_ZIP_URL  = f"{config.STAGING_GITHUB_RELEASE}/tnm-{config.TNM_VERSION}.zip"
TNM_ZIP_PATH = os.path.join(config.DOWNLOAD_DIR, f"tnm-{config.TNM_VERSION}.zip")


def _download_zip(verbose=True):
    if os.path.exists(TNM_ZIP_PATH):
        if verbose:
            print(f"[tnm] Using cached {TNM_ZIP_PATH}")
        return TNM_ZIP_PATH

    if verbose:
        print(f"[tnm] Downloading TNM {config.TNM_VERSION} from GitHub...")
    r = requests.get(TNM_ZIP_URL, timeout=60, stream=True)
    r.raise_for_status()
    with open(TNM_ZIP_PATH, "wb") as f:
        for chunk in r.iter_content(chunk_size=65536):
            f.write(chunk)
    if verbose:
        size_mb = os.path.getsize(TNM_ZIP_PATH) / 1_000_000
        print(f"[tnm] Downloaded {size_mb:.1f} MB -> {TNM_ZIP_PATH}")
    return TNM_ZIP_PATH


def fetch_all(verbose=True):
    """
    Parse the TNM ZIP.  Returns the same structure as eod.fetch_all():

    schemas : list[dict]   (schema_id, schema_name, algorithm, version, naaccr_items)
    values  : list[dict]   (schema_id, table_id, table_name, item_number, code, description)
    """
    zip_path = _download_zip(verbose)

    schemas = []
    values  = []

    with zipfile.ZipFile(zip_path) as zf:
        names = zf.namelist()
        schema_files = [n for n in names if n.startswith("schemas/") and n.endswith(".json")]
        table_files  = [n for n in names if n.startswith("tables/")  and n.endswith(".json")]

        if verbose:
            print(f"[tnm] {len(schema_files)} schemas, {len(table_files)} tables in ZIP")

        tables = {}
        for tname in table_files:
            data = json.loads(zf.read(tname))
            tables[data["id"]] = data

        for sname in schema_files:
            schema = json.loads(zf.read(sname))
            schema_id   = schema["id"]
            schema_name = schema.get("name") or schema.get("title", schema_id)

            inputs = schema.get("inputs", [])
            item_by_table = {}
            naaccr_items  = []
            input_names   = {}   # item_number -> schema-specific display name
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
                "algorithm":    schema.get("algorithm", "tnm"),
                "version":      schema.get("version", config.TNM_VERSION),
                "naaccr_items": naaccr_items,
                "input_names":  input_names,
            })

            for inp in inputs:
                table_id = inp.get("table")
                if not table_id or table_id not in tables:
                    continue
                table       = tables[table_id]
                item_number = item_by_table.get(table_id)
                definition  = table.get("definition", [])
                rows        = table.get("rows", [])

                code_col = next(
                    (i for i, d in enumerate(definition) if d.get("type") == "INPUT"), 0
                )
                desc_col = next(
                    (i for i, d in enumerate(definition) if d.get("type") == "DESCRIPTION"), 1
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
        print(f"[tnm] Extracted {len(schemas)} schemas, {len(values)} value rows.")
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
