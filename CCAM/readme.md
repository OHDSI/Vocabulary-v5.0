Update of CCAM

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory CCAM.

1. Run create_source_tables.sql
2. Go to https://www.ameli.fr/accueil-de-la-ccam/telechargement/index.php and download "Fichier dbf complet": CCAM DBF PART01 and CCAM DBF PART03
3. Unzip files: R_ACTE.dbf, R_MENU.dbf, R_ACTE_IVITE.dbf, R_REGROUPEMENT.dbf
4. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('CCAM',TO_DATE('20200701','YYYYMMDD'),'64');
5. Run load_stage.sql
6. Run generic_update: devv5.GenericUpdate();