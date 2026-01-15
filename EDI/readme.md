Update of EDI

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory dev_edi.

1. Run create_source_tables.sql
2. Run 
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> false, include_deprecated_rels=> true, include_synonyms=> true);
   ```
3. Run edi_refresh.sql

4. Run load_stage.sql

5. Run generic_update:
   ```sql
   DO $_$
   BEGIN
       PERFORM devv5.GenericUpdate();
   END $_$;
   ```
6. Run basic tables check (should retrieve NULL):
   ```sql
    SELECT * FROM qa_tests.get_checks();
    ```
7. Run scripts to get summary, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_summary('concept');
    SELECT DISTINCT * FROM qa_tests.get_summary('concept_relationship');
    ```
8. Run scripts to collect statistics, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_domain_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts();
    SELECT DISTINCT * FROM qa_tests.get_standard_concept_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts_standard_concept_status();
    SELECT DISTINCT * FROM qa_tests.get_changes_concept_mapping();
    ```
9. If no problems, enjoy!