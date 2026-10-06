# README for maps_for_load_stage.sql

## Purpose

`maps_for_load_stage.sql` builds the canonical CIEL to OMOP Standard mapping set used to populate `concept_relationship_stage` for the CIEL vocabulary.

The script:

- Takes all raw CIEL mapping candidates from `ciel_mapping_lookup`.
- Applies a series of prioritization and QA rules.
- Assigns each mapping to a **ranked bucket** with an explicit `rule_applied`.
- Produces a single, consolidated interim staging table: `maps_for_load_stage`.

This staging table is the **only source of automated CIEL “Maps to” / “Maps to value” relationships** used later in the CIEL load pipeline.

---

## Inputs and Dependencies

The script assumes the following objects exist and are populated:

- `ciel_mapping_lookup` – denormalized mapping lookup table containing:
  - `source_code`, `source_name`, `source_class`
  - `map_type` (`SAME-AS`, `NARROWER-THAN`, `BROADER-THAN`)
  - `target_concept_id`, `target_concept_code`, `target_concept_name`
  - `target_vocabulary_id`, `target_domain_id`
  - `target_standard_concept` (`S` or `NULL`)
- OMOP core tables:
  - `concept`
  - `concept_relationship`
  - `concept_ancestor`
- Intermediate rank tables (created/overwritten by this script):
  - `ciel_rank_1_same_as`
  - `ciel_rank_1_narrower_than`
  - `ciel_rank_1_broader_than`
  - `missing_drugs_rank_1`
  - `ciel_rank_2_same_as`
  - `ciel_rank_2_narrower_than`
  - `ciel_rank_2_broader_than`
  - `ciel_unmapped`

The script is **idempotent** in the sense that it starts by dropping/re-creating these rank tables and `maps_for_load_stage`.

---

## Output: `maps_for_load_stage`

The final table has one row per selected mapping from CIEL to an OMOP concept and includes at least: 

- `source_code`  
- `source_name`  
- `source_class`  
- `map_type` – original CIEL map type (`SAME-AS` / `NARROWER-THAN` / `BROADER-THAN`)  
- `target_concept_id`  
- `target_concept_code`  
- `target_concept_name`  
- `target_vocabulary_id`  
- `target_domain_id`  
- `target_concept_class_id`  
- `target_standard_concept`  
- `target_invalid_reason`  
- `relationship_id` – resulting OMOP relationship (`Maps to`, `Maps to value`, etc.)  
- `rank_num` – mapping rank (1 = primary, 2 = crosswalk-based; 8–9 for problematic/unmapped buckets)  
- `rule_applied` – textual label describing which rule selected this mapping (e.g., `1.01: ...`, `2.09: ...`, etc.)

Note: A single source_code may appear in multiple rows whenever it is mapped to more than one Standard Concept (for example, 1-to-many mappings, composite diagnoses, drug regimens, or Maps to + Maps to value pairs).

Downstream, `maps_for_load_stage` is used to populate `concept_relationship_stage` (filtered e.g. by `rank_num IN (1,2)`), after which manual overrides and vocabulary-pack QA procedures are applied.

---

## Ranking Strategy Overview

The script builds `maps_for_load_stage` in several stages:

1. **Rank 1: Direct CIEL to Standard mappings**
   - `ciel_rank_1_same_as`
   - `ciel_rank_1_narrower_than`
   - `ciel_rank_1_broader_than`
   - `missing_drugs_rank_1` (additional ingredient mappings for combination drugs)
2. **Rank 2: Crosswalk-based mappings from non-standard targets**
   - `ciel_rank_2_same_as`
   - `ciel_rank_2_narrower_than`
   - `ciel_rank_2_broader_than`
3. **Residual and problematic**
   - `ciel_unmapped` – CIEL codes that either lack any Standard target or require manual review.

Each ranking table encodes detailed sub-rules in `rule_applied` (for example, `2.05: 1 NARROWER-THAN LOINC alone`), which describes why a particular mapping was chosen.

The union of all these tables becomes `maps_for_load_stage`.

---

## Rank 1: SAME-AS Mappings (`ciel_rank_1_same_as`)

**Goal:** Prefer the most semantically faithful and structurally “clean” SAME-AS mappings where CIEL and the OMOP target represent essentially the same concept.

Key ideas (summary; exact rules are encoded in the SQL):

