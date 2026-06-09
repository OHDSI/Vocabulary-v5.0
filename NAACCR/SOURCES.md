# NAACCR Vocabulary — ETL Sources and Rules

This document describes the ETL process for building and maintaining the NAACCR
vocabulary in OMOP CDM: what data sources are used, how concepts are assembled,
and what rules govern inclusion, exclusion, naming, and retirement.

**Current vocabulary version: NAACCR v26** (EOD Public 3.3, TNM 2.1).

The rules documented here reflect decisions made for v26.  NAACCR, EOD, and TNM
evolve with each release cycle — code tables change, schemas are added or versioned,
items are retired.  Any heuristic in this document may need revisiting when the
vocabulary is updated.  Where a rule is fragile or version-sensitive, this is noted.

---

## Background

The NAACCR vocabulary encodes the data items collected by cancer registries
(Variables), their permissible coded values (Values), and the staging schemas
(EOD, TNM) used to classify tumour extent.  It also encodes surgery procedure
codes used in treatment-summary reporting.

### Concept classes

| Class | Description | `standard_concept` |
|-------|-------------|-------------------|
| NAACCR Variable | A NAACCR data item, identified by item number | NULL |
| NAACCR Value | A permissible code for a Variable | NULL |
| NAACCR Schema | An EOD or TNM staging schema (e.g. `breast`, `anus_v9_2023`) | NULL |
| NAACCR Proc Schema | A surgery procedure schema grouping (e.g. `Breast`) | NULL |
| NAACCR Procedure | A surgery procedure code (item 1290 or 1291) | S |
| Permissible Range | Numeric range constraints *(retired — see below)* | NULL |

NAACCR Procedures are Standard because there is no adequate external procedure
terminology to map to; they function as their own standard.

### Concept code formats

| Format | Example | Class |
|--------|---------|-------|
| `{item_number}` | `400` | NAACCR Variable |
| `{item_number}@{code}` | `400@C500` | NAACCR Value (generic) |
| `{schema_id}` | `breast` | NAACCR Schema |
| `{schema_id}@{item_number}` | `breast@3861` | NAACCR Variable (SSDI) |
| `{schema_id}@{item_number}@{code}` | `breast@3861@010` | NAACCR Value (schema-specific) |
| `{proc_schema}` | `Breast` | NAACCR Proc Schema |
| `{proc_schema}@{item}@{code}` | `Breast@1291@B200` | NAACCR Procedure |

**Concept codes are immutable.**  Changing a `concept_code` invalidates any
existing data mapped to it and breaks the `concept_manual` lookup (matched on
`concept_code + vocabulary_id`).  Name changes are made through `concept_manual`;
code changes require retiring the old concept and creating a new one with a
`Concept replaced by` relationship.

---

## Data Sources

Three upstream providers supply all source data:

| # | Provider | What we take |
|---|----------|-------------|
| 1 | `api.seer.cancer.gov` | NAACCR item list and generic permissible values |
| 2 | `github.com/imsweb/layout` | HTML documentation files — supplementary generic values |
| 3 | `github.com/imsweb/algorithms` | EOD and TNM staging ZIPs + surgery XML files |

---

### 1. NAACCR API — `sources/naaccr_api.py`

**URL:** `https://api.seer.cancer.gov/rest/naaccr/{version}`  
**Auth:** SEER API key (stored in `.env`)  
**v26 coverage:** 954 Variables, ~3,890 generic Values

Provides the canonical item list (item number, name, section) and each item's
`allowed_codes` array of generic permissible values.

**Key limitation:** The API omits codes for SSDI (Site-Specific Data Item) fields.
SSDIs have schema-specific code tables that vary by cancer site; the API correctly
returns no values for them.  They are covered by EOD/TNM instead.

**Caching:** Item JSON files cached as `downloads/naaccr_v{version}_item_*.json`.

---

### 2. imsweb/layout CSV lookup tables — `sources/naaccr_html.py`

