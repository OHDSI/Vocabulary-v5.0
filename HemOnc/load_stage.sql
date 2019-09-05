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
* Date: 2019
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'HemOnc',
	pVocabularyDate			=> TO_DATE ('20190829', 'yyyymmdd'),
	pVocabularyVersion		=> 'HemOnc 2019-08-29',
	pVocabularyDevSchema	=> 'DEV_HEMONC'
);
END $_$;


--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Create concept_stage. Take only the folowing concept classes in the first iteration
INSERT INTO concept_stage
SELECT NULL AS concept_id,
	concept_name,
	CASE 
		WHEN h.concept_class_id IN (
				'Procedure',
				'Context'
				)
			THEN 'Procedure'
		WHEN h.concept_class_id IN (
				'Component',
				'Brand Name',
				'Component Class',
				'Route',
				'Regimen type'
				)
			THEN 'Drug'
		WHEN h.concept_class_id IN (
				'Condition',
				'Condition Class',
				'BioCondition'
				)
			THEN 'Condition'
		WHEN h.concept_class_id IN (
				'Regimen',
				'Modality'
				)
			THEN 'Regimen' --https://github.com/OHDSI/OncologyWG/issues/69
		ELSE 'Undefined'
		END AS domain_id,
	h.vocabulary_id,
	h.concept_class_id,
	CASE 
		WHEN h.concept_class_id = 'Condition Class'
			THEN 'C' -- let's make them classification concepts (in previos version Component Class was assigned manually, Jeremy fixed it in the 30-Aug-2019 release)
		WHEN concept_class_id = 'Modality'
			THEN 'S' -- can be used as a generic Regimen when we don't know what exact Chemo or Hormonotherapy patient got
		ELSE h.standard_concept
		END AS standard_concept,
	h.concept_code,
	h.valid_start_date,
	h.valid_end_date,
	h.invalid_reason
FROM sources.hemonc_cs h
WHERE h.concept_class_id IN (
		'Regimen type', -- type
		'Component Class', -- looks like ATC, perhaps require additional mapping to ATC, in a first run make them "C", then replace with ATC, still a lot of work
		'Component', -- ingredient, Standard if there's no equivalent in Rx, RxE
		'Context', -- therapy intent or line or other Context, STANDARD
		'Regimen', -- Standard
		'Brand Name', -- need to map to RxNorm, RxNorm Extension if possible, if not - leave it as is
		'Route',
		'Procedure',
		--added 30-Aug-2019
		'Modality'
		--need to be added, requires further analysis of relationships
		/*
		'BioCondition',
		'Condition',
		'Condition Class'
		*/
		)
	AND h.concept_name IS NOT NULL;

--4. Create concept_relationship_stage
INSERT INTO concept_relationship_stage
SELECT DISTINCT NULL::int4 AS concept_id_1,
	NULL::int4 AS concept_id_2,
	r.concept_code_1,
	r.concept_code_2,
	r.vocabulary_id_1,
	r.vocabulary_id_2,
	r.relationship_id,
	r.valid_start_date,
	r.valid_end_date,
	r.invalid_reason
FROM sources.hemonc_crs r
JOIN concept_stage cs ON cs.concept_code = r.concept_code_1
	AND cs.vocabulary_id = r.vocabulary_id_1
LEFT JOIN concept c ON c.concept_code = r.concept_code_2
	AND c.vocabulary_id = r.vocabulary_id_2
	AND c.vocabulary_id IN (
		'RxNorm',
		'RxNorm Extension'
		)
LEFT JOIN concept_stage cs2 ON cs2.concept_code = r.concept_code_2
	AND cs2.vocabulary_id = r.vocabulary_id_2
WHERE r.relationship_id NOT IN (
		-- these aren't investigated well yet
		'Has been compared to',
		'Can be preceded by',
		'Can be followed by'
		)
	--Antithymocyte globulin rabbit ATG was mapped to Thymoglobulin (Brand Name) , correct mapping will be added below
	AND NOT (
		r.concept_code_1 = '37'
		AND r.concept_code_2 = '225741'
		AND r.relationship_id = 'Maps to'
		)
	AND NOT (
		c.concept_code IS NULL
		AND cs2.concept_code IS NULL
		);

--5. Update relationships to precise ingredient, replace Precise Ingredient with Ingredient
UPDATE concept_relationship_stage crs
SET concept_code_2 = i.concept_code_2,
	vocabulary_id_2 = i.vocabulary_id_2
