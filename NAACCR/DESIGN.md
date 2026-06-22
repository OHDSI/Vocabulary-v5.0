# NAACCR Vocabulary — Design and Rules

This document covers the concept model, data sources, build rules, and version
considerations for the NAACCR vocabulary.  It is the authoritative reference for
anyone extending or updating the pipeline.

**Current versions: NAACCR v26 · EOD Public 3.3 · TNM 2.1**

---

## Concept model

### Concept classes and code formats

| Class | Code format | Example | `standard_concept` |
|-------|------------|---------|-------------------|
| NAACCR Variable | `{item}` | `400` | NULL |
| NAACCR Value (generic) | `{item}@{code}` | `400@C500` | NULL |
| NAACCR Value (schema-specific) | `{schema}@{item}@{code}` | `breast@3861@010` | NULL |
| NAACCR Schema | `{schema_id}` | `breast` | NULL |
| NAACCR Proc Schema | `{proc_schema}` | `Breast` | NULL |
| NAACCR Procedure | `{proc_schema}@{item}@{code}` | `Breast@1291@B200` | S |
| Permissible Range | `{item}@{range}` | `3800@002-988` | NULL (retiring) |

NAACCR Procedures carry `standard_concept = 'S'` because there is no external
procedure terminology that adequately covers cancer surgery codes; they are their
own standard.

**Terminology note:** NAACCR and its API use the word "code" for what OMOP calls
a "value" — a single permissible entry for a data item.  For example, item 220
(Sex) has codes `1` = Male, `2` = Female, `9` = Unknown.  In the source fetch
tables (`naaccr_api_values`, `naaccr_csv_values`, etc.) the column is named `code`
following the upstream API.  In the OMOP vocabulary these become `NAACCR Value`
concepts and are linked to their parent Variable by a `Has Answer` relationship.

**Concept codes are immutable.**  A `concept_code` is the permanent identifier.
Renaming a concept is done through `concept_name`; retiring and replacing one
requires retiring the old concept and creating a new one with a
`Concept replaced by` relationship.

---

### Generic vs. schema-specific values (the SSDI rule)

NAACCR data items fall into two categories:

**Generic items** have a single code table that applies the same way for every
cancer site.  Examples: Sex (item 220), Marital Status at DX (item 282), Race 1
(item 160).  These produce:
- One `NAACCR Variable` concept (code = item number, e.g. `220`)
- One `NAACCR Value` per code (2-part code, e.g. `220@1`)
- One `Has Answer` relationship per value

**Site-Specific Data Items (SSDIs)** have code tables that differ by cancer site.
The same item number means different things in the Breast schema vs. the Lung
schema.  Examples: Tumor Size Summary (item 752), LN Size (item 3882), and all
schema-specific staging fields.  These produce:
- One `NAACCR Schema` per EOD/TNM schema (code = schema ID, e.g. `breast`)
- One compound `NAACCR Variable` per schema-item pair (code = `breast@752`)
- One schema-specific `NAACCR Value` per code (3-part code, e.g. `breast@752@010`)
- One `Has Answer` from the compound Variable to each value
- One `Schema to Value` from the schema to each value

**An item cannot be both generic and SSDI.**  The build pipeline detects SSDI
items as those that appear in any EOD or TNM schema input list.  Once an item is
identified as SSDI, all its values come exclusively from the schema-specific code
tables; no 2-part generic Values are generated for it.

The imsweb/layout CSV lookup files respect this rule naturally — they only provide
files for generic items.  The SEER API `allowed_codes` field also omits SSDI values
by design.  The `_ssdi_items` filter in `build_concepts.py` is a safety net for
edge cases where a source crosses the boundary.

**Generic items that appear in all schemas** (e.g. EOD Primary Tumor (item 772),
Regional Nodes Examined (item 820)) look like SSDIs because they appear in every
EOD schema input list.  As of v26, inspection of their code tables shows most have
schema-specific variants — they are genuine SSDIs.  Only a small set of truly
universal utility items (item 400, 500, 10, 40, 390, 522, 523) are hardcoded in
`_SKIP_COMPOUND` and treated as generic.

---

### Relationships

All relationships are bidirectional: the pipeline emits one direction; the OHDSI
vocabulary loader (`ProcessManualRelationships`) adds the reverse automatically.

| Relationship emitted | Auto-reverse |
|---------------------|-------------|
| `Has Answer` | `Answer of` |
| `Schema to Value` | `Value to Schema` |
| `Concept replaced by` | `Concept replaces` |

---

### Domain assignment

Domain is assigned to Variables by section and item name; Values inherit from
their parent Variable.

