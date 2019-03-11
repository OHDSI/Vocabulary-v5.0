AMT readme
upload / update of amt

Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_amt.

1. Run create_source_tables.sql and additional_ddl.sql
2. Download the latest file from https://www.digitalhealth.gov.au/implementation-resources/ehealth-foundations/clinical-terminology (file name EP_xxxx_YYYY_ClinicalTerminology_vYYYYMMDD.zip ).
Login and password are required.

3. Unzip DH_xxxx_YYYY_AustralianMedicinesTerminology_DataExtract_vYYYYMMDD.zip
4. Extract
from AMT_Release_AU1000168_YYYYMMDD\RF2Release\Full\Terminology\
sct2_Description_Full-en-AU_AU1000168_YYYYMMDD.txt
sct2_Relationship_Full_AU1000168_YYYYMMDD.txt
sct2_Concept_Full_AU1000168_YYYYMMDD.txt

from AMT_Release_AU1000168_YYYYMMDD\RF2Release\Full\Refset\Content\
der2_ccsRefset_StrengthFull_AU1000168_YYYYMMDD.txt

5. Unzip DH_xxx_YYYY_SNOMEDCT-AU_CombinedReleaseFile_vYYYYMMDD.zip
6. Exctact
from SnomedCT_Release_AU1000036_20161130\RF2Release\Full\Terminology\
sct2_Relationship_Full_AU1000036_20161130.txt and rename to sct2_Relationship_Full_AU36.txt

7. Delete numbers from the name of the file (1000168_YYYYMMDD)
8. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('AMT',TO_DATE('20161130','YYYYMMDD'),'Clinical Terminology v20161130');
9. Run concat.bat or concat.sh depending on your OS
10. Run load_stage.sql
11. Run generic_update: devv5.GenericUpdate();
12. Create backup of input tables as table_name_bckp_ddmmyyyy
