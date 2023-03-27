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
* Authors: Eduard Korchmar, Timur Vakhitov, Dmitry Dymshyts, Christian Reich, Maria Khitrun
* Date: 2022
**************************************************************************/

--1. Latest update construction
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'OPS',
	pVocabularyDate			=> TO_DATE ('20220101', 'yyyymmdd'),
	pVocabularyVersion		=> 'OPS Version 2022',
	pVocabularyDevSchema	=> 'DEV_OPS'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Input source tables ops_src_agg and ops_mod_src for all years
--WbImport example

--4. Unite sources in a single table with full names
DROP TABLE IF EXISTS hierarchy_full;
CREATE UNLOGGED TABLE hierarchy_full AS
SELECT DISTINCT ON (s0.code) s0.code,
	s0.label_de,
	s0.superclass,
	s0.modifiedby,
	TO_DATE(s0.min_year::TEXT, 'yyyy') AS valid_start_date,
	CASE 
		WHEN s0.end_year = s0.max_year
			THEN TO_DATE('20991231', 'yyyymmdd')
		ELSE TO_DATE(end_year::TEXT || '1231', 'yyyymmdd')
		END AS valid_end_date
FROM (
	SELECT o.code,
		o.label_de,
		o.superclass,
		o.modifiedby,
		MIN(year) OVER (PARTITION BY o.code) min_year,
		o.year AS end_year,
		MAX(year) OVER () AS max_year
	FROM dev_ops.ops_src_agg o
	) s0
ORDER BY s0.code,
	s0.end_year DESC;

DROP TABLE IF EXISTS modifiers_append;
CREATE UNLOGGED TABLE modifiers_append AS
SELECT DISTINCT ON (
		s0.modifier,
		s0.code
		) s0.modifier,
	s0.code,
	s0.label_de,
	s0.superclass,
	TO_DATE(s0.min_year::TEXT, 'yyyy') AS valid_start_date,
	CASE 
		WHEN s0.end_year = s0.max_year
			THEN TO_DATE('20991231', 'yyyymmdd')
		ELSE TO_DATE(end_year::TEXT || '1231', 'yyyymmdd')
		END AS valid_end_date
FROM (
	SELECT o.modifier,
		o.code,
		o.label_de,
		o.superclass,
		MIN(year) OVER (
			PARTITION BY o.modifier,
			o.code
			) min_year,
		o.year AS end_year,
		MAX(year) OVER () AS max_year
	FROM dev_ops.ops_mod_src o
	) s0
ORDER BY s0.modifier,
	s0.code,
	s0.end_year DESC;

--imprint modifiers into main table
--modifier = superclass
INSERT INTO hierarchy_full (
	code,
	label_de,
	superclass,
	valid_start_date,
	valid_end_date
	)
SELECT CONCAT (
		h.code,
		a.code
		) AS code,
	a.label_de AS label_de,
	h.code AS superclass,
	CASE 
		WHEN h.valid_start_date > a.valid_start_date
			THEN h.valid_start_date
		ELSE a.valid_start_date
		END AS valid_start_date,
	CASE 
		WHEN h.valid_end_date < a.valid_end_date
			THEN h.valid_end_date
		ELSE a.valid_end_date
		END AS valid_end_date
FROM hierarchy_full h
JOIN modifiers_append a ON h.modifiedby = a.modifier
WHERE a.modifier = a.superclass
	AND h.valid_start_date <= a.valid_end_date
	AND a.valid_start_date <= h.valid_end_date;

--superclass must be created from parent modifier
INSERT INTO hierarchy_full (
	code,
	label_de,
	superclass,
	valid_start_date,
	valid_end_date
	)
SELECT CONCAT (
		h.code,
		a.code
		) AS code,
	a.label_de AS label_de,
	CONCAT (
		h.code,
		b.code
		) AS superclass,
	CASE 
		WHEN h.valid_start_date > a.valid_start_date
			THEN h.valid_start_date
		ELSE a.valid_start_date
		END AS valid_start_date,
	CASE 
		WHEN h.valid_end_date < a.valid_end_date
			THEN h.valid_end_date
		ELSE a.valid_end_date
		END AS valid_end_date