FROM (
	SELECT c1.concept_code concept_code_1,
		c1.vocabulary_id vocabulary_id_1,
		c2.concept_code concept_code_2,
		c2.vocabulary_id vocabulary_id_2
	FROM concept_relationship r
	JOIN concept c1 ON c1.concept_id = r.concept_id_1
		AND c1.vocabulary_id = 'RxNorm'
		AND c1.concept_class_id = 'Precise Ingredient'
	JOIN concept c2 ON c2.concept_id = r.concept_id_2
		AND c2.concept_class_id = 'Ingredient'
		AND c2.standard_concept = 'S'
	WHERE r.relationship_id = 'Form of'
		AND r.invalid_reason IS NULL
	) i
WHERE crs.concept_code_2 = i.concept_code_1
	AND crs.vocabulary_id_2 = i.vocabulary_id_1;

--6. Update wrong 'Maps to' and relationships from Regimen to Drugs to Brand Names
--and one totally incorrect drug form
--to do, make this step automatic
UPDATE concept_relationship_stage crs
SET concept_code_2 = i.new_code,
	vocabulary_id_2 = i.new_vocab
FROM (
	SELECT DISTINCT crs.concept_code_2 AS old_code,
		crs.vocabulary_id_2 AS old_vocab,
		c2.concept_code AS new_code,
		c2.vocabulary_id AS new_vocab
	FROM concept_relationship_stage crs
	JOIN concept c1 ON c1.concept_code = crs.concept_code_2
		AND c1.vocabulary_id = crs.vocabulary_id_2
		AND c1.vocabulary_id = 'RxNorm'
		AND c1.concept_class_id = 'Brand Name'
	JOIN concept_relationship cr ON cr.concept_id_1 = c1.concept_id
		AND cr.relationship_id = 'Brand name of'
		AND cr.invalid_reason IS NULL
	JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		AND c2.concept_class_id = 'Ingredient'
		AND c2.standard_concept = 'S'
	JOIN concept_stage cs ON cs.concept_code = crs.concept_code_1
		AND cs.concept_name NOT LIKE '% and %' -- avoiding the combinatory drugs, they are mapped manually, see union below
		AND c1.concept_code NOT IN (
			'2119715',
			'1927886'
			) -- Herceptin Hylecta , Rituxan Hycela -  need to make better automatic work-aroud when have time
	WHERE crs.relationship_id IN (
			'Maps to',
			'Has antineopl Rx',
			'Has immunosuppr Rx',
			'Has local therap Rx',
			'Has support med Rx'
			)
	--Clinical Drug Forms Picked up manually
	
	UNION ALL
	
	SELECT '1552344',
		'RxNorm',
		'2044421',
		'RxNorm'
	
	UNION ALL
	
	SELECT '1670317',
		'RxNorm',
		'1670309',
		'RxNorm'
	
	UNION ALL
	
	SELECT '794048',
		'RxNorm',
		'1942741',
		'RxNorm'
	
	UNION ALL
	
	SELECT '2119715',
		'RxNorm',
		'2119717', -- Herceptin Hylecta , Hyaluronidase / trastuzumab Injection [Herceptin Hylecta]
		'RxNorm'
	
	UNION ALL
	
	SELECT '1927886',
		'RxNorm',
		'1927888', -- Rituxan Hycela , Hyaluronidase / rituximab Injection [Rituxan Hycela] 
		'RxNorm'
	) i
WHERE crs.concept_code_2 = i.old_code
	AND crs.vocabulary_id_2 = i.old_vocab;

--7. Build mappings to missing RxNorm, RxNorm Extension, need to do this because of RxNorm updates and adds new ingredients
INSERT INTO concept_relationship_stage
SELECT NULL AS concept_id_1,
	NULL AS concept_id_2,
	cs.concept_code,
	c.concept_code,
	cs.vocabulary_id,
	c.vocabulary_id,
	'Maps to' AS relationship_id,
	cs.valid_start_date,
	cs.valid_end_date,
	CASE 
		WHEN cs.valid_end_date = TO_DATE('20991231', 'yyyymmdd')
			THEN NULL
		ELSE 'D'
		END AS invalid_reason
FROM concept_stage cs
LEFT JOIN concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
	AND crs.vocabulary_id_1 = cs.vocabulary_id
	AND crs.vocabulary_id_2 LIKE 'Rx%'
	AND crs.relationship_id = 'Maps to'
JOIN concept c ON lower(c.concept_name) = lower(cs.concept_name)
	AND c.standard_concept = 'S'
	AND c.vocabulary_id LIKE 'Rx%'
WHERE cs.concept_class_id = 'Component'
	AND crs.concept_code_1 IS NULL;

