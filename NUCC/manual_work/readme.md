### STEP 5 of the refresh:

5.1. During FastRecreate run concept_manual and concept_relationship_manual are synchronized, respectively, with base_concept_manual and base_concept_relationship_manual tables stored in devv5. 

5.2. Work with nucc_refresh.sql:

5.2.1. Create nucc_mapped table and pre-populate it with the resulting manual table of the previous CPT4 refresh.

5.2.2. Review the previous mapping and map new concepts. Use _cr_invalid_reason_ field to deprecate mappings.

5.2.3. Select concepts to map and add them to the manual file in the spreadsheet editor.

5.2.4. Truncate the nucc_mapped table. Save the spreadsheet as the nucc_mapped table and upload it into the working schema.

5.2.5. Perform any mapping checks you have set.

5.2.6. Iteratively repeat steps 5.2.3-5.2.6 if found any issues.

5.2.7. Insert new and corrected mappings into the concept_relationship_manual table.

5.2.8. Create concept_mapped table and populate it with concepts that require manual changes.

5.2.9.  Truncate concept_mapped table. Save the spreadsheet as 'concept_mapped table' and upload it to the schema.

5.2.10.  Change concept_manual table according to concept_mapped table.