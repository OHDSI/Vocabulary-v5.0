Update of ICD10GM

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- ICD10, SNOMED must be loaded first
- Working directory ICD10GM
- Manual tables must be filled (e.g. for translations)

1. Go to https://www.dimdi.de/dynamic/de/klassifikationen/downloads/ and download latest ICD-10-GM version
2. Unzip the file \Klassifikationsdateien\icd10gmYYYYsyst_kodes.txt and rename to icd10gm.csv
3. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('ICD10GM',TO_DATE('20200101','YYYYMMDD'),'2020 Release');
4. Run load_stage.sql
5. Run generic_update: devv5.GenericUpdate();