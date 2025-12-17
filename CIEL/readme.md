## CIEL Refresh Runbook

This readme describes the end-to-end OMOP CIEL refresh.

## Source loading
Source Data dictionary avaliable here [neet to add link to GD]

1. Go to folder **_source_load_**
1. Run script _create_source_tables.sql_
2. Run script _additional_functions.sql_ for **API** and **JSON** work
3. Run scripts _load_ciel_concepts.sql_ **and** _load_ciel_mappings.sql_ **and** _load_ciel_source_versions.sql_ **and**  _get_ciel_concept_retired_version.sql_
4. Run script _load_ciel_all.sql_

### To load source us one of the following:

**Full load of latest version**
>SELECT * FROM sources.load_ciel_all \
>  ( \
>  p_token          := 'YOUR_TOKEN', \
>  p_source_version := NULL, \
>  p_clear          := true  \
> );

**Fixed version of CIEL _(now CIEL provides only 10000 concepts via this approach, can be used when they fix on their side)_**
> SELECT * FROM sources.load_ciel_all( \
> p_token          := 'YOUR_TOKEN', \
> p_source_version := 'v2025-10-19', \
> p_clear          := true \
> );

### Environment prerequisites

- A development vocabulary schema (e.g. `devv5`) with:
  - Fresh copies of `concept`, `concept_relationship`, `concept_synonym` and `concept_ancestor` from production.
  - All standard indexes and constraints in place.
- CIEL source data loaded into the `sources` schema:
  - `sources.ciel_source_versions`
  - `sources.ciel_concepts`
  - `sources.ciel_concept_names`
  - `sources.ciel_concept_retired_history`
  - `sources.ciel_mappings`
- Manual override table:
  - refreshed `concept_relationship_manual`called `concept_relationship_manual_updated`
- Vocabulary utilities and QA functions available:
  - `vocabulary_pack.*`
  - `qa_tests.Check_Stage_Tables()`
  - `qa_tests.get_checks();`
  - `qa_tests.get_summary();`

A typical CIEL refresh run looks as follows:

1. **Reset dev schema**  
   Run:
   ```sql
   SELECT devv5.FastRecreateSchema(
     include_concept_ancestor => TRUE,
     include_deprecated_rels  => TRUE,
     include_synonyms         => TRUE
   );

2. **Prepare CIEL mapping input**
- Load or refresh CIEL source tables under sources.
3. **Run maps_for_load_stage.sql** to populate the ranked mapping table maps_for_load_stage in the dev shema.
4. Load concept_relationship_manual_updated into the dev schema and **run crm_changes.sql** to refresh manual mapping overrides.
5. **Run load_stage.sql**
- Rebuild concept_stage, concept_synonym_stage, and concept_relationship_stage for CIEL based on:
  - the latest CIEL snapshot in sources.
  - the prioritized mappings in maps_for_load_stage
  - manual overrides.
6. **Run staging QA scripts**
- `SELECT * FROM qa_tests.Check_Stage_Tables();`
- `load_stage_qa.sql`     
7. **Run generic update**
- `SELECT devv5.genericupdate();` This moves staged CIEL content into the main concept and concept_relationship tables in your dev schema.
8. **Run after_generic_qa.sql**
- Address any blocking issues before promoting dev to production.
9. **Promote to production**
  
After all the vocabulary is refreshed.
