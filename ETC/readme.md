Update of ETC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- GCN_SEQNO must be loaded first.
- Working directory ETC.

1. Run create_source_tables.sql
2. Unpack "ETC sources.zip"
3. Load all TXT files using control files of the same name
4. Run load_stage.sql
5. Run generic_update.sql (from working directory)