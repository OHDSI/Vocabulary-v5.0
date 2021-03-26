### ICD10 upload/update

#### Prerequisites
- Basic knowledge of the [OMOP representation of the ICD10 vocabulary](https://www.ohdsi.org/web/wiki/doku.php?id=documentation:vocabulary:icd10)
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- SNOMED must be loaded first
- Working directory dev_icd10

#### Sequence of actions
1. Download the latest ICD-10 version (e.g. ICD-10 2016 version) on the [WHO Website](http://apps.who.int/classifications/apps/icd/ClassificationDownload/DLArea/Download.aspx) 
2. Unzip the file icdClaMLYYYYens.xml and rename to icdClaML.xml
3. Run in devv5 (with the fresh vocabulary date and version): 
```sql
SELECT sources.load_input_tables('ICD10',TO_DATE('20161201','YYYYMMDD'),'2016 Release');
```
4. Run the FastRecreate:
```sql
SELECT devv5.FastRecreateSchema(include_synonyms=>true); 
```
5. As described in the "manual_work" folder, upload concept_manual.csv and concept_relationship_manual.csv into eponymous tables, which exist by default in the dev schema after  the FastRecreate. If you already have manual staging tables, obligatory create backups of them (e.g. concept_relationship_manual_backup_ddmmyy, concept_manual_backup_ddmmyy)
6. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10-documentation/ICD10/load_stage.sql) for the first time to define problems in mapping
7. Run [mapping_refresh.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10-documentation/ICD10/mapping_refresh.sql). Table refresh_lookup will be created. It contains the list with mappings to outdated, deprecated or updated Standard concepts, as well as automaticaly improved mapping. Download this table and open it in Excel. Columns icd_ represent ICD10 concepts with uncertain mapping, columns current_ refer to mapping which currently exists in concept_relationship_stage and columns repl_by_ suggest automatically created mapping, the reason for concepts appearing in this table you can see in column reason (e.g., 'improve_map','without mapping').
8. Perform manual review and mapping. Note, if you think that current mapping is better than suggested replacement, delete rows with these concepts from Excel table. Finally, delete current_ and reason columns.
9. Save table as refresh_lookup_done.csv and upload it into your schema using script 
```sql
CREATE TABLE refresh_lookup_done (
icd_code VARCHAR,
icd_name VARCHAR,
repl_by_id INT,
repl_by_code VARCHAR,
repl_by_name VARCHAR,
repl_by_domain VARCHAR,
repl_by_vocabulary VARCHAR);
```
10. Using recommendations described in the "manual_work" folder, run [manual_mapping_qa.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10-documentation/ICD10/manual_work/manual_mapping_qa.sql) to check whether refresh mapping meets the ICD10 logic
11. If everything is OK, deprecate old mappings for the ICD10 codes of interest in the concept_relationship_manual with valid_end_date = current_date and invalid_reason = 'D'
```sql
UPDATE concept_relationship_manual SET valid_end_date = CURRENT_DATE, invalid_reason = 'D' WHERE concept_code_1 IN (SELECT icd_code FROM refresh_lookup_done);
```
12. Add fresh mappings to the concept_relationship_manual with valid_start_date = current_date and invalid_reason IS NULL. Note, that all changes in concept_relationship_manual table should be reflected in the folder "manual_work" (e.g. manual_work_MMYY.sql)
```sql
INSERT INTO concept_relationship_manual SELECT icd_code, repl_by_code, 'ICD10', repl_by_vocabulary, 'Maps to', CURRENT_DATE, TO_DATE('20991231','YYYYMMDD'), NULL FROM refresh_update_done;
```
13. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10-documentation/ICD10/load_stage.sql) for the second time to refresh ICD10
14. Run generic_update: 
```sql
SELECT devv5.GenericUpdate();
```
15. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql)
16. If no problems, enjoy!
