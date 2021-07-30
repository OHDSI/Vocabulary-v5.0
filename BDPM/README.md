BDPM readme upload / update 


Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_bdpm.

1. Run create_source_tables.sql and additional_DDL.sql
2. Download files 
-CIS_bdpm.txt
-CIS_CIP_bdpm.txt
-CIS_COMPO_bdpm.txt
-CIS_GENER_bdpm.txt
from: https://base-donnees-publique.medicaments.gouv.fr/telechargement.php
3. Run in devv5: SELECT sources.load_input_tables('BDPM',TO_DATE('20180622','YYYYMMDD'));
4. Run load_stage.sql
