Update of VANDF and VA Class vocabularies

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed
- RxNorm in SOURCES schema
- Working directory VANDF

1. Run fast_recreate_schema:
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> false, include_deprecated_rels=> true, include_synonyms=> true);
   ```
2. Run load_stage.sql

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
5. Run vocabulary-specific QA from 'specific_qa' folder.

6. Run scripts to get summary, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_summary('concept');
    SELECT DISTINCT * FROM qa_tests.get_summary('concept_relationship');
    ```
7. Run scripts to collect statistics, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_domain_changes('devv5');
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts('devv5');
    SELECT DISTINCT * FROM qa_tests.get_standard_concept_changes('devv5');
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts_standard_concept_status('devv5');
    SELECT DISTINCT * FROM qa_tests.get_changes_concept_mapping('devv5');
    ```
8. If no problems, enjoy!
