### NCCD upload / update ###

#### Prerequisites ####

* Schema DevV5 with copies of tables concept, concept_relationship, and concept_synonym from ProdV5, fully indexed. 
* Working directory - dev_nccd

#### Sequence of actions ####

* Do manual_work
* Run load_stage.sql
* Run create_input_tables.sql
* Run QA scripts:
  * https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/drug_stage_tables_QA.sql
  * https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/Drug_stage_QA_optional.sql
  * https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/input_QA_integratable_E.sql
  * https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/input_QA_integratable_W.sql
* If there are NO crucial errors, run Build_RxE.sql
* Run generic_update: select devv5.genericupdate();
