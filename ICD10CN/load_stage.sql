/**************************************************************************
* Copyright 2020 Observational Health Data Sciences and Informatics (OHDSI)
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
* Authors: Timur Vakhitov, Eduard Korchmar, Dmitry Dymshyts
* Date: 2020
**************************************************************************/
/*
TODO:
-Mapping of granular codes
-Mapping of missing Histologies
-Correcting translations
*/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ICD10CN',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.icd10cn_concept LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.icd10cn_concept LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_ICD10CN'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Add manual table to more accurately define concept_class_id
DROP TABLE IF EXISTS icd10cn_chapters;
CREATE UNLOGGED TABLE icd10cn_chapters (chapter_code VARCHAR(10));
INSERT INTO icd10cn_chapters
VALUES ('A00-B99'),
	('C00-D48'),
	('D50-D89'),
	('E00-E90'),
	('F00-F99'),
	('G00-G99'),
	('H00-H59'),
	('H60-H95'),
	('I00-I99'),
	('J00-J99'),
	('K00-K93'),
	('L00-L99'),
	('M00-M99'),
	('N00-N99'),
	('O00-O99'),
	('P00-P96'),
	('Q00-Q99'),
	('R00-R99'),
	('S00-T98'),
	('V01-Y98'),
	('Z00-Z99'),
	('U00-U99');

--4. Gather list of names to avoid usage of automatically translated chinese names where possible
DROP TABLE IF EXISTS name_source;
CREATE UNLOGGED TABLE name_source AS
SELECT
	--Clean ICD10 names
	ic.concept_code_clean,
	'ICD10' AS source,
	c.concept_name,
	'S' AS preferred,
	4180186 AS language_concept_id -- English
FROM sources.icd10cn_concept ic
JOIN concept c ON c.vocabulary_id = 'ICD10'
	AND replace(ic.concept_code_clean, '.x00', '') = c.concept_code
WHERE ic.concept_code <> 'Metadata'

UNION

SELECT
	--Clean ICD10 names for concepts with 00 in end (generic equivalency)
	ic.concept_code_clean,
	'ICD10' AS source,
	c.concept_name,
	'S' AS preferred,
	4180186 AS language_concept_id -- English
FROM sources.icd10cn_concept ic
JOIN concept c ON c.vocabulary_id = 'ICD10'
	AND ic.concept_code_clean = c.concept_code || '00'
WHERE ic.concept_code <> 'Metadata'

UNION

SELECT
	--ICDO3 names
	/*
	ICD10CN codes modify ICDO3 codes with 5th digit added to morphology.
	If the 5th digit equals 0, than code means the same as ICDO code.
	*/
	ic.concept_code_clean,
	'ICD03' AS source,
	c.concept_name,
	'S' AS preferred,
	4180186 AS language_concept_id -- English
FROM sources.icd10cn_concept ic
JOIN concept c ON c.vocabulary_id = 'ICDO3'
	AND c.concept_class_id = 'ICDO Histology'
	--ICD10CN Morphology codes that may match ICDO codes
	AND ic.concept_code_clean ~ '^M\d{4}0\/\d$'
	--Same Behaviour code
	AND RIGHT(c.concept_code, 1) = RIGHT(ic.concept_code_clean, 1)
	--Same Morphology code
	AND LEFT(c.concept_code, 4) = LEFT(TRIM(LEADING 'M' FROM ic.concept_code_clean), 4)
WHERE ic.concept_code <> 'Metadata'

UNION

--Preserve original names as synonyms
SELECT ic.concept_code_clean,
	'ICD10CN' AS source,
	ic.concept_name,
	NULL AS preferred,
	4182948 AS language_concept_id -- Chinese
FROM sources.icd10cn_concept ic
WHERE ic.concept_code <> 'Metadata';

--5. If there are no other sources, save Google translation as source
INSERT INTO name_source
SELECT DISTINCT
	--Pick preferred english synonym
	ic.concept_code_clean,
	'Google Translate',
	FIRST_VALUE(ic.english_concept_name) OVER (
		PARTITION BY ic.concept_code_clean ORDER BY LENGTH(ic.english_concept_name)
		) || ' (machine translation)',
	'S' AS preferred,
	4180186 AS language_concept_id -- English