- Prioritize **direct CIEL to Standard SAME-AS** mappings where the target is already a Standard concept (`target_standard_concept = 'S'`).
- Use **source_class** and **target_vocabulary_id** to distinguish:
  - Condition / diagnosis / finding terms.
  - CVX vaccine codes.
  - Drug ingredients and combo drugs.
  - Questions, tests, and other non-condition content.
- Ensure that for each `source_code`, **only one consistent SAME-AS “family”** is selected:
  - Uses `NOT EXISTS` filters to prevent the same source from appearing in multiple rule buckets.
- For combo drugs and regimens, SAME-AS mappings are used only when they point to appropriate Standard concepts (e.g., regimen concepts or specific preparations), not to generic or unrelated components.

These mappings are considered **highest priority** and are always included with `rank_num = 1`.

---

## Rank 1: NARROWER-THAN Mappings (`ciel_rank_1_narrower_than`)

**Goal:** Use CIEL NARROWER-THAN mappings to standard vocabularies in a controlled and interpretable way.

The script:

- Builds a base set `nt_base` of `NARROWER-THAN` mappings to Standard concepts (`target_standard_concept = 'S'`) that are not already used in `ciel_rank_1_same_as`.
- Splits them into:
  - `nt_single` – `source_code` with exactly one NARROWER-THAN mapping.
  - `nt_multi` – `source_code` with multiple NARROWER-THAN mappings.

Then it derives thematic buckets, each with `rank_num = 1`, such as:

- **Single NARROWER-THAN SNOMED vs ICD10 companion**  
  (`one_narrower_1` – e.g., one SNOMED mapping when ICD10 mappings also exist).
- **Single NARROWER-THAN SNOMED alone** (`one_narrower_2`).
- **Single NARROWER-THAN CVX** (`one_narrower_cvx`).
- **Single NARROWER-THAN RxNorm/RxNorm Extension** (`one_narrower_rxnorm`).
- **Single NARROWER-THAN LOINC** (`one_narrower_loinc`, excluding radiology tests).
- **Multi NARROWER-THAN SNOMED composite** (`many_narrower_composite`) with explicit blacklists for known bad composite mappings.
- Specialised multi-mapping buckets:
  - Anatomy (`many_narrower_anatomy`, `Spec Anatomic Site`).
  - Procedures & imaging (`many_narrower_procedure`).
  - Lab tests / questions (`many_narrower_lab_test_quest`).
  - Composite diagnoses/findings (`many_narrower_composite_diagn_find`).
  - Vaccines (`many_narrower_cvx`).
  - Drugs & drug regimens in RxNorm/RxE (`many_narrower_drugs_and_regimens_rx`).
  - SNOMED therapeutic regimens (`many_narrower_regimens_sn`, restricted to descendants of `4045950 – Therapeutic regimen`).

Each bucket uses **NOT EXISTS** filters to ensure that a given `source_code` only appears in **one** NARROWER-THAN rule, in a controlled priority order.

---

## Rank 1: BROADER-THAN Mappings (`ciel_rank_1_broader_than`)

**Goal:** Use BROADER-THAN mappings where they are the best available approximation.

Steps:

- Build `bt_base` as all `BROADER-THAN` mappings from CIEL to Standard concepts not already covered by rank-1 SAME-AS or NARROWER-THAN.
- Split:
  - `bt_single` – exactly one BROADER-THAN per `source_code`.
  - `bt_multi` – multiple BROADER-THAN per `source_code`.
- Derive buckets:
  - `one_broader`: single SNOMED BROADER-THAN (`3.01: 1 BROADER-THAN SNOMED only`).
  - `many_broader_radiology`: multiple SNOMED BROADER-THAN for radiology/imaging procedures.
  - `many_broader_labs`: multiple LOINC BROADER-THAN for tests; with a small hard-coded exclusion for a redundant mapping.

All these are included with `rank_num = 1`.

---

## Rank 1: Missing Drug Ingredients (`missing_drugs_rank_1`)

**Goal:** Add missing Standard ingredients for combination drugs whose CIEL mappings partially cover ingredients.

Logic:

- Combine all rank-1 buckets into `mapped`.
- Identify `source_code` that:
  - Represent combination drugs/regimens (via `source_name` pattern like `/`, `and`, `with`, `single agent`).
  - Already have some mapping in `mapped`.
  - Have additional non-standard drug targets in OMOP that can be crosswalked via `concept_relationship ('Maps to')` to Standard ingredients.
- Generate additional mappings:
  - From CIEL source to Standard ingredients derived from OMOP crosswalks.
  - Only when those ingredients are not already included in rank-1.
