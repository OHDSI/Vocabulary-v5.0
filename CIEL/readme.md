Update of CIEL

Annotation:
We got vocabulary from mysql dumpfile. But this dumpfile cannot be directly imported to Oracle, we used local MySQL DB
to convert dump to csv files and manually transform them into SQL Loader file.

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- RxNorm and SNOMED must be loaded first.
- Working directory CIEL.

1. Run create_source_tables.sql
2. Unzip CIEL_CTL.zip
3. Load *.ctl using SQL Loader
4. Run load_stage.sql
5. Run generic_update.sql (from working directory)

 