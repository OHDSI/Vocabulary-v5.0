1. Upload concept_manual table into the working schema (skip this step if implementing on the Pallas vocabulary server). Extract the respective csv file into the concept_manual table. The file was generated using the query:

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

2. Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server). Extract the respective csv file into the concept_relationship_manual table. The file was generated using the query:

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


csv format:
delimiter: ','
encoding: 'UTF8'
header: ON
decimal symbol: '.'
quote escape: with backslash \
quote always: FALSE
NULL string: empty

3. Work with meddra_refresh file:

3.1. Backup concept_relationship_manual table and concept_manual table.

3.2. Create meddra_mapped table and pre-populate it with the resulting manual table of the previous MedDRA refresh.

3.3. Select concepts to map (flag shows different reasons for mapping refresh) and add them to the manual file in the spreadsheet editor.

3.4. Select COVID concepts lacking hierarchy and add them to the manual file in the spreadsheet editor (these concepts need 'Is a' relationships)

3.5. Review the previous mapping and map new concepts. If previous mapping can be improved, just change mapping of the respective row. To deprecate a previous mapping without a replacement, just delete a row.

3.6. Truncate the meddra_mapped table. Save the spreadsheet as the meddra_mapped table and upload it into the working schema.

3.7. Perform any mapping checks you have set.

3.5. Iteratively repeat steps 3.5-3.7 if found any issues.

3.6. Deprecate all mappings that differ from the new version of resulting mapping file.

3.7. Insert new and corrected mappings into the concept_relationship_manual table.