FROM hierarchy_full h
JOIN modifiers_append a ON h.modifiedby = a.modifier
--get parent modifier
JOIN modifiers_append b ON b.modifier = a.modifier
	AND b.code = a.superclass
WHERE a.modifier <> a.superclass
	AND h.valid_start_date <= a.valid_end_date
	AND a.valid_start_date <= h.valid_end_date;

--5. Use hierarchy_full to create a single table concept_stage_de with full German concept names
DROP TABLE IF EXISTS concept_stage_de;
CREATE UNLOGGED TABLE concept_stage_de AS
	WITH RECURSIVE code_full_term AS (
			SELECT code,
				label_de AS full_term,
				superclass,
				valid_start_date,
				valid_end_date
			FROM hierarchy_full
			
			UNION ALL
			
			SELECT t.code,
				s.label_de || ': ' || t.full_term AS full_term,
				s.superclass,
				t.valid_start_date,
				t.valid_end_date
			FROM code_full_term t
			JOIN hierarchy_full s ON t.superclass = s.code
			)
SELECT code AS concept_code,
	full_term AS concept_name_de,
	valid_start_date,
	valid_end_date
FROM code_full_term
WHERE superclass LIKE '%...%';-- down to lowest parental level for full name

--6. Rely on concept_manual and concept_relationship_manual to retrieve correct translated names
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT 'Placeholder English term' concept_name,
	'Procedure' AS domain_id,
	'OPS' AS vocabulary_id,
	'Procedure' AS concept_class_id,
	s0.concept_code,
	s0.valid_start_date,
	s0.valid_end_date,
	CASE 
		WHEN s0.valid_end_date < CURRENT_DATE
			THEN 'D'
		END AS invalid_reason
FROM (
	SELECT concept_code,
		--Sum lifespans of the duplicative concepts
		MIN(valid_start_date) AS valid_start_date,
		MAX(valid_end_date) AS valid_end_date
	FROM concept_stage_de
	GROUP BY concept_code
	) s0;

--7. Fill concept_synonym_stage with original full German names
INSERT INTO concept_synonym_stage (
	synonym_name,
	synonym_concept_code,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT concept_name_de AS synonym_name,
	concept_code AS synonym_concept_code,
	'OPS' AS synonym_vocabulary_id,
	4182504 AS language_concept_id --German
FROM concept_stage_de;

--8. Insert the automated translation in concept_manual table:
/*DROP TABLE IF EXISTS ops_translation_auto;
CREATE TABLE ops_translation_auto AS
SELECT synonym_concept_code AS concept_code,
	synonym_name AS german_term,
	NULL::TEXT AS english_term
FROM dev_ops.concept_synonym_stage
WHERE language_concept_id = 4182504
	AND synonym_concept_code IN (
		SELECT concept_code
		FROM dev_ops.concept_stage
		WHERE concept_name LIKE 'Placeholder%'
		);

DO $_$
BEGIN
	PERFORM devv5.GTranslate(
		pInputTable    =>'ops_translation_auto',
		pInputField    =>'german_term',
		pOutputField   =>'english_term',
		pDestLang      =>'en'
	);
END $_$;

INSERT INTO dev_ops.concept_manual (
	concept_name,
	vocabulary_id,
	concept_code,
	invalid_reason
	)
SELECT vocabulary_pack.CutConceptName(english_term) AS concept_name,
	'OPS' AS vocabulary_id,
	t.concept_code AS concept_code,
	'X' AS invalid_reason
FROM dev_ops.ops_translation_auto t
WHERE concept_code NOT IN (
		SELECT concept_code
		FROM dev_ops.concept_manual
		);
*/

--9. Fill internal hierarchy in concept_relationship_stage; Mappings come from manual table
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT h.code AS concept_code_1,
	h.superclass AS concept_code_2,
	'OPS' AS vocabulary_id_1,
	'OPS' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM hierarchy_full h
JOIN concept_stage a ON h.superclass = a.concept_code;

--10. Process manual tables
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--11. Automated scripts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--12. Clean up
DROP TABLE hierarchy_full;
DROP TABLE concept_stage_de;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script