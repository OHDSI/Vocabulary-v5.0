### STEP 2 of the refresh: mining concepts for mapping

This folder contains an optional mining workflow used to find oncology-related concepts in SNOMED, LOINC and NAACCR and prepare them for Cancer Modifier mapping review. The workflow combines rule-based discovery, seed expansion and Hecate semantic search. It does not update the OMOP basic tables directly; curated results are later moved through the CDE script into manual tables.

#### Prerequisites
- Run from the `dev_cancer_modifier` development schema, or set `search_path` so unqualified working tables resolve there.
- SNOMED, LOINC, NAACCR and Cancer Modifier content must be available in the dev schema.
- Deploy [`working/packages/vocabulary_pack/SeedBasedHecateMine_multithread.sql`](../../../working/packages/vocabulary_pack/SeedBasedHecateMine_multithread.sql) before running the Hecate mining step. Deployment notes are kept as comments in that script.
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

6. Run `6 - curation output clean.sql`.

Creates CDE-ready curator-facing review tables such as `oncology_concept_mined_for_review_cde_ready_snomed_t1` and `oncology_concept_mined_for_review_cde_ready_naaccr_t1`. These tables include one row per proposed mapping or review decision, not one row per `source_concept_id`. The same source concept may appear in multiple rows when it has multiple proposed targets, so `decision`, `to_destandardize`, `create_standard` and `comment` are reviewed per mapping row.

The older `6 - analysis and visualization.sql` script is kept for comparison, but the clean script is the preferred export for CDE review.

Optional: run `6 - curation output metadata backlog.sql` when the goal is to avoid dependencies on `dev_nemesis_release` and `splitting_snomed_conditions_oncology_wg`. This version combines current mined candidates with existing non-`exactMatch` Cancer Modifier mappings from `devv5.concept_relationship_metadata` for SNOMED, LOINC and NAACCR source concepts. It is useful for reviewing mined concepts together with the previous metadata backlog.

#### CDE handoff

After curator review, load the approved spreadsheet rows into `dev_cancer_modifier.cancer_modifier_cde` and run the script documented in [`CDE/readme.md`](CDE/readme.md). That script converts approved decisions into `concept_manual` and `concept_relationship_manual` rows for the Cancer Modifier `load_stage.sql`.
