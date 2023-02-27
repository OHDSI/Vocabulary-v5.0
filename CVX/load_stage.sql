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
* Date: 2016
**************************************************************************/

--1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CVX',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.cvx LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.cvx LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_CVX'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Insert into concept_stage
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	domain_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT CASE 
		WHEN d.vaccinestatus = 'Non-US'
			AND d.full_vaccine_name NOT ILIKE '%Non-US%'
			THEN LEFT(d.full_vaccine_name, 245) || ' (non-US)'
		ELSE vocabulary_pack.CutConceptName(d.full_vaccine_name)
		END AS concept_name,
	'CVX' AS vocabulary_id,
	'Drug' AS domain_id,
	'CVX' AS concept_class_id,
	'S' AS standard_concept,
	d.cvx_code AS concept_code,
	COALESCE(cd.concept_date, d.last_updated_date) AS valid_start_date, --get concept date from true source
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.cvx d
LEFT JOIN sources.cvx_dates cd USING (cvx_code);

--4. load into concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT cvx_code,
	full_vaccine_name,
	'CVX',
	4180186
FROM sources.cvx

UNION

SELECT cvx_code,
	short_description,
	'CVX',
	4180186
FROM sources.cvx;

--5. Add CVX to RxNorm/RxNorm Extension manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--6. Add additional mappings from rxnconso
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT rxn.code AS concept_code_1,
	rxn.rxcui AS concept_code_2,
	'CVX' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'CVX - RxNorm' AS relationship_id,
	(
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'CVX'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.rxnconso rxn
JOIN concept c ON c.concept_code = rxn.rxcui
	AND c.vocabulary_id = 'RxNorm'
	AND c.standard_concept = 'S'
JOIN concept_stage cs ON cs.concept_code = rxn.code
WHERE rxn.sab = 'CVX'
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = rxn.code
			AND crs.concept_code_2 = rxn.rxcui
			AND crs.relationship_id = 'CVX - RxNorm'
		);

--7. Get rid from mappings to deprecated concepts 
DELETE
FROM concept_relationship_stage crs
WHERE crs.relationship_id = 'CVX - RxNorm'
	AND crs.invalid_reason IS NULL
	AND EXISTS (
		SELECT 1
		FROM concept c
		WHERE c.concept_code = crs.concept_code_2
			AND c.vocabulary_id = crs.vocabulary_id_2
			AND c.invalid_reason = 'D'
		);

--reverse
DELETE
FROM concept_relationship_stage crs
WHERE crs.relationship_id = 'RxNorm - CVX'
	AND crs.invalid_reason IS NULL
	AND EXISTS (
		SELECT 1
		FROM concept c
		WHERE c.concept_code = crs.concept_code_1
			AND c.vocabulary_id = crs.vocabulary_id_1
			AND c.invalid_reason = 'D'
		);

--8. Add relationships to the Vaccine Groups
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT cv.cvx_code AS concept_code_1,
	cv.cvx_vaccine_group AS concept_code_2,
	'CVX' AS vocabulary_id_1,
	'CVX' AS vocabulary_id_2,
	'Has vaccine group' AS relationship_id,
	(
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'CVX'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.cvx_vaccine cv
JOIN concept_stage cs ON cs.concept_code = cv.cvx_code
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = cv.cvx_code
			AND crs.concept_code_2 = cv.cvx_vaccine_group
			AND crs.relationship_id = 'Has vaccine group'
		);

--9. Make concepts that have relationship 'Maps to' non-standard
UPDATE concept_stage cs
SET standard_concept = NULL
FROM concept_relationship_stage crs
WHERE cs.concept_code = crs.concept_code_1
	AND cs.vocabulary_id = crs.vocabulary_id_1
	AND crs.relationship_id = 'Maps to'
	AND crs.invalid_reason IS NULL;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script