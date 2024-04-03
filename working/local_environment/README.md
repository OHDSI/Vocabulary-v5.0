Preparing a Local Environment for the Vocabulary Development Process

# Description

This document describes the local database preparation that needs to be done for the vocabulary development process

# Prerequisites

PostgreSQL 14 or higher.

# Creating Schemas
Create schemas:
>-- replace <dev_schema_name> with an actual schema name:
>CREATE SCHEMA <dev_schema_name>;
>CREATE SCHEMA devv5;
>CREATE SCHEMA sources;
>CREATE SCHEMA qa_tests;
>CREATE SCHEMA vocabulary_pack;
>CREATE SCHEMA admin_pack;

# Creating Functions

## devv5

- GenericUpdate_LE.sql
- FastRecreateSchema()  
    [Vocabulary-v5.0/working/fast_recreate_schema.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/fast_recreate_schema.sql)
- GetPrimaryRelationshipID() [Vocabulary-v5.0/working/packages/admin_pack/GetPrimaryRelationshipID.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/GetPrimaryRelationshipID.sql)
- Functions from  
    [Vocabulary-v5.0/working/packages/DevV5_additional_functions at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/tree/master/working/packages/DevV5_additional_functions)

## vocabulary_pack

- DropFKConstraints()  
    [Vocabulary-v5.0/working/packages/vocabulary_pack/DropFKConstraints.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/DropFKConstraints.sql)
- SetLatestUpdate()  
    [Vocabulary-v5.0/working/packages/vocabulary_pack/SetLatestUpdate.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/SetLatestUpdate.sql)
- ProcessManualSynonyms()  
    [Vocabulary-v5.0/working/packages/vocabulary_pack/ProcessManualSynonyms.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/ProcessManualSynonyms.sql)
- CheckManualSynonyms()  
    [Vocabulary-v5.0/working/packages/vocabulary_pack/CheckManualSynonyms.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/CheckManualSynonyms.sql)
- ProcessManualRelationships()  
    [Vocabulary-v5.0/working/packages/vocabulary_pack/ProcessManualRelationships.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/ProcessManualRelationships.sql)
- CheckReplacementMappings()  
    [Vocabulary-v5.0/working/packages/vocabulary_pack/CheckReplacementMappings.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/CheckReplacementMappings.sql)
- AddFreshMAPSTO()  
    [Vocabulary-v5.0/working/packages/vocabulary_pack/AddFreshMAPSTO.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/AddFreshMAPSTO.sql)
- GetActualConceptInfo() [Vocabulary-v5.0/working/packages/vocabulary_pack/GetActualConceptInfo.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/GetActualConceptInfo.sql)
- DeprecateWrongMapsTo() [Vocabulary-v5.0/working/packages/vocabulary_pack/DeprecateWrongMapsTo.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/DeprecateWrongMapsTo.sql)
- DeleteAmbiguousMapsTo()

[Vocabulary-v5.0/working/packages/vocabulary_pack/DeleteAmbiguousMapsTo.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/DeleteAmbiguousMapsTo.sql)

## qa_tests

- Functions from [Vocabulary-v5.0/working/packages/QA_TESTS at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/tree/master/working/packages/QA_TESTS)

## admin_pack

Create extensions:
>CREATE EXTENSION pgcrypto;  
>CREATE EXTENSION tablefunc;

- admin_pack_ddl.sql  
    [Vocabulary-v5.0/working/packages/admin_pack/admin_pack_ddl.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/admin_pack_ddl.sql)
- VirtualLogIn()  
    [Vocabulary-v5.0/working/packages/admin_pack/VirtualLogIn.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/VirtualLogIn.sql)
- CreateVirtualUser()  
    [Vocabulary-v5.0/working/packages/admin_pack/CreateVirtualUser.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/CreateVirtualUser.sql)
- CheckUserPrivilege()  
    [Vocabulary-v5.0/working/packages/admin_pack/CheckUserPrivilege.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/CheckUserPrivilege.sql)
- GetUserID()  
    [Vocabulary-v5.0/working/packages/admin_pack/GetUserID.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/GetUserID.sql)
- CheckEmailCharacters()  
    [Vocabulary-v5.0/working/packages/admin_pack/CheckEmailCharacters.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/CheckEmailCharacters.sql)
- CheckLoginCharacters()  
    [Vocabulary-v5.0/working/packages/admin_pack/CheckLoginCharacters.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/CheckLoginCharacters.sql)
- CheckPasswordStrength()  
    [Vocabulary-v5.0/working/packages/admin_pack/CheckPasswordStrength.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/CheckPasswordStrength.sql)
- CheckPrivilegeCharacters()  
    [Vocabulary-v5.0/working/packages/admin_pack/CheckPrivilegeCharacters.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/CheckPrivilegeCharacters.sql)
- CheckUserSpecificVocabulary()  
    [Vocabulary-v5.0/working/packages/admin_pack/CheckUserSpecificVocabulary.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/CheckUserSpecificVocabulary.sql)
