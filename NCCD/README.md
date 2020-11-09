### NCCD upload / update ###

#### Prerequisites ####

* Schema DevV5 with copies of tables concept, concept_relationship, and concept_synonym from ProdV5, fully indexed. 
* Working directory - dev_nccd

#### Sequence of actions ####

* Download the source_file
* Run manual_changes.sql if you do not have the NCCD vocabulary in your Vocabulary version
* Run create_source_tables.sql
* Run create_input_tables.sql
* Run QA scripts:
  * https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/drug_stage_tables_QA.sql
  * https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/Drug_stage_QA_optional.sql
  * https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/input_QA_integratable_E.sql
  * https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/input_QA_integratable_W.sql
* If there are NO crucial errors, run Build_RxE.sql
* Perfom manual mapping if necessary and run manual_table.sql
* Run finilize_load_stage.sql
* Run generic_update: select devv5.genericupdate();
