Update of DRG

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Working directory DRG.

1. Run create_source_tables.sql
2. Download "Files for FY" (Table 5 only) from http://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Acute-Inpatient-Files-for-Download.html
2011: http://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY_2011_FR_Table_5.zip
2012: http://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY_12_NPRM_Table_5.zip
2013: http://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY_13_FR_Table_5.zip
2014: http://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY_14_FR_Table_5.zip
2015: http://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY2015-NPRM-Table-5.zip

3. Extract *.txt files from archives
4. Rename them to FY2011.txt, FY2012.txt ... FY2015.txt and sequentially load using control files of the same names
5. Run load_stage.sql
6. generic_update NOT needed

 