- CreatePrivilege()  
    [Vocabulary-v5.0/working/packages/admin_pack/CreatePrivilege.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/CreatePrivilege.sql)

# Creating Tables

The next four columns are for internal use only, so they should be excluded from the DevV5_DDL script before execution (from **base_concept_relationship_manual**, **base_concept_manual**, **base_concept_synonym_manual** tables):
- created
- created_by
- modified
- modified_by

## Devv5

In case the table structure already exists in the database, this part can be skipped.

When tables are created for the first time, everything should be executed from the script except creating constraints and indexes so that they do not interfere with the import of vocabularies from Athena.

- DevV5_DDL.sql  
    [Vocabulary-v5.0/working/DevV5_DDL.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/DevV5_DDL.sql)  
    Or just run this script \[DevV5_tables_DDL.sql\] (<https://github.com/OHDSI/Vocabulary-v5.0/blob/master/local_environment/DevV5_tables_DDL.sql>)
- Prepare_manual_tables.sql [Vocabulary-v5.0/working/packages/admin_pack/prepare_manual_tables.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/prepare_manual_tables.sql)

## dev_schema_name

- DevV5_DDL.sql  
    [Vocabulary-v5.0/working/DevV5_DDL.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/DevV5_DDL.sql)
- Prepare_manual_tables.sql [Vocabulary-v5.0/working/packages/admin_pack/prepare_manual_tables.sql at master · OHDSI/Vocabulary-v5.0 (github.com)](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/prepare_manual_tables.sql)  

## Update Vocabulary table structure

If the table structure was created before 03/04/2024, the following script should be run:

- 2024-03-04.sql (working/manual_changes/2024/2024-03-04.sql)

## sources

Creating source tables according to instructions for your vocabulary.

# Import Vocabulary Data from Athena

To initially fill out the vocabulary tables, it needs to download the necessary vocabularies from [Athena (ohdsi.org)](https://athena.ohdsi.org/vocabulary/list) and import them using the “copy” command in psql.

Also there is the video instruction how to do it using DBeaver:

[Demo: Getting Vocabularies Into My OMOP CDM (Michael Kallfelz • Nov. 9 OHDSI Community Call) (youtube.com)](https://www.youtube.com/watch?v=FCHxAQOBptE)

The data should be imported to the tables in **devv5** schema.

Before importing dictionaries from CSV files, the client encoding should be set to “UTF8” (psql):
>SET client_encoding = ‘UTF8’;


The “COPY” command to import data from CSV files (psql):

>COPY DRUG_STRENGTH FROM '&lt;path_to_csv_file&gt;\\DRUG_STRENGTH.csv' WITH DELIMITER E'\\t' CSV HEADER QUOTE E'\\b';
>
>COPY CONCEPT FROM '&lt;path_to_csv_file&gt;\\CONCEPT.csv' WITH DELIMITER E'\\t' CSV HEADER QUOTE E'\\b';
>
>COPY CONCEPT_RELATIONSHIP FROM '&lt;path_to_csv_file&gt;\\CONCEPT_RELATIONSHIP.csv' WITH DELIMITER E'\\t' CSV HEADER QUOTE E'\\b';
>
>COPY CONCEPT_ANCESTOR FROM '&lt;path_to_csv_file&gt;\\CONCEPT_ANCESTOR.csv' WITH DELIMITER E'\\t' CSV HEADER QUOTE E'\\b';
>
>COPY CONCEPT_SYNONYM FROM '&lt;path_to_csv_file&gt;\\CONCEPT_SYNONYM.csv' WITH DELIMITER E'\\t' CSV HEADER QUOTE E'\\b';
>
>COPY VOCABULARY FROM '&lt;path_to_csv_file&gt;\\VOCABULARY.csv' WITH DELIMITER E'\\t' CSV HEADER QUOTE E'\\b';
>
>COPY RELATIONSHIP FROM '&lt;path_to_csv_file&gt;\\RELATIONSHIP.csv' WITH DELIMITER E'\\t' CSV HEADER QUOTE E'\\b';
>
>COPY CONCEPT_CLASS FROM '&lt;path_to_csv_file&gt;\\CONCEPT_CLASS.csv' WITH DELIMITER E'\\t' CSV HEADER QUOTE E'\\b';
>
>COPY DOMAIN FROM '&lt;path_to_csv_file&gt;\\DOMAIN.csv' WITH DELIMITER E'\\t' CSV HEADER QUOTE E'\\b';

After all the data has been imported, it is necessary to create constraints and indexes from the DevV5_DDL.sql, mentioned above, or use this script:
**DevV5_constraints_DDL.sql**
<https://github.com/OHDSI/Vocabulary-v5.0/blob/master/local_environment/DevV5_constraints_DDL.sql>

# Import Source Data

Filling out source tables according to instructions for a vocabulary.

# Start the Vocabulary Development Process

1. **devv5**.FastRecreateSchema()
2. Load_Stage in **dev_schema_name**
3. **qa_tests**.check_stage_tables()
4. **devv5**.GenericUpdate
5. **qa_tests**.get_\* functions