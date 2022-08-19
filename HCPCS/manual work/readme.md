### STEP 8 of the refresh:

8.1. Upload concept_manual table into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file](https://drive.google.com/drive/u/0/folders/1-Sv1csKD7Bztt62bISdsOhOWZBvJp3SX) into the concept_manual table.
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
8.2 Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file] (https://drive.google.com/drive/u/0/folders/1-Sv1csKD7Bztt62bISdsOhOWZBvJp3SX) into the concept_relationship_manual table.
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

8.3. Work with the [hcpcs_refresh] file:

8.3.1. Backup concept_relationship_manual table and concept_manual table.

8.3.2. Create hcpcs_mapped table in the spreadsheet editor pre-populate it with the resulting manual table of the previous HCPCS refresh.

8.3.3. Review the previous mapping and map new concepts. If previous mapping can be improved, just change mapping of the respective row. To deprecate a previous mapping without a replacement, just delete a row.

8.3.4. Select concepts to map and add them to the manual file in the spreadsheet editor.

8.3.5. Truncate the hcpcs_mapped table. Save the spreadsheet as the hcpcs_mapped table and upload it into the working schema.

8.3.6. Perform any mapping checks you have set.

8.3.7. Iteratively repeat steps 8.2.3-8.2.6 if found any issues.

8.3.8. Deprecate all mappings that differ from the new version of resulting mapping file.

8.3.9. Insert new and corrected mappings into the concept_relationship_manual table.