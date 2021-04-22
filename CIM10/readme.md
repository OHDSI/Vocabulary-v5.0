### CIM10 upload/update

#### Prerequisites
- Basic knowledge of the [OMOP representation of the ICD10 vocabulary](https://www.ohdsi.org/web/wiki/doku.php?id=documentation:vocabulary:icd10gm)
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- SNOMED and ICD10 must be loaded first
- Working directory dev_cim10
- Manual tables must be filled (e.g. for translations)
#### Sequence of actions
1. Download the latest CIM-10 version [here]
2. Unzip the file 
3. Run [create_source_tables.sql]
4. Run in devv5 (with fresh vocabulary date and version): 
```sql
SELECT sources.load_input_tables('CIM10',TO_DATE('20200101','YYYYMMDD'),'2020 Release');
```
5. Run the FastRecreate:
```sql
SELECT devv5.FastRecreateSchema('dev_icd10'); 
```
