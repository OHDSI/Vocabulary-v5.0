### ICD10CN upload/update

#### Prerequisites
- Basic knowledge of the [OMOP representation of the ICD10 vocabulary](https://www.ohdsi.org/web/wiki/doku.php?id=documentation:vocabulary:icd10gm)
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- SNOMED and ICD10 must be loaded first
- Working directory dev_icd10cn

#### Sequence of actions
1. Download the latest ICD-10-CN version [here](https://github.com/ohdsi-china/Phase1Testing)
2. Unzip CONCEPT.csv, CONCEPT_RELATIONSHIP.csv (password required) and rename to icd10cn_concept.csv (we use modified version of this file) and icd10cn_concept_relationship.csv
3. Run [create_source_tables.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/ICD10CN/create_source_tables.sql)
4. Run in devv5 (with fresh vocabulary date and version): 
```sql
SELECT sources.load_input_tables('ICD10CN',TO_DATE('20160101','YYYYMMDD'),'2016 Release');
```
5. Run the FastRecreate:
```sql
SELECT devv5.FastRecreateSchema('dev_icd10'); 
```
6. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/ICD10CN/load_stage.sql) for the first time to define problems in mapping.
7. Perform manual work described in manual_work folder
8. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/ICD10CN/load_stage.sql) for the second time to refresh the vocabulary.
9. Run generic_update: 
```sql
SELECT devv5.GenericUpdate();
```
10. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql)
