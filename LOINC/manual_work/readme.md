### STEP 18 of the refresh:
18.1. Upload concept_manual table into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file](https://drive.google.com/file/d/1sXdWNn1oN-EhsqFyT6cl2TI4YBXbDQyV/view?usp=sharing) into the concept_manual table.
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

18.2. Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file](https://drive.google.com/file/d/1-R7_j_PNDrNIO1me_ni4-FNL2bs0iE1d/view?usp=sharing) into the concept_relationship_manual table.
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


18.3. Work with [loinc_refresh](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/LOINC/manual_work/loinc_refresh.sql) file:

18.3.1. Create loinc_mapped table and pre-populate it with the resulting manual table of the previous LOINC refresh.

18.3.2. Select concepts to map (flag shows different reasons for mapping refresh) and add them to the manual file in the spreadsheet editor.

18.3.3. Select COVID concepts lacking hierarchy and add them to the manual file in the spreadsheet editor (these concepts need 'Is a' relationships).

18.3.4. Truncate the loinc_mapped table. Save the spreadsheet as the loinc_mapped table and upload it into the working schema.

18.3.5 Perform any mapping checks you have set.

18.3.5. Change concept_relationship_manual table according to loinc_mapped table.

18.3.6 Iteratively repeat steps 18.3.2-18.3.5 if found any issues.

18.3.7. Change concept_relationship_manual table according to loinc_mapped table.

18.3.8. Change concept_manual if needed