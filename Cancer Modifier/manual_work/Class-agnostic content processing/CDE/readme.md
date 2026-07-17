### Reasoning behind the cancer_modifier_cde

The CDE script converts curated mining-review decisions into Cancer Modifier manual content. It is the handoff point between the working group review tables and the standard OHDSI manual tables used by `load_stage.sql`.

#### Prerequisites for developer
- Output from [`../6 - curation output metadata backlog.sql`](../Mining%20concepts%20for%20Mapping/6%20-%20curation%20output%20metadata%20backlog.sql). (or other heuristic) used for curator review
- A populated `dev_cancer_modifier.cancer_modifier_cde` table with curator decisions.
- The `concept_manual` and `concept_relationship_manual` tables in `dev_cancer_modifier`.
- Replace the parameter `:your_vocabs` with the source vocabularies included in the current review, for example `'SNOMED','NAACCR'`.

#### Table purpose

`dev_cancer_modifier.cancer_modifier_cde` stores one row per reviewed mapping, relationship, destandardization, or new-target decision. 'source_concept_id` considerations: the same source concept may appear in multiple CDE rows when it has multiple proposed mapping targets, so combinations of source_concept_id,relationship_id,target_concept_id should be treated as unique identifiers. This preserves 1-to-many mappings because the curator flags are reviewed per target row, not once per source concept (excetp 'to_destandardize' flag)

Important decision fields:
- `decision`: curator-approved row.
- `to_destandardize`: approved source concept should be inserted or updated in `concept_manual` with `standard_concept = NULL`.
- `create_standard`: approved row requires a new Cancer Modifier target concept. If `target_concept_id` is empty in the reviewed CDE file, resolve the target after the new Cancer Modifier concept is loaded into `concept_manual`.

#### Sequence of actions

1. Create or refresh `dev_cancer_modifier.cancer_modifier_cde` using the final CDE DDL.
2. Load the curator-approved spreadsheet rows into `dev_cancer_modifier.cancer_modifier_cde`. (loated at )
3. Insert approved new Cancer Modifier concepts, their synonyms and relationships into `concept_manual`, `concept_synonym_manual` and  `concept_relationship_manual` first via corresponding `_manual_refresh` tables.
4. Insert approved mappings into `concept_relationship_manual` after the target concepts are present or resolvable.
5. Run `populate_manual_tables_with_CDE_content.sql`.
6. Review the affected `concept_manual` and `concept_relationship_manual` rows before running `Cancer Modifier/load_stage.sql`.

Rows approved for destandardization are inserted into `concept_manual`. Rows approved for mapping are inserted into `concept_relationship_manual` when the source and target concepts can be resolved and the relationship is not already present. This order matches `load_stage.sql`, where manual concepts are processed before manual relationships.
