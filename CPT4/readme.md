Update of CPT4

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- UMLS in SOURCES schema
- Working directory CPT4

Manual tables are available here https://drive.google.com/drive/u/2/folders/1TWGdyVy95AT-9GfK7KaKY2HQA4rDqxrH

1. Run SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>true, include_deprecated_rels=>true, include_synonyms=>true);

2. Run load_stage.sql (The pVocabularyDate will be automatically retrieved from the UMLS [SOURCES.MRSMAP.vocabulary_date])

3. Run generic_update:
```sql
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;
```
4. Run basic tables check (should retrieve NULL):
```sql
SELECT * FROM qa_tests.get_checks();
```
5. Clean cache:
```sql
SELECT * FROM qa_tests.purge_cache();
```
6. Run scripts to get summary, and interpret the results:
```sql
SELECT DISTINCT * FROM qa_tests.get_summary('concept');
```
```sql
SELECT DISTINCT * FROM qa_tests.get_summary('concept_relationship');
```
7. Run scripts to collect statistics, and interpret the results:
```sql
SELECT DISTINCT * FROM qa_tests.get_domain_changes();
```
```sql
SELECT DISTINCT * FROM qa_tests.get_newly_concepts();
```
```sql
SELECT DISTINCT * FROM qa_tests.get_standard_concept_changes();
```
```sql
SELECT DISTINCT * FROM qa_tests.get_newly_concepts_standard_concept_status();
```
```sql
SELECT DISTINCT * FROM qa_tests.get_changes_concept_mapping();
```
8. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql), and interpret the results.

9. Work with 'manual work' directory

10. Run load_stage.sql

11. Run check_stage_tables function (should retrieve NULL):

12. Run generic_update

13. Clean cache

14. Run scripts to get summary, and interpret the results:

13. Run scripts to collect statistics, and interpret the results:

14. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql), and interpret the results.


