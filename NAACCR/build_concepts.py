"""
build_concepts.py

Assembles all source data into a dict of OMOP concept rows keyed by concept_code.

Domain assignment rules (reverse-engineered from ProdV5, refined with Christian):

  NAACCR Variable
    Section "Stage/Prognostic Factors"
        → Measurement

    Section "Treatment-1st Course"
        name is a date field (contains "Date", no "Flag") → Metadata
        name matches RX Summ--* or Radiation Treatment Modality  → Episode
        name matches dose/fraction/volume/margin/nodes keywords  → Measurement
        else                                                     → Observation

    Section "Cancer Identification"
        name is a date field (contains "Date", no "Flag") → Metadata
        name matches grade/laterality/multiplicity keywords      → Measurement
        else                                                     → Observation

    All other sections (Demographic, Pathology, Admin, Follow-up, etc.)
        → Observation

    Blank section (new v26 items not in old vocabulary)
        → Observation

  NAACCR Value  (2-part code: item@code  or 3-part: schema@item@code)
    domain_id mirrors parent Variable:
        Measurement parent → Meas Value
        Episode parent     → Observation   (treatment values; flavors-of-null fall here too)
        everything else    → Observation

    standard_concept = None  (entire vocabulary will be de-standardized
                               and mapped to SNOMED/Cancer Modifier/OMOP Genomic)

  NAACCR Schema  (EOD/TNM schema ids)
    domain_id = Observation,  standard_concept = None

  NAACCR Variable — compound SSDI  (schema@item)
    Same domain as the plain numeric Variable for that item.
    standard_concept = None
"""

import re
import sys
import config
from sources import naaccr_api, naaccr_html, eod, tnm, surgery

# ── Domain assignment ─────────────────────────────────────────────────────────

def _variable_domain(item):
    """Return domain_id for a NAACCR Variable given its API detail dict."""
    section = (item.get("section") or "").strip()
    name    = (item.get("item_name") or "").lower()

    # ── Stage/Prognostic Factors ──────────────────────────────────────────────
    if section == "Stage/Prognostic Factors":
        return "Measurement"

    # ── Treatment-1st Course ──────────────────────────────────────────────────
    if section == "Treatment-1st Course":
        # Dates (no "flag")
        if "date" in name and "flag" not in name:
            return "Metadata"
        # Treatment summary / modality → Episode
        if name.startswith("rx summ--") or "radiation treatment modality" in name:
            return "Episode"
        # Radiation measurements → Measurement
        _rx_meas = ("dose", "fraction", "volume", "margin", "nodes examined",
                    "regional dose", "number of treatment")
        if any(k in name for k in _rx_meas):
            return "Measurement"
        # Surgical margins / nodes examined also Measurement
        if "surgical margins" in name or "reg ln examined" in name:
            return "Measurement"
        return "Observation"

    # ── Cancer Identification ─────────────────────────────────────────────────
    if section == "Cancer Identification":
        if "date" in name and "flag" not in name:
            return "Metadata"
        _ci_meas = ("grade", "laterality", "multiplicity", "mult tum")
        if any(k in name for k in _ci_meas):
            return "Measurement"
        return "Observation"

    # ── Everything else ───────────────────────────────────────────────────────
    return "Observation"


def _value_domain(parent_domain):
    """Return domain_id for a Value concept given its parent Variable's domain."""
    if parent_domain == "Measurement":
        return "Meas Value"
    return "Observation"


def _clean(s, n=255):
    """Normalize a concept name to plain ASCII-safe text, then truncate to n chars."""
    if not s:
        return ""
    # ── Mojibake: UTF-8 multi-byte sequences decoded as Latin-1 / CP-1252 ──────
    # ® (U+00AE, UTF-8: 0xC2 0xAE) read as Latin-1 → Â® (U+00C2 U+00AE)
    s = s.replace('\xc2\xae', '®')
    # em-dash (U+2014, UTF-8: 0xE2 0x80 0x94) read as CP-1252 → â€" (U+00E2 U+20AC U+201D)
    s = s.replace('\xe2€”', '—')
    # ── Typographic normalization ─────────────────────────────────────────────
    s = s.replace('\xa0', ' ')          # non-breaking space → space
    s = s.replace('–', ' - ')      # en-dash → spaced hyphen
    s = s.replace('—', ' - ')      # em-dash → spaced hyphen
    s = s.replace('’', "'")        # right single quote → straight apostrophe
    s = s.replace('‘', "'")        # left single quote → straight apostrophe
    s = s.replace('“', '"')        # left double quote → straight quote
    s = s.replace('”', '"')        # right double quote → straight quote
    s = s.replace('•', ' - ')      # bullet → spaced hyphen
    s = s.replace('�', '')         # Unicode replacement char → remove
    # ── Markdown formatting artifacts ────────────────────────────────────────
    s = s.replace('**', '')             # bold markers → remove
    s = re.sub(r'\\([*_])', r'\1', s)  # \* \_ → * _
    # ── Whitespace and separators ─────────────────────────────────────────────
    s = re.sub(r'[\r\n]+', ' ', s)
    s = re.sub(r'\|+', ' ', s)
    s = re.sub(r' {2,}', ' ', s)
    s = s.strip()
    if len(s) > n:
        s = s[:n - 3] + '...'
    return s

