1. Run attr_tables.sql to get list of unique ICD10PCS attributes and map them to SNOMED in attr_from_usagi table
2. Run pool_generation.sql to create intermediate table to find SNOMED ancestors
3. Run crs_insert to implement new relationships to SNOMED concepts. WARNING: current version overwrites CONCEPT_RELATIONSHIP_STAGE and CONCEPT_RELATIONSHIP_MANUAL tables