| Condition | Domain |
|-----------|--------|
| Section = "Stage/Prognostic Factors" | Measurement |
| Section = "Treatment-1st Course", name is a date field | Metadata |
| Section = "Treatment-1st Course", name matches RX Summ or radiation modality | Episode |
| Section = "Treatment-1st Course", name matches dose/fraction/volume/margin | Measurement |
| Section = "Cancer Identification", name is a date field | Metadata |
| Section = "Cancer Identification", name matches grade/laterality/multiplicity | Measurement |
| All other sections and items without a section | Observation |

Values take `Meas Value` when their parent Variable is Measurement; otherwise
`Observation`.  Procedures take `Procedure`.

---

## Data sources

### 1. NAACCR API — `sources/naaccr_api.py`

**URL:** `https://api.seer.cancer.gov/rest/naaccr/{version}`  
**Auth:** SEER API key  
**v26 coverage:** 954 Variables, ~3,900 generic Values

Provides the canonical list of NAACCR data items with their item numbers, names,
sections, and `allowed_codes` arrays.  The `xml_naaccr_id` field (camelCase XML
field name) is used to link items to their CSV lookup files.

The API does not return values for SSDI items — it correctly returns an empty
`allowed_codes` for them.

**Caching:** Results cached as `downloads/naaccr_api_v{version}.json`.

---

### 2. imsweb/layout CSV lookup tables — `sources/naaccr_html.py`

**URL:** `https://github.com/imsweb/layout/tree/master/docs/naaccr-lookups/lookups`  
**v26 coverage:** 280 CSV files, 6,773 values across 241 items

One CSV file per NAACCR item that has a discrete code table, named by
`xml_naaccr_id` (e.g. `grade.csv`, `maritalStatusAtDx.csv`).  The `xml_naaccr_id`
field from the SEER API provides the mapping from filename to item number.

These files are the machine-readable form of the NAACCR permissible value tables.
They supplement the API — items whose `allowed_codes` is empty in the API but have
a CSV file get their values from here.

**History:** Before v26, this module scraped 954 HTML documentation files from the
same repository.  The HTML files included SSDI items (requiring post-hoc filtering)
and large ICD/ICD-O tables that belong to other vocabularies.  The CSV files are
cleaner and more narrowly scoped; the HTML scraper was retired.

**Excluded items:** Two items are explicitly excluded because their CSV files contain
external vocabulary codes rather than NAACCR permissible values: item 1910
(Cause of Death — 93,000+ ICD-10 codes) and item 1960 (Site 73-91 ICD-O-1).
These belong in the ICD10 and ICD-O vocabularies respectively.

**Known gap:** A small number of items (e.g. item 1540 Rad--Treatment Volume,
item 3200 Rad--Boost RX Modality) have neither a CSV lookup file nor API
`allowed_codes`.  They produce no Values until imsweb publishes CSV files for them.

**Caching:** Individual CSV files cached in `downloads/naaccr_csv_lookups/`.
Parsed values cached as `downloads/naaccr_csv_values.json`.

---

### 3. EOD (Extent of Disease) — `sources/eod.py`

**Source:** `https://github.com/imsweb/staging-client-java/releases` — `eod_public-{version}.zip`  
**v26 coverage:** 141 schemas, ~66,000 schema-specific value rows

The EOD ZIP contains one JSON file per staging schema.  Each schema lists its
input items (`inputs[]`) and references shared lookup tables for each input's code
values.  The pipeline extracts schemas, their item memberships, and all code-value
pairs.

**Versioned schemas** — see the Version notes section below.

**Caching:** ZIP cached as `downloads/eod_public-{version}.zip`.

---

### 4. TNM — `sources/tnm.py`

**Source:** `https://github.com/imsweb/staging-client-java/releases` — `tnm-{version}.zip`  
**v26 coverage:** 153 schemas, ~71,000 schema-specific value rows

Same structure as EOD.  No versioned schemas in TNM 2.1 — each anatomic site has
a single schema.

**Caching:** ZIP cached as `downloads/tnm-{version}.zip`.

---

### 5. Surgery codes — `sources/surgery.py`

**Source:** `https://github.com/imsweb/algorithms` — surgery XML files  
**Coverage:** 30 anatomic schemas, items 1290 and 1291

Surgery procedure codes for the two surgical-procedure items:

| Item | Code range | Diagnosis years | Notes |
|------|-----------|-----------------|-------|
| 1290 | `00`–`99` | 2003–2022 | Numeric format |
| 1291 | `A000`–`A999` | 2023 | Format change only |
| 1291 | `B000`–`B999` | 2024+ | 5 schemas clinically redesigned |

The five schemas redesigned for 2024 (Breast, Colon, Lung, Pancreas, Thyroid Gland)
have B-codes that replace their A-codes.  The remaining 25 schemas use identical
A- and B-code tables; only A-codes are emitted for them.