FROM sources.icd10cn_concept ic
WHERE NOT EXISTS (
		SELECT 1
		FROM name_source ns
		WHERE ns.concept_code_clean = ic.concept_code_clean
			AND ns.language_concept_id = 4180186
		)
	AND ic.concept_code <> 'Metadata';

--6. Fill concept_stage with cleaned codes and English names
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	concept_code,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT ns.concept_name,
	'Undefined' AS domain_id,
	'ICD10CN' AS vocabulary_id,
	CASE 
		WHEN ic.concept_code_clean ~ '[A-Z]\d{2}\.'
			THEN 'ICD10 code'
		WHEN ic.concept_code_clean ~ '^[A-Z]\d{2}$'
			THEN 'ICD10 Hierarchy'
		WHEN ic.concept_code_clean ~ '^M\d{5}\/\d$'
			THEN 'ICD10 Histology'
		WHEN ch.chapter_code IS NOT NULL
			THEN 'ICD10 Chapter'
		WHEN ic.concept_code_clean LIKE '%-%'
			THEN 'ICD10 SubChapter'
		ELSE NULL --Not supposed to be encountered
		END AS concept_class_id,
	ic.concept_code_clean AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD10CN'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM sources.icd10cn_concept ic
JOIN name_source ns ON ns.concept_code_clean = ic.concept_code_clean
	AND ns.preferred = 'S'
LEFT JOIN icd10cn_chapters ch ON ch.chapter_code = ic.concept_code_clean

UNION ALL

VALUES ('Emergency use of U07.1 | Disease caused by severe acute respiratory syndrome coronavirus 2','Observation','ICD10CN','ICD10 code','U07.1',TO_DATE('19700101','yyyymmdd'),TO_DATE('20991231','yyyymmdd')),
	('Confirmed COVID-19, excluding pneumonia (machine translation)','Observation','ICD10CN','ICD10 code','U07.100x002',TO_DATE('19700101','yyyymmdd'),TO_DATE('20991231','yyyymmdd')),
	('COVID-19 (machine translation)','Observation','ICD10CN','ICD10 code','U07.100',TO_DATE('19700101','yyyymmdd'),TO_DATE('20991231','yyyymmdd')),
	('Suspected case of COVID-19 (machine translation)','Condition','ICD10CN','ICD10 code','Z03.800x001',TO_DATE('19700101','yyyymmdd'),TO_DATE('20991231','yyyymmdd')),
	('COVID-19 pneumonia (machine translation)','Observation','ICD10CN','ICD10 code','U07.100x001',TO_DATE('19700101','yyyymmdd'),TO_DATE('20991231','yyyymmdd')),
	('COVID-19 pneumonia (machine translation)','Observation','ICD10CN','ICD10 code','U07.100x003',TO_DATE('19700101','yyyymmdd'),TO_DATE('20991231','yyyymmdd'));

