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
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>true, include_deprecated_rels=>true, include_synonyms=>true);
```
8. Run load_stage.sql
9. Perform manual work
10. Run load_stage.sql
11. Run generic_update:
```sql
SELECT devv5.GenericUpdate();
```
12. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql)
13. If no problems, enjoy!