Update of CVX

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- RxNorm must be loaded first

1. Run create_source_tables.sql
2. Download CVX code distrbution file
- Open the site http://www2a.cdc.gov/vaccines/IIS/IISStandards/vaccines.asp?rpt=cvx
- Download Excel file (https://www2a.cdc.gov/vaccines/IIS/IISStandards/downloads/web_cvx.xlsx)
3. Load Vaccines administered (CVX) Value Set Updates from https://phinvads.cdc.gov/vads/ValueSetRssFeed.xml?oid=2.16.840.1.114222.4.11.934. Download all versions (in Excel format), except 4.
4. Sequentially upload data to the database by executing in devv5: SELECT sources.load_input_tables('CVX', TO_DATE('YYYYMMDD', 'yyyymmdd'), 'CVX Code Set '||TO_DATE('YYYYMMDD', 'yyyymmdd'));
where YYYYMMDD = date of 'Vaccines administered value set' taken from RSS feed
Example:
- put web_cvx.xlsx and ValueSetConceptDetailResultSummary.xls (version 1) into your upload folder
- run SELECT sources.load_input_tables('CVX', TO_DATE('20081201', 'yyyymmdd'), 'CVX Code Set '||TO_DATE('20081201', 'yyyymmdd'));
- leave the web_cvx.xlsx and replace ValueSetConceptDetailResultSummary.xls with ValueSetConceptDetailResultSummary.xls from version 2
- run SELECT sources.load_input_tables('CVX', TO_DATE('20091015', 'yyyymmdd'), 'CVX Code Set '||TO_DATE('20091015', 'yyyymmdd'));
- repeat untill last version
Note: be careful with dates, because we need a minimum date of each concept code of all the sets
5. Download "CPT Codes Mapped to CVX Codes" from https://www2a.cdc.gov/vaccines/iis/iisstandards/vaccines.asp?rpt=cpt
6. Download "Mapping CVX to Vaccine Groups" from https://www2a.cdc.gov/vaccines/iis/iisstandards/vaccines.asp?rpt=vg

##### Filling stage and basic tables
14. Run FULL FastRecreate:
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> false,
                                include_deprecated_rels=> true, include_synonyms=> true);
```
15. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/CVX/load_stage.sql).
16. Run check_stage_tables function (should retrieve NULL):
```sql
SELECT * FROM qa_tests.check_stage_tables();
```
17. Run generic_update:
```sql
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;
```
18. Run basic tables check (should retrieve NULL):
```sql
SELECT * FROM qa_tests.get_checks();
```
19. Perform manual work described in the [readme.md](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/CVX/manual_work/readme.md) file in the 'manual_work' folder.

20. Repeat steps 11-15.

21. Run scripts to get summary, and interpret the results:
```sql
SELECT * FROM qa_tests.get_summary('concept');
```
```sql
SELECT * FROM qa_tests.get_summary('concept_relationship');
```
22. Run scripts to collect statistics, and interpret the results:
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

23. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql), and interpret the results.
24. If no problems, enjoy!