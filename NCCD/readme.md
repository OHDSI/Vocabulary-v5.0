### NCCD upload / update ###

#### Prerequisites ####

* Schema DevV5 with copies of tables concept, concept_relationship, and concept_synonym from ProdV5, fully indexed. 
* Working directory - dev_nccd

#### Sequence of actions ####

* Run fast_recreate: select devv5.FastRecreateSchema();
* Download the source_file from https://drive.google.com/file/d/1CSUC7xgdTxso8Hp_5k6EnW6IvWepijua/view?usp=sharing
* Run create_source_tables.sql
* Extract the nccd_full_done.csv file into the nccd_full_done table
* Run load_stage.sql
* Run QA scripts:
  * https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/input_QA_integratable_E.sql
  * https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/input_QA_integratable_W.sql
* If there are NO crucial errors, run Build_RxE.sql
* Do manual_work
* Run post_processing.sql
* Run generic_update: select devv5.genericupdate();

**csv format:**
* delimiter: ','
* encoding: 'UTF8'
* header: ON
* decimal symbol: '.'
* quote escape: NONE
* quote always: TRUE
* NULL string: empty


