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
* Date: 2021
**************************************************************************/

-- 1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'OPCS4',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.opcs LIMIT 1),
	pVocabularyVersion		=> (SELECT EXTRACT (YEAR FROM vocabulary_date)||' Release' FROM sources.opcs LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_OPCS4'
);
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Load into concept_stage from opcs
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
SELECT term AS concept_name, -- probably limit to 255 characters
	'Procedure' AS domain_id,
	'OPCS4' AS vocabulary_id,
	'Procedure' AS concept_class_id,
	'S' AS standard_concept,
	REGEXP_REPLACE(CUI, '([[:print:]]{3})([[:print:]]+)', '\1.\2','g') -- Dot after 3 characters
	AS concept_code,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.opcs o,
	vocabulary v
WHERE cui NOT LIKE '%-%' -- don't use chapters
	AND term NOT LIKE 'CHAPTER %'
	AND v.vocabulary_id = 'OPCS4';

--4. Create concept_relationship_stage only from manual source
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--5. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--6. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--7. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--8. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--9. Make concepts that have relationship 'Maps to' non-standard
UPDATE concept_stage cs
SET standard_concept = NULL
FROM concept_relationship_stage crs
WHERE cs.concept_code = crs.concept_code_1
	AND cs.vocabulary_id = crs.vocabulary_id_1
	AND crs.relationship_id = 'Maps to'
	AND crs.invalid_reason IS NULL;

--10. Update domain_id and concept_class for mapped concepts
UPDATE concept_stage cs
SET domain_id = i.domain_id,
	concept_class_id = i.concept_class_id
FROM (
	SELECT c.domain_id,
		c.concept_class_id,
		crs.concept_code_1,
		crs.vocabulary_id_1
	FROM concept c
	JOIN concept_relationship_stage crs ON crs.concept_code_2 = c.concept_code
		AND crs.vocabulary_id_2 = c.vocabulary_id
		AND crs.relationship_id IN (
			'Maps to',
			'Is a'
			)
		AND crs.invalid_reason IS NULL
	) i
WHERE cs.concept_code = i.concept_code_1
	AND cs.vocabulary_id = i.vocabulary_id_1;

--11. Delete concepts, that was deleted or retired
DELETE
FROM concept_stage cs
WHERE (
		cs.concept_code,
		cs.vocabulary_id
		) NOT IN (
		SELECT crs.concept_code_1,
			crs.vocabulary_id_1
		FROM concept_relationship_stage crs
		WHERE crs.invalid_reason IS NULL
		);

--12. Add distinct relationships to SNOMED attributes from target procedures for standard procedures
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT r.concept_code_1,
	y.concept_code,
	'OPCS4',
	'SNOMED',
	x.relationship_id,
	min(x.valid_start_date) OVER (PARTITION BY r.concept_code_1), --attribute may come from multiple parents
	x.valid_end_date
FROM concept_relationship_stage r
JOIN concept c ON r.concept_code_2 = c.concept_code
	AND c.vocabulary_id = 'SNOMED'
	AND c.concept_class_id = 'Procedure'
	AND r.invalid_reason IS NULL
	AND r.relationship_id = 'Is a'
JOIN concept_relationship x ON x.concept_id_1 = c.concept_id
	AND x.invalid_reason IS NULL
JOIN concept y ON y.concept_id = x.concept_id_2
	AND y.vocabulary_id = 'SNOMED'
	AND y.invalid_reason IS NULL
JOIN sources.sct2_rela_full_merged m ON -- check if relation exists in SNOMED sources, to avoid where procedures themselves are attributes of other concepts
	m.sourceid::VARCHAR = c.concept_code
	AND m.destinationid::VARCHAR = y.concept_code
WHERE x.relationship_id NOT IN (
		'Is a',
		'Subsumes',
		'Maps to',
		'Mapped from'
		);

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