**URL:** `https://github.com/imsweb/layout/tree/master/docs/naaccr-lookups/lookups`  
**v26 coverage:** 280 CSV files, format: `Code, Description`

One CSV file per NAACCR item that has a discrete code table.  Files are named
by the NAACCR XML field ID (camelCase, e.g. `grade.csv`), which matches the
`xml_naaccr_id` field returned by the SEER API.  That field provides the
mapping from CSV filename to item number.

**Use:** Supplements the API.  Adds values not returned by the API.

**SSDI handling:** The CSV files naturally omit true SSDI items (those whose
code tables vary by cancer site).  Of the 174 SSDI item numbers identified in
EOD/TNM, only 15 have a CSV — and those 15 are universal staging items
(e.g. `primarySite`, `behaviorCodeIcdO3`, `regionalNodesPositive`) that appear
in every schema and are already excluded from schema-specific concept generation
by `_GENERIC_ITEMS` / `_ALL_SCHEMA_ITEMS`.  The SSDI suppression filter in
`build_concepts.py` remains as a safety net but is no longer the primary
defence.

**History:** Before v26, this module scraped 954 HTML documentation files from
the same repository.  The HTML files include SSDI items without distinguishing
them from generic items, requiring a post-hoc suppression filter.  The CSV
source is the authoritative machine-readable form of the same data and is
strictly better.

---

### 3. EOD (Extent of Disease) — `sources/eod.py`

**Source:** `https://github.com/imsweb/algorithms` — `eod_public-{version}.zip`  
**v26 coverage:** 141 schemas, ~66,000 schema-specific value rows

Provides EOD staging schemas with their SSDI code tables.  Primary source for
3-part schema-specific Values and compound SSDI Variables.

**Versioned schemas:** From EOD V9 onward, anatomic sites where the SSDI code
tables changed between editions are represented as separate schemas rather than
overwriting the existing one.  For example, `anus` (8th edition, 2018–2022) and
`anus_v9_2023` (V9, 2023+) coexist as distinct schemas.  This is necessary because
the same code number can mean different things across editions — merging them would
create concept_code collisions with conflicting clinical meanings.  As of EOD 3.3
there are 21 versioned schemas, all V9.

---

### 4. TNM — `sources/tnm.py`

**Source:** `https://github.com/imsweb/algorithms` — `tnm-{version}.zip`  
**v26 coverage:** 153 schemas, ~71,000 schema-specific value rows

Same structure as EOD.  No versioned schemas in TNM 2.1.

---

### 5. Surgery codes — `sources/surgery.py`

**Source:** `https://github.com/imsweb/algorithms` — surgery XML files (one per
diagnosis year)

Surgery procedure codes for NAACCR items 1290 (pre-2023, numeric) and 1291
(2023+, alphanumeric).  30 anatomic schemas.

**Three code generations (as of v26):**

| Generation | Item | Code range | Diagnosis years | Notes |
|------------|------|-----------|-----------------|-------|
| Numeric | 1290 | `00`–`99` | 2003–2022 | Classic format |
| A-codes | 1291 | `A000`–`A999` | 2023 | Format change only; same procedures |
| B-codes | 1291 | `B000`–`B999` | 2024+ | 5 schemas clinically redesigned |

The 5 schemas with B-code redesigns: Breast, Colon, Lung, Pancreas, Thyroid Gland.
Detection: a schema is considered changed when the set of code values in the 2024
XML differs from the 2023 XML.  For the remaining 25 schemas the two files are
identical.

**Schema name mapping:** Four XML table titles do not exactly match the DB Proc
Schema `concept_code`.  A hard-coded lookup (`TITLE_TO_SCHEMA` in `surgery.py`)
corrects these:

| XML title | DB `concept_code` |
|-----------|------------------|
| Bones, Joints, And Articular Cartilage | Bones, Joints, and Soft Tissue |
| Brain [and other parts of central nervous system] | Brain |
| Hematopoietic/Reticuloendothelial/… Disease | Hematopoietic |
| Unknown and Ill-Defined Primary Sites | Unknown And Ill-Defined Primary Sites |

