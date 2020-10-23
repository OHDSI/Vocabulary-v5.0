Update of CIEL

Annotation:
We got vocabulary from mysql dumpfile and converted it to csv files
https://drive.google.com/drive/folders/15omdYTgmftnUm0TA3D498yE8aSWw-SG3?usp=sharing

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- RxNorm, ICD10, NDFRT, UCUM, LOINC and SNOMED must be loaded first.
- Working directory CIEL.

1. Run create_source_tables.sql
2. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('CIEL',TO_DATE('20150227','YYYYMMDD'),'Openmrs 1.11.0 20150227');
3. Run load_stage.sql
4. Run generic_update: devv5.GenericUpdate();