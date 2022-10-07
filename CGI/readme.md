Update of CGI

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory CGI.

1. Run create_source_tables.sql
2. Get the latest CGI source zip-file (https://www.cancergenomeinterpreter.org/2018/data/catalog_of_validated_oncogenic_mutations_latest.zip?ts=20180216)
3. Run load_stage.sql
4. Run generic_update: devv5.GenericUpdate();