This mapping is version-sensitive and should be verified on each update.

**Replacement relationships:** Built by description matching — if a procedure
description is identical across generations, the codes represent the same clinical
procedure and a `Concept replaced by` / `Replaces` pair is emitted.  Codes with
no matching description in the successor generation receive no replacement.

**No chaining:** Every deprecated code points directly to the definitive current
code in a single hop.  For the 5 changed schemas, 1290 codes point to the B-code
directly, skipping the A-code.

**Date conventions:**

| Generation | `valid_start_date` | `valid_end_date` | `standard_concept` | `invalid_reason` |
|------------|-------------------|-----------------|-------------------|-----------------|
| 1290 — replaced | preserved from DB | 2022-12-31 | NULL | U |
| 1290 — no match | preserved from DB | 2099-12-31 | S | — |
| A-code — replaced by B | 2023-01-01 | 2023-12-31 | NULL | U |
| A-code — kept | 2023-01-01 | 2099-12-31 | S | — |
| B-code | 2024-01-01 | 2099-12-31 | S | — |

Effective dates follow NAACCR diagnosis-year conventions (January 1 of the
applicable year).  The 1290 `valid_start_date` is preserved from the existing DB
row so that `ProcessManualConcepts` NULL-coalesce logic retains any more precise
value already stored.

**Unmatched 1290 codes (24 in v26):** Combination codes dropped by NAACCR in 2023
with no direct successor (procedures that were split or eliminated).  They remain
active Standard concepts; historical data may reference them.

---

## Build Pipeline

```
sources/naaccr_api.py   → Variables + generic Values (2-part)
sources/naaccr_html.py  → Additional generic Values (2-part, SSDI-filtered)
sources/eod.py          → EOD Schemas + schema-specific Values (3-part)
sources/tnm.py          → TNM Schemas + schema-specific Values (3-part)
sources/surgery.py      → Procedure concepts + replacement relationships
        ↓
build_concepts.py       → Assembles all concepts, applies domain rules,
                          builds SSDI compound Variables, deduplicates,
                          applies all exclusion filters
        ↓
compare.py              → Diffs against prodv5.concept, classifies as
                          new / updated / same / retiring
        ↓
output.py               → Truncates and reloads the work schema tables:
                          concept_manual and concept_relationship_stage_manual
```

---

## Domain Assignment Rules

Domain is assigned to Variables by section and name; Values inherit from their
parent Variable.

| Condition | Domain |
|-----------|--------|
| Section = "Stage/Prognostic Factors" | Measurement |
| Section = "Treatment-1st Course", name is a date (no "flag") | Metadata |
| Section = "Treatment-1st Course", name matches RX Summ or radiation modality | Episode |
| Section = "Treatment-1st Course", name matches dose/fraction/volume/margin/nodes | Measurement |
| Section = "Cancer Identification", name is a date (no "flag") | Metadata |
| Section = "Cancer Identification", name matches grade/laterality/multiplicity | Measurement |
| All other sections and new items without a section | Observation |

Values take `Meas Value` when their parent Variable is Measurement; otherwise
`Observation`.  Procedures take `Procedure`.

---

## Exclusion Rules (concepts not generated)

The following categories are filtered out during build and never written to the
vocabulary.  Each represents abstraction instructions or internal machinery, not
coded facts.

### E1 — Template placeholders in EOD/TNM code tables

EOD and TNM staging tables contain year-range discriminator rows used by the Java
staging algorithm to select the correct schema version for a case.  Example code:
`2018-{{ctx_year_current}},9999` for item 390 (Year of Diagnosis).  These contain
Java template syntax (`{{...}}`), not valid registry codes.

**Filter:** any EOD/TNM value row whose code contains `{{` is skipped.

### E2 — Range-notation codes in EOD/TNM code tables

EOD and TNM code tables include rows where the code is written as a numeric range
(e.g. `002-988`, `0.1-99.9`) to document that any value within the range is valid
for a continuous measurement field.  These are abstraction instructions, not
discrete codes.  Individual integer or decimal values within the range appear as
their own rows and are included normally.

