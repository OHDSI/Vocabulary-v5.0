### Process of working with _manual tables
1. Upload concept_manual table into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file](https://drive.google.com/file/d/1sXTGSjgP-DfZsx6SoQQET5ehksA1BH_W/view?usp=sharing) into the concept_manual table.
The file was generated using the query:
```sql
SELECT concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_manual
ORDER BY vocabulary_id, concept_code, invalid_reason, valid_start_date, valid_end_date, concept_name
```

2. Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file](https://drive.google.com/file/d/12gAlrCw5YFkC_ycrw3eMyWC6R92Aj1Gy/view?usp=sharing) into the concept_relationship_manual table.
The file was generated using the query:
```sql
SELECT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_relationship_manual
ORDER BY vocabulary_id_1, vocabulary_id_2, relationship_id, concept_code_1, concept_code_2, invalid_reason, valid_start_date, valid_end_date
```
#### csv format:
- delimiter: ','
- encoding: 'UTF8'
- header: ON
- decimal symbol: '.'
- quote escape: with backslash \
- quote always: FALSE
- NULL string: empty


3. Work with [cvx_refresh](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/CVX/manual_work/cvx_refresh.sql) file:

3.1. Create cvx_mapped table and pre-populate it with the resulting manual table of the previous CVX refresh. You may need to introduce new concepts first.

3.2. Review the previous mapping and map new concepts. If previous mapping should be changed or deprecated, use cr_invalid_reason field.

3.3. Truncate the cvx_mapped table. Save the spreadsheet as the cvx_mapped table and upload it into the working schema.

3.4. Perform any mapping checks you have set.

3.5. Iteratively repeat steps 3.3-3.5 if found any issues.

3.6. Insert new and update existing relationships according to _mapped table.

3.7. Correction of valid_start_dates and valid_end_dates for deprecation of existing mappings, existing in base, but not manual tables.

##### Filling stage and basic tables
4. Run FULL FastRecreate:
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> false,
                                include_deprecated_rels=> true, include_synonyms=> true);
```
5. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/CVX/load_stage.sql).
6. Run check_stage_tables function (should retrieve NULL):
```sql
SELECT * FROM qa_tests.check_stage_tables();
```
7. Run generic_update:
```sql
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;
```
8. Run basic tables check (should retrieve NULL):
```sql
SELECT * FROM qa_tests.get_checks();
```
9. Run scripts to get summary, and interpret the results:
```sql
SELECT * FROM qa_tests.get_summary('concept');
```
```sql
SELECT * FROM qa_tests.get_summary('concept_relationship');
```
10. Run scripts to collect statistics, and interpret the results:
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

11. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql), and interpret the results.
12. If no problems, enjoy!
