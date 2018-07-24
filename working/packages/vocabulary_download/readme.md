/**************************************************************************
* Copyright 2018 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov
* Date: 2018
**************************************************************************/

--1. create a schema and grant permissions to other
CREATE SCHEMA vocabulary_download AUTHORIZATION devv5;
ALTER DEFAULT PRIVILEGES IN SCHEMA vocabulary_download GRANT SELECT ON TABLES TO PUBLIC;
GRANT USAGE ON SCHEMA vocabulary_download TO PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA vocabulary_download GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

--2. create a sequence and LOG table
CREATE SEQUENCE vocabulary_download.log_seq START WITH 1 INCREMENT BY 1 CACHE 10;
CREATE TABLE vocabulary_download.vocabulary_log (
  object_no int4 primary key,
  vocabulary_id varchar (20) not null,
  session_id int4 not null, /*session identifier during update*/
  operation_time timestamp not null,
  vocabulary_operation text not NULL /*started, stopped, etc*/,
  vocabulary_error text,
  error_details text,
  vocabulary_status int not null /*0 - update started, 1 - operation success, 2 - operation error, 3 - all tasks done*/
);
CREATE INDEX idx_log_sessionid ON vocabulary_download.vocabulary_log (session_id);

--3. execute all *.sql files in vocabulary_download folder

--4. all functions in Vocabulary-v5.0\working\packages\vocabulary_pack\*.sql should already exist in the database

################################################

Usage:
select * from vocabulary_download.get_umls();
This query will download, extract and import UMLS data into sources tables
Query supports some additional options, for UMLS they are JUMP_TO_UMLS_PREPARE and JUMP_TO_UMLS_IMPORT, e.g.
select * from vocabulary_download.get_umls('JUMP_TO_UMLS_PREPARE');
This option skips downloading and jumps to prepare section. Useful option when downloading was successful, but something was bad while extraction,
so you can fix this and re-run query straight from prepare section.
JUMP_TO_UMLS_IMPORT - same, but jumps to import section.

Each vocabulary processing returns session_id, so you can easily get full log about processing from the LOG table:
select * from vocabulary_download.vocabulary_log where vocabulary_id='UMLS' and session_id=xxx order by object_no desc;

Almost all vocabularies support additional params in devv5.vocabulary_access.vocabulary_params in JSON-format,
e.g. for SNOMED: vocabulary_params='{"fast_recreate_script": "devv5.FastRecreateSchema()","load_stage_path": "https://github.com/OHDSI/Vocabulary-v5.0/raw/master/SNOMED/load_stage.sql"}'.
This means 'execute the function devv5.FastRecreateSchema()' and 'path to load_stage in the GitHub repository'
Note: some vocabularies may require setting a special variable for FastRecreateSchema: 'devv5.FastRecreateSchema(include_concept_ancestor=>true)'.

################################################

Automation part
UpdateAllVocabularies.sql - run this script to automatically update all necessary vocabularies