Update of GPI

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- RxNorm must be loaded first.
- Working directory GPI.

1. Run create_source_tables.sql
2. Load gpi_name.ctl using SQL Loader
3. Unzip ndw_v_product.zip and load ndw_v_product.txt using SQL Loader
4. Run load_stage.sql
5. Run generic_update.sql (from working directory)