--7. Fill table concept_synonym_stage with chinese and English names
INSERT INTO concept_synonym_stage (
	synonym_name,
	synonym_concept_code,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT ns.concept_name AS synonym_name,
	ns.concept_code_clean AS synonym_concept_code,
	'ICD10CN' AS synonym_vocabulary_id,
	ns.language_concept_id
FROM name_source ns

UNION ALL

VALUES ('新型冠状病毒肺炎疑似病例','Z03.800x001','ICD10CN',4182948),
	('Emergency use of U07.1 | COVID-19','U07.1','ICD10CN',4180186),
	('新型冠状病毒肺炎临床诊断病例','U07.100x003','ICD10CN',4182948),
	('新型冠状病毒肺炎','U07.100x001','ICD10CN',4182948),
	('2019冠状病毒病','U07.100','ICD10CN',4182948),
	('新型冠状病毒感染','U07.100x002','ICD10CN',4182948);

--8. Fill concept_relationship_stage
-- Preserve ICD10CN internal hierarchy (even if concepts are non-standard)
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT ic1.concept_code_clean AS concept_code_1,
	ic2.concept_code_clean AS concept_code_2,
	'ICD10CN' AS vocabulary_id_1,
	'ICD10CN' AS vocabulary_id_2,
	r.relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD10CN'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM sources.icd10cn_concept_relationship r
JOIN sources.icd10cn_concept ic1 ON ic1.concept_id = r.concept_id_1
JOIN sources.icd10cn_concept ic2 ON ic2.concept_id = r.concept_id_2
WHERE r.relationship_id = 'Is a'
	AND ic1.concept_code_clean <> ic2.concept_code_clean;

--9. Find parents among ICD10 and ICDO3 to inherit mapping relationships from
CREATE INDEX IF NOT EXISTS trgm_idx ON concept_stage USING GIN (concept_code devv5.gin_trgm_ops); --For LIKE patterns
ANALYZE concept_stage;

INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT i.concept_code as concept_code_1,
	c.concept_code as concept_code_2,
	'ICD10CN' as vocabulary_id_1,
	c.vocabulary_id as vocabulary_id_2,
	'Maps to' as relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD10CN'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM (
	--ICDO3: parents share first 4 digits of morphology and last digit of behaviour
	SELECT cs.concept_code,
		c2.concept_id
	FROM concept_stage cs
	JOIN concept c1 ON --Find right Histology code to translate to Condition
		c1.vocabulary_id = 'ICDO3'
		AND c1.concept_class_id = 'ICDO Histology'
		AND cs.concept_class_id = 'ICD10 Histology'
		AND
		--Same Behaviour code
		RIGHT(c1.concept_code, 1) = RIGHT(cs.concept_code, 1)
		AND
		--Same Morphology code beginning
		LEFT(c1.concept_code, 4) = LEFT(TRIM(LEADING 'M' FROM cs.concept_code), 4)
	JOIN concept c2 ON --Translate to ICDO Condition code to get correct mappings
		c2.vocabulary_id = 'ICDO3'
		AND c2.concept_class_id = 'ICDO Condition'
		AND c2.concept_code = c1.concept_code || '-NULL'
	--Commented since we allow fuzzy match uphill for this iteration
	-- where substring (c.concept_code from 6 for 1) = '0' --Exact match to ICDO is MXXXX0/X
	
	UNION ALL
	
	SELECT DISTINCT cs.concept_code,
		FIRST_VALUE(c.concept_id) OVER (
			PARTITION BY cs.concept_code ORDER BY LENGTH(c.concept_code) DESC --Longest matching code for best results
			) AS concept_id
	FROM concept_stage cs
	JOIN concept c ON c.vocabulary_id = 'ICD10'
		AND
		--Allow fuzzy match uphill for this iteration
		cs.concept_code LIKE c.concept_code || '%'
	WHERE cs.concept_class_id IN (
			'ICD10 code',
			'ICD10 Hierarchy'
			)
	) i
JOIN concept_relationship r ON r.concept_id_1 = i.concept_id
	AND r.invalid_reason IS NULL
	AND r.relationship_id = 'Maps to'
JOIN concept c ON c.concept_id = r.concept_id_2;

--10. Append resulting file from Medical Coder (in concept_relationship_stage format) to concept_relationship_stage
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--11. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--12. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--13. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--14. Update Domains 
--ICD10 Histologies are always Condition
UPDATE concept_stage
SET domain_id = 'Condition'
WHERE concept_class_id = 'ICD10 Histology';

--From mapping target
UPDATE concept_stage cs
SET domain_id = i.domain_id
FROM (
	SELECT DISTINCT cs1.concept_code,
		FIRST_VALUE(c2.domain_id) OVER (
			PARTITION BY cs1.concept_code ORDER BY CASE c2.domain_id
					WHEN 'Condition'
						THEN 1
					WHEN 'Observation'
						THEN 2
					WHEN 'Procedure'
						THEN 3
					WHEN 'Measurement'
						THEN 4
					WHEN 'Device'
						THEN 5
					ELSE 6
					END
			) AS domain_id
	FROM concept_relationship_stage crs
	JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_1
		AND cs1.vocabulary_id = crs.vocabulary_id_1
	JOIN concept c2 ON c2.concept_code = crs.concept_code_2
		AND c2.vocabulary_id = crs.vocabulary_id_2
	WHERE crs.relationship_id = 'Maps to'
		AND crs.invalid_reason IS NULL
	) i
