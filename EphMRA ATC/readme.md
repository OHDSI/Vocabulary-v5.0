Update of EphMRA ATC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory EphMRA ATC.

1. Run create_source_tables.sql
2. Unpack "ATC_Glossary.zip"
3. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('EphMRA ATC',TO_DATE('20160704','YYYYMMDD'),'EphMRA ATC 2016');
4. Run load_stage.sql
5. Run generic_update.sql (from working directory)