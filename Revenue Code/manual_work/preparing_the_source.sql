/**************************************************************************
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
* Authors: Medical team
* Date: 2021
**************************************************************************/

--1. Create a local source table inside dev_revenuecode schema
DROP TABLE IF EXISTS dev_revenuecode.revcode_source;
CREATE TABLE dev_revenuecode.revcode_source (
	action_mode TEXT,
	concept_code TEXT,
	concept_name TEXT,
	valid_start_date DATE,
	valid_end_date DATE
);

--2. Load csv file
--for example:
DO $$
BEGIN
	TRUNCATE dev_revenuecode.revcode_source;
	SET LOCAL DATESTYLE=DMY;
	COPY dev_revenuecode.revcode_source FROM '/home/vocab_import/manual/UB04-Revenue Code update2010-20.csv' DELIMITER ';' CSV QUOTE '"' HEADER;
END $$;

--3. Fill the manual tables (truncate if necessary)
--concepts for update
INSERT INTO concept_manual (
	concept_name,
	vocabulary_id,
	standard_concept,
	concept_code,
	valid_start_date
	)
SELECT concept_name,
	'Revenue Code' AS vocabulary_id,
	'S' AS standard_concept,
	concept_code,
	valid_start_date
FROM dev_revenuecode.revcode_source
WHERE action_mode IN (
		'U',
		'R'
		);

--concepts for deprecate
INSERT INTO concept_manual (
	vocabulary_id,
	standard_concept,
	concept_code,
	valid_end_date,
	invalid_reason
	)
SELECT 'Revenue Code' AS vocabulary_id,
	NULL AS standard_concept,
	concept_code,
	valid_end_date,
	'D' AS invalid_reason
FROM dev_revenuecode.revcode_source
WHERE action_mode = 'D';

--new concepts
INSERT INTO concept_manual
SELECT concept_name,
	'Revenue Code' AS domain_id,
	'Revenue Code' AS vocabulary_id,
	'Revenue Code' AS concept_class_id,
	'S' AS standard_concept,
	concept_code,
	TO_DATE('19700101', 'YYYYMMDD') AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM dev_revenuecode.revcode_source
WHERE action_mode = 'I';