Update of SNOMED Veterinary

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory SNOMED Veterinary.
- SNOMED must be loaded first.

1. Run create_source_tables.sql
2. Download the Veterinary Extension of SNOMED CT file SnomedCT_Release_VTSzzzzzzz_yyyymmdd.zip from https://vtsl.vetmed.vt.edu/extension/
3. Extract the following files from the folder \Full\Terminology:
- sct2_Concept_Full_VTS_YYYYMMDD.txt
- sct2_Description_Full_en_VTS_YYYYMMDD.txt
- sct2_Relationship_Full_VTS_YYYYMMDD.txt
Rename files to sct2_Concept_Full_VTS.txt, sct2_Description_Full_VTS.txt, sct2_Relationship_Full_VTS.txt

4. Extract der2_cRefset_AssociationReferenceFull_VTS_YYYYMMDD.txt from SnomedCT_Release_VTSzzzzzzz\Full\Refset\Content
Rename to der2_cRefset_AssociationFull_VTS.txt

5. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('SNOMED Veterinary',TO_DATE('20181001','YYYYMMDD'),'SNOMED Veterinary 20181001');

6. Run 
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> true, include_deprecated_rels=> true, include_synonyms=> true);
   ```
7. Run load_stage.sql
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
10. Run scripts to get summary, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_summary('concept', 'devv5');
    SELECT DISTINCT * FROM qa_tests.get_summary('concept_relationship', 'devv5');
    ```
11. Run scripts to collect statistics, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_domain_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts();
    SELECT DISTINCT * FROM qa_tests.get_standard_concept_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts_standard_concept_status();
    SELECT DISTINCT * FROM qa_tests.get_changes_concept_mapping();
    ```
12. If no problems, enjoy!