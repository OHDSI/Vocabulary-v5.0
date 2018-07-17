DROP TABLE IF EXISTS CONCEPT_STAGE_SN;
CREATE TABLE CONCEPT_STAGE_SN (LIKE CONCEPT_STAGE);

--1. Create core version of SNOMED without concept_id, domain_id, concept_class_id, standard_concept
INSERT INTO concept_stage_sn (
	concept_name,
	vocabulary_id,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT regexp_replace(coalesce(umls.concept_name, sct2.concept_name), ' (\([^)]*\))$', ''), -- pick the umls one first (if there) and trim something like "(procedure)"
	'SNOMED' AS vocabulary_id,
	sct2.concept_code,
	(
		SELECT latest_update
		FROM vocabulary_conversion
		WHERE vocabulary_id_v5 = 'SNOMED'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT SUBSTR(d.term, 1, 255) AS concept_name,
		d.conceptid::TEXT AS concept_code,
		c.active,
		ROW_NUMBER() OVER (
			PARTITION BY d.conceptid
			-- Order of preference: newest in sct2_concept, in sct2_desc, synonym, does not contain class in parenthesis
			ORDER BY TO_DATE(c.effectivetime, 'YYYYMMDD') DESC,
				TO_DATE(d.effectivetime, 'YYYYMMDD') DESC,
				CASE 
					WHEN typeid = 900000000000013009
						THEN 0
					ELSE 1
					END,
				CASE 
					WHEN term LIKE '%(%)%'
						THEN 1
					ELSE 0
					END,
				LENGTH(TERM) DESC,
				d.id DESC
			) AS rn
	FROM sources.amt_sct2_concept_full_au c,
		sources.amt_full_descr_drug_only d
	WHERE c.id = d.conceptid
		AND term IS NOT NULL
	) sct2
LEFT JOIN (
	-- get a better concept_name
	SELECT DISTINCT code AS concept_code,
		FIRST_VALUE(-- take the best str 
			SUBSTR(str, 1, 255)) OVER (
			PARTITION BY code ORDER BY CASE tty
					WHEN 'PT'
						THEN 1
					WHEN 'PTGB'
						THEN 2
					WHEN 'SY'
						THEN 3
					WHEN 'SYGB'
						THEN 4
					WHEN 'MTH_PT'
						THEN 5
					WHEN 'FN'
						THEN 6
					WHEN 'MTH_SY'
						THEN 7
					WHEN 'SB'
						THEN 8
					ELSE 10 -- default for the obsolete ones
					END
			) AS concept_name
	FROM sources.mrconso
	WHERE sab = 'SNOMEDCT_US'
		AND tty IN (
			'PT',
			'PTGB',
			'SY',
			'SYGB',
			'MTH_PT',
			'FN',
			'MTH_SY',
			'SB'
			)
	) umls ON sct2.concept_code = umls.concept_code
WHERE sct2.rn = 1
	AND sct2.active = 1;

--2. Create temporary table with extracted class information and terms ordered by some good precedence
DROP TABLE IF EXISTS tmp_concept_class;
CREATE UNLOGGED TABLE tmp_concept_class AS
SELECT *
FROM (
	SELECT concept_code,
		f7, -- extracted class
		ROW_NUMBER() OVER (
			PARTITION BY concept_code
			-- order of precedence: active, by class relevance, by highest number of parentheses
			ORDER BY active DESC,
				CASE f7
					WHEN 'disorder'
						THEN 1
					WHEN 'finding'
						THEN 2
					WHEN 'procedure'
						THEN 3
					WHEN 'regime/therapy'
						THEN 4
					WHEN 'qualifier value'
						THEN 5
					WHEN 'contextual qualifier'
						THEN 6
					WHEN 'body structure'
						THEN 7
					WHEN 'cell'
						THEN 8
					WHEN 'cell structure'
						THEN 9
					WHEN 'external anatomical feature'
						THEN 10
					WHEN 'organ component'
						THEN 11
					WHEN 'organism'
						THEN 12
					WHEN 'living organism'
						THEN 13
					WHEN 'physical object'
						THEN 14
					WHEN 'physical device'
						THEN 15
					WHEN 'physical force'
						THEN 16
					WHEN 'occupation'
						THEN 17
					WHEN 'person'
						THEN 18
					WHEN 'ethnic group'
						THEN 19
					WHEN 'religion/philosophy'
						THEN 20
					WHEN 'life style'
						THEN 21
					WHEN 'social concept'
						THEN 22
					WHEN 'racial group'
						THEN 23
					WHEN 'event'
						THEN 24
					WHEN 'life event - finding'
						THEN 25
					WHEN 'product'
						THEN 26
					WHEN 'substance'
						THEN 27
					WHEN 'assessment scale'
						THEN 28
					WHEN 'tumor staging'
						THEN 29
					WHEN 'staging scale'
						THEN 30
					WHEN 'specimen'
						THEN 31
					WHEN 'special concept'
						THEN 32
					WHEN 'observable entity'
						THEN 33
					WHEN 'namespace concept'
						THEN 34
					WHEN 'morphologic abnormality'
						THEN 35
					WHEN 'foundation metadata concept'
						THEN 36
					WHEN 'core metadata concept'
						THEN 37
					WHEN 'metadata'
						THEN 38
					WHEN 'environment'
						THEN 39
					WHEN 'geographic location'
						THEN 40
					WHEN 'situation'
						THEN 41
					WHEN 'situation'
						THEN 42
					WHEN 'context-dependent category'
						THEN 43
					WHEN 'biological function'
						THEN 44
					WHEN 'attribute'
						THEN 45
					WHEN 'administrative concept'
						THEN 46
					WHEN 'record artifact'
						THEN 47
					WHEN 'navigational concept'
						THEN 48
					WHEN 'inactive concept'
						THEN 49
					WHEN 'linkage concept'
						THEN 50
					WHEN 'link assertion'
						THEN 51
					WHEN 'environment / location'
						THEN 52
					WHEN 'AU substance'
						THEN 53
					WHEN 'AU qualifier'
						THEN 54
					WHEN 'medicinal product unit of use'
						THEN 55
					WHEN 'medicinal product pack'
						THEN 56
					WHEN 'medicinal product'
						THEN 57
					WHEN 'trade product pack'
						THEN 58
					WHEN 'trade product unit of use'
						THEN 59
					WHEN 'trade product'
						THEN 60
					WHEN 'containered trade product pack'
						THEN 61
					ELSE 99
					END,
				rnb
			) AS rnc
	FROM (
		SELECT concept_code,
			active,
			pc1,
			pc2,
			CASE 
				WHEN pc1 = 0
					OR pc2 = 0
					THEN term -- when no term records with parentheses
						-- extract class (called f7)
				ELSE substring(term, '\(([^(]+)\)$')
				END AS f7,
			rna AS rnb -- row number in SCT2_DESC_FULL_AU
		FROM (
			SELECT c.concept_code,
				d.term,
				d.active,
				(
					SELECT count(*)
					FROM regexp_matches(d.term, '\(', 'g')
					) pc1, -- parenthesis open count
				(
					SELECT count(*)
					FROM regexp_matches(d.term, '\)', 'g')
					) pc2, -- parenthesis close count
				ROW_NUMBER() OVER (
					PARTITION BY c.concept_code ORDER BY d.active DESC, -- first active ones
						(
							SELECT count(*)
							FROM regexp_matches(d.term, '\(', 'g')
							) DESC -- first the ones with the most parentheses - one of them the class info
					) rna -- row number in SCT2_DESC_FULL_AU
			FROM concept_stage_sn c
			JOIN sources.amt_full_descr_drug_only d ON d.conceptid::TEXT = c.concept_code
			WHERE c.vocabulary_id = 'SNOMED'
			) AS s0
		) AS s1
	) AS s2
WHERE rnc = 1;
CREATE INDEX x_cc_2cd ON tmp_concept_class (concept_code);

--3. Create reduced set of classes 
UPDATE concept_stage_sn cs
SET concept_class_id = CASE 
		WHEN F7 = 'disorder'
			THEN 'Clinical Finding'
		WHEN F7 = 'procedure'
			THEN 'Procedure'
		WHEN F7 = 'finding'
			THEN 'Clinical Finding'
		WHEN F7 = 'organism'
			THEN 'Organism'
		WHEN F7 = 'body structure'
			THEN 'Body Structure'
		WHEN F7 = 'substance'
			THEN 'Substance'
		WHEN F7 = 'product'
			THEN 'Pharma/Biol Product'
		WHEN F7 = 'event'
			THEN 'Event'
		WHEN F7 = 'qualifier value'
			THEN 'Qualifier Value'
		WHEN F7 = 'observable entity'
			THEN 'Observable Entity'
		WHEN F7 = 'situation'
			THEN 'Context-dependent'
		WHEN F7 = 'occupation'
			THEN 'Social Context'
		WHEN F7 = 'regime/therapy'
			THEN 'Procedure'
		WHEN F7 = 'morphologic abnormality'
			THEN 'Morph Abnormality'
		WHEN F7 = 'physical object'
			THEN 'Physical Object'
		WHEN F7 = 'specimen'
			THEN 'Specimen'
		WHEN F7 = 'environment'
			THEN 'Location'
		WHEN F7 = 'environment / location'
			THEN 'Location'
		WHEN F7 = 'context-dependent category'
			THEN 'Context-dependent'
		WHEN F7 = 'attribute'
			THEN 'Attribute'
		WHEN F7 = 'linkage concept'
			THEN 'Linkage Concept'
		WHEN F7 = 'assessment scale'
			THEN 'Staging / Scales'
		WHEN F7 = 'person'
			THEN 'Social Context'
		WHEN F7 = 'cell'
			THEN 'Body Structure'
		WHEN F7 = 'geographic location'
			THEN 'Location'
		WHEN F7 = 'cell structure'
			THEN 'Body Structure'
		WHEN F7 = 'ethnic group'
			THEN 'Social Context'
		WHEN F7 = 'tumor staging'
			THEN 'Staging / Scales'
		WHEN F7 = 'religion/philosophy'
			THEN 'Social Context'
		WHEN F7 = 'record artifact'
			THEN 'Record Artifact'
		WHEN F7 = 'physical force'
			THEN 'Physical Force'
		WHEN F7 = 'foundation metadata concept'
			THEN 'Model Comp'
		WHEN F7 = 'namespace concept'
			THEN 'Namespace Concept'
		WHEN F7 = 'administrative concept'
			THEN 'Admin Concept'
		WHEN F7 = 'biological function'
			THEN 'Biological Function'
		WHEN F7 = 'living organism'
			THEN 'Organism'
		WHEN F7 = 'life style'
			THEN 'Social Context'
		WHEN F7 = 'contextual qualifier'
			THEN 'Qualifier Value'
		WHEN F7 = 'staging scale'
			THEN 'Staging / Scales'
		WHEN F7 = 'life event - finding'
			THEN 'Event'
		WHEN F7 = 'social concept'
			THEN 'Social Context'
		WHEN F7 = 'core metadata concept'
			THEN 'Model Comp'
		WHEN F7 = 'special concept'
			THEN 'Special Concept'
		WHEN F7 = 'racial group'
			THEN 'Social Context'
		WHEN F7 = 'therapy'
			THEN 'Procedure'
		WHEN F7 = 'external anatomical feature'
			THEN 'Body Structure'
		WHEN F7 = 'organ component'
			THEN 'Body Structure'
		WHEN F7 = 'physical device'
			THEN 'Physical Object'
		WHEN F7 = 'linkage concept'
			THEN 'Linkage Concept'
		WHEN F7 = 'link assertion'
			THEN 'Linkage Assertion'
		WHEN F7 = 'metadata'
			THEN 'Model Comp'
		WHEN F7 = 'navigational concept'
			THEN 'Navi Concept'
		WHEN F7 = 'inactive concept'
			THEN 'Inactive Concept'
		WHEN F7 = 'AU substance'
			THEN 'AU Substance'
		WHEN F7 = 'AU qualifier'
			THEN 'AU Qualifier'
		WHEN F7 = 'medicinal product unit of use'
			THEN 'Med Product Unit'
		WHEN F7 = 'medicinal product pack'
			THEN 'Med Product Pack'
		WHEN F7 = 'medicinal product'
			THEN 'Medicinal Product'
		WHEN F7 = 'trade product pack'
			THEN 'Trade Product Pack'
		WHEN F7 = 'trade product'
			THEN 'Trade Product'
		WHEN F7 = 'trade product unit of use'
			THEN 'Trade Product Unit'
		WHEN F7 = 'containered trade product pack'
			THEN 'Containered Pack'
		ELSE 'Undefined'
		END
FROM tmp_concept_class cc
WHERE cc.concept_code = cs.concept_code;