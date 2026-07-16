**Refresh of HPO**

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- UMLS in SOURCES schema
- Working directory HPO


1. Run 
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>true, include_deprecated_rels=>true, include_synonyms=>true);
```
2. Make sure the source tables and related triggers are created/implemented (`create_source_tables.sql`)
3. Run functions developed to scrape  HPO sources into prepared source tables (`download_hpo_sources.sql`)
4. Run `hpo_mapping_refresh` (manual work) in order to populate concept_relationship_manual table (use the inputs provided by steward)
5. Run `load_stage.sql` in the OHDSI vocabulary working schema 
6. Run generic_update:
```sql
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;
```
7. Execute `concept_relationship_metadata.sql` (manual work) AFTER generic (use the content provided by steward) in order to populate relationship_metadata 
8. Run basic tables check (should retrieve NULL):
```sql
SELECT * FROM qa_tests.get_checks();
```

9. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql), and interpret the results. 
10. Run scripts to get summary, and interpret the results:
```sql
SELECT * FROM qa_tests.get_summary('concept');
SELECT * FROM qa_tests.get_summary('concept_relationship');
```
11. Run scripts to collect statistics, and interpret the results:
```sql
SELECT * FROM qa_tests.get_domain_changes();
SELECT * FROM qa_tests.get_newly_concepts();
SELECT * FROM qa_tests.get_standard_concept_changes();
SELECT * FROM qa_tests.get_newly_concepts_standard_concept_status();
SELECT * FROM qa_tests.get_changes_concept_mapping();
```
12. If no problems, enjoy!