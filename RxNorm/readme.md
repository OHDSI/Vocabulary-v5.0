Update of RxNorm

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- SNOMED must be loaded first
- Working directory is RxNorm.

1. Run create_source_tables.sql
2. Run qa_rxnorm.sql in your dev-schema for RxNorm e.g. dev_rxnorm (this will create one procedure).
3. Run FillDrugStrengthStage.sql in your dev-schema for RxNorm e.g. dev_rxnorm (this will create one procedure).
4. Download RxNorm_full_MMDDYYYY.zip from http://www.nlm.nih.gov/research/umls/rxnorm/docs/rxnormfiles.html
5. Extract files from the folder "rrf":
RXNATOMARCHIVE.RRF
RXNCONSO.RRF
RXNREL.RRF
RXNSAT.RRF

6. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('RxNorm',TO_DATE('20180507','YYYYMMDD'),'RxNorm Full 20180507');
7. Run fast_recreate:
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> true, include_deprecated_rels=> true, include_synonyms=> true);
   ```
8. Run load_stage.sql
9. NOTE: When RxNorm is run in dev_rxnorm schema, rxn_info_sheet table is created.
Review the results of QA using the query:
```sql
SELECT *
FROM rxn_info_sheet;
```
10. Run generic_update:
```sql
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;
```
11. Run basic tables check (should retrieve NULL):
```sql
    SELECT * FROM qa_tests.get_checks();
```
12. Run vocabulary-specific QA from 'vocab_specific_checks' folder.

13. Run scripts to get summary, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_summary('concept');
    SELECT DISTINCT * FROM qa_tests.get_summary('concept_relationship');
    ```
14. Run scripts to collect statistics, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_domain_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts();
    SELECT DISTINCT * FROM qa_tests.get_standard_concept_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts_standard_concept_status();
    SELECT DISTINCT * FROM qa_tests.get_changes_concept_mapping();
    ```
15. If no problems, enjoy!