# Keep _truncate as an alias for callers that use it directly
_truncate = _clean


# ── Main assembly ─────────────────────────────────────────────────────────────

def build(verbose=True):
    """
    Fetch all sources and assemble OMOP concept rows.

    Returns
    -------
    concepts : dict  concept_code -> concept dict
    relationships : list of relationship dicts
    """
    # 1. NAACCR variables + generic values from API
    if verbose:
        print("[build] Fetching NAACCR variables from API...")
    variables, api_values = naaccr_api.fetch_all_variables(verbose=verbose)
    var_by_item = {v["item_number"]: v for v in variables}

    # 2. HTML documentation values (fills the ~27k gap vs the API's ~4k)
    if verbose:
        print("[build] Fetching NAACCR HTML documentation values...")
    html_values = naaccr_html.fetch_all_values(verbose=verbose)

    # 3. EOD schemas
    if verbose:
        print("[build] Parsing EOD schemas...")
    eod_schemas, eod_values = eod.fetch_all(verbose=verbose)

    # 4. TNM schemas
    if verbose:
        print("[build] Parsing TNM schemas...")
    tnm_schemas, tnm_values = tnm.fetch_all(verbose=verbose)

    # 5. Surgery procedure codes (1290 + 1291)
    if verbose:
        print("[build] Fetching surgery codes...")
    surgery_concepts, surgery_relationships = surgery.fetch_all(verbose=verbose)

    concepts      = {}
    relationships = []

    # ── Schema name resolution ────────────────────────────────────────────────
    # Rules:
    #   Existing schemas (concept_code already in DB):
    #     Keep the DB concept_name (longer, more descriptive).
    #     If the EOD title contains a year-range suffix like "[8th: 2018-2022]"
    #     or "[V9: 2023+]", append it to the DB name so the edition is visible.
    #   New schemas (not in DB):
    #     Use the EOD title directly.
    #   Never change concept_code — old codes remain valid forever.
    _conn = config.get_db_conn()
    _cur = _conn.cursor()
    _cur.execute(f"""SELECT concept_code, concept_name
                    FROM {config.DB_SOURCE_SCHEMA}.concept
                    WHERE vocabulary_id = 'NAACCR'
                    AND concept_class_id = 'NAACCR Schema'""")
    _db_schema_names = {r[0]: r[1] for r in _cur.fetchall()}
    _conn.close()

    _YEAR_RANGE_RE = re.compile(r'\[(?:8th|V\d+)[^\]]*\]')

    def _schema_name(schema_id, eod_title):
        """
        Return the concept_name to use for a schema concept.
        Existing schemas: DB name + edition suffix (if EOD title has one).
        New schemas:      EOD title as-is.
        """
        suffix_match = _YEAR_RANGE_RE.search(eod_title or '')
        suffix = suffix_match.group(0) if suffix_match else ''

        if schema_id in _db_schema_names:
            db_name = _db_schema_names[schema_id]
            if suffix and suffix not in db_name:
                return _truncate(f"{db_name} {suffix}")
            return _truncate(db_name)
        # New schema — use EOD title
        return _truncate(eod_title or schema_id)

    # ── Plain NAACCR Variables ────────────────────────────────────────────────
    for item in variables:
        code   = item["item_number"]
        domain = _variable_domain(item)
        concepts[code] = {
            "concept_code":     code,
            "concept_name":     _truncate(item["item_name"]),
            "concept_class_id": config.CLASS_VARIABLE,
            "domain_id":        domain,
            "vocabulary_id":    config.VOCABULARY_ID,
            "standard_concept": None,
        }

    # ── Generic Values (item@code) ────────────────────────────────────────────
    # Items that appear in EOD/TNM as schema-specific (3-part) values must NOT
    # also be emitted as 2-part generic values — the DB keeps these mutually
    # exclusive by design.  The API already respects this rule; the HTML scraper
    # does not, so we filter here.
    _ssdi_items = {v['item_number']
                   for v in (eod_values + tnm_values)
                   if v.get('item_number')}

    # Merge API values and HTML values; HTML takes precedence (more complete).
    generic_value_map = {}
    for val in api_values:
        if val['item_number'] in _ssdi_items:
            continue
        key = f"{val['item_number']}@{val['code']}"
        generic_value_map[key] = val
    for val in html_values:
        if val['item_number'] in _ssdi_items:
            continue
        key = f"{val['item_number']}@{val['code']}"
        generic_value_map[key] = val   # HTML overrides API where both exist

    for val in generic_value_map.values():
        item_num = val["item_number"]
        code     = f"{item_num}@{val['code']}"
        name     = _truncate(val["description"])
        if not name:
            continue
        parent_domain = _variable_domain(var_by_item.get(item_num, {}))
        is_range = bool(re.match(r'^[01]\d*\.?\d*-\d+\.?\d*$', val["code"]))
        concepts[code] = {
            "concept_code":     code,
            "concept_name":     name,
            "concept_class_id": config.CLASS_PERM_RANGE if is_range else config.CLASS_VALUE,
            "domain_id":        "Meas Value" if is_range else _value_domain(parent_domain),
            "vocabulary_id":    config.VOCABULARY_ID,
            "standard_concept": None,
        }
        if item_num in concepts:
            relationships.append(
                {"concept_code_1": item_num, "concept_code_2": code,
                 "relationship_id": "Has Answer"})

        # Zero-padding transition: if the source uses @0N (leading zero, e.g. @08)
        # and the bare @N form (e.g. @8) is absent from the source, the old code
        # was retired when the v26 coding scheme moved to 2-digit zero-padded codes.
        raw_val = val["code"]
        if len(raw_val) == 2 and raw_val[0] == "0" and raw_val[1].isdigit():
            old_code = f"{item_num}@{raw_val[1]}"
            if old_code not in generic_value_map:
                relationships.append({
                    "concept_code_1": old_code,
                    "concept_code_2": code,
                    "relationship_id": "Concept replaced by",
                })


    # ── Schemas (EOD + TNM) ───────────────────────────────────────────────────
    # Collect all schema inputs for compound Variable generation later
    all_schema_inputs  = []   # list of (schema_id, item_number, schema_specific_name)
    all_schema_values  = []   # combined eod + tnm value rows

    for s in eod_schemas:
        sid = s["schema_id"]
        concepts[sid] = {
            "concept_code":     sid,
            "concept_name":     _schema_name(sid, s["schema_name"]),
            "concept_class_id": config.CLASS_SCHEMA,
            "domain_id":        "Observation",
            "vocabulary_id":    config.VOCABULARY_ID,
            "standard_concept": None,
        }
        inp_names = s.get("input_names", {})
        for item_num in s["naaccr_items"]:
            all_schema_inputs.append((sid, item_num, inp_names.get(item_num, "")))
    all_schema_values.extend(eod_values)

    for s in tnm_schemas:
        sid = s["schema_id"]
        if sid not in concepts:
            concepts[sid] = {
                "concept_code":     sid,
                "concept_name":     _schema_name(sid, s["schema_name"]),
                "concept_class_id": config.CLASS_SCHEMA,
                "domain_id":        "Observation",
                "vocabulary_id":    config.VOCABULARY_ID,
                "standard_concept": None,
            }
        inp_names = s.get("input_names", {})
        for item_num in s["naaccr_items"]:
            all_schema_inputs.append((sid, item_num, inp_names.get(item_num, "")))
    all_schema_values.extend(tnm_values)

    # ── Compound SSDI Variables (schema@item) ─────────────────────────────────
    # Only create compound Variable concepts for true SSDI items — those that
    # appear in a SUBSET of schemas.  Items that appear in ALL EOD schemas are
    # generic staging variables (Tumor Size, EOD Primary Tumor, Regional Nodes,
    # Summary Stage, etc.) and stay as plain Variables only.
    #
    # Generic shared items to skip entirely:
    _GENERIC_ITEMS = {"400", "522", "523", "390", "500", "10", "40"}
    # Previously, items that appeared in all 141 EOD schemas were excluded from
    # compound Variable generation on the assumption that their code tables were
    # universal.  Inspection shows that most of these items (752, 754, 820, 830,
    # 764, 772, 774, 776, 1068, 1634, 3843, 3844, 3845) have 3–130 distinct
    # code-table variants across schemas — they are genuine SSDIs.  Only 1632
    # and 1633 are truly identical across all schemas.  All are treated as SSDIs.
    _SKIP_COMPOUND = _GENERIC_ITEMS

    seen_compound = set()
    for sid, item_num, schema_specific_name in all_schema_inputs:
        if item_num in _SKIP_COMPOUND:
            continue
        compound_code = f"{sid}@{item_num}"
        if compound_code in seen_compound:
            continue
        seen_compound.add(compound_code)

        # Inherit domain from the plain variable if known
        parent = var_by_item.get(item_num, {})
        domain = _variable_domain(parent) if parent else "Measurement"
        # Prefer the schema-specific name from EOD/TNM inputs[].name over
        # the generic SEER API item_name (e.g. avoids "CS Site-Specific Factor 8")
        api_name  = parent.get("item_name", item_num) if parent else item_num
        item_name = schema_specific_name or api_name

        # Only add if not already in the DB (compare.py will filter further)
        concepts[compound_code] = {
            "concept_code":     compound_code,
            "concept_name":     _truncate(item_name),
            "concept_class_id": config.CLASS_VARIABLE,
            "domain_id":        domain,
            "vocabulary_id":    config.VOCABULARY_ID,
            "standard_concept": None,
        }

        # Schema to Variable relationship (reverse placed automatically by vocab system)
        if sid in concepts:
            relationships.append(
                {"concept_code_1": sid, "concept_code_2": compound_code,
                 "relationship_id": "Schema to Variable"})

    # ── Schema-specific Values (schema@item@code) ─────────────────────────────
    _SKIP_ITEMS = _GENERIC_ITEMS  # for schema-specific values, only skip admin items

    _RANGE_RE = re.compile(r'^[01]\d*\.?\d*-\d+\.?\d*$')

    for val in all_schema_values:
        item_num  = val.get("item_number")
        schema_id = val["schema_id"]
        if not item_num or item_num in _SKIP_ITEMS:
            continue

        # Skip EOD/TNM internal template placeholders (staging logic, not values).
        raw_code = str(val['code'])
        if '{{' in raw_code:
            continue

        code = f"{schema_id}@{item_num}@{raw_code}"
        if len(code) > 50:
            continue   # safety net: drop anything still over the DB column limit

        name = _truncate(val["description"])
        if not name:
            continue

        # Only emit relationships the first time we see this concept_code.
        # The same schema@item@code can appear in both EOD and TNM value rows;
        # the second pass would overwrite the concept (fine) but must not
        # append duplicate relationships.
        is_new = code not in concepts
        is_range = bool(_RANGE_RE.match(raw_code))

        parent_domain = _variable_domain(var_by_item.get(item_num, {}))
        concepts[code] = {
            "concept_code":     code,
            "concept_name":     name,
            "concept_class_id": config.CLASS_PERM_RANGE if is_range else config.CLASS_VALUE,
            "domain_id":        "Meas Value" if is_range else _value_domain(parent_domain),
            "vocabulary_id":    config.VOCABULARY_ID,
            "standard_concept": None,
        }

        if is_new:
            # Schema to Value (reverse placed automatically by vocab system)
            if schema_id in concepts:
                relationships.append(
                    {"concept_code_1": schema_id, "concept_code_2": code,
                     "relationship_id": "Schema to Value"})

            # Has Answer: compound SSDI Variable -> schema-specific Value
            compound_var = f"{schema_id}@{item_num}"
            if compound_var in concepts:
                relationships.append(
                    {"concept_code_1": compound_var, "concept_code_2": code,
                     "relationship_id": "Has Answer"})

    # ── Surgery Procedure concepts (1290 + 1291) ──────────────────────────────
    for sc in surgery_concepts:
        concepts[sc["concept_code"]] = sc
    relationships.extend(surgery_relationships)


    if verbose:
        from collections import Counter
        counts = Counter(c["concept_class_id"] for c in concepts.values())
        dom_counts = Counter(c["domain_id"] for c in concepts.values())
        print("\n[build] Concept counts by class:")
        for cls, cnt in sorted(counts.items()):
            print(f"  {cls:30} {cnt:>7}")
        print(f"  {'TOTAL':30} {len(concepts):>7}")
        print("\n[build] Concept counts by domain:")
        for dom, cnt in sorted(dom_counts.items(), key=lambda x: -x[1]):
            print(f"  {dom:20} {cnt:>7}")
        print(f"\n[build] Relationships: {len(relationships)}")

    return concepts, relationships


if __name__ == "__main__":
    concepts, relationships = build()
