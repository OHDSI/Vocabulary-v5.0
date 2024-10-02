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
* Date: 2021
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
	AND c.concept_class_id NOT LIKE '%Chapter%'
	AND REPLACE(ic.concept_code_clean, '.x00', '') = c.concept_code
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
	AND c.concept_class_id NOT LIKE '%Chapter%'
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

VALUES
	('Emergency use of U07.1 | COVID-19, virus identified','Condition','ICD10CN','ICD10 code','U07.1',TO_DATE('19700101','yyyymmdd'),TO_DATE('20991231','yyyymmdd')),
	('Emergency use of U07.2 | COVID-19, virus not identified','Condition','ICD10CN','ICD10 code','U07.2',TO_DATE('19700101','yyyymmdd'),TO_DATE('20991231','yyyymmdd')),
	('COVID-19, excluding pneumonia','Condition','ICD10CN','ICD10 code','U07.100x002',TO_DATE('19700101','yyyymmdd'),TO_DATE('20991231','yyyymmdd')),
	('COVID-19','Condition','ICD10CN','ICD10 code','U07.100',TO_DATE('19700101','yyyymmdd'),TO_DATE('20991231','yyyymmdd')),
	('Suspected case of COVID-19 pneumonia','Observation','ICD10CN','ICD10 code','Z03.800x001',TO_DATE('19700101','yyyymmdd'),TO_DATE('20991231','yyyymmdd')),
	('COVID-19 pneumonia','Condition','ICD10CN','ICD10 code','U07.100x001',TO_DATE('19700101','yyyymmdd'),TO_DATE('20991231','yyyymmdd')),
	('COVID-19 pneumonia','Condition','ICD10CN','ICD10 code','U07.100x003',TO_DATE('19700101','yyyymmdd'),TO_DATE('20991231','yyyymmdd'));

--6.1. Replace names with manually corrected English components wherever possible
WITH new_names
AS (
	SELECT *
	FROM (
		VALUES	('Hepatitis B virus after transfusion', 'B16.903'),
				('Post-transfusion hepatitis', 'B19.901'),
				('Immune deficiency caused by human immunodeficiency virus disease', 'B23.201'),
				('Chronic granulomatous disease of childhood', 'D71.x01'),
				('IgM deficiency', 'D80.401'),
				('Lymphopenia syndrome', 'D81.601'),
				('Functional myasthenia', 'F45.804'),
				('Epileptic dementia', 'G40.903'),
				('Hypertensive Crisis', 'I10.x01'),
				('Coronary atherosclerotic heart disease', 'I25.103'),
				('Arrhythmia type of coronary heart disease', 'I25.104'),
				('Congenital cardiomyopathy', 'I42.401'),
				('Total acinar emphysema', 'J43.101'),
				('Chronic emphysematous bronchitis', 'J44.803'),
				('Cough variant asthma', 'J45.005'),
				('Dysbacteriosis of intestinal flora', 'K59.101'),
				('HELLP syndrome', 'O14.101'),
				('Early mild hyperemesis gravidarum', 'O21.001'),
				('Transient tachypnea of the newborn', 'P22.101'),
				('Neonatal dyspnea', 'P22.801'),
				('Neonatal achalasia', 'P92.001'),
				('Corrected transposition of great arteries', 'Q20.301'),
				('Transitional atrioventricular septal defect', 'Q21.204'),
				('Congenital chordae tendineae of mitral valve', 'Q23.803'),
				('Congenital superior septum of aortic valve', 'Q23.804'),
				('Congenital mitral valve cleft', 'Q23.805'),
				('Congenital mitral malformation', 'Q23.901'),
				('Congenital coronary hypoplasia', 'Q24.506'),
				('Congenital coronary artery fistula to pulmonary artery', 'Q24.507'),
				('Congenital coronary malformation', 'Q24.508'),
				('Congenital coronary arteriovenous fistula', 'Q24.509'),
				('Apical coronary sinus syndrome', 'Q24.510'),
				('Congenital first degree atrioventricular block', 'Q24.601'),
				('Congenital second degree atrioventricular block', 'Q24.602'),
				('Congenital third degree atrioventricular block', 'Q24.603'),
				('False chordae tendineae', 'Q24.803'),
				('Crisscross heart', 'Q24.804'),
				('Left ventricular outflow tract hypertrophy', 'Q24.805'),
				('Congenital pericardial defect', 'Q24.808'),
				('Congenital diverticulum right atrium', 'Q24.811'),
				('Mesocardia', 'Q24.813'),
				('Congenital abnormality of ascending aorta', 'Q25.401'),
				('Congenital interrupted aortic arch', 'Q25.404'),
				('Dextrotransposition of aorta', 'Q25.407'),
				('Congenital absence of pulmonary artery', 'Q25.703'),
				('Congenital bronchial malformation', 'Q32.401'),
				('Congenital pulmonary cystic disease', 'Q33.001'),
				('Congenital absence of lobe of lung', 'Q33.301'),
				('Congenital pulmonary dysplasia', 'Q33.601'),
				('High altitude hypertension', 'T70.202')
		) AS t(concept_name, concept_code)
	)
UPDATE concept_stage cs
SET concept_name = i.concept_name
FROM new_names i
WHERE i.concept_code = cs.concept_code;

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

VALUES
	('新型冠状病毒肺炎疑似病例','Z03.800x001','ICD10CN',4182948),
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

--9. Update Domains
--ICD10 Histologies are always Condition
UPDATE concept_stage
SET domain_id = 'Condition'
WHERE concept_class_id = 'ICD10 Histology';

