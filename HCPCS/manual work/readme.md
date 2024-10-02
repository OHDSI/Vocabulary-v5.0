### STEP 9 of the refresh:

9.1. Upload concept_manual table into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file](https://drive.google.com/drive/u/0/folders/1mvXzaXW9294RaDC2DgnM1qBi1agCwxHJ) into the concept_manual table.
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
9.2 Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file](https://drive.google.com/drive/u/0/folders/1mvXzaXW9294RaDC2DgnM1qBi1agCwxHJ) into the concept_relationship_manual table.
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

9.3. Work with the [hcpcs_refresh] file:

9.3.1. Create hcpcs_mapped table and pre-populate it with the resulting manual table of the previous hcpcs refresh.

9.3.2. Review the previous mapping and map new concepts. Use _cr_invalid_reason_ field to deprecate mappings.

9.3.3. Truncate the hcpcs_mapped table. Save the spreadsheet as the hcpcs_mapped table and upload it into the working schema.

9.3.4. Perform any mapping checks you have set.

9.3.5. Iteratively repeat steps 9.3.2-9.3.4 if found any issues.

9.3.6. Change concept_relationship_manual table according to hcpcs_mapped table.

9.3.7. Create concept_mapped table and populate it with concepts that require manual changes.

9.3.8  Truncate concept_mapped table. Save the spreadsheet as 'concept_mapped table' and upload it to the schema.

9.3.9  Change concept_manual table according to concept_mapped table.