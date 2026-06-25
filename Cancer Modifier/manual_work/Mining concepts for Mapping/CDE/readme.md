### STEP 3 of the refresh: prepare CDE output for universal load stage

The CDE script converts curated mining-review decisions into Cancer Modifier manual content. It is the handoff point between the working group review tables and the standard OHDSI manual tables used by `load_stage.sql`.

#### Prerequisites
- Curated review output from [`../6 - curation output clean.sql`](../6%20-%20curation%20output%20clean.sql) or [`../6 - curation output metadata backlog.sql`](../6%20-%20curation%20output%20metadata%20backlog.sql).
- A populated `dev_cancer_modifier.cancer_modifier_cde` table with curator decisions.
- The `concept_manual` and `concept_relationship_manual` tables in `dev_cancer_modifier`.
- Replace the parameter `:your_vocabs` with the source vocabularies included in the current review, for example `'SNOMED','NAACCR'`.

#### Table purpose

`dev_cancer_modifier.cancer_modifier_cde` stores one row per reviewed mapping, relationship, destandardization, or new-target decision. Do not make `source_concept_id` unique: the same source concept may appear in multiple CDE rows when it has multiple proposed mapping targets. This preserves 1-to-many mappings because the curator flags are reviewed per target row, not once per source concept.

Important decision fields:
- `decision`: curator-approved row.
- `to_destandardize`: approved source concept should be inserted or updated in `concept_manual` with `standard_concept = NULL`.
- `create_standard`: approved row requires a new Cancer Modifier target concept. If `target_concept_id` is empty in the reviewed CDE file, resolve the target after the new Cancer Modifier concept is loaded into `concept_manual`.
- `relationship_id`, `target_concept_id`: approved manual relationship target.

#### Sequence of actions

1. Create or refresh `dev_cancer_modifier.cancer_modifier_cde` using the final CDE DDL.
2. Load the curator-approved spreadsheet rows into `dev_cancer_modifier.cancer_modifier_cde`.
3. Insert approved new Cancer Modifier concepts into `concept_manual` first.
4. Insert approved mappings into `concept_relationship_manual` after the target concepts are present or resolvable.
5. Run `1- prepare tables for Universal Load Stage.sql` after replacing `:your_vocabs`.
6. Review the affected `concept_manual` and `concept_relationship_manual` rows before running `Cancer Modifier/load_stage.sql`.

Rows approved for destandardization are inserted into `concept_manual`. Rows approved for mapping are inserted into `concept_relationship_manual` when the source and target concepts can be resolved and the relationship is not already present. This order matches `load_stage.sql`, where manual concepts are processed before manual relationships.
