Update of CIM10

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- ICD10, SNOMED must be loaded first
- Working directory CIM10
- Manual tables must be filled (e.g. for translations)

Manual tables are available here: https://drive.google.com/file/d/1fCgq9NBf3nvUGYldwDzY44LTdFQaggmZ/view?usp=sharing

1. Go to _____________________ and download latest CIM-10 version
2. Unzip the file ____________ and rename to cim10.csv
3. (Run create_source_tables.sql)
4. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('ICD10GM',TO_DATE('20200101','YYYYMMDD'),'2020 Release');
5. Add English translations to concept_manual
6. Edit concept_relationship_manual according to new concepts in CIM10, or changes in SNOMED and then add these in the folder 'manual_work'
7. Run load_stage.sql
8. Run generic_update: devv5.GenericUpdate();
