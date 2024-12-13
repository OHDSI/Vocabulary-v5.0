### Metadata for Concepts and Concept Relationships

Metadata for concepts and concept relationships are stored in separate concept_metadata and concept_relationship_metadata tables in the Devv5 schema.

Currently, the metadata is represented by the following fields:
concept_metadata
- concept_category
- reuse_status

concept_relationship_metadata
- relationship_predicate_id
- relationship_group
- mapping_source
- confidence
- mapping_tool
- mapper
- reviewer

For the concept_metadata and concept_relationship_metadata tables in devv5 schema, foreign keys are defined that refer to the corresponding records in the concept and concept_relationship tables.

Scripts for creating these tables are located in the file:
[DevV5_Metadata_DDL
](https://github.com/OHDSI/Vocabulary-v5.0/blob/reuse_metadata/working/DevV5_Metadata_DDL.sql)

In the vocabulary developing process, the metadata tables are filled in a local development schema.
Then, after the concepts and concept relations from the local development schema are moved to the Devv5 schema using the GenericUpdate() function, the metadata from the local schema is transferred to the metadata tables of the devv5 schema using the following script:
[move_to_devv5.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/reuse_metadata/working/metadata/move_to_devv5.sql)

The logic of the scripts for transferring metadata is as follows:
- If the devv5.concept_metadata table already contains a record with the key (concept_id) from a dev schema, then the metadata is updated, otherwise a new record is inserted.
- If the devv5.concept_relationship_metadata table already contains a record with the key (concept_id_1, concept_id_2, relationship_id) from a dev schema, then the metadata is updated, otherwise a new record is inserted.

All changes to the concept_metadata and concept_relationship_metadata tables in the devv5 schema are logged using the standard audit mechanism.
