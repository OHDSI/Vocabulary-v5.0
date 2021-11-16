LPD_Belgium readme upload / update of LPD_Belgium

Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_belg.

You need to have the access to source files (IQVIA proprietary).

All required current manual tables can be found in manual_work subdirectory.


1. Load source table in belg_source. Optionally also upload r_to_c_all table to reuse legacy mappings
2. Run ls_refactored.sql. It will prepare manual mapping table (relationship_to_concept_to_map)
* Avoid mapping to Brand Names that are not found in brand_rx table. Those will be marked with invalid_indicator field is not null
* Brand names can also be mapped to Ingredients or targets from CVX vocabulary
3. Reupload filled out mappings as relationship_to_concept_manual
4. Run mapping_input.sql to prepare input tables
5. Run Build_RxE.sql (without last section with drops) and MapDrugVocab.sql from /working/directory
6. Run pp.sql.
7. Run genericupdate.sql from /working/directory
