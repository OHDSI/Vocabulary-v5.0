BDPM readme upload / update 


Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_bdpm.

1.Run create_source_tables.sql 
2 download files from BDPM\data\data_2017
3.Load files:
CIS_bdpm.txt > table DRUG
CIS_CIP_bdpm.txt > table PACKAGING
CIS_COMPO_bdpm.txt > table INGREDIENT
CIS_GENER_bdpm.txt > table GENERIC

4 Run whole_script.sql
