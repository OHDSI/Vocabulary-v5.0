STEP 7 of the Refresh
7.1. Upload concept_manual table into the working schema (skip this step if implementing on the Pallas vocabulary server).
    Extract the [respective csv file](https://drive.google.com/drive/u/0/folders/1P2dJ9PDMDuu03K-EqzAR8QgmLj72kEB0) into the concept_manual table. The file was generated using the query:

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

7.2 Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server).
    Extract the [respective csv file](https://drive.google.com/drive/u/1/folders/1P2dJ9PDMDuu03K-EqzAR8QgmLj72kEB0) into the concept_relationship_manual table. The file was generated using the query:

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

7.3. Work with the [ops_refresh] file:

7.3.1. Backup concept_relationship_manual table and concept_manual table.

7.3.2. Create table ops_delta_translated.

7.3.3. Truncate the ops_delta_translated table. Save the spreadsheet as the OPS_delta_translated table and upload it into the working schema

7.3.4. Insert the manual translation into the concept_manual table.

7.3.5. Insert the automated translation of the concepts in concept_manual table (2022 temporary solution for translation of the new codes, missing from delta)

7.3.6. Create OPS_mapped table in the spreadsheet editor pre-populate it with the resulting manual table of the previous OPS refresh.

7.3.7. Review the previous mapping and map new concepts. If previous mapping can be improved, just change mapping of the respective row. To deprecate a previous mapping without a replacement, just delete a row.

7.3.8. Select concepts to map and add them to the manual file in the spreadsheet editor.

7.3.9. Truncate the hcpcs_mapped table. Save the spreadsheet as the hcpcs_mapped table and upload it into the working schema.

7.3.10. Perform any mapping checks you have set.

7.3.11. Iteratively repeat steps 8.2.3-8.2.6 if found any issues.

7.3.12. Deprecate all mappings that differ from the new version of resulting mapping file.

7.3.13. Insert new and corrected mappings into the concept_relationship_manual table.

7.3.14 Activate mapping, that became valid again.