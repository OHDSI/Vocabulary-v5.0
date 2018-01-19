DPD readme upload / update of DPD

Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_dpd.

1.Download the latest file from http://www.hc-sc.gc.ca/dhp-mps/prodpharma/databasdon/dpd_bdpp_data_extract-eng.php (file names: allfiles.zip,allfiles_ia.zip,allfiles_ap.zip).

2.Exctract the files, open them and resave them as text (tab delemited).

3.Run create_source_tables.sql

4.Load the files into the tables using the control files of the same name consequentially.

5.Load manual tables using the control files of the same name consequentially.

6.Run load_stage.sql 

7.Run Build_RxE.sql and generic_update.sql (from working directory);

8.Run drops.sql to remove all the temporary tables