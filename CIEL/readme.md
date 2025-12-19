## CIEL Refresh Runbook

This readme describes the end-to-end OMOP CIEL refresh.

## Source loading
Source Data dictionary avaliable here: [link](https://docs.google.com/spreadsheets/d/1SEPF6SWBtQT5RCjy5UdnBTB_5HdqD-GY/edit?usp=drive_link&ouid=113306385753414474534&rtpof=true&sd=true)

1. Go to folder **source_load**
1. Run script `create_source_tables.sql`
2. Run script `additional_functions.sql` for **API** and **JSON** work
3. Run scripts `load_ciel_concepts.sql` **and** `load_ciel_mappings.sql`\
**and** `load_ciel_source_versions.sql` **and**  `get_ciel_concept_retired_version.sql`
4. Run script `load_ciel_all.sql`

### To load source us one of the following:

**Full load of latest version**
```sql
SELECT * FROM sources.load_ciel_all (
  p_token          := 'YOUR_TOKEN', 
  p_source_version := NULL, 
  p_clear          := true  
  );
```
**Fixed version of CIEL _(now CIEL provides only 10000 concepts via this approach, can be used when they fix on their side)_**
```sql
SELECT * FROM sources.load_ciel_all(
  p_token          := 'YOUR_TOKEN', 
  p_source_version := 'v2025-10-19', 
  p_clear          := true 
  );
```

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

### Action sequence

1. **Reset dev schema**  
   Run:
   ```sql
   SELECT devv5.FastRecreateSchema(
     include_concept_ancestor => TRUE,
     include_deprecated_rels  => TRUE,
     include_synonyms         => TRUE
   );
   ```
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
7. **Run generic update**
- `SELECT devv5.genericupdate();` This moves staged CIEL content into the main concept and concept_relationship tables in your dev schema.
8. **Prform QA after generic run**
- `SELECT qa_tests.get_checks();`
- `SELECT * FROM qa_tests.Get_Summary ('concept','devv5');`
- `SELECT * FROM qa_tests.Get_Summary ('concept_relationship','devv5');`
- Address any blocking issues before promoting dev to production.
9. **Run metadata.sql**
10. **Promote to production**
  
After all the vocabulary is refreshed.

> You can read more about the CIEL refresh logic here: [link](https://docs.google.com/document/d/1f2D-YDlSYS0OG6qTuqdcaSPnra1tjNBVrgmat2-MN1k/edit?usp=drive_link).
