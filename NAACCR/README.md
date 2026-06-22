# NAACCR Vocabulary

Builds and maintains the **NAACCR** vocabulary in an OMOP CDM vocabulary database.
The pipeline fetches data from five upstream sources, assembles OMOP concept rows,
diffs them against the existing vocabulary, and writes the results into the
`concept_stage` and `concept_relationship_stage` tables for loading by the standard
OHDSI vocabulary pipeline.

See [DESIGN.md](DESIGN.md) for concept model rules, source details, and version notes.

---

## Prerequisites

- Python 3.9+
- `pip install psycopg2-binary python-dotenv requests beautifulsoup4 lxml`
- A SEER API key — register at <https://api.seer.cancer.gov>
- Read access to the source schema (`devv5` or `prodv5`) and write access to a work schema

---

## Configuration

Copy `.env.example` to `.env` and fill in the values:

```
DB_HOST=<postgres host>
DB_PORT=5432
DB_NAME=<database name>
DB_USER=<your user>
DB_PASSWORD=<your password>
DB_SOURCE_SCHEMA=devv5        # schema with existing OMOP vocabulary (read-only)
DB_WORK_SCHEMA=dev_christian  # schema where concept_stage tables are written
SEER_API_KEY=<your key>
NAACCR_VERSION=26             # optional, defaults to 26
EOD_VERSION=3.3               # optional, defaults to 3.3
TNM_VERSION=2.1               # optional, defaults to 2.1
```

`.env` is gitignored — never commit credentials.

---

## Running

```bash
# Full run: fetch sources, build concepts, diff, write to DB
python run.py

# Dry run: shows new/updated/retiring counts, writes nothing
python run.py --dry-run
```

Source data is cached in `downloads/` (also gitignored).  Delete a cache file to
force a fresh fetch on the next run:

| File / directory | Source |
|-----------------|--------|
| `downloads/naaccr_api_v26.json` | NAACCR API — all items and generic values |
| `downloads/naaccr_csv_lookups/` | imsweb/layout CSV lookup files |
| `downloads/naaccr_csv_values.json` | Parsed CSV values (delete to re-parse CSVs) |
| `downloads/eod_public-3.3.zip` | EOD staging schemas |
| `downloads/tnm-2.1.zip` | TNM staging schemas |

---

## Sources

| Source | Script | What it provides |
|--------|--------|-----------------|
| SEER API (`api.seer.cancer.gov`) | `sources/naaccr_api.py` | Item list (954 Variables), generic permissible values (~3,900) |
| imsweb/layout CSV lookups | `sources/naaccr_html.py` | Additional coded values for items with discrete lookup tables |
| imsweb/algorithms EOD ZIP | `sources/eod.py` | 141 EOD staging schemas and their schema-specific value tables |
| imsweb/algorithms TNM ZIP | `sources/tnm.py` | 153 TNM staging schemas and their schema-specific value tables |
| imsweb/algorithms surgery XML | `sources/surgery.py` | Surgery procedure codes for items 1290 and 1291 (30 schemas) |

All five sources are fetched on every full run; network calls are skipped when a
cached file exists.

---

## Output

Two tables in the work schema are truncated and reloaded on each full run:

### `concept_stage`

One row per concept.  Concept counts for NAACCR v26:

| Class | Approx. count | Description |
|-------|--------------|-------------|
| NAACCR Variable | ~960 | One per NAACCR data item |
| NAACCR Value | ~60,000 | Generic (`item@code`) and schema-specific (`schema@item@code`) |
| NAACCR Schema | ~294 | EOD and TNM staging schemas |
| NAACCR Proc Schema | 30 | Surgery procedure schema groupings |
| NAACCR Procedure | ~1,450 | Surgery procedure codes (items 1290/1291) |

### `concept_relationship_stage`

One row per directional relationship.  Relationship types used:

| Relationship | Direction | Meaning |
|-------------|-----------|---------|
| `Has Answer` | Variable → Value | This Variable accepts this coded Value |
| `Answer of` | Value → Variable | Reverse of Has Answer |
| `Schema to Value` | Schema → Value | This Schema includes this Value |
| `Value to Schema` | Value → Schema | Reverse of Schema to Value |
| `Concept replaced by` | Old → New | Retired concept points to its successor |
| `Concept replaces` | New → Old | Reverse of Concept replaced by |

Relationship counts are approximately:
- Has Answer / Answer of: ~90,000 pairs
- Schema to Value / Value to Schema: ~75,000 pairs
- Concept replaced by / replaces: ~1,400 pairs (surgery codes)

---

## Common errors

**`PermissionError` on source schema** — your DB user cannot read `DB_SOURCE_SCHEMA`.
Ask the DBA for SELECT on that schema, or change `DB_SOURCE_SCHEMA` to a schema
you can read (e.g. `devv5`).

**`KeyError: 'SEER_API_KEY'`** — `.env` is missing or not in the NAACCR directory.

**`HTTP 401` from SEER API** — API key is invalid or expired.  Register a new one
at <https://api.seer.cancer.gov>.

**`HTTP 404` for EOD or TNM ZIP** — `EOD_VERSION` or `TNM_VERSION` in `.env` does
not match a published release.  Check available releases at
<https://github.com/imsweb/staging-client-java/releases>.

**`UnicodeEncodeError`** — run Python with UTF-8 mode: `python -X utf8 run.py`
(Windows consoles default to CP1252; concept names contain arrows and other
non-ASCII characters).
