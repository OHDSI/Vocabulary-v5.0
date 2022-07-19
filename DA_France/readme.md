Theis version of load_stage is different from those stored in archive. It should be used for refresh purposes only as the archived scripts and DDLs are failed to be replicable.

The current (July 2022) state of concept naming is based on predominant patterns detected in in released versions.

Da_France upload / update

Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_da_france_2
1. Download source files
2. Run create_source_tables.sql ( be careful with population of fields in FRANCE table, as UPDATE statements are Prerequisites for adequate Working)
3. Download tables of manual work (https://drive.google.com/drive/folders/1nWSomSS_Z8FWJasMggPCc9bhMk8dxdrw)
3. Run load_stage.sql
