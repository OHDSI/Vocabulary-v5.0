## Update of OMOP Investigational Drugs

Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
Schema sources with sources.genomic_nci_thesaurus table 
Working directory dev_omopinv

1. Run create_source_tables.sql
2. Run load sources.load_input_tables
3. Run load_stage.sql
4. Run generic_update: devv5.GenericUpdate();