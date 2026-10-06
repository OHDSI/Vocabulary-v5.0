/***************************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
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
* Authors: Maksym Trofymenko, Polina Talapova, Denys Kaduk
* Date: 2026
***************************************************************************************
T1DX manual tables population script

 Purpose:
   Append T1DX manual vocabulary content from locally downloaded CSV files into:
     - concept_manual
     - concept_relationship_manual
     - concept_synonym_manual

 Assumptions:
   - CSV files were already curated and validated separately.
   - Field normalization, QA checks, duplicate checks, and semantic review are performed
     outside this script.
   - Base OHDSI manual tables are already present in concept_manual,
     concept_relationship_manual, and concept_synonym_manual.
   - This script must not truncate destination manual tables.

Logic:
1. Recreate local typed manual staging tables for T1DX CSV import.
2. Import CSV files into the manual staging tables.
3. Delete existing T1DX rows from destination manual tables.
4. Insert the current T1DX concepts, relationships, and synonyms from manual staging tables into
   destination manual tables.
***************************************************************************************/

/***************************************************************************************
 Step 1. Create local staging tables for already prepared T1DX manual CSV files.
***************************************************************************************/
DROP TABLE IF EXISTS t1dx_concept_manual;
DROP TABLE IF EXISTS t1dx_concept_relationship_manual;
DROP TABLE IF EXISTS t1dx_concept_synonym_manual;

CREATE TABLE t1dx_concept_manual (
    concept_name       varchar(255)  NOT NULL,
    domain_id          varchar(20)   NOT NULL,
    vocabulary_id      varchar(20)   NOT NULL,
    concept_class_id   varchar(20)   NOT NULL,
    standard_concept   varchar(1),
    concept_code       varchar(50)   NOT NULL,
    valid_start_date   date          NOT NULL,
    valid_end_date     date          NOT NULL,
    invalid_reason     varchar(1)
);


CREATE TABLE t1dx_concept_relationship_manual (
    concept_code_1     varchar(50)   NOT NULL,
    concept_code_2     varchar(50)   NOT NULL,
    vocabulary_id_1    varchar(20)   NOT NULL,
    vocabulary_id_2    varchar(20)   NOT NULL,
    relationship_id    varchar(20)   NOT NULL,
    valid_start_date   date          NOT NULL,
    valid_end_date     date          NOT NULL,
    invalid_reason     varchar(1)
);


CREATE TABLE t1dx_concept_synonym_manual (
    synonym_name           varchar(1000) NOT NULL,
    synonym_concept_code   varchar(50)   NOT NULL,
    synonym_vocabulary_id  varchar(20)   NOT NULL,
    language_concept_id    integer       NOT NULL
);

/****************************************************************************************
 Step 2. Import CSV files into the staging tables.

 Example psql commands:

 \copy t1dx_concept_manual
 FROM 'manual_work/t1dx_concept_manual.csv'
 WITH (FORMAT csv, HEADER true, NULL '', QUOTE '"');

 \copy t1dx_concept_relationship_manual
 FROM 'manual_work/t1dx_concept_relationship_manual.csv'
 WITH (FORMAT csv, HEADER true, NULL '', QUOTE '"');

 \copy t1dx_concept_synonym_manual
 FROM 'manual_work/t1dx_concept_synonym_manual.csv'
 WITH (FORMAT csv, HEADER true, NULL '', QUOTE '"');

 If CSV files are imported via DBeaver, pgAdmin, or another GUI client, complete the import
 into the three staging tables above before running the append section below.

****************************************************************************************
 Step 3. Replace existing T1DX rows in destination manual tables (for future refreshes)
****************************************************************************************/
DELETE FROM concept_relationship_manual
WHERE vocabulary_id_1 = 'T1DX'
   OR vocabulary_id_2 = 'T1DX';

DELETE FROM concept_synonym_manual
WHERE synonym_vocabulary_id = 'T1DX';

DELETE FROM concept_manual
WHERE vocabulary_id = 'T1DX';
/****************************************************************************************
 Step 4. Insert the current T1DX concepts.
****************************************************************************************/
INSERT INTO concept_manual (
    concept_name,
    domain_id,
    vocabulary_id,
    concept_class_id,
    standard_concept,
    concept_code,
    valid_start_date,
    valid_end_date,
    invalid_reason
)
SELECT
    concept_name,
    domain_id,
    vocabulary_id,
    concept_class_id,
    standard_concept,
    concept_code,
    valid_start_date,
    valid_end_date,
    invalid_reason
FROM t1dx_concept_manual;

/****************************************************************************************
 Step 5. Insert the current T1DX concept relationships.
****************************************************************************************/
INSERT INTO concept_relationship_manual (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
)
SELECT
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
FROM t1dx_concept_relationship_manual;

/****************************************************************************************
 Step 6. Insert the current T1DX concept synonyms.
****************************************************************************************/
INSERT INTO concept_synonym_manual (
    synonym_name,
    synonym_concept_code,
    synonym_vocabulary_id,
    language_concept_id
)
SELECT
    synonym_name,
    synonym_concept_code,
    synonym_vocabulary_id,
    language_concept_id
FROM t1dx_concept_synonym_manual;

/****************************************************************************************
 Step 7. Refresh planner statistics to ensure optimal query performance after the bulk insert.
****************************************************************************************/
ANALYZE concept_manual;
ANALYZE concept_relationship_manual;
ANALYZE concept_synonym_manual;