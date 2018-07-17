LPD_Belgium readme upload / update of LPD_Belgium

Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_belg.

You need to have the access to source files (IQVIA proprietary).

All required current manual tables can be found in manual_work subdirectory.

1. Run create_source_tables.sql and additional_DDL.sql
2. Load all source tables and mappings
3. Run init_full.sql. It will prepare input tables.
4. Run Build_RxE and MapDrugVocab from /working
5. Run to_concept_map.sql. It creates table s_to_c_map with applied mappings from source_data to concept.
6. Run drops.sql to clean up the working directory