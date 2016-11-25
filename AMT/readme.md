AMT readme
upload / update of amt

Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_amt.

1.Run create_source_tables.sql
2.Download the latest file from https://www.digitalhealth.gov.au/implementation-resources/ehealth-foundations/clinical-terminology (file name Clinical Terminology vYYYYMMDD.zip ).
Login and password are required.

3.Exctract 
sct2_Description_Full-en-AU_AU1000036_YYYYMMDD.txt
sct2_Relationship_Full_AU1000036_YYYYMMDD.txt
sct2_Concept_Full_AU1000036_YYYYMMDD.txt
der2_Refset_ContaineredTradeProductPackFull_AU1000036_YYYYMMDD.txt
der2_Refset_MedicinalProductUnitOfUseFull_AU1000036_YYYYMMDD.txt
der2_Refset_TradeProductUnitOfUseFull_AU1000036_YYYYMMDD.txt
der2_Refset_TradeProductPackFull_AU1000036_YYYYMMDD.txt
der2_Refset_TradeProductFull_AU1000036_YYYYMMDD.txt
der2_Refset_MedicinalProductPackFull_AU1000036_YYYYMMDD.txt
der2_Refset_MedicinalProductFull_AU1000036_YYYYMMDD.txt
der2_ccsRefset_StrengthFull_AU1000036_YYYYMMDD.txt
der2_ccsRefset_UnitOfUseSizeFull_AU1000036_YYYYMMDD.txt
der2_ccsRefset_UnitOfUseQuantityFull_AU1000036_YYYYMMDD.txt
der2_cciRefset_SubpackQuantityFull_AU1000036_YYYYMMDD.txt

4.Open the files and resave them with .csv file extension, delete numbers from the name of the file

Load them into the following tables:
sct2_Description_Full-en-AU_AU.csv - FULL_DESCR_DRUG_ONLY
sct2_Relationship_Full_AU.csv - rf2_full_relationships
sct2_Concept_Full_AU.csv - SCT2_CONCEPT_FULL_AU
der2_Refset_ContaineredTradeProductPackFull_AU.csv - rf2_ss_refset
der2_Refset_MedicinalProductUnitOfUseFull_AU.csv - rf2_ss_refset
der2_Refset_TradeProductUnitOfUseFull_AU.csv - rf2_ss_refset
der2_Refset_TradeProductPackFull_AU.csv - rf2_ss_refset
der2_Refset_TradeProductFull_AU.csv - rf2_ss_refset
der2_Refset_MedicinalProductPackFull_AU.csv - rf2_ss_refset
der2_Refset_MedicinalProductFull_AU.csv - rf2_ss_refset
der2_ccsRefset_StrengthFull_AU.csv - rf2_ss_strength_refset
der2_ccsRefset_UnitOfUseSizeFull_AU.csv - rf2_ss_unit_of_use_size_refset
der2_ccsRefset_UnitOfUseQuantityFull_AU.csv - rf2_ss_unit_of_use_qr
der2_cciRefset_SubpackQuantityFull_AU.csv - rf2_ss_subpack_quantity_refset


5.Use the control files of the same name consequentially.

6.Run concat.bat
7.Run load_stage.sql
8.Run generic_update.sql (from working directory);
