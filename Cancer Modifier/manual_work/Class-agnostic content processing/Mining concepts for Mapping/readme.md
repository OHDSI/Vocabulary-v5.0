### Mining concepts for mapping

This folder contains an optional mining workflow used to find oncology-related concepts in SNOMED, LOINC and NAACCR and prepare them for Cancer Modifier mapping review. The workflow combines rule-based discovery, seed expansion and Hecate semantic search. It does not update the OMOP basic tables directly; curated results are later moved through the CDE script into manual tables.

#### Prerequisites
- Run from the `dev_cancer_modifier` development schema, or set `search_path` so unqualified working tables resolve there.
- SNOMED, LOINC, NAACCR and Cancer Modifier content must be available in the dev schema.
- Deploy [`working/packages/vocabulary_pack/SeedBasedHecateMine_multithread.sql`](../../../../working/packages/vocabulary_pack/SeedBasedHecateMine_multithread.sql) before running the Hecate mining step. Deployment notes are kept as comments in that script.
- The database server must have `plpython3u` and outbound HTTPS access to the Hecate API when semantic mining is used.

#### Sequence of actions

1. Run `1 - rule-based candidates selection.sql`.

Creates `oncology_concepts_mined_with_rules` from keyword matches, source-vocabulary membership, LOINC stage/grade anchors, SNOMED descendants and mapped concepts.

2. Run `2 - Root concept.sql`.

Creates `dev_cancer_modifier.onco_seed_roots`, the curated set of root oncology concepts that defines the initial seed scope.

3. Run `3 - build_initial_oncology_seed_scope.sql`.

Creates `dev_cancer_modifier.seeding_table` by expanding the root concepts through `concept_ancestor`, selected concept relationships, name matches and synonym matches.

4. Run `4 - SeedBasedHecateMine_multithread run.sql`.

Uses `vocabulary_pack.hecate_populate_similar_results_mt` to mine similar concepts for SNOMED, LOINC and NAACCR. Expected output tables are `hecate_mined_snomed`, `hecate_mined_LOINC` and `hecate_mined_NAACCR` in the working schema.

5. Run `5 - table assembling.sql`.

Creates `oncology_concept_mined_for_review` and `oncology_concept_mined_for_review_prioritized` by combining rule-based hits, Hecate hits, seed rows, full-name matches and synonym-name matches. The prioritized table groups candidates into review tiers.

6. Run `6 - curation output metadata backlog.sql`.

Creates CDE-ready curator-facing review tables such. This script combines current mined candidates with existing non-`exactMatch` Cancer Modifier mappings from `devv5.concept_relationship_metadata` for SNOMED, LOINC and NAACCR source concepts. It is useful for reviewing mined concepts together with the previous metadata backlog.

#### CDE handoff

After curator review, load the approved spreadsheet rows into `dev_cancer_modifier.cancer_modifier_cde` and run the script documented in main `readme.md` in manual_work folder
