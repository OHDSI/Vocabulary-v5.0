Update of ICD10PCS

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory ICD10PCS.

1. Run create_source_tables.sql
2. Download the latest file from https://www.cms.gov/medicare/coding-billing/icd-10-codes,
file name YYYY-ICD-10-PCS-Order-File.zip (e.g. 2019-ICD-10-PCS-Order-File.zip) listed as "ICD-10-PCS Order File (Long and Abbreviated Titles)"
3. Exctract icd10pcs_order_YYYY.txt and rename to icd10pcs.txt
4. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('ICD10PCS',TO_DATE('20180101','YYYYMMDD'),'ICD10PCS 20180101'); (pVocabularyDate=YYYY-1)

6. Run FastRecreateSchema:
```sql
   SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> true, include_deprecated_rels=> true, include_synonyms=> true);
```
7. Run load_stage.sql.
8. Run generic_update:
  ```sql
   DO $_$
   BEGIN
       PERFORM devv5.GenericUpdate();
   END $_$;
   ```
9. Run basic tables check (should retrieve NULL):
```sql
   SELECT * FROM qa_tests.get_checks();
```
10. Perform manual work described in the readme.md file in the 'manual_work' folder.

Repeat steps 5-10.

11. Run scripts to get summary, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_summary('concept','devv5');
    SELECT DISTINCT * FROM qa_tests.get_summary('concept_relationship','devv5');
    ```
12. Run scripts to collect statistics, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_domain_changes('devv5');
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts('devv5');
    SELECT DISTINCT * FROM qa_tests.get_standard_concept_changes('devv5');
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts_standard_concept_status('devv5');
    SELECT DISTINCT * FROM qa_tests.get_changes_concept_mapping('devv5');
    ```
13. Run manual_checks_after_generic.sql, and interpret the results.
14. Run project_specific_manual_checks_after_generic.sql, and interpret the results.
15. If no problems, enjoy!


Directory snomed_hierarchy contains unrefined version of tools to build automated relationship to SNOMED concepts currently stored in concept_relationship_manual. 
These scripts are early version and require a thorough refactoring before being reused.

Attribute mappings for SNOMED are available under: https://drive.google.com/drive/u/2/folders/17PPiksUxXYNQ6batNduHpGxO-CDC1ZqV