Update of NUCC vocabulary

Pre-requisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- NUCC source files uploaded in the sources schema.
- Schema dev_nucc.

1. Run FastRecreate: 
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>false, include_deprecated_rels=>true, include_synonyms=>true);
```
2. Run load_stage.sql

3. Run generic_update:
```sql
SELECT admin_pack.VirtualLogIn ('dev_mkhitrun','Do_Not_Share_Your_Pass_2024!');

DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;
```
4. Run basic tables check (should retrieve NULL):
```sql
SELECT * FROM qa_tests.get_checks();
```
5. Work with 'manual work' directory

Repeat steps 1-5

6. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql), and interpret the results.

7. Run scripts to get summary, and interpret the results:
```sql
SELECT * FROM qa_tests.get_summary('concept', 'devv5');
SELECT * FROM qa_tests.get_summary('concept_relationship', 'devv5');
```
8. Run scripts to collect statistics, and interpret the results:
```sql
SELECT * FROM qa_tests.get_domain_changes();
SELECT * FROM qa_tests.get_newly_concepts();
SELECT * FROM qa_tests.get_standard_concept_changes();
SELECT * FROM qa_tests.get_newly_concepts_standard_concept_status();
SELECT * FROM qa_tests.get_changes_concept_mapping();
```
9. If no problems, enjoy!