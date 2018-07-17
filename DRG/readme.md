Update of DRG

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Working directory DRG.

1. Run create_source_tables.sql
2. Download "Files for FY" (Table 5 only) from http://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Acute-Inpatient-Files-for-Download.html
Examples:
2011: http://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY_2011_FR_Table_5.zip
2012: http://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY_12_NPRM_Table_5.zip
2013: http://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY_13_FR_Table_5.zip
2014: http://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY_14_FR_Table_5.zip
2015: http://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY2015-NPRM-Table-5.zip

3. Extract *.txt file from the archive
4. Run in console (sed for removing first 2 lines and head for removing last two lines):
sed '1,2d' *Table_5.txt | head -n-2 > FY.txt

5. Run in devv5 (with fresh vocabulary date): SELECT sources.load_input_tables('DRG',TO_DATE('20150417','YYYYMMDD'));
6. Run load_stage.sql
7. generic_update NOT needed

 