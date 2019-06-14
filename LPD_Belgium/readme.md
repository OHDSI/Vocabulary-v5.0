LPD_Belgium readme upload / update of LPD_Belgium

Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_belg.

You need to have the access to source files (IQVIA proprietary).

All required current manual tables can be found in manual_work subdirectory.

1. Run additional_DDL.sql
2. Load source table in belg_source. Optionally also upload r_to_c_all table to reuse legacy mappings
3. Run init_full.sql. It will prepare manual mapping table (relationship_to_concept_to_map)
* Avoid mapping to Brand Names that are not found in brand_rx table. Those will be marked with '!' in invalid_indicator field
* Brand names can also be mapped to Ingredients or targets from CVX vocabulary
4. Reupload filled out mappings as relationship_to_concept_manual
5. Run after_mm.sql to prepare input tables
6. Run Build_RxE.sql (without last section with drops) and MapDrugVocab.sql from /working/directory
7. Run pp.sql.
8. Run genericupdate.sql from /working/directory
9. Run drops.sql to clean up the working directory