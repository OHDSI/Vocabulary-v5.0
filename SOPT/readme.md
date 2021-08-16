Update of SOPT

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory SOPT.

1. Run create_source_tables.sql
2. Download the Source of Payment Typology file SourceofPaymentTypologyVersionxxx.pdf from https://www.nahdo.org/sopt
3. Convert PDF to csv with delimiter ';' (UTF), save as sopt_source.csv 
The processed csv file can be found here: https://drive.google.com/file/d/1gS4sFLDgMlOZpAZC8w8c4US-anwwJCKp/view?usp=sharing
4. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('SOPT',TO_DATE('20201211','YYYYMMDD'),'SOPT Version 9.2');
5. Run load_stage.sql
6. Run generic_update: devv5.GenericUpdate();