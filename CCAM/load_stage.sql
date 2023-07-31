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
* Authors: Dmitry Dymshyts, Timur Vakhitov
* Date: 2020
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CCAM',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.ccam_version LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.ccam_version LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_CCAM'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--1. Prepare hierarchy
DROP TABLE IF EXISTS ccam_hierarchy;
CREATE UNLOGGED TABLE ccam_hierarchy AS
	WITH RECURSIVE hierarchy_concepts AS (
			SELECT cod_pere,
				cod_menu,
				NULL AS an_chapter,
				rang::TEXT AS chapter,
				1 AS LEVEL
			FROM sources.ccam_r_menu
			WHERE cod_pere = 1
			
			UNION ALL
			
			SELECT c.cod_pere,
				c.cod_menu,
				hc.chapter AS an_chapter,
				CASE 
					WHEN hc.LEVEL = 1
						THEN LPAD(hc.chapter, 2, '0')
					ELSE hc.chapter
					END || '.' || LPAD(c.rang::TEXT, 2, '0') AS chapter,
				hc.LEVEL + 1
			FROM sources.ccam_r_menu c
			JOIN hierarchy_concepts hc ON hc.cod_menu = c.cod_pere
			)
SELECT hc.an_chapter,
	hc.chapter AS de_chapter,
	de.libelle AS descendant_libelle,
	l.cod_acte
FROM hierarchy_concepts hc
JOIN sources.ccam_r_menu de ON de.cod_menu = hc.cod_menu
LEFT JOIN LATERAL(SELECT DISTINCT a.cod_acte FROM sources.ccam_r_acte a WHERE a.menu_cod = de.cod_menu) l ON TRUE;

--2. Fill concept_stage with codes and without names
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
--load main codes
SELECT concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	CASE 
		WHEN valid_end_date = TO_DATE('20991231', 'yyyymmdd')
			THEN NULL
		ELSE 'D'
		END AS invalid_reason
FROM (
	SELECT NULL AS concept_name,
		'Procedure' AS domain_id,
		'CCAM' AS vocabulary_id,
		'Procedure' AS concept_class_id,
		NULL AS standard_concept,
		cod_acte AS concept_code,
		MIN(dt_creatio) AS valid_start_date,
		COALESCE(MAX(dt_fin), TO_DATE('20991231', 'yyyymmdd')) AS valid_end_date
	FROM sources.ccam_r_acte
	GROUP BY cod_acte
	) AS s0

UNION ALL

--load chapters
SELECT DISTINCT NULL AS concept_name,
	'Procedure' AS domain_id,
	'CCAM' AS vocabulary_id,
	'Proc Hierarchy' AS concept_class_id,
	NULL AS standard_concept,
	de_chapter AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date, --chapters have no real date
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM ccam_hierarchy

UNION ALL

--load groups
SELECT NULL AS concept_name,
	'Procedure' AS domain_id,
	'CCAM' AS vocabulary_id,
	'Proc Group' AS concept_class_id,
	NULL AS standard_concept,
	cod_regrou AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date, --groups have no real date
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.ccam_r_regroupement;

--3. Fix invalid_reason for upgraded concepts
UPDATE concept_stage cs
SET invalid_reason = 'U'
FROM (
	SELECT FIRST_VALUE(precedent) OVER (
			PARTITION BY cod_acte ORDER BY dt_fin DESC
			) AS prev_code
	FROM sources.ccam_r_acte
	WHERE precedent <> ''
	) a
WHERE cs.concept_code = a.prev_code;

--4. Append English names
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--5. Fill concept_relationship_stage with upgraded concepts
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT s0.concept_code_1,
	s0.concept_code_2,
	'CCAM' AS vocabulary_id_1,
	'CCAM' AS vocabulary_id_2,
	'Concept replaced by',
	cs.valid_end_date,
	TO_DATE('20991231', 'yyyymmdd')
FROM (
	SELECT DISTINCT FIRST_VALUE(precedent) OVER (
			PARTITION BY cod_acte ORDER BY dt_fin DESC
			) AS concept_code_1,
		cod_acte AS concept_code_2
	FROM sources.ccam_r_acte
	WHERE precedent <> ''
	) AS s0
