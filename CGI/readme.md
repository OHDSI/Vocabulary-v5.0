Update of CGI

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory CGI.

1. Run create_source_tables.sql
2. Get the latest CGI source zip-file (https://www.cancergenomeinterpreter.org/2018/data/catalog_of_validated_oncogenic_mutations_latest.zip?ts=20180216)
3. Upload concept_manual.csv from  https://docs.google.com/spreadsheets/d/1YLTJPQQpg6nzAFE_VjP1iN1LIdj66lI1RLnM1kpp0_A/edit#gid=0
4. Run load_stage.sql
5. Run generic_update: devv5.GenericUpdate();
-+