--8. Build relationship from Regimen to Standard concepts
--only for newly added mappings between HemOnc and RxNorm (E)
INSERT INTO concept_relationship_stage
SELECT *
FROM (
	SELECT NULL::int4 AS concept_id_1,
		NULL::int4 AS concept_id_2,
		cs1.concept_code AS concept_code_1,
		r2.concept_code_2,
		cs1.vocabulary_id AS vocabulary_id_1,
		r2.vocabulary_id_2,
		CASE 
			WHEN r.relationship_id = 'Has antineoplastic'
				THEN 'Has antineopl Rx'
			WHEN r.relationship_id = 'Has immunosuppressor'
				THEN 'Has immunosuppr Rx'
			WHEN r.relationship_id = 'Has local Therapy'
				THEN 'Has local therap Rx'
			WHEN r.relationship_id = 'Has supportive med'
				THEN 'Has support med Rx'
			ELSE NULL
			END AS relationship_id,
		cs1.valid_start_date,
		cs1.valid_end_date,
		CASE 
			WHEN cs1.valid_end_date = TO_DATE('20991231', 'yyyymmdd')
				THEN NULL
			ELSE 'D'
			END AS invalid_reason
	FROM concept_stage cs1
	JOIN concept_relationship_stage r ON r.concept_code_1 = cs1.concept_code
		AND r.vocabulary_id_1 = cs1.vocabulary_id
	JOIN concept_stage cs2 ON cs2.concept_code = r.concept_code_2
		AND cs2.vocabulary_id = r.vocabulary_id_2
	JOIN concept_relationship_stage r2 ON r2.concept_code_1 = r.concept_code_2
		AND r2.vocabulary_id_2 LIKE 'Rx%'
		AND r2.relationship_id = 'Maps to'
	WHERE cs1.concept_class_id = 'Regimen'
		AND cs2.concept_class_id = 'Component'
	) i -- in order not to write the relationship_id case in the last condition, I use subquery
WHERE (
		i.concept_code_1,
		i.vocabulary_id_1,
		i.relationship_id,
		i.concept_code_2,
		i.vocabulary_id_2
		) NOT IN (
		SELECT concept_code_1,
			vocabulary_id_1,
			relationship_id,
			concept_code_2,
			vocabulary_id_2
		FROM concept_relationship_stage
		);

--9. Get rid of concept_relationship_stage duplicates
DELETE
FROM concept_relationship_stage crs
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = crs.concept_code_1
			AND crs_int.concept_code_2 = crs.concept_code_2
			AND crs_int.vocabulary_id_1 = crs.vocabulary_id_1
			AND crs_int.vocabulary_id_2 = crs.vocabulary_id_2
			AND crs_int.relationship_id = crs.relationship_id
			AND crs_int.ctid > crs.ctid
		);

--10. To build hierarchy relationships from RxNorm (E) concepts
INSERT INTO concept_relationship_stage
SELECT DISTINCT --results in  Duplications, which should be fine as we can have different ways to go through
	NULL::int4 AS concept_id_1,
	NULL::int4 AS concept_id_2,
	rb.concept_code_2,
	ra.concept_code_2,
	rb.vocabulary_id_2,
	ra.vocabulary_id_2,
	'Subsumes' AS relationship_id,
	ra.valid_start_date,
	ra.valid_end_date,
	ra.invalid_reason
FROM concept_relationship_stage ra --component  to rxnorm
JOIN concept_relationship_stage rb ON rb.concept_code_1 = ra.concept_code_1
	AND rb.vocabulary_id_1 = ra.vocabulary_id_1
	AND rb.relationship_id = 'Is a'
	AND rb.invalid_reason IS NULL -- component to component class
WHERE ra.relationship_id = 'Maps to'
	AND ra.invalid_reason IS NULL;

--11. Concept synonym
INSERT INTO concept_synonym_stage
SELECT css.*
FROM sources.hemonc_css css
JOIN concept_stage cs ON cs.concept_code = css.synonym_concept_code
	AND cs.vocabulary_id = css.synonym_vocabulary_id
	-- 15704 has empty name, typo, I suppose
	AND css.synonym_name IS NOT NULL;

--12. Replace 'Was replaced by' to 'Concept replaced by' (need to tell Jeremy)
UPDATE concept_relationship_stage
SET relationship_id = 'Concept replaced by'
WHERE relationship_id = 'Was replaced by';

UPDATE concept_stage cs
SET standard_concept = NULL,
	valid_end_date = (
		SELECT v.latest_update - 1
		FROM vocabulary v
		WHERE v.vocabulary_id = cs.vocabulary_id
		),
	invalid_reason = 'U'
FROM concept_relationship_stage crs
WHERE crs.concept_code_1 = cs.concept_code
	AND crs.vocabulary_id_1 = cs.vocabulary_id
	AND crs.relationship_id = 'Concept replaced by'
	AND crs.invalid_reason IS NULL;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script