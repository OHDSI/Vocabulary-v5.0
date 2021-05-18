Update of CIEL

CIEL vocabulary source files can be requested from Andrew Kanter (IMO). The files had to be post-processed for a couple of small formatting issues (e.g. extra TAB charac ters)
The processed csv files can be found here:
https://drive.google.com/drive/folders/15omdYTgmftnUm0TA3D498yE8aSWw-SG3?usp=sharing

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- RxNorm, ICD10 (WHO), NDFRT, UCUM, LOINC and SNOMED must be loaded first.
- Working directory CIEL.

1. Run create_source_tables.sql
2. Import source files into source tables
   (in DevV5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('CIEL',TO_DATE('20150227','YYYYMMDD'),'Openmrs 1.11.0 20150227');
3. Run load_stage.sql
4. Run generic_update: devv5.GenericUpdate();
