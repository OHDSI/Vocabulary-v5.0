LPD_Belgium readme upload / update of LPD_Belgium

Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_belg.

You need to have the access to source files (IQVIA proprietary).

1. Create empty input tables and load all source tables and mappings

2. Run init_full.sql. It will prepare input tables.

3. Run Build_RxE and MapDrugVocab from /working

4. Run to_concept_map.sql. It creates table s_to_c_map with applied mappings from source_data to concept.

5. Run drops.sql to clean up the working directory