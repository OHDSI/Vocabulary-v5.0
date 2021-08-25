Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_ancestor from ProdV5, fully indexed. Table with valid combination list in sources schema. Source files for SNOMED Vocabulary in sources schema.

1. Supply CSV sources including manual mappings for topography & histologies. File names coincide with table names.
1. Run load_stage.sql
2. Run generic_update: devv5.GenericUpdate()

CSV sources are available from Google Drive:
https://drive.google.com/drive/u/2/folders/1A9PmC9T_d8zPn51RQu5Wg7zXyVRuuWN6