WHERE i.concept_code = cs.concept_code
	AND cs.domain_id = 'Undefined';

--From descendants - for cathegories and groupers
UPDATE concept_stage cs
SET domain_id = i.domain_id
FROM (
	SELECT DISTINCT cs1.concept_code,
		FIRST_VALUE(cs2.domain_id) OVER (
			PARTITION BY cs1.concept_code ORDER BY CASE cs2.domain_id
					WHEN 'Condition'
						THEN 1
					WHEN 'Observation'
						THEN 2
					WHEN 'Procedure'
						THEN 3
					WHEN 'Measurement'
						THEN 4
					WHEN 'Device'
						THEN 5
					ELSE 6
					END
			) AS domain_id
	FROM concept_stage cs1
	JOIN concept_relationship_stage crs ON crs.relationship_id = 'Is a'
		AND crs.concept_code_2 = cs1.concept_code
		AND crs.invalid_reason IS NULL
		AND cs1.vocabulary_id = crs.vocabulary_id_2
	JOIN concept_stage cs2 ON cs2.concept_code = crs.concept_code_1
		AND cs2.vocabulary_id = crs.vocabulary_id_1
	WHERE cs1.domain_id = 'Undefined'
	) i
WHERE i.concept_code = cs.concept_code
	AND cs.domain_id = 'Undefined';

--Only highest level of hierarchy has Domain still not defined at this point
UPDATE concept_stage
SET domain_id = 'Observation'
WHERE domain_id = 'Undefined';

--15. Add "subsumes" relationship between concepts where the concept_code is like of another
-- Although 'Is a' relations exist, it is done to differentiate between "true" source-provided hierarchy and convenient "jump" links we build now
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	c1.vocabulary_id AS vocabulary_id_1,
	c1.vocabulary_id AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD10CN'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept_stage c1,
	concept_stage c2
WHERE c2.concept_code LIKE c1.concept_code || '%'
	AND c1.concept_code <> c2.concept_code
	AND 'ICD10 Histology' NOT IN (
		c1.concept_class_id,
		c2.concept_class_id
		)
	AND c1.concept_code NOT LIKE '%-%'
	AND c2.concept_code NOT LIKE '%-%'
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage r_int
		WHERE r_int.concept_code_1 = c1.concept_code
			AND r_int.concept_code_2 = c2.concept_code
			AND r_int.relationship_id = 'Subsumes'
		);

--Build same for Hierarchy intervals
DROP TABLE IF EXISTS intervals;
CREATE UNLOGGED TABLE intervals AS
SELECT DISTINCT c.concept_code,
	LEFT(c.concept_code, 3) AS start_code,
	RIGHT(c.concept_code, 3) AS end_code
FROM concept_stage c
WHERE c.concept_code LIKE '%-%';

--Intervals that are parts of other intervals
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	'ICD10CN' AS vocabulary_id_1,
	'ICD10CN' AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD10CN'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM intervals c1,
	intervals c2
WHERE c1.start_code <= c2.start_code
	AND c1.end_code >= c2.end_code
	AND c1.concept_code <> c2.concept_code
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage r_int
		WHERE r_int.concept_code_1 = c1.concept_code
			AND r_int.concept_code_2 = c2.concept_code
			AND r_int.relationship_id = 'Subsumes'
		);

--All ICD10 codes as part of intervals
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	'ICD10CN' AS vocabulary_id_1,
	'ICD10CN' AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD10CN'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM intervals c1
JOIN concept_stage c2 ON LEFT(c2.concept_code, 3) BETWEEN c1.start_code
		AND c1.end_code
	AND c2.concept_class_id <> 'ICD10 Histology'
	AND c2.concept_code NOT LIKE '%-%'
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage r_int
		WHERE r_int.concept_code_1 = c1.concept_code
			AND r_int.concept_code_2 = c2.concept_code
			AND r_int.relationship_id = 'Subsumes'
		);

--16. Cleanup
DROP INDEX trgm_idx;
DROP TABLE icd10cn_chapters, name_source, intervals;

-- At the end, the three tables concept_stage, concept_relationship_stage AND concept_synonym_stage should be ready to be fed into the generic_update.sql script