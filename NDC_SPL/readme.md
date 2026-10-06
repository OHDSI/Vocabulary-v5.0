Update of NDC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- RxNorm must be loaded first
- Working directory NDC.
- Created schema ApiGrabber (\working\packages\APIgrabber). You must execute all functions in ApiGrabber at least once

1. Run create_source_tables.sql

2. Download NDC code distrbution file
Open the site http://www.fda.gov/Drugs/InformationOnDrugs/ucm142438.htm
- Download the latest NDC Database File
- Extract product.txt and package.txt files

3. Download additional source for SPL concepts and relationships from https://dailymed.nlm.nih.gov/dailymed/spl-resources-all-drug-labels.cfm and https://dailymed.nlm.nih.gov/dailymed/spl-resources-all-mapping-files.cfm
- Full Releases of HUMAN PRESCRIPTION LABELS, HUMAN OTC LABELS, HOMEOPATHIC LABELS and REMAINDER LABELS (1st link)
- SPL-RXNORM MAPPINGS (2d link)

4. Extract LABELS using unzipxml.sh

5. Extract rxnorm_mappings.txt from rxnorm_mappings.zip

6. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('NDC',TO_DATE('20180420','YYYYMMDD'),'NDC 20180420');

7. Run the FastRecreate (Full recreate, all tables are included):
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>false, include_deprecated_rels=>true, include_synonyms=>true);
```
8. Run [load_stage.sql]

9. Perform manual work described in manual_work folder

10. Run [load_stage.sql]

11. Run generic_update:
```sql
SELECT devv5.GenericUpdate();
```

12. Perform QA checks (should retrieve NULL)
```sql
SELECT * FROM QA_TESTS.GET_CHECKS();
```

13. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql)

14. Get_summary - changes in tables between dev-schema (current) and devv5/prodv5/any other schema

--14.1. summary (table to check, schema to compare)
```sql
select * from qa_tests.get_summary ('concept', 'devv5');
```
--14.2. summary (table to check, schema to compare)
```sql
select * from qa_tests.get_summary ('concept_relationship','devv5');
```

15. Statistics QA checks
--changes in tables between dev-schema (current) and devv5/prodv5/any other schema

--15.1. Domain changes
```sql
select * from qa_tests.get_domain_changes(pCompareWith=>'devv5');
```
--15.2. Newly added concepts grouped by vocabulary_id and domain
```sql
select * from qa_tests.get_newly_concepts(pCompareWith=>'devv5');
```
--15.3. Standard concept changes
```sql
select * from qa_tests.get_standard_concept_changes(pCompareWith=>'devv5');
```
--15.4. Newly added concepts and their standard concept status
```sql
select * from qa_tests.get_newly_concepts_standard_concept_status(pCompareWith=>'devv5');
```
--15.5. Changes of concept mapping status grouped by target domain
```sql
select * from qa_tests.get_changes_concept_mapping(pCompareWith=>'devv5');
```