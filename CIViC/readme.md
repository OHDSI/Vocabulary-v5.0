Update of CIViC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory CGI.

1. Run create_source_tables.sql
2. Get the latest CIViC source tsv-file from https://civicdb.org/releases/main (only GeneSummaries.tsv) and rename to variantsummaries.tsv
3. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('CIVIC',TO_DATE('20221001','YYYYMMDD'),'CIViC 2022-10-01');
4. Run load_stage.sql
5. Run generic_update: devv5.GenericUpdate();