JOIN concept_stage cs ON cs.concept_code = s0.concept_code_1;

--6. Fill concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)
--load main codes
SELECT synonym_concept_code,
	'CCAM' AS synonym_vocabulary_id,
	synonym_name,
	4180190 AS language_concept_id --French
FROM (
	--there are duplicates here, so "union"
	SELECT cod_acte AS synonym_concept_code,
		FIRST_VALUE(TRIM(nom_court)) OVER (
			PARTITION BY cod_acte ORDER BY dt_effet DESC --get the "last" name
			) AS synonym_name
	FROM sources.ccam_r_acte
	
	UNION
	
	SELECT cod_acte,
		FIRST_VALUE(TRIM(nom_long || nom_long0)) OVER (
			PARTITION BY cod_acte ORDER BY dt_effet DESC --get the "last" name
			) AS synonym_name
	FROM sources.ccam_r_acte
	) AS s0

UNION ALL

--load chapters
SELECT DISTINCT de_chapter AS synonym_concept_code,
	'CCAM' AS synonym_vocabulary_id,
	descendant_libelle AS synonym_name,
	4180190 AS language_concept_id --French
FROM ccam_hierarchy

UNION ALL

--load groups
SELECT cod_regrou AS synonym_concept_code,
	'CCAM' AS synonym_vocabulary_id,
	libelle AS synonym_name,
	4180190 AS language_concept_id --French
FROM sources.ccam_r_regroupement;

--7. Load hierarchy to the concept_relationship_stage
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
--hierarchy between chapters
SELECT DISTINCT an_chapter AS concept_code_1,
	de_chapter AS concept_code_2,
	'CCAM' AS vocabulary_id_1,
	'CCAM' AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM ccam_hierarchy
WHERE an_chapter IS NOT NULL --the first element in the source is technical root "ARBORESCENCE CCAM", so skipped

UNION ALL

--hierarchy between chapters and main codes
SELECT de_chapter AS concept_code_1,
	cod_acte AS concept_code_2,
	'CCAM' AS vocabulary_id_1,
	'CCAM' AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM ccam_hierarchy
WHERE cod_acte IS NOT NULL --some chapters have no hierarchy

UNION ALL

--hierarchy between main codes and groups
SELECT i.regrou_cod AS concept_code_1,
	cs.concept_code AS concept_code_2,
	'CCAM' AS vocabulary_id_1,
	'CCAM' AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	i.dt_modif AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept_stage cs
JOIN (
	SELECT DISTINCT acte_cod,
		LAST_VALUE(regrou_cod) OVER (
			PARTITION BY acte_cod,
			activ_cod ORDER BY dt_modif ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
			) AS regrou_cod, --get the "last" group code
		FIRST_VALUE(dt_modif) OVER (
			PARTITION BY acte_cod,
			activ_cod ORDER BY dt_modif
			) AS dt_modif, --get the min date (dt_modif=acdt_modif, so it doesn't matter which field we take)
		row_number () over (PARTITION BY acte_cod,regrou_cod ORDER BY dt_modif) as row_number_idx	-- AVOC-4014-CCAM-REFRESH	
	FROM sources.ccam_r_acte_ivite
	) i ON i.acte_cod = cs.concept_code
	where i.row_number_idx = 1;

--8. Append manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--9. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--10. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--11. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--12. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--13. Update domain_id from SNOMED
UPDATE concept_stage cs
SET domain_id = i.domain_id
FROM (
	SELECT DISTINCT crs.concept_code_1,
		FIRST_VALUE(c2.domain_id) OVER (
			PARTITION BY crs.concept_code_1 ORDER BY CASE c2.domain_id
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
	JOIN concept c2 ON c2.concept_code = crs.concept_code_2
		AND c2.vocabulary_id = crs.vocabulary_id_2
		AND c2.vocabulary_id = 'SNOMED'
	WHERE crs.relationship_id = 'Maps to'
		AND crs.invalid_reason IS NULL
		AND crs.vocabulary_id_1 = 'CCAM'
	) i
WHERE i.concept_code_1 = cs.concept_code;

--14. Cleaning
DROP TABLE ccam_hierarchy;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script