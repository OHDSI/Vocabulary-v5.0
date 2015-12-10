Update of GCN_SEQNO

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- RxNorm must be loaded first.
- Working directory GCN_SEQNO.

1. Run create_source_tables.sql
2. Load NDDF_PRODUCT_INFO.TXT into NDDF_PRODUCT_INFO using control file of the same name
3. Run load_stage.sql
4. Run generic_update.sql (from working directory)
 