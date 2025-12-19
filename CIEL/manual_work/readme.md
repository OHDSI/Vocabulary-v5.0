### Manual content processing

Before running the CIEL load pipeline (`load_stage.sql`), you must refresh the manual mapping layer. Otherwise, the load may ignore new or corrected mappings and continue to rely on outdated relationships.
This refresh is driven by the table `concept_relationship_manual_updated` and the scripts `crm_qa.sql` and `crm_changes.sql`.

1. Prepare concept_relationship_manual_updated
- Make sure the table concept_relationship_manual_updated exists.
- Its structure must be identical to concept_relationship_manual (you can reuse the same DDL).
- Load the updated set of manual mappings into concept_relationship_manual_updated from the CSV export: [link](https://drive.google.com/file/d/1ESQg9iDcCVDOYsYC1KYRamQwDWL7Jny4/view?usp=drive_link)
- Load it via COPY, bulk import, or your preferred ETL mechanism.
At this point, concept_relationship_manual_updated should contain the complete, current manual mapping set you want to use (not just deltas).
2. Run QA on the updated manual mappings
- Execute `crm_qa.sql`
- Review and resolve all issues flagged by crm_qa.sql (e.g., non-standard targets, duplicates, invalid vocabularies, invalid relationship_ids, etc.) before proceeding.
3. Ensure that maps_for_load_stage.sql has already been executed.
4. Apply changes to concept_relationship_manual
- Once QA is clean, apply the changes `crm_changes.sql`
- crm_changes.sql performs three key operations:
  - Remove old manual mappings that are now handled automatically. To avoid double-counting and conflicts, the script removes any CIEL mappings from concept_relationship_manual that have been fully processed and promoted as rank 1–2 mappings in `maps_for_load_stage`.
  - Deprecate manual mappings that are no longer present in the updated file. For rows that exist in concept_relationship_manual but do not exist in concept_relationship_manual_updated, the script sets invalid_reason = 'D', and closes valid_end_date to the current CIEL snapshot date.
  - Insert new manual mappings from the updated file. For rows that exist in concept_relationship_manual_updated but do not exist in concept_relationship_manual, the script inserts them into concept_relationship_manual with valid_start_date = current CIEL snapshot date, valid_end_date = 2099-12-31, invalid_reason = NULL.
 
After these steps, `concept_relationship_manual` becomes the canonical manual mapping source that will be respected during `load_stage.sql` execution.
