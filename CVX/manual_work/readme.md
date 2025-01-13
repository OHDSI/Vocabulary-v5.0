### STEP 19 of the refresh:
19.1. Upload concept_manual table into the working schema (skip this step if implementing on the Pallas vocabulary server).
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

19.2. Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server).
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


19.3. Work with [cvx_refresh](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/CVX/manual_work/cvx_refresh.sql) file

19.3.1. Create cvx_mapped table and pre-populate it with the resulting manual table of the previous CVX refresh. You may need to introduce new concepts first.

19.3.2. Review the previous mapping and map new concepts. If previous mapping should be changed or deprecated, use cr_invalid_reason field.

19.3.3. Truncate the cvx_mapped table. Save the spreadsheet as the cvx_mapped table and upload it into the working schema.

19.3.4. Perform any mapping checks you have set.

19.3.5. Iteratively repeat steps 19.3.3.-19.3.5. if found any issues.

19.3.6. Insert new and update existing relationships according to _mapped table.

19.3.7. Correction of valid_start_dates and valid_end_dates for deprecation of existing mappings, existing in base, but not manual tables.
