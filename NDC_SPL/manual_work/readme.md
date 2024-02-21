### STEP 9 of the refresh:

#### csv format:
- delimiter: ','
- encoding: 'UTF8'
- header: ON
- decimal symbol: '.'
- quote escape: with backslash \
- quote always: FALSE
- NULL string: empty

9.1 Work with [NDC_SPL_refresh] file:

9.1.1. Create NDC_manual_mapped table and pre-populate it with the resulting manual table of the previous refresh.

9.1.2. Select concepts to map and add them to the manual file in the spreadsheet editor.

9.1.3. Review the previous mapping and map new concepts. If previous mapping can be improved, just change mapping of the respective row. To deprecate a previous mapping without a replacement, just delete a row.

9.1.4. Truncate the NDC_manual_mapped table. Save the spreadsheet as the NDC_manual_mapped table and upload it into the working schema.

9.1.5. Perform any mapping checks you have set.

9.1.6. Deprecate all mappings that differ from the new version of resulting mapping file.

9.1.7. Insert new and corrected mappings into the concept_relationship_manual table.