### NCCD upload / update ###

#### Prerequisites ####

* Schema DevV5 with copies of tables concept, concept_relationship, and concept_synonym from ProdV5, fully indexed. 
* Working directory - dev_nccd

#### Sequence of actions ####

* Download the source_file
* Run manual_changes.sql if you do not have the NCCD vocabulary in your Vocabulary version
* Run create_source_tables.sql
* Run load_stage.sql
* Run generic_update: select devv5.genericupdate();
