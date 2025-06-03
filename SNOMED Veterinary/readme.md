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

4. Extract the following files from SnomedCT_Release_VTSzzzzzzz\Full\Refset\Content
-der2_cRefset_AssociationReferenceFull_VTS_20240401.txt
-der2_cRefset_AttributeValueFull_VTS_20240401.txt
Rename the files to der2_cRefset_AssociationFull_VTS.txt,der2_cRefset_AttributeValueFull_VTS.txt

5. Extract der2_cRefset_LanguageFull_en_VTS_YYYMMDD.txt from SnomedCT_Release_VTS1000009\Full\Refset\Language
- Rename to der2_cRefset_LanguageFull_en_VTS.txt

6. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('SNOMED Veterinary',TO_DATE('20181001','YYYYMMDD'),'SNOMED Veterinary 20181001');

7. Run 
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> true, include_deprecated_rels=> true, include_synonyms=> true);
   ```
8. Run load_stage.sql
9. Run generic_update:
   ```sql
   DO $_$
   BEGIN
       PERFORM devv5.GenericUpdate();
   END $_$;
   ```
10. Run basic tables check (should retrieve NULL):
```sql
    SELECT * FROM qa_tests.get_checks();
```
11. Run scripts to get summary, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_summary('concept', 'devv5');
    SELECT DISTINCT * FROM qa_tests.get_summary('concept_relationship', 'devv5');
    ```
12. Run scripts to collect statistics, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_domain_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts();
    SELECT DISTINCT * FROM qa_tests.get_standard_concept_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts_standard_concept_status();
    SELECT DISTINCT * FROM qa_tests.get_changes_concept_mapping();
    ```
13. If no problems, enjoy!