**Filter:** any EOD/TNM value row whose code matches `^\d+\.?\d*-\d+\.?\d*$` is
skipped.  (~1,185 rows across EOD + TNM in v26.)

### E3 — Concept codes exceeding 50 characters

The OMOP `concept_code` column is `varchar(50)`.  For schemas with long
`schema_id` values (e.g. `esophagus_including_ge_junction_squamous`, 40 chars),
the 3-part value code can exceed the limit.  Rules E1 and E2 together eliminate
all known overlong codes in v26; a safety-net drop of any code still exceeding 50
characters is applied as a backstop.

---

## Retirement Rules

OMOP never deletes concepts — historical data may reference any code.  Retired
concepts receive `valid_end_date = today`, `invalid_reason = 'D'`,
`standard_concept = NULL`.

| Class | Rule |
|-------|------|
| NAACCR Variable | Retire if `concept_name` starts with "Reserved" (~17 placeholder items in v26) |
| NAACCR Value | Retire range-notation codes (R1 below); keep all others |
| NAACCR Schema | Never retire |
| NAACCR Proc Schema | Never retire |
| NAACCR Procedure | Use `valid_end_date` / `invalid_reason = U` for superseded codes; never `D` |
| Permissible Range | Retire all |

### R1 — Range-notation NAACCR Values

Any `NAACCR Value` whose `concept_code` matches `^[^@]+@\d+\.?\d*-\d+\.?\d*$`
(a 2-part code where the value portion is two numbers joined by a hyphen) is
retired.  These are the same abstraction instructions as E2, but stored in the DB
under `NAACCR Value` class rather than `Permissible Range`.  (9 such concepts in
the v26 DB.)

### R2 — All Permissible Range concepts

All concepts with `concept_class_id = 'Permissible Range'` are retired.  These
document the same numeric ranges as E2 and R1, but were assigned their own class
in the v18 build.  (481 concepts in the v26 DB.)

Both R1 and R2 reflect the same principle: NAACCR uses range notation as an
abstraction instruction ("enter any value in this range"), not as a coded fact.
No patient record stores a literal range as a coded value.

### R3 — "Reserved" Variables

NAACCR reserves item numbers for future use under placeholder names like
"Reserved 05".  These are not real data items and are retired when found in the DB.

---

## Schema Naming Convention

- **Existing schemas** (concept_code already in DB): preserve the original
  descriptive name.  If the EOD title now carries an edition/year-range suffix
  (e.g. `[8th: 2018-2022]`), append it so the edition is visible in the name.
- **New versioned schemas**: use the EOD title directly (e.g. *"Anus [V9: 2023+]"*).
- **New non-versioned schemas**: use the EOD title directly.

The DB names tend to be more descriptive than the short EOD schema IDs.  The
`concept_code` (the schema ID) never changes; only the human-readable name can
be updated.

---

## Known Limitations and Version-Sensitive Heuristics

- **SSDI filter relies on EOD/TNM coverage.** If a future NAACCR version introduces
  a new SSDI item that is not yet in the EOD/TNM ZIP, the HTML scraper may produce
  spurious 2-part generic values for it.  Check the SSDI item count after each update.

- **Surgery `TITLE_TO_SCHEMA` mapping** is hard-coded for 4 known mismatches in v26.
  Verify this mapping when new surgery XML files are released.

- **"Reserved" variable detection** matches on the name prefix "Reserved".  If NAACCR
  changes this naming convention, the filter needs updating.

- **Range-notation pattern** `\d+\.?\d*-\d+\.?\d*` covers all known cases in v26.
  A future release could introduce a different notation (e.g. comma-separated ranges
  or open-ended bounds) that would need a new rule.

- **Versioned schema count** will grow as EOD V9 replaces V8 schemas over successive
  release cycles.  The versioning logic in `build_concepts.py` is generic; no changes
  needed unless EOD introduces a V10 or changes the naming pattern.
