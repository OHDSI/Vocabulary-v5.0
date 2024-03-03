### STEP 7 of the refresh: updating concept_relationship_manual

7.1. Run [mapping_refresh.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10gm-documentation/ICD10GM/manual_work/mapping_refresh.sql). Table icd10gm_refresh will be created. It contains the list with potential replacement mappings and codes without mappings.
7.2. Run the ICD_CDE_source.sql to integrate data into the ICD common data environment.
7.3. Perform manual review and mapping. Note, that it is forbidden to delete rows from the manual file. 
7.4. Perform manual mapping checks.
7.5. If everything is OK, deprecate old mappings for the ICD10 codes of interest and add fresh mappings to the concept_relationship_manual using crm_changes.sql 