--10. Append resulting file from Medical Coder (in concept_relationship_stage format) to concept_relationship_stage
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--11. Find parents among ICD10 and ICDO3 to inherit mapping relationships from
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
SELECT i.concept_code AS concept_code_1,
	c.concept_code AS concept_code_2,
	'ICD10CN' AS vocabulary_id_1,
	c.vocabulary_id AS vocabulary_id_2,
	r.relationship_id AS relationship_id,
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
	--where substring (c.concept_code from 6 for 1) = '0' --Exact match to ICDO is MXXXX0/X
	
	UNION ALL
	
	SELECT DISTINCT cs.concept_code,
		FIRST_VALUE(c.concept_id) OVER (
			PARTITION BY cs.concept_code ORDER BY LENGTH(c.concept_code) DESC --Longest matching code for best results
			) AS concept_id
	FROM concept_stage cs
	JOIN concept c ON c.vocabulary_id = 'ICD10'
		AND c.concept_class_id NOT LIKE '%Chapter%'
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
	AND r.relationship_id IN (
		'Maps to',
		'Maps to value'
		)
JOIN concept c ON c.concept_id = r.concept_id_2
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = i.concept_code
			AND crs.invalid_reason IS NULL
			AND crs.relationship_id = 'Maps to'
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_manual crm
		WHERE crm.concept_code_1 = i.concept_code
			AND crm.vocabulary_id_1 = 'ICD10CN'
		);

--12. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--13. 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--14. Add mapping from deprecated to fresh concepts (value level)
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

--15. Update domain from mapping target
UPDATE concept_stage cs
SET domain_id = i.domain_id
FROM (
	SELECT DISTINCT ON (cs1.concept_code) cs1.concept_code,
		c2.domain_id
	FROM concept_relationship_stage crs
	JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_1
		AND cs1.vocabulary_id = crs.vocabulary_id_1
	JOIN concept c2 ON c2.concept_code = crs.concept_code_2
		AND c2.vocabulary_id = crs.vocabulary_id_2
	WHERE crs.relationship_id = 'Maps to'
		AND crs.invalid_reason IS NULL
	ORDER BY cs1.concept_code,
		CASE c2.domain_id
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
			END
	) i
WHERE i.concept_code = cs.concept_code
	AND cs.domain_id = 'Undefined';

--Update domain from descendants - for cathegories and groupers
UPDATE concept_stage cs
SET domain_id = i.domain_id
FROM (
	SELECT DISTINCT ON (cs1.concept_code) cs1.concept_code,
		cs2.domain_id
	FROM concept_stage cs1
	JOIN concept_relationship_stage crs ON crs.relationship_id = 'Is a'
		AND crs.concept_code_2 = cs1.concept_code
		AND crs.invalid_reason IS NULL
		AND cs1.vocabulary_id = crs.vocabulary_id_2
	JOIN concept_stage cs2 ON cs2.concept_code = crs.concept_code_1
		AND cs2.vocabulary_id = crs.vocabulary_id_1
	WHERE cs1.domain_id = 'Undefined'
	ORDER BY cs1.concept_code,
		CASE cs2.domain_id
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
			END
	) i
WHERE i.concept_code = cs.concept_code
	AND cs.domain_id = 'Undefined';

--16. Only highest level of hierarchy has Domain still not defined at this point
UPDATE concept_stage
SET domain_id = 'Observation'
WHERE domain_id = 'Undefined';

UPDATE concept_stage
SET domain_id = 'Procedure'
WHERE concept_code IN (
		'R93.5',
		'R93.6',
		'R93.7',
		'R93.8',
		'R94.3',
		'R90',
		'R90.8',
		'R91',
		'R92',
		'R93',
		'R93.0',
		'R93.1',
		'R93.2',
		'R93.3',
		'R93.4'
		);

UPDATE concept_stage
SET domain_id = 'Condition'
WHERE concept_code ILIKE '%C%';

--Reuse domains from icd10
UPDATE concept_stage cs
SET domain_id = c.domain_id
FROM concept c
WHERE c.vocabulary_id = 'ICD10'
	AND c.concept_code = cs.concept_code
	AND c.concept_code IN (
		'U07.2',
		'C77',
		'C77.0',
		'C77.1',
		'C77.2',
		'C77.3',
		'C77.4',
		'C77.5',
		'C77.8',
		'C77.9',
		'C78.0',
		'C78.1',
		'C78.2',
		'C78.3',
		'C78.4',
		'C78.5',
		'C78.6',
		'C78.7',
		'C78.8',
		'C79.0',
		'C79.1',
		'C79.2',
		'C79.3',
		'C79.4',
		'C79.5',
		'C79.6',
		'C79.7',
		'R70.1',
		'Z40-Z54',
		'V90-V94',
		'Y60-Y69',
		'V80-V89',
		'V98-V99',
		'X50-X57',
		'W85-W99',
		'W50-W64',
		'X58-X59',
		'V10-V19',
		'V01-V09',
		'X00-X09',
		'Y40-Y59',
		'V95-V97',
		'Z30-Z39',
		'Z55-Z65',
		'V50-V59',
		'V70-V79',
		'Y35-Y36',
		'V60-V69',
		'Z70-Z76',
		'W65-W74',
		'X10-X19',
		'V40-V49',
		'V30-V39',
		'W00-W19',
		'X20-X29',
		'M15-M19',
		'X85-Y09',
		'M05-M14',
		'M50-M54',
		'M86-M90',
		'M20-M25',
		'M70-M79',
		'M91-M94',
		'M45-M49',
		'M65-M68'
		);

--17. Add "subsumes" relationship between concepts where the concept_code is like of another
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

--18. Cleanup
DROP INDEX trgm_idx;
DROP TABLE icd10cn_chapters, name_source, intervals;

-- At the end, the three tables concept_stage, concept_relationship_stage AND concept_synonym_stage should be ready to be fed into the generic_update.sql script