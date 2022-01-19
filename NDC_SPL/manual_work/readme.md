### STEP 9 of the refresh:

#### csv format:
- delimiter: ','
- encoding: 'UTF8'
- header: ON
- decimal symbol: '.'
- quote escape: with backslash \
- quote always: FALSE
- NULL string: empty


9.3Work with [NDC_SPL_refresh] file:

9.3.1. Backup concept_relationship_manual table.

9.3.2. Create NDC_manual_mapped table and pre-populate it with the resulting manual table of the previous refresh.

9.3.3. Select concepts to map and add them to the manual file in the spreadsheet editor.

9.3.4. Review the previous mapping and map new concepts. If previous mapping can be improved, just change mapping of the respective row. To deprecate a previous mapping without a replacement, just delete a row.

9.3.5. Truncate the NDC_manual_mapped table. Save the spreadsheet as the NDC_manual_mapped table and upload it into the working schema.

9.3.6. Perform any mapping checks you have set.

9.3.7. Deprecate all mappings that differ from the new version of resulting mapping file.

9.3.8. Insert new and corrected mappings into the concept_relationship_manual table.