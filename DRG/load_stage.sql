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
* Authors: Timur Vakhitov, Christian Reich
* Date: 2017
**************************************************************************/

--directly update concept and concept_relationship
DO $$
DECLARE
	ex INTEGER;
	cDate SOURCES.fy_table_5%rowtype;
BEGIN
	--create sequence
	SELECT max(c.concept_id) + 1 INTO ex FROM concept c WHERE concept_id < 500000000;-- Last valid below HOI concept_id
	DROP SEQUENCE IF EXISTS v5_concept;
	EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
	FOR cDate.vocabulary_date IN (SELECT DISTINCT vocabulary_date FROM SOURCES.fy_table_5 ORDER BY vocabulary_date) LOOP
		--1. deprecate missing concepts
		UPDATE concept c
		SET invalid_reason = 'D',
			valid_end_date = cDate.vocabulary_date - 1
		WHERE c.vocabulary_id = 'DRG'
			AND c.invalid_reason IS NULL
			AND c.valid_start_date <= cDate.vocabulary_date
			AND c.concept_code NOT IN (
				SELECT drg_code
				FROM SOURCES.fy_table_5 f
				WHERE f.vocabulary_date = cDate.vocabulary_date
				);

		--2. if concept not exists or exists, but names are different, then deprecate old record and create the new one
		UPDATE concept c
		SET invalid_reason = 'U',
			valid_end_date = cDate.vocabulary_date - 1
		WHERE c.vocabulary_id = 'DRG'
			AND c.invalid_reason IS NULL
			AND c.valid_start_date <= cDate.vocabulary_date
			AND EXISTS (
				SELECT 1
				FROM SOURCES.fy_table_5 f
				WHERE f.vocabulary_date = cDate.vocabulary_date
					AND c.concept_code = f.drg_code
					AND lower(c.concept_name) <> lower(f.drg_name)
				);
				
		EXECUTE '
		INSERT INTO concept (concept_id,
			concept_name,
			domain_id,
			vocabulary_id,
			concept_class_id,
			standard_concept,
			concept_code,
			valid_start_date,
			valid_end_date,
			invalid_reason)
		SELECT NEXTVAL(''v5_concept''),
			f.drg_name as concept_name,
			''Observation'' as domain_id,
			''DRG'' as vocabulary_id,
			''MS-DRG'' as concept_class_id,
			''S'' as standard_concept,
			f.drg_code as concept_code,
			f.vocabulary_date AS valid_start_date,
			TO_DATE (''20991231'', ''yyyymmdd'') AS valid_end_date,
			null as invalid_reason
		FROM SOURCES.fy_table_5 f WHERE f.vocabulary_date=$1
		AND NOT EXISTS (
				SELECT 1 FROM concept c_int WHERE c_int.vocabulary_id=''DRG''
				AND c_int.invalid_reason IS NULL
				AND c_int.concept_code=f.drg_code
		)
		' USING cDate.vocabulary_date;
	END LOOP;

	--3. add 'Concept replaced by' for 'U'
	INSERT INTO concept_relationship
	SELECT DISTINCT c1.concept_id AS concept_id_1,
		last_value(c2.concept_id) OVER (
			PARTITION BY c1.concept_id ORDER BY c2.invalid_reason ROWS BETWEEN UNBOUNDED PRECEDING
					AND UNBOUNDED FOLLOWING
			) AS concept_id_2,
		'Concept replaced by' AS relationship_id,
		c1.valid_start_date AS valid_start_date,
		last_value(c2.valid_end_date) OVER (
			PARTITION BY c1.concept_id ORDER BY c2.invalid_reason ROWS BETWEEN UNBOUNDED PRECEDING
					AND UNBOUNDED FOLLOWING
			) AS valid_end_date,
		NULL AS invalid_reason
	FROM concept c1,
		concept c2
	WHERE c1.concept_code = c2.concept_code
		AND c1.vocabulary_Id = 'DRG'
		AND c2.vocabulary_Id = 'DRG'
		AND c1.invalid_reason = 'U'
		AND COALESCE(c2.invalid_reason, 'D') = 'D'
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship r_int
			WHERE r_int.concept_id_1 = c1.concept_id
				AND r_int.relationship_id = 'Concept replaced by'
			);

	DROP SEQUENCE v5_concept;
END$$;