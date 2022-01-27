Update of MedDRA

Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
SNOMED must be loaded first
Working directory MedDRA.
Run create_source_tables.sql
Download the current Meddra from https://www.meddra.org/software-packages (english) and "SNOMED CT – MedDRA Mapping Release Package"
From MedDRA_xy_z_English.zip extract files from the folder "MedAscii": hlgt_hlt.asc hlt.asc hlt_pt.asc hlgt.asc llt.asc mdhier.asc pt.asc soc.asc soc_hlgt.asc
From "SNOMED CT - MedDRA Mapping Release Package DD MONTH YYYY.zip" extract *.xlsx file and rename to meddra_mappings.xlsx

Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('MedDRA',TO_DATE('20160901','YYYYMMDD'),'MedDRA version 19.1');
Run load_stage.sql
Run generic_update: devv5.GenericUpdate();