- Assign `rank_num = 2` and rule `4.01: missing n-S combo Drug/Regimen Ingredient to standard (OMOP crosswalk)`.

These are **supplementary** to rank-1 mappings and are important for correct denominator of ingredients in combo-drug analyses.

---

## Rank 2: SAME-AS / NARROWER-THAN / BROADER-THAN via Crosswalks

When CIEL maps to **non-standard** targets (`target_standard_concept IS NULL`), the script uses OMOP relationships to find Standard concepts:

- `ciel_rank_2_same_as`
  - Handles non-Standard SAME-AS targets.
  - Uses `concept_relationship (Maps to / Maps to value)` to reach Standard concepts.
  - Separate rules for:
    - Single crosswalk (`5.01: 1 n-S SAME-AS to standard`).
    - Multi crosswalk:
      - Diagnoses/findings (`5.02`).
      - Vaccines (CVX; `5.03`).
      - Drugs (RxNorm/RxE; `5.04`).
      - Other classes (`5.05`).

- `ciel_rank_2_narrower_than`
  - Same idea for `NARROWER-THAN` (`map_type = 'NARROWER-THAN'`).
  - Rules differentiate diagnoses/findings, vaccines, drug/regimens, and “other” classes.

- `ciel_rank_2_broader_than`
  - Analogous for `BROADER-THAN`:
    - `7.01` – single n-S BROADER-THAN to standard.
    - `7.02` – multiple n-S BROADER-THAN to standard.

All rank-2 mappings have `rank_num = 2` and are **second-line** options compared to rank-1 mappings.

---

## Residual: Unmapped and Problematic (`ciel_unmapped`)

Any CIEL concept not covered by rank-1 or rank-2 tables is classified in `ciel_unmapped`:

- `8.01: Problematic standard one-to-many. Manual review is needed`  
  – cases where `target_standard_concept = 'S'` but mappings are structurally problematic (e.g., complex 1:n situations that do not pass rule filters).
- `8.02: Does not have Standard OMOP map`  
  – no Standard target reachable; CIEL concept remains unmapped.

These rows are **not** intended for automated load; they serve as a backlog for manual curation.

---

## Post-processing and QA on `maps_for_load_stage`

After all rank tables are unioned into `maps_for_load_stage`, additional QA logic is applied (in the same or subsequent scripts):

1. **Ingredient cleanup for combination drugs**
   - Detect combination drug names (via `/`, `and`, `with`, `single agent`) where the number of ingredients inferred from the name does not match the number of distinct ingredient targets.
   - Remove spurious ingredient targets that come from generic or incorrect non-S to S crosswalks.
   - Maintain explicit whitelists for specific `source_code` / `target_concept_id` pairs that must be preserved.

2. **Parent–child de-duplication**
   - For `source_code` with multiple targets, find cases where one target concept is an ancestor of another (via `concept_ancestor`).
   - Depending on the name pattern (e.g., whether the text indicates explicit conjunction vs regimen), drop either parent or child mappings so that the remaining set best reflects the intended clinical semantics.
   - Special case lists (whitelist/blacklist of `source_code`) are used to override default behaviour for specific CIEL concepts.

These cleanups ensure that `maps_for_load_stage` contains a **minimal, non-redundant, and clinically interpretable mapping set** before it is consumed by the main CIEL load step into `concept_relationship_stage`.

---

## How to Use `maps_for_load_stage`

Typical usage in the CIEL load pipeline:

1. Run `maps_for_load_stage.sql` to populate:
   - Rank tables (`ciel_rank_*`, `missing_drugs_rank_1`, `ciel_unmapped`).
   - The consolidated `maps_for_load_stage`.
2. Run load_stage.sql

## Notes and Maintenance

The rule_applied labels are intended to be stable and human-readable, so that QA reports and documentation can refer to them directly.

New patterns (e.g., additional regimen naming conventions, new source classes) can be integrated by:
- Adding new rule-specific Common Table Expressions (CTEs).
- Enforcing mutual exclusivity via NOT EXISTS filters.
- Assigning them appropriate rank_num and rule_applied values.

The script is written defensively:

- Uses NOT EXISTS instead of NOT IN to avoid NULL pitfalls.
- Uses explicit blacklists for known problematic CIEL codes and crosswalks.
- Separates direct mappings (rank 1) from crosswalk-based inferences (rank 2).

**This README should be kept in sync with any changes to maps_for_load_stage.sql, especially when new rule buckets or QA steps are added or renamed.**
