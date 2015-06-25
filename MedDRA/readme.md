Update of MedDRA

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- SNOMED must be loaded first
- Working directory MedDRA.

1. Run create_source_tables.sql
2. Download the current Meddra from https://www.meddra.org/user?destination=downloads (english)
3. Extract and load into the tables from the folder "MedAscii". Use the control files of the same name
hlgt_hlt.asc
hlt.asc
hlt_pt.asc
intl_ord.asc
llt.asc
mdhier.asc
pt.asc
soc.asc
soc_hlgt.asc

4. Run load_stage.sql
5. Run generic_update.sql (from working directory)

 