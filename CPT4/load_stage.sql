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

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CPT4',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.mrsmap LIMIT 1),
	pVocabularyVersion		=> (SELECT EXTRACT (YEAR FROM vocabulary_date)||' Release' FROM sources.mrsmap LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_CPT4'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Load concepts into concept_stage from MRCONSO
-- Main CPT codes. Str picked in certain order to get best concept_name
INSERT INTO concept_stage (
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
SELECT DISTINCT SUBSTR(str, 1, 255) AS concept_name,
	NULL AS domain_id, -- adding manually
	'CPT4' AS vocabulary_id,
	'CPT4' AS concept_class_id,
	'S' AS standard_concept,
	scui AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CPT4'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.mrconso
WHERE sab = 'CPT'
	AND suppress NOT IN (
		'E',
		'O',
		'Y'
		)
	AND tty IN (
		'PT',
		'GLP'
		);

-- Place of Sevice (POS) CPT terms
INSERT INTO concept_stage (
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
SELECT DISTINCT SUBSTR(str, 1, 255) AS concept_name,
	NULL AS domain_id,
	'CPT4' AS vocabulary_id,
	'Place of Service' AS concept_class_id,
	NULL AS standard_concept, -- not to appear in clinical tables, only for hierarchical search
	scui AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CPT4'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.mrconso
WHERE sab = 'CPT'
	AND suppress NOT IN (
		'E',
		'O',
		'Y'
		)
	AND tty = 'POS';

-- CPT Modifiers
INSERT INTO concept_stage (
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
SELECT DISTINCT FIRST_VALUE(substr(str, 1, 255)) OVER (
		PARTITION BY scui ORDER BY CASE 
				WHEN LENGTH(str) <= 255
					THEN LENGTH(str)
				ELSE 0
				END DESC,
				LENGTH(str) ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS concept_name,
	NULL AS domain_id,
	'CPT4' AS vocabulary_id,
	'CPT4 Modifier' AS concept_class_id,
	'S' AS standard_concept,
	scui AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CPT4'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.mrconso
WHERE sab IN (
		'CPT',
		'HCPT'
		)
	AND suppress NOT IN (
		'E',
		'O',
		'Y'
		)
	AND tty = 'MP';

-- Hierarchical CPT terms
INSERT INTO concept_stage (
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
SELECT DISTINCT SUBSTR(str, 1, 255) AS concept_name,
	NULL AS domain_id,
	'CPT4' AS vocabulary_id,
	'CPT4 Hierarchy' AS concept_class_id,
	'C' AS standard_concept, -- not to appear in clinical tables, only for hierarchical search
	scui AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CPT4'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.mrconso
WHERE sab IN (
		'CPT',
		'HCPT'
		)
	AND suppress NOT IN (
		'E',
		'O',
		'Y'
		)
	AND tty = 'HT';

--4. Update domain_id in concept_stage
UPDATE concept_stage c
SET domain_id = t.domain_id
FROM (
	SELECT c.concept_code,
		COALESCE(domain.domain_id, 'Procedure') AS domain_id
	FROM concept_stage c
	LEFT JOIN (
		SELECT cpt.code,
			CASE 
				WHEN cpt.tty = 'POS'
					THEN 'Place of Service'
				WHEN cpt.tty = 'GLP'
					THEN 'Observation'
				WHEN COALESCE(h2.code, cpt.code) = '1011137'
					THEN 'Measurement' -- Organ or Disease Oriented Panels
				WHEN COALESCE(h2.code, cpt.code) = '1011219'
					THEN 'Measurement' -- Clinical Pathology Consultations
				WHEN COALESCE(h2.code, cpt.code) = '1019043'
					THEN 'Measurement' -- In Vivo (eg, Transcutaneous) Laboratory Procedures
				WHEN COALESCE(h2.code, cpt.code) = '1020889'
					THEN 'Measurement' -- Molecular Pathology Procedures
				WHEN COALESCE(h2.code, cpt.code) = '1021433'
					THEN 'Observation' -- Non-Measure Category II Codes
				WHEN COALESCE(h2.code, cpt.code) = '1014516'
					THEN 'Observation' -- Patient History
				WHEN COALESCE(h2.code, cpt.code) = '1019288'
					THEN 'Observation' -- Structural Measures
				WHEN COALESCE(h2.code, cpt.code) = '1014549'
					THEN 'Observation' -- Follow-up or Other Outcomes
				WHEN COALESCE(h2.code, cpt.code) = '1014516'
					THEN 'Observation' -- Patient History
				WHEN COALESCE(h2.code, cpt.code) = '1014511'
					THEN 'Observation' -- Patient Management
				WHEN COALESCE(h2.code, cpt.code) = '1014535'
					THEN 'Observation' -- Therapeutic, Preventive or Other Interventions - these are the disease guideline codes such as (A-BRONCH), (OME) etc.
				WHEN COALESCE(h2.code, cpt.code) = '1011759'
					THEN 'Measurement' -- Hematology and Coagulation Procedures
				WHEN COALESCE(h2.code, cpt.code) = '1011223'
					THEN 'Measurement' -- Urinalysis Procedures
				WHEN COALESCE(h2.code, cpt.code) = '1012134'
					THEN 'Measurement' -- Microbiology Procedures
				WHEN COALESCE(h2.code, cpt.code) = '1014550'
					THEN 'Observation' -- Patient Safety - these are guidelines
				WHEN COALESCE(h2.code, cpt.code) = '1021135'
					THEN 'Observation' -- Multianalyte Assays with Algorithmic Analyses
				WHEN COALESCE(h2.code, cpt.code) = '1014532'
					THEN 'Observation' -- Diagnostic/Screening Processes or Results - guidelines, but also results and diagnoses, which need be mapped
				WHEN COALESCE(h2.code, cpt.code) = '1014526'
					THEN 'Observation' -- Physical Examination
				WHEN COALESCE(h2.code, cpt.code) = '1011153'
					THEN 'Measurement' -- Therapeutic Drug Assays - these are measurements of level after dosing, so, also drug
				WHEN COALESCE(h2.code, cpt.code) = '1011237'
					THEN 'Measurement' -- Chemistry Procedures
				WHEN COALESCE(h2.code, cpt.code) = '1013575'
					THEN 'Observation' -- Special Services, Procedures and Reports - medical services really
				WHEN COALESCE(h2.code, cpt.code) = '1013774'
					THEN 'Observation' -- Home Services - medical service as well
				WHEN COALESCE(h2.code, cpt.code) = '1012420'
					THEN 'Measurement' -- Cytogenetic Studies
				WHEN COALESCE(h2.code, cpt.code) = '1011147'
					THEN 'Measurement' -- Drug Testing Procedures
				WHEN COALESCE(h2.code, cpt.code) = '1012370'
					THEN 'Measurement' -- Cytopathology Procedures
				WHEN COALESCE(h3.code, cpt.code) = '1011889'
					THEN 'Procedure' -- Blood bank physician services
				WHEN COALESCE(h2.code, cpt.code) = '1011874'
					THEN 'Measurement' -- Immunology Procedures
				WHEN cpt.code IN (
						'88362',
						'88309',
						'88302',
						'88300',
						'88304',
						'88305',
						'88307',
						'88311',
						'88375',
						'88321',
						'88399',
						'88325',
						'88323'
						)
					THEN 'Procedure'
				WHEN COALESCE(h3.code, cpt.code) = '1014276'
					THEN 'Procedure' -- Pathology consultation during surgery
				WHEN COALESCE(h2.code, cpt.code) = '1012454'
					THEN 'Measurement' -- Surgical Pathology Procedures
				WHEN COALESCE(h3.code, cpt.code) = '1012549'
					THEN 'Measurement' -- Semen analysis
				WHEN COALESCE(h3.code, cpt.code) = '1012555'
					THEN 'Measurement' -- Sperm evaluation
				WHEN cpt.code IN (
						'89230',
						'89220'
						)
					THEN 'Procedure' -- Sweat collection etc.
				WHEN COALESCE(h2.code, cpt.code) = '1013981'
					THEN 'Measurement' -- Other Pathology and Laboratory Procedures
				WHEN COALESCE(h3.code, cpt.code) = '1012089'
					THEN 'Measurement' -- Antihuman globulin test (Coombs test)
				WHEN COALESCE(h3.code, cpt.code) = '1012093'
					THEN 'Measurement' -- Autologous blood or component, collection processing and storage
				WHEN COALESCE(h3.code, cpt.code) = '1012096'
					THEN 'Measurement' -- Blood typing
				WHEN COALESCE(h3.code, cpt.code) = '1012103'
					THEN 'Measurement' -- Blood typing, for paternity testing, per individual
				WHEN COALESCE(h3.code, cpt.code) = '1012106'
					THEN 'Measurement' -- Compatibility test each unit
				WHEN COALESCE(h3.code, cpt.code) = '1012116'
					THEN 'Measurement' -- Hemolysins and agglutinins
				WHEN cpt.code = '92531'
					THEN 'Observation' -- Spontaneous nystagmus, including gaze - Condition
				WHEN cpt.code = '90745'
					THEN 'Drug' -- Immunization, hepatits B
				WHEN cpt.code IN (
						'86890',
						'86891'
						)
					THEN 'Observation' -- Autologous blood or component, collection processing and storage
				WHEN cpt.str LIKE 'End-stage renal disease (ESRD)%'
					THEN 'Observation'
				WHEN h2.code IN (
						'1012570',
						'1012602'
						)
					THEN 'Drug' -- Vaccines, Toxoids or Immune Globulins, Serum or Recombinant Products
				WHEN h2.code = '1011189'
					THEN 'Measurement' -- Evocative/Suppression Testing Procedures
				WHEN cpt.code IN (
						'1013264',
						'1013276',
						'1013281',
						'1013282',
						'1013285',
						'1013295',
						'1013301',
						'1021142',
						'1021170',
						'95004',
						'95012',
						'95017',
						'95018',
						'95024',
						'95027',
						'95028',
						'95044',
						'95052',
						'95056',
						'95060',
						'95065',
						'95070',
						'95071',
						'95076',
						'95079'
						)
					THEN 'Measurement' -- allergy and immunologic testing
				WHEN cpt.str LIKE 'Electrocardiogram, routine ECG%'
					THEN 'Measurement'
				ELSE 'Procedure'
				END AS domain_id
		FROM (
			SELECT aui AS cpt,
				regexp_replace(ptr, '(A\d+\.)(A\d+\.)(A\d+)(.*)', '\3','g') AS aui2,
				regexp_replace(ptr, '(A\d+\.)(A\d+\.)(A\d+\.)(A\d+)(.*)', '\4','g') AS aui3
			FROM sources.mrhier
			WHERE sab = 'CPT'
				AND rela = 'isa'
			) h
		JOIN sources.mrconso cpt ON h.cpt = cpt.aui
			AND cpt.sab = 'CPT'
		LEFT JOIN sources.mrconso h2 ON h2.aui = h.aui2
			AND h2.sab = 'CPT'
		LEFT JOIN sources.mrconso h3 ON h3.aui = h.aui3
			AND h3.sab = 'CPT'
		) domain ON domain.code = c.concept_code
	) t
WHERE c.concept_code = t.concept_code;

 --5. Pick up all different str values that are not obsolete or suppressed
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT scui AS synonym_concept_code,
	SUBSTR(str, 1, 1000) AS synonym_name,
	'CPT4' AS synonym_vocabulary_id,
	4180186 AS language_concept_id
FROM sources.mrconso
WHERE sab IN (
		'CPT',
		'HCPT'
		)
	AND suppress NOT IN (
		'E',
		'O',
		'Y'
		);

/*
--6. Create text for Medical Coder with new codes and mappings
SELECT c.concept_code AS concept_code_1,
	u2.scui AS concept_code_2,
	'CPT4 - SNOMED eq' AS relationship_id, -- till here strawman for concept_relationship to be checked and filled out, the remaining are supportive information to be truncated in the return file
	c.concept_name AS cpt_name,
	u2.str AS snomed_str,
	sno.concept_id AS snomed_concept_id,
	sno.concept_name AS snomed_name
FROM concept_stage c
LEFT JOIN (
	-- UMLS record for CPT4 code
	SELECT DISTINCT cui,
		scui
	FROM sources.mrconso
	WHERE sab IN (
			'CPT',
			'HCPT'
			)
		AND suppress NOT IN (
			'E',
			'O',
			'Y'
			)
	) u1 ON u1.scui = concept_code
	AND c.vocabulary_id = 'CPT4' -- join UMLS for code one
LEFT JOIN (
	-- UMLS record for SNOMED code of the same cui
	SELECT DISTINCT cui,
		scui,
		FIRST_VALUE(str) OVER (
			PARTITION BY scui ORDER BY CASE tty
					WHEN 'PT'
						THEN 1
					WHEN 'PTGB'
						THEN 2
					ELSE 10
					END
			) AS str
	FROM sources.mrconso
	WHERE sab IN ('SNOMEDCT_US')
		AND suppress NOT IN (
			'E',
			'O',
			'Y'
			)
	) u2 ON u2.cui = u1.cui
LEFT JOIN concept sno ON sno.vocabulary_id = 'SNOMED'
	AND sno.concept_code = u2.scui -- SNOMED concept
WHERE NOT EXISTS (
		-- only new codes we don't already have
		SELECT 1
		FROM concept co
		WHERE co.concept_code = c.concept_code
			AND co.vocabulary_id = 'CPT4'
		)
	AND c.vocabulary_id = 'CPT4';
*/

--7. Append resulting file from Medical Coder (in concept_relationship_stage format) to concept_relationship_stage
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--8. Set proper standard_concept for mapped CPT4
UPDATE concept_stage cs
SET standard_concept = NULL
FROM (
	SELECT concept_code_1
	FROM concept_relationship_manual
	WHERE vocabulary_id_1 = 'CPT4'
		AND relationship_id = 'Maps to'
		AND invalid_reason IS NULL
	) crm
WHERE cs.concept_code = crm.concept_code_1;

--9. Load concept_relationship_stage from the existing one. The reason is that there is no good source for these relationships, and we have to build the ones for new codes from UMLS and manually
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT c.concept_code AS concept_code_1,
	c1.concept_code AS concept_code_2,
	r.relationship_id AS relationship_id,
	c.vocabulary_id AS vocabulary_id_1,
	c1.vocabulary_id AS vocabulary_id_2,
	r.valid_start_date,
	r.valid_end_date,
	r.invalid_reason
FROM concept_relationship r,
	concept c,
	concept c1
WHERE c.concept_id = r.concept_id_1
	AND c.vocabulary_id = 'CPT4'
	AND c1.concept_id = r.concept_id_2
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = c.concept_code
			AND crs.concept_code_2 = c1.concept_code
			AND crs.relationship_id = r.relationship_id
			AND crs.vocabulary_id_1 = c.vocabulary_id
			AND crs.vocabulary_id_2 = c1.vocabulary_id
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs,
			relationship rel
		WHERE crs.concept_code_2 = c.concept_code
			AND crs.concept_code_1 = c1.concept_code
			AND rel.relationship_id = r.relationship_id
			AND crs.relationship_id = rel.reverse_relationship_id
			AND crs.vocabulary_id_2 = c.vocabulary_id
			AND crs.vocabulary_id_1 = c1.vocabulary_id
		);

--10. Create hierarchical relationships between HT and normal CPT codes
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT c1.code AS concept_code_1,
	c2.code AS concept_code_2,
	'Is a' AS relationship_id,
	'CPT4' AS vocabulary_id_1,
	'CPT4' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT aui AS aui1,
		REGEXP_REPLACE(ptr, '(.+\.)(A\d+)$', '\2', 'g') AS aui2
	FROM sources.mrhier
	WHERE sab = 'CPT'
		AND rela = 'isa'
	) h
JOIN sources.mrconso c1 ON c1.aui = h.aui1
	AND c1.sab = 'CPT'
JOIN sources.mrconso c2 ON c2.aui = h.aui2
	AND c2.sab = 'CPT'
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = c1.code
			AND crs.concept_code_2 = c2.code
			AND crs.relationship_id = 'Is a'
			AND crs.vocabulary_id_1 = 'CPT4'
			AND crs.vocabulary_id_2 = 'CPT4'
		);

--11. Extract all CPT4 codes inside the concept_name of other cpt codes.
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT *
FROM (
	SELECT unnest(regexp_matches(concept_name, '\((\d\d\d\d[A-Z])\)', 'gi')) AS concept_code_1,
		concept_code AS concept_code_2,
		'Subsumes' AS relationship_id,
		'CPT4' AS vocabulary_id_1,
		'CPT4' AS vocabulary_id_2,
		TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
		TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
		NULL AS invalid_reason
	FROM concept_stage
	WHERE vocabulary_id = 'CPT4'
	) AS s
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = s.concept_code_1
			AND crs.concept_code_2 = s.concept_code_2
			AND crs.relationship_id = 'Subsumes'
			AND crs.vocabulary_id_1 = 'CPT4'
			AND crs.vocabulary_id_2 = 'CPT4'
		);

--12. Update dates from mrsat.atv (only for new concepts)
UPDATE concept_stage cs
SET valid_start_date = i.dt
FROM (
	SELECT MAX(TO_DATE(s.atv, 'yyyymmdd')) dt,
		cs.concept_code
	FROM concept_stage cs
	LEFT JOIN sources.mrconso m ON m.scui = cs.concept_code
		AND m.sab IN (
			'CPT',
			'HCPT'
			)
	LEFT JOIN sources.mrsat s ON s.cui = m.cui
		AND s.atn = 'DA'
	WHERE NOT EXISTS (
			-- only new codes we don't already have
			SELECT 1
			FROM concept co
			WHERE co.concept_code = cs.concept_code
				AND co.vocabulary_id = cs.vocabulary_id
			)
		AND cs.vocabulary_id = 'CPT4'
		AND cs.concept_class_id = 'CPT4'
		AND s.atv IS NOT NULL
	GROUP BY concept_code
	) i
WHERE i.concept_code = cs.concept_code;

--13. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--14. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--15. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--16. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		