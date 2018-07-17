DA_Australia readme upload / update of amt

Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_aus.

1. Run create_source_tables.sql and additional_ddl.sql
2. Download and extract files from \\kha-file01\Odysseus\DA_AUstralia
3. Run in devv5: SELECT sources.load_input_tables('Da_AUstralia'); (some data in drug_mapping_3 and fo_product_3 are bad - need to delete extra columns, 3 and 1 respectively in some rows)
4. Run load_stage.sql
5. Run generic_update.sql (from working directory)

