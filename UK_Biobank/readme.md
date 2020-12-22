Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_uk_biobank.

To upload source data use the following instructions:

1) Run create_source_tables.sql in your schema

2) Download the latest available files from https://biobank.ctsu.ox.ac.uk/showcase/schema.cgi for Main dataset and https://biobank.ctsu.ox.ac.uk/showcase/refer.cgi?id=141140 for HES dataset

3) Run inserts into concept_relationship_manual table (/manual work/inserts_into_crm.sql)

4) Run load_stage.sql

5) Run GenericUpdate: devv5.GenericUpdate(). (/working/packages/generic_update.sql)