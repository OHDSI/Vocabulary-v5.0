Update of ICD10GM

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- ICD10, SNOMED must be loaded first
- Working directory ICD10GM
- Manual tables must be filled (e.g. for translations)

Manual tables are available here: https://drive.google.com/file/d/1ZjYCykojpUyxljZ4v1Qs3Yz72TiXWvKC/view?usp=sharing

1. Go to https://www.dimdi.de/dynamic/de/klassifikationen/downloads/ and download latest ICD-10-GM version
2. Unzip the file \Klassifikationsdateien\icd10gmYYYYsyst_kodes.txt and rename to icd10gm.csv
3. Run create_source_tables.sql
4. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('ICD10GM',TO_DATE('20200101','YYYYMMDD'),'2020 Release');
5. Run manual_work/pre_load_stage.sql in dev_icd10gm schema
6. Add English translations to concept_manual
7. Edit concept_relationship_manual according to new concepts in ICD10GM, or changes in SNOMED and then add these in the folder 'manual_work'
8. Run load_stage.sql
9. Run generic_update: devv5.GenericUpdate();
