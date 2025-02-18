Update of ICD10GM

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- UMLS in SOURCES schema
- SNOMED and ICD10 must be loaded first
- Working directory ICD10GM

1. Run 
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>true, include_deprecated_rels=>true, include_synonyms=>true);
```
2. Run crm_changes.sql (The script updates CRM table with manual mappings. For more information see readme.md for ICD environment https://github.com/OHDSI/Vocabulary-v5.0/tree/master/ICD_CDE).

3. Run load_stage.sql

4. Run generic_update:
```sql
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;
```
5. Run basic tables check (should retrieve NULL):
```sql
SELECT * FROM qa_tests.get_checks();
```

6. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql), and interpret the results.

7. Run scripts to get summary, and interpret the results:
```sql
SELECT * FROM qa_tests.get_summary('concept');
SELECT * FROM qa_tests.get_summary('concept_relationship');
```
8. Run scripts to collect statistics, and interpret the results:
```sql
SELECT * FROM qa_tests.get_domain_changes();
SELECT * FROM qa_tests.get_newly_concepts();
SELECT * FROM qa_tests.get_standard_concept_changes();
SELECT * FROM qa_tests.get_newly_concepts_standard_concept_status();
SELECT * FROM qa_tests.get_changes_concept_mapping();
```
9. If no problems, enjoy! If any mistakes were detected, make changes in ICD environment (see readme.md for ICD CDE https://github.com/OHDSI/Vocabulary-v5.0/tree/master/ICD_CDE) and repeat the process from the beginning.
