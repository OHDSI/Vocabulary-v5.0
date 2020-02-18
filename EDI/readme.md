Update of EDI

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory EDI.

1. Run create_source_tables.sql
2. Get the latest EdiData_UTF8.csv
5. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('EDI',TO_DATE('20191001','YYYYMMDD'),'EDI 2019.10.01');
6. Run load_stage.sql
7. Run generic_update: devv5.GenericUpdate();