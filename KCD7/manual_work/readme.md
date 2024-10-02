### STEP 5 of the refresh: updating concept_relationship_manual

5.1. Run [mapping_refresh.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10gm-documentation/ICD10GM/manual_work/mapping_refresh.sql). Table kcd7_refresh will be created. It contains the list with potential replacement mappings and codes without mappings.
5.2. Run the ICD_CDE_source.sql to integrate data into the ICD common data environment.
5.3. Perform manual review and mapping. Note, that it is forbidden to delete rows from the manual file. 
5.4. Perform manual mapping checks.
5.5. If everything is OK, deprecate old mappings for the ICD10 codes of interest and add fresh mappings to the concept_relationship_manual using crm_changes.sql 