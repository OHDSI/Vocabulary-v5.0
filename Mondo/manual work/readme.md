# MONDO Mapping Curation 
These scripts build and review heuristic MONDO-to-OMOP mapping candidates. They are development and curator-review tooling, not the core OHDSI Vocabulary release load.

## Process

1. `create_mapping_pipeline.sql` recreates `dev_mondo.mondo_cde`, collects candidate mappings from MONDO SSSOM/UMLS bridges and HECATE output (if executed), scores them, and creates `dev_mondo.mondo_to_omop_mapped`.
2. `manual_mappings_incorporation.sql` defines mappings that are assumed pragmatical/valid to be introduced to concept_relationship_manual. At thise step please make sure that any previously generated mappings  should be explicitly deprecated at the time of refresh (if needed).

## Reference
Manual tables location: https://drive.google.com/drive/folders/1RQfXj2u8YNnO6VBGR-PvNBnUQo7EUX07?usp=drive_link