# Preparing a Local Environment for the Vocabulary Development Process

# Description

This document describes the local database preparation that needs to be done for the vocabulary development process

# Prerequisites

PostgreSQL 14 or higher.

# Creating Extensions

Pgcrypto and Tablefunc extensions should be installed for some functions to work correctly. 
Create extensions:
>CREATE EXTENSION pg_trgm;  
>CREATE EXTENSION tablefunc;  
>CREATE EXTENSION plpython3u;  
>CREATE EXTENSION pg_trgm;

If during the installation of plpython3u you get an error like:  
_“ERROR: could not load library "C:/Program Files/PostgreSQL/15/lib/plpython3.dll": The specified module could not be found.”_  
this means that it is necessary to install the required packages.  
There is an example for Postgresql 15 using apt or apt-get (for Linux system):  
>**apt-get:**  
>sudo apt-get update  
>sudo apt-get -y install postgresql-plpython3-15  
>  
>**apt:**  
>sudo apt update  
>sudo apt -y install postgresql-plpython3-15  



# Creating Schemas

As an initial step, it needs to create schemas in the database. 
It is also necessary to give an appropriate name to a schema for the vocabulary development process (e.g. **dev_hemonc** for the HemOnc vocabulary).
>-- replace <dev_schema_name> with an actual schema name:
>CREATE SCHEMA <dev_schema_name>;  
>CREATE SCHEMA devv5;  
>CREATE SCHEMA sources;  
>CREATE SCHEMA qa_tests;  
>CREATE SCHEMA vocabulary_pack;  
>CREATE SCHEMA admin_pack;

# Creating Functions

This section describes the features and procedures that should be installed in the database in the appropriate schemas.
All functions except Generic_Update() (which is in the **local_environment** brantch) are in the **master** branch.

## devv5

- GenericUpdate() (a version of the GenericUpdate function for a local environment)  [Vocabulary-v5.0/working/generic_update.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/local_environment/working/generic_update.sql)
- FastRecreateSchema()  [Vocabulary-v5.0/working/fast_recreate_schema.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/fast_recreate_schema.sql)
- GetPrimaryRelationshipID()  [Vocabulary-v5.0/working/packages/admin_pack/GetPrimaryRelationshipID.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/GetPrimaryRelationshipID.sql)
- Functions from  [Vocabulary-v5.0/working/packages/DevV5_additional_functions](https://github.com/OHDSI/Vocabulary-v5.0/tree/master/working/packages/DevV5_additional_functions)

## vocabulary_pack

- DropFKConstraints()  [Vocabulary-v5.0/working/packages/vocabulary_pack/DropFKConstraints.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/DropFKConstraints.sql)
- SetLatestUpdate()  [Vocabulary-v5.0/working/packages/vocabulary_pack/SetLatestUpdate.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/SetLatestUpdate.sql)
- ProcessManualSynonyms()  [Vocabulary-v5.0/working/packages/vocabulary_pack/ProcessManualSynonyms.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/ProcessManualSynonyms.sql)
- CheckManualSynonyms()  [Vocabulary-v5.0/working/packages/vocabulary_pack/CheckManualSynonyms.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/CheckManualSynonyms.sql)
- ProcessManualRelationships()  [Vocabulary-v5.0/working/packages/vocabulary_pack/ProcessManualRelationships.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/ProcessManualRelationships.sql)
- CheckReplacementMappings()  [Vocabulary-v5.0/working/packages/vocabulary_pack/CheckReplacementMappings.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/CheckReplacementMappings.sql)
- AddFreshMAPSTO()  [Vocabulary-v5.0/working/packages/vocabulary_pack/AddFreshMAPSTO.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/AddFreshMAPSTO.sql)
- GetActualConceptInfo()  [Vocabulary-v5.0/working/packages/vocabulary_pack/GetActualConceptInfo.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/GetActualConceptInfo.sql)
- DeprecateWrongMapsTo()  [Vocabulary-v5.0/working/packages/vocabulary_pack/DeprecateWrongMapsTo.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/DeprecateWrongMapsTo.sql)
- DeleteAmbiguousMapsTo()  [Vocabulary-v5.0/working/packages/vocabulary_pack/DeleteAmbiguousMapsTo.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/DeleteAmbiguousMapsTo.sql)

## qa_tests

- Functions from [Vocabulary-v5.0/working/packages/QA_TESTS](https://github.com/OHDSI/Vocabulary-v5.0/tree/master/working/packages/QA_TESTS)

# Creating Tables

## Devv5

In case the table structure already exists in the database, this part can be skipped.

When tables are created for the first time, everything should be executed from the script except creating constraints and indexes so that they do not interfere with the import of vocabularies from Athena.

- DevV5_DDL.sql (create only tables structures without any constraints)
    [Vocabulary-v5.0/working/DevV5_DDL.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/local_environment/working/DevV5_DDL.sql)  
- Prepare_manual_tables.sql [Vocabulary-v5.0/working/packages/admin_pack/prepare_manual_tables.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/prepare_manual_tables.sql)

## development schema

- DevV5_DDL.sql without created, created_by, modified, modified_by fields
    [Vocabulary-v5.0/working/DevV5_DDL.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/DevV5_DDL.sql)  
- Prepare_manual_tables.sql [Vocabulary-v5.0/working/packages/admin_pack/prepare_manual_tables.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/admin_pack/prepare_manual_tables.sql)  

## Update Vocabulary table structure

If the table structure was created before 03/04/2024, the following script should be run:
- 2024-03-04.sql (working/manual_changes/2024/2024-03-04.sql)

## sources

Creating source tables according to instructions for your vocabulary.

# Import Vocabulary Data from Athena

To initially fill out the vocabulary tables, it needs to download the necessary vocabularies from [Athena (ohdsi.org)](https://athena.ohdsi.org/vocabulary/list) and import them using the “copy” command in psql.

The following vocabularies have to be installed:
- SNOMED
- (TBD)

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

After all the data has been imported, it is necessary to create constraints and indexes from the DevV5_DDL.sql, mentioned above.

# Import Source Data

Filling out source tables according to instructions for vocabulary you are going to work.

# Start the Vocabulary Development Process

1. **devv5**.FastRecreateSchema()
2. Load_Stage in **dev_schema_name**
3. **devv5**.GenericUpdate
4. **qa_tests**.get_\* functions