**Replacement relationships:** Built by description matching — if a procedure
description is identical across generations, `Concept replaced by` / `Concept replaces`
are emitted.  Codes without a match in the successor generation remain active.

**No chaining:** Every deprecated code points directly to the definitive current code
in a single hop.  For the 5 redesigned schemas, numeric 1290 codes point to the
B-code directly, bypassing the A-code.

**Schema name mapping:** Four XML table titles do not match the DB Proc Schema
`concept_code`.  A hard-coded lookup (`TITLE_TO_SCHEMA` in `surgery.py`) corrects
these.  Verify on each release:

| XML title | DB concept_code |
|-----------|----------------|
| Bones, Joints, And Articular Cartilage | Bones, Joints, and Soft Tissue |
| Brain [and other parts of central nervous system] | Brain |
| Hematopoietic/Reticuloendothelial/… Disease | Hematopoietic |
| Unknown and Ill-Defined Primary Sites | Unknown And Ill-Defined Primary Sites |

---

## Source fetch tables

The Python fetch scripts populate eleven tables in the `sources` schema
(overridable via `DB_SOURCES_SCHEMA`).  These are truncated and reloaded on
every pipeline run by `fetch.py`.  The `load_stage.sql` script reads from them
to build `concept_stage` and `concept_relationship_stage`.

| Table | Source | Contents |
|-------|--------|----------|
| `naaccr_items` | SEER API | One row per NAACCR data item: item number, name, section, XML field ID |
| `naaccr_api_values` | SEER API | Permissible codes (`allowed_codes`) for each item |
| `naaccr_csv_values` | imsweb/layout CSVs | Permissible codes from CSV lookup files |
| `naaccr_eod_schemas` | EOD ZIP | One row per EOD staging schema |
| `naaccr_eod_schema_inputs` | EOD ZIP | Schema–item pairs: which items belong to which EOD schema |
| `naaccr_eod_values` | EOD ZIP | Schema-specific codes for each schema–item pair |
| `naaccr_tnm_schemas` | TNM ZIP | One row per TNM staging schema |
| `naaccr_tnm_schema_inputs` | TNM ZIP | Schema–item pairs for TNM |
| `naaccr_tnm_values` | TNM ZIP | Schema-specific codes for each TNM schema–item pair |
| `naaccr_surgery_concepts` | Surgery XML | One row per surgery procedure code (items 1290/1291) |
| `naaccr_surgery_replacements` | Surgery XML | Old→new code pairs where a procedure was superseded |

**`naaccr_api_values` vs `naaccr_csv_values`:** Both tables have the same
structure (item_number, code, description) and cover the same concept — generic
permissible values for NAACCR items.  They are kept separate to preserve
provenance.  When building concepts, the two are merged with CSV taking
precedence over API where both provide values for the same item@code.  Items
covered by neither source produce no Values.

**`naaccr_eod_schema_inputs` (and `naaccr_tnm_schema_inputs`):** Each row is a
schema–item pair, e.g. `breast` + `3861`.  This drives compound Variable
creation: every row produces a `breast@3861` compound Variable concept.  The
`input_name` column holds the schema-specific display name for that item within
that schema, which may differ from the generic item name in `naaccr_items`.

**`naaccr_surgery_replacements`:** One row per superseded surgery procedure code,
storing the old→new pair (old proc_schema / item / code → new proc_schema / item
/ code).  Only the forward direction ("Concept replaced by") is stored; the
reverse ("Concept replaces") is added automatically by the OHDSI vocabulary
loader.  Two rules govern which rows appear here: (1) description matching —
only codes whose description appears identically in the successor generation
receive a replacement row; codes with no match remain active without a
replacement; (2) no chaining — for the 5 redesigned schemas, a 1290 code
superseded via an intermediate A-code points directly to the definitive B-code
in a single hop.  Every deprecated concept in `naaccr_surgery_concepts`
(`invalid_reason = 'U'`) has exactly one corresponding row here.

---

## Exclusion rules

### E1 — Template placeholders in EOD/TNM code tables

EOD/TNM staging tables contain year-range discriminator rows using Java template
syntax (e.g. `2018-{{ctx_year_current}},9999`).  These are algorithm control rows,
not registry codes.

**Filter:** any value row whose code contains `{{` is skipped.

### E2 — Range-notation codes

EOD/TNM code tables document continuous measurement fields with range-notation rows
(e.g. `002-988`, `0.1-99.9`), meaning "any value in this range is valid."
These are abstraction instructions, not discrete coded values.

**Filter:** any value row whose code matches `^\d+\.?\d*-\d+\.?\d*$` is skipped.
(~1,185 rows in v26.)

