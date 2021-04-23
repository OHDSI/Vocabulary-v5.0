### KCD7 upload/update

#### Prerequisites
- Basic knowledge of the [OMOP representation of the ICD10 vocabulary](https://www.ohdsi.org/web/wiki/doku.php?id=documentation:vocabulary:icd10gm)
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- SNOMED and ICD10 must be loaded first
- Working directory dev_kcd7
#### Sequence of actions
1. Download the latest KCD-7 version [here](https://www.hira.or.kr/rd/insuadtcrtr/bbsView.do?pgmid=HIRAA030069000000&brdScnBltNo=4&brdBltNo=50760&pageIndex=1&isPopupYn=Y#none) 
2. Unzip the file 배포용 상병마스터 파일.xlsx and rename to kcd7.csv
3. [create_source_tables.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/KCD7/create_source_table.sql)
4. Run in devv5 (with fresh vocabulary date and version): 
```sql
SELECT sources.load_input_tables('KCD7',TO_DATE('20170701','yyyymmdd'),'7th revision');
```
5. 5. Run the FastRecreate:
```sql
SELECT devv5.FastRecreateSchema('dev_icd10'); 
```
6. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/KCD7/load_stage.sql)
7. Run generic_update: 
```sql
SELECT devv5.GenericUpdate();
```
8. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql)
