### KCD7 upload/update

#### Prerequisites
- Basic knowledge of the [OMOP representation of the ICD10 vocabulary](https://www.ohdsi.org/web/wiki/doku.php?id=documentation:vocabulary:icd10gm)
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- SNOMED and ICD10 must be loaded first
- Working directory dev_kcd7
#### Sequence of actions
1. Download the latest KCD-7 version [here](https://www.hira.or.kr/rd/insuadtcrtr/bbsView.do?pgmid=HIRAA030069000000&brdScnBltNo=4&brdBltNo=50760&pageIndex=1&isPopupYn=Y#none) 
2. Unzip the file 배포용 상병마스터 파일.xlsx and rename to kcd7.csv
3. Run [create_source_tables.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/KCD7/create_source_table.sql)
4. Run in devv5 (with fresh vocabulary date and version): 
```sql
SELECT sources.load_input_tables('KCD7',TO_DATE('20170701','yyyymmdd'),'7th revision');
```
5. Run the FastRecreate:
```sql
SELECT devv5.FastRecreateSchema('dev_icd10'); 
```
6. As described in the "manual_work" folder, upload concept_relationship_manual.csv, which exist by default in the dev schema after the FastRecreate. If you already have manual staging tables, obligatory create backups of them (e.g. concept_relationship_manual_backup_ddmmyy)
7. Perform manual work described in manual_work folder
8. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/KCD7/load_stage.sql) to refresh KCD7
9. Run generic_update: 
```sql
SELECT devv5.GenericUpdate();
```
10. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql)
