Update of CIViC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory CGI.

1. Run create_source_tables.sql
2. Get the latest CIViC source tsv-file (https://civicdb.org/downloads/01-Oct-2022/01-Oct-2022-GeneSummaries.tsv)
3. Run in devv5 (with fresh vocabulary date and version)
4. Run load_stage.sql
5. Run generic_update: devv5.GenericUpdate();