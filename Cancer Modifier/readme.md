### Update of Cancer Modifier
The Cancer Modifier load_stage.sql follows the universal load stage approach: it copies the selected updatable vocabularies into stage tables and applies approved manual content before the generic update. Manual concepts are processed before manual relationships, so newly approved Cancer Modifier concepts can be created first and then used as mapping targets during the same refresh.

#### Prerequisites
- Schema DevV5 with copies of tables `concept`, `concept_relationship`, `concept_synonym`, `pack_content` and `drug_strength` from ProdV5, fully indexed.
- Vocabualries to be curated by reviewer (most recent versions available) must be loaded first.
- Working directory is `Cancer Modifier`.
- Manual tables in `dev_cancer_modifier` must contain the approved Cancer Modifier content before running `load_stage.sql`.
- The `vocabulary_pack` package must be available. The oncology concept-mining workflow also uses the Hecate helper documented in comments in [`working/packages/vocabulary_pack/SeedBasedHecateMine_multithread.sql`](../working/packages/vocabulary_pack/SeedBasedHecateMine_multithread.sql).

#### Sequence of actions

##### Manual work and source preparation
1. Perform manual work described in the [`manual_work/readme.md`](manual_work/readme.md) file.
2. If new oncology candidates are needed, run the mining workflow described in [`manual_work/Mining concepts for Mapping/readme.md`](manual_work/Mining%20concepts%20for%20Mapping/readme.md).
3. If the mining workflow is used, prepare the CDE review output and convert approved rows to manual tables as described in [`manual_work/Mining concepts for Mapping/CDE/readme.md`](manual_work/Mining%20concepts%20for%20Mapping/CDE/readme.md).

The manual work is intentionally split between the top-level and subfolder readmes. This file describes the refresh sequence; [`manual_work/readme.md`](manual_work/readme.md) describes manual table handling; [`manual_work/Mining concepts for Mapping/readme.md`](manual_work/Mining%20concepts%20for%20Mapping/readme.md) describes candidate mining; and [`manual_work/Mining concepts for Mapping/CDE/readme.md`](manual_work/Mining%20concepts%20for%20Mapping/CDE/readme.md) describes how reviewed CDE rows become `concept_manual` and `concept_relationship_manual` content.

##### Filling stage and basic tables
4. Run FULL FastRecreate:
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5',
                                include_concept_ancestor=>true,
                                include_deprecated_rels=>true,
                                include_synonyms=>true);
```
5. Run `load_stage.sql`.
6. Run check_stage_tables function (should retrieve NULL):
```sql
SELECT * FROM qa_tests.Check_Stage_Tables();
```
7. Run generic_update. If manual content was changed, perform virtual authorization before the update according to [`working/packages/admin_pack/readme.md`](../working/packages/admin_pack/readme.md).
```sql
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;
```
8. Run basic tables check (should retrieve NULL):
```sql
SELECT * FROM qa_tests.get_checks();
```
9. Run scripts to get summary, and interpret the results:
```sql
SELECT * FROM qa_tests.get_summary('concept')
WHERE vocabulary_id_1 IN ('Cancer Modifier', 'SNOMED');
```
```sql
SELECT * FROM qa_tests.get_summary('concept_relationship')
WHERE vocabulary_id_1 IN ('Cancer Modifier', 'SNOMED')
   OR vocabulary_id_2 IN ('Cancer Modifier', 'SNOMED');
```
10. Run scripts to collect statistics, and interpret the results:
```sql
SELECT * FROM qa_tests.get_domain_changes();
```
```sql
SELECT * FROM qa_tests.get_newly_concepts();
```
```sql
SELECT * FROM qa_tests.get_standard_concept_changes();
```
```sql
SELECT * FROM qa_tests.get_changes_concept_mapping();
```
11. Run `working/manual_checks_after_generic_update.sql`, and interpret the results.