### E3 — Concept codes over 50 characters

The OMOP `concept_code` column is `varchar(50)`.  Rules E1 and E2 together eliminate
all known overlong codes in v26; a safety-net truncation drops any code still
exceeding 50 characters.

### E4 — CS (Collaborative Staging) items

NAACCR items 2800–2860 are CS fields used prior to EOD/TNM.  The SEER API includes
them with an `xml_naaccr_id` that implies schema-specific lookup tables exist, but
no CSV or EOD/TNM ZIP covers them — they are absent from all current sources.
They do not receive compound Variables or schema-specific Values in the new build.
The ~1,071 compound Variable concepts present in builds prior to v26 were generated
by the old HTML scraper from stale HTML pages and should not be reproduced.

Action item: flag to NAACCR team that the API's `xml_naaccr_id` values for items
2800–2860 point to non-existent lookup files.

---

## Retirement rules

OMOP never deletes concepts — historical data may reference any code.

| Class | Rule |
|-------|------|
| NAACCR Variable | Retire if name starts with "Reserved" (~17 placeholder items in v26) |
| NAACCR Value | Retire range-notation 2-part codes (see R1) |
| Permissible Range | Retire all (see R2) |
| NAACCR Schema / Proc Schema | Never retire |
| NAACCR Procedure | Use `invalid_reason = 'U'` for superseded codes — never 'D' |

### R1 — Range-notation 2-part Values

Any `NAACCR Value` whose concept_code matches `^[^@]+@\d+\.?\d*-\d+\.?\d*$` is
retired.  These are abstraction instructions stored as Values in the pre-v26 DB.

### R2 — Permissible Range concepts

All `Permissible Range` concepts are retired.  They document the same numeric ranges
as E2 and R1 but were assigned their own class in the v18 build (481 concepts in v26 DB).

### R3 — "Reserved" Variables

NAACCR reserves item numbers under names like "Reserved 05".  Retire when found in DB.

---

## Schema naming convention

- **Existing schemas:** preserve the original DB name.  If the EOD title now carries
  an edition/year-range suffix, append it to make the edition visible.
- **New schemas (versioned or not):** use the EOD title directly.

The `concept_code` (schema ID, e.g. `anus_v9_2023`) is permanent.  Only the
human-readable `concept_name` can change.

---

## Version notes

### Versioned EOD schemas (introduced ~EOD V9, diagnosis year 2023+)

Before EOD V9, each anatomic site had a single schema and code revisions overwrote
previous values.  Starting with diagnosis year 2023, sites where the SSDI code
tables changed between editions are published as separate schemas rather than
replacing the existing one.

Example: `anus` (8th edition, 2018–2022) and `anus_v9_2023` (V9, 2023+) coexist.
The same code number can carry different clinical meanings in each edition; separate
schemas prevent concept_code collisions with conflicting semantics.

As of EOD 3.3 there are 21 versioned V9 schemas.  This number will grow with each
release cycle as more sites are revised.  The build logic handles this generically —
no code changes are needed unless EOD changes its naming pattern or introduces a
V10.

### TNM versioning

TNM 2.1 does not use versioned schemas.  All anatomic sites have a single schema.
If future TNM releases adopt the same versioning approach as EOD, the same pattern
would apply.

### NAACCR version transitions

When upgrading from one NAACCR version to another:

1. Update `NAACCR_VERSION`, `EOD_VERSION`, `TNM_VERSION` in `.env`.
2. Delete the relevant cache files in `downloads/` to force a fresh fetch.
3. Run `python run.py --dry-run` and inspect the retiring/new counts.
4. Check the SSDI item count: if it drops, a new SSDI may have been missed.
5. Verify the surgery `TITLE_TO_SCHEMA` mapping against the new XML files.
6. Verify that the range-notation filter still covers all range-code formats in the new ZIPs.

---

## Known limitations

- **Non-Demographic items without API or CSV coverage** (Radiation/Treatment fields)
  currently produce no Values.  If imsweb adds CSV lookup files for them, the
  pipeline will pick them up automatically.

- **Surgery Schema to Value / Has Answer relationships** are not yet generated by
  the Python pipeline — NAACCR Proc Schemas and their NAACCR Procedure Values exist
  as concepts but are not linked.  This is planned for the SQL relationship-assembly
  layer (`load_stage.sql`).

- **SSDI filter relies on EOD/TNM coverage.**  If a future release introduces an
  SSDI item not yet in any EOD/TNM schema, the API may produce spurious 2-part
  generic Values for it.  Check the SSDI item count after each update.

- **"Reserved" variable detection** matches on the name prefix "Reserved".  Update
  the filter if NAACCR changes this naming convention.
