### Update of MedDRA

#### Prerequisites
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- SNOMED must be loaded first.
- Working directory is MedDRA.

 #### Sequence of actions
##### Source filling 
1. Run create_source_tables.sql
2. Download the current Meddra from https://www.meddra.org/software-packages (english) and "SNOMED CT – MedDRA Mapping Release Package"
3. From MedDRA_xy_z_English.zip extract files from the folder "MedAscii":
- hlgt_hlt.asc
- hlt.asc
- hlt_pt.asc
- hlgt.asc
- llt.asc
- mdhier.asc
- pt.asc
- soc.asc
- soc_hlgt.asc
4. From "SNOMED CT - MedDRA Mapping Release Package DD MONTH YYYY.zip" extract *.xlsx file and rename to meddra_mappings.xlsx
5. From "ICD-10 to MedDRA Release Package-MONTH YYYY.zip" extract *.xlsx file and rename to meddra_mappings_icd10.xlsx
6. Run in devv5 (with fresh vocabulary date and version):
```sql
SELECT sources.load_input_tables('MedDRA',TO_DATE('20160901','YYYYMMDD'),'MedDRA version 25.0')
```
##### Filling stage and basic tables
7. Perform manual work described in the [readme.md](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/MedDRA/Manual_work/readme.md) file in the 'manual_work' folder.
8. Run load_stage.sql
9. Run check_stage_tables function (should retrieve NULL):
```sql
SELECT * FROM qa_tests.check_stage_tables ();
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
12. Run scripts to get summary, and interpret the results:
```sql
SELECT * FROM qa_tests.get_summary('concept')
WHERE vocabulary_id_1 = 'MedDRA';
```
```sql
SELECT * FROM qa_tests.get_summary('concept_relationship')
WHERE vocabulary_id_1 = 'MedDRA' OR vocabulary_id_2 = 'MedDRA';
```
13. Run scripts to collect statistics, and interpret the results:
```sql
SELECT * FROM qa_tests.get_domain_changes();
```
```sql
SELECT * FROM qa_tests.get_newly_concepts();
```
```sql
SELECT * FROM qa_tests.get_standard_concept_changes();
```
```sql
SELECT * FROM qa_tests.get_newly_concepts_standard_concept_status();
```
```sql
SELECT * FROM qa_tests.get_changes_concept_mapping();
```
14. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic_update.sql), and interpret the results.