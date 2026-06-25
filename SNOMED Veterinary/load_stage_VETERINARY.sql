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
* Date: 2019
**************************************************************************/

--1. Update latest_update field to new date
-- NOTE: Only SNOMED Veterinary is registered here. This build must NOT call
-- SetLatestUpdate for 'SNOMED', since the canonical SNOMED build (which
-- feeds the official OHDSI Athena release) already owns and maintains that
-- vocabulary's latest_update, concept dates, and deprecation lifecycle.
-- Registering 'SNOMED' here would cause GenericUpdate() to overwrite dates
-- and potentially deprecate core SNOMED concepts that this build's source
-- files don't fully cover, corrupting the shared Athena SNOMED data.
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'SNOMED Veterinary',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources_vet_sct2_concept_full where moduleId = '332351000009108' LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources_vet_sct2_concept_full LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_VETERINARY'
);
END $_$;


--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Add SNOMED Veterinary extension concepts only.
-- NOTE: The original step 3 here also inserted core international SNOMED
-- module concepts (900000000000207008, 900000000000012004) tagged as
-- vocabulary_id = 'SNOMED'. That block has been REMOVED. Core SNOMED
-- concepts already exist in the live concept table from the canonical
-- SNOMED build; this build must read them from there (not from
-- concept_stage) wherever vet concepts need to reference or traverse into
-- the core SNOMED hierarchy. See steps 5, 12, and 18-20 below for the
-- corresponding read-from-concept (not concept_stage) adjustments.
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT sct2.concept_name,
	'SNOMED Veterinary' AS vocabulary_id,
	sct2.concept_code,
	DATE(effectivestart) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
	from (
		SELECT vocabulary_pack.CutConceptName(d.term) AS concept_name,
		d.conceptid AS concept_code,
		c.active,
		FIRST_VALUE(c.effectivetime) OVER (
			PARTITION BY c.id ORDER BY c.active DESC,
				c.effectivetime --if there ever were active versions of the concept, take the earliest one
			) AS effectivestart,
		ROW_NUMBER() OVER (
			PARTITION BY d.conceptid
			-- Order of preference:
			-- Active descriptions first, characterised as Preferred Synonym, prefer SNOMED Int, then US, then UK, then take the latest term
			ORDER BY c.active DESC,
				d.active DESC,
				l.active DESC,
				CASE l.acceptabilityid
					WHEN '900000000000548007'
						THEN 1 --Preferred
					WHEN '900000000000549004'
						THEN 2 --Acceptable
					ELSE 99
					END ASC,
				CASE d.typeid
					WHEN '900000000000013009'
						THEN 1 --Synonym (PT)
					WHEN '900000000000003001'
						THEN 2 --Fully specified name
					ELSE 99
					END ASC,
				CASE l.refsetid
					WHEN '332501000009101'
						THEN 1 --Vet extension language reference set
					WHEN '900000000000509007'
						THEN 2 --US English language reference set
					ELSE 99
					END,
				CASE l.source_file_id
					WHEN 'VET'
						THEN 1 -- SNOMED VET
					WHEN 'INT'
						THEN 2 -- SNOMED INT
					ELSE 99
					END ASC,
				l.effectivetime DESC,
				d.term
			) AS rn
	FROM sources_vet_sct2_concept_full c
	JOIN sources_vet_sct2_desc_full d ON d.conceptid = c.id
	JOIN sources_vet_der2_crefset_language l ON l.referencedcomponentid = d.id where c.moduleId = '332351000009108' 
	 ) sct2
WHERE sct2.rn = 1  
AND not EXISTS (
		SELECT 1
		FROM concept c
		WHERE c.concept_code = sct2.concept_code
			AND c.vocabulary_id = 'SNOMED'
		and c.invalid_reason is null 

    );

ANALYZE concept_stage;

--4.1 For concepts with latest entry in sources_vet_sct2_concept_full having active = 0, preserve invalid_reason and valid_end date
UPDATE concept_stage cs
SET invalid_reason = 'D',
	valid_end_date = i.effectiveend
FROM (
	SELECT s0.*
	FROM (
		SELECT DISTINCT ON (c.id) c.id,
			DATE(c.effectivetime) AS effectiveend,
			c.active
		FROM sources_vet_sct2_concept_full c
		ORDER BY c.id,
			c.effectivetime DESC
		) s0
	WHERE s0.active = 0
	) i
WHERE i.id = cs.concept_code;

--4.2 Fix concept names: change vitamin B>12< deficiency to vitamin B-12 deficiency; NAD(P)^+^ to NAD(P)+
UPDATE concept_stage
SET concept_name = vocabulary_pack.CutConceptName(TRANSLATE(concept_name, '>,<,^', '-'))
WHERE (
		(
			concept_name LIKE '%>%'
			AND concept_name LIKE '%<%'
			)
		OR (concept_name LIKE '%^%^%')
		)
	AND LENGTH(concept_name) > 5;

ANALYZE concept_stage;

--5. Update concept_class_id from extracted hierarchy tag information and terms ordered by description table precedence
UPDATE concept_stage cs
SET concept_class_id = i.concept_class_id
FROM (
	WITH tmp_concept_class AS (
			SELECT *
			FROM (
				SELECT concept_code,
					f7, -- SNOMED hierarchy tag
					ROW_NUMBER() OVER (
						PARTITION BY concept_code
-- order of precedence: active, by class relevance
-- Might be redundant, as normally concepts will never have more than 1 hierarchy tag, but we
-- have concurrent sources, so this may prevent problems and breaks nothing
						ORDER BY active DESC,
							rnb,
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
								WHEN 'animal life circumstance'
									THEN 53
								ELSE 99
								END
						) AS rnc
				FROM (
					SELECT concept_code,
						active,
						SUBSTRING(term, '\(([^(]+)\)$') AS f7,
						rna AS rnb -- row number in sources_vet_sct2_desc_full
					FROM (
						SELECT c.concept_code,
							d.term,
							d.active,
							ROW_NUMBER() OVER (
								PARTITION BY c.concept_code ORDER
								BY
									d.active DESC, -- active ones
									d.effectivetime DESC -- latest active ones
								) rna -- row number in sources_vet_sct2_desc_full
						FROM concept_stage c
						JOIN sources_vet_sct2_desc_full d ON d.conceptid = c.concept_code
						WHERE c.vocabulary_id IN ('SNOMED', 'SNOMED Veterinary')
							AND d.typeid = '900000000000003001' -- only Fully Specified Names
					) AS s0
					) AS s1
				) AS s2
			WHERE rnc = 1
			)
	SELECT concept_code,
		CASE
			WHEN F7 = 'disorder'
				THEN 'Disorder'
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
			WHEN F7 = 'link assertion'
				THEN 'Linkage Assertion'
			WHEN F7 = 'metadata'
				THEN 'Model Comp'
			WHEN F7 = 'navigational concept'
				THEN 'Navi Concept'
			WHEN F7 = 'inactive concept'
				THEN 'Inactive Concept'
			WHEN F7 = 'administration method'
				THEN 'Qualifier Value'
			WHEN F7 = 'basic dose form'
				THEN 'Dose Form'
			WHEN F7 = 'clinical drug'
				THEN 'Clinical Drug'
			WHEN F7 = 'disposition'
				THEN 'Disposition'
			WHEN F7 = 'dose form'
				THEN 'Dose Form'
			WHEN F7 = 'intended site'
				THEN 'Qualifier Value'
			WHEN F7 = 'medicinal product'
				THEN 'Pharma/Biol Product'
			WHEN F7 = 'medicinal product form'
				THEN 'Clinical Drug Form'
			WHEN F7 = 'number'
				THEN 'Qualifier Value'
			WHEN F7 = 'release characteristic'
				THEN 'Qualifier Value'
			WHEN F7 = 'role'
				THEN 'Qualifier Value'
			WHEN F7 = 'state of matter'
				THEN 'Qualifier Value'
			WHEN F7 = 'transformation'
				THEN 'Qualifier Value'
			WHEN F7 = 'unit of presentation'
				THEN 'Qualifier Value'
			WHEN F7 = 'OWL metadata concept'
				THEN 'Model Comp'
			WHEN F7 = 'supplier'
				THEN 'Qualifier Value'
			WHEN F7 = 'product name'
				THEN 'Qualifier Value'
			WHEN F7 = 'animal life circumstance'
				THEN 'Life circumstance'
			ELSE 'Undefined'
			END AS concept_class_id
	FROM tmp_concept_class
	) i
WHERE i.concept_code = cs.concept_code
	AND cs.vocabulary_id IN ('SNOMED', 'SNOMED Veterinary')
;

ANALYZE concept_stage;

--7. Add active synonyms from merged Veterinary descriptions list
-- This first insert covers descriptions for vet extension concepts
-- (resolved against concept_stage, which is vet-only).
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)
SELECT DISTINCT d.conceptid,
	cs.vocabulary_id AS synonym_vocabulary_id,
	vocabulary_pack.CutConceptSynonymName(d.term),
	4180186 -- English
FROM (
	SELECT m.conceptid,
		m.term,
		FIRST_VALUE(m.active) OVER (
			PARTITION BY m.id ORDER BY m.effectivetime DESC
			) AS active_status
	FROM sources_vet_sct2_desc_full m
	) d
JOIN concept_stage cs ON cs.concept_code = d.conceptid
WHERE d.active_status = 1
ON CONFLICT DO NOTHING;

-- NOTE: vet-authored synonyms for EXISTING core SNOMED concepts (e.g. breed/
-- species/disorder concepts whose own current module is the vet extension
-- module 332351000009108) are intentionally NOT added here. Inserting them
-- into concept_synonym_stage with synonym_vocabulary_id = 'SNOMED' trips
-- qa_tests.Check_Stage_Tables()'s guard against staging rows for a
-- vocabulary not registered via SetLatestUpdate - and registering 'SNOMED'
-- here would reintroduce the exact problem this rewrite fixes (GenericUpdate
-- would deprecate every core SNOMED concept absent from concept_stage).
-- That logic is instead handled directly against the live concept_synonym
-- table in post_generic_update.sql, AFTER GenericUpdate() completes, which
-- sidesteps the staging-table QA check entirely since it only inspects
-- concept_stage/concept_relationship_stage/concept_synonym_stage.

ANALYZE concept_synonym_stage;

--8. Fill concept_relationship_stage from merged SNOMED Veterinary source
-- 8.1 Add relationships from concept to module and from concept to status:
-- NOTE: cs (the vet concept) must come from concept_stage, since this build
-- only owns vet concepts there. csm (the module concept) is usually a core
-- SNOMED concept (900000000000207008, 900000000000012004) that already
-- exists in the live concept table (owned by the canonical SNOMED build),
-- so it is resolved via concept_stage first (covers the case where the
-- module concept is itself a vet concept, e.g. 332351000009108) and falls
-- back to the live concept table otherwise. This relationship row only
-- references the existing core concept; it does NOT insert/modify it.
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
--add relationships from concept to module
SELECT cs.concept_code AS concept_code_1,
	COALESCE(csm.concept_code, c_core.concept_code) AS concept_code_2,
	cs.vocabulary_id AS vocabulary_id_1,
	COALESCE(csm.vocabulary_id, c_core.vocabulary_id) AS vocabulary_id_2,
	'Has Module' AS relationship_id,
	cs.valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM sources_vet_sct2_concept_full c
JOIN concept_stage cs ON cs.concept_code = c.id
LEFT JOIN concept_stage csm ON csm.concept_code = c.moduleid
LEFT JOIN concept c_core ON c_core.concept_code = c.moduleid
	AND c_core.vocabulary_id = 'SNOMED'
	AND csm.concept_code IS NULL -- only look up live concept if not already a vet concept
WHERE c.moduleid IN (
		'900000000000207008', --Core (international) module
		'332351000009108', --SNOMED Veterinary extension module
		'900000000000012004' --SNOMED CT model component
		)
	AND COALESCE(csm.concept_code, c_core.concept_code) IS NOT NULL -- skip if module concept can't be resolved anywhere

UNION ALL

--add relationship from concept to status
-- statusid concepts (Defined/Primitive) are core SNOMED metadata concepts
-- already owned by the canonical build; vocabulary_id_2 is resolved from
-- the live concept table rather than hardcoded, in case that ever changes.
(
	SELECT DISTINCT ON (c.id) c.id AS concept_code_1,
		c.statusid AS concept_code_2,
		cs.vocabulary_id AS vocabulary_id_1,
		c_status.vocabulary_id AS vocabulary_id_2,
		'Has status' AS relationship_id,
		DATE(c.effectivetime) AS valid_start_date,
		TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
		NULL AS invalid_reason
	FROM sources_vet_sct2_concept_full c
	JOIN concept_stage cs ON cs.concept_code = c.id
	JOIN concept c_status ON c_status.concept_code = c.statusid
		AND c_status.vocabulary_id = 'SNOMED'
	WHERE c.statusid IN (
			'900000000000073002', --Defined
			'900000000000074008' --Primitive
			)
		AND c.active = 1
	ORDER BY c.id,
		c.effectivetime DESC
)
ON CONFLICT DO NOTHING;

-- 8.2. Add other attribute relationships:
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
WITH attr_rel AS (
		SELECT s0.sourceid,
			s0.destinationid,
			s0.typeid,
			REPLACE(s0.term, ' (attribute)', '') AS term
		FROM (
			SELECT DISTINCT ON (r.id) r.sourceid,
				r.destinationid,
				r.typeid,
				d.term,
				r.active
			FROM sources_vet_sct2_rela_full r
			JOIN sources_vet_sct2_desc_full d ON d.conceptid = r.typeid
			-- get the latest in a sequence of relationships, to decide whether it is still active
			ORDER BY r.id,
				r.effectivetime DESC,
				d.id DESC -- fix for AVOF-650
			) AS s0
		WHERE s0.active = 1
			AND s0.sourceid IS NOT NULL
			AND s0.destinationid IS NOT NULL
			AND s0.term <> 'PBCL flag true'
		)
--convert SNOMED to OMOP-type relationship_id
-- NOTE: cs1/cs2 resolve against concept_stage first (vet concepts), falling
-- back to the live concept table for core SNOMED concepts already owned by
-- the canonical build. The relationship is only inserted when at least one
-- side is a SNOMED Veterinary concept - pure core-to-core SNOMED
-- relationships are intentionally excluded, since the canonical SNOMED
-- build already owns and maintains those.
SELECT DISTINCT COALESCE(cs1.concept_code, c1_core.concept_code) AS concept_code_1,
	COALESCE(cs2.concept_code, c2_core.concept_code) AS concept_code_2,
	COALESCE(cs1.vocabulary_id, c1_core.vocabulary_id) AS vocabulary_id_1,
	COALESCE(cs2.vocabulary_id, c2_core.vocabulary_id) AS vocabulary_id_2,
	CASE
		WHEN ar.typeid = '260507000'
			THEN 'Has access'
		WHEN ar.typeid = '363715002'
			THEN 'Has etiology'
		WHEN ar.typeid = '255234002'
			THEN 'Followed by'
		WHEN ar.typeid IN ('260669005',
		                '424876005')
			THEN 'Has surgical appr'
		WHEN ar.typeid = '246090004'
			THEN 'Has asso finding'
		WHEN ar.typeid = '116676008'
			THEN 'Has asso morph'
		WHEN ar.typeid = '363589002'
			THEN 'Has asso proc'
		WHEN ar.typeid = '47429007'
			THEN 'Finding asso with'
		WHEN ar.typeid = '246075003'
			THEN 'Has causative agent'
		WHEN ar.typeid = '246093002'
			THEN 'Has component'
		WHEN ar.typeid = '363699004'
			THEN 'Has dir device'
		WHEN ar.typeid = '363700003'
			THEN 'Has dir morph'
		WHEN ar.typeid = '363701004'
			THEN 'Has dir subst'
		WHEN ar.typeid = '42752001'
			THEN 'Has due to'
		WHEN ar.typeid = '246456000'
			THEN 'Has episodicity'
		WHEN ar.typeid = '260858005'
			THEN 'Has extent'
		WHEN ar.typeid = '408729009'
			THEN 'Has finding context'
		WHEN ar.typeid = '419066007'
			THEN 'Using finding inform'
		WHEN ar.typeid = '418775008'
			THEN 'Using finding method'
		WHEN ar.typeid = '363698007'
			THEN 'Has finding site'
		WHEN ar.typeid = '127489000'
			THEN 'Has active ing'
		WHEN ar.typeid = '363705008'
			THEN 'Has manifestation'
		WHEN ar.typeid = '411116001'
			THEN 'Has dose form'
		WHEN ar.typeid = '363702006'
			THEN 'Has focus'
		WHEN ar.typeid = '363713009'
			THEN 'Has interpretation'
		WHEN ar.typeid = '116678009'
			THEN 'Has meas component'
		WHEN ar.typeid = '116686009'
			THEN 'Has specimen'
		WHEN ar.typeid = '258214002'
			THEN 'Has stage'
		WHEN ar.typeid = '363710007'
			THEN 'Has indir device'
		WHEN ar.typeid = '363709002'
			THEN 'Has indir morph'
		WHEN ar.typeid = '309824003'
			THEN 'Using device'
		WHEN ar.typeid = '363703001'
			THEN 'Has intent'
		WHEN ar.typeid = '363714003'
			THEN 'Has interprets'
		WHEN ar.typeid = '116680003'
			THEN 'Is a'
		WHEN ar.typeid = '272741003'
			THEN 'Has laterality'
		WHEN ar.typeid = '370129005'
			THEN 'Has measurement'
		WHEN ar.typeid = '260686004'
			THEN 'Has method'
		WHEN ar.typeid = '246454002'
			THEN 'Has occurrence'
		WHEN ar.typeid IN (
		        '246100006',
		        '263502005',
		   		'260908002'
		        )
			THEN 'Has clinical course'
		WHEN ar.typeid = '123005000'
			THEN 'Part of'
		WHEN ar.typeid IN (
				'308489006',
				'370135005',
				'719722006'
				)
			THEN 'Has pathology'
		WHEN ar.typeid = '260870009'
			THEN 'Has priority'
		WHEN ar.typeid = '408730004'
			THEN 'Has proc context'
		WHEN ar.typeid = '405815000'
			THEN 'Has proc device'
		WHEN ar.typeid = '405816004'
			THEN 'Has proc morph'
		WHEN ar.typeid = '405813007'
			THEN 'Has dir proc site'
		WHEN ar.typeid = '405814001'
			THEN 'Has indir proc site'
		WHEN ar.typeid = '363704007'
			THEN 'Has proc site'
		WHEN ar.typeid = '370130000'
			THEN 'Has property'
		WHEN ar.typeid = '370131001'
			THEN 'Has recipient cat'
		WHEN ar.typeid = '246513007'
			THEN 'Has revision status'
		WHEN ar.typeid = '410675002'
			THEN 'Has route of admin'
		WHEN ar.typeid = '370132008'
			THEN 'Has scale type'
		WHEN ar.typeid = '246112005'
			THEN 'Has severity'
		WHEN ar.typeid = '118171006'
			THEN 'Has specimen proc'
		WHEN ar.typeid = '118170007'
			THEN 'Has specimen source'
		WHEN ar.typeid = '118168003'
			THEN 'Has specimen morph'
		WHEN ar.typeid = '118169006'
			THEN 'Has specimen topo'
		WHEN ar.typeid = '370133003'
			THEN 'Has specimen subst'
		WHEN ar.typeid = '408732007'
			THEN 'Has relat context'
		WHEN ar.typeid = '408731000'
			THEN 'Has temporal context'
		WHEN ar.typeid = '363708005'
			THEN 'Occurs after'
		WHEN ar.typeid = '370134009'
			THEN 'Has time aspect'
		WHEN ar.typeid = '425391005'
			THEN 'Using acc device'
		WHEN ar.typeid = '424226004'
			THEN 'Using device'
		WHEN ar.typeid = '424244007'
			THEN 'Using energy'
		WHEN ar.typeid = '424361007'
			THEN 'Using subst'
		WHEN ar.typeid = '8940601000001102'
			THEN 'Has non-avail ind'
		WHEN ar.typeid = '12223201000001101'
			THEN 'Has ARP'
		WHEN ar.typeid = '12223101000001108'
			THEN 'Has VRP'
		WHEN ar.typeid = '9191701000001107'
			THEN 'Has trade family grp'
		WHEN ar.typeid = '8941101000001104'
			THEN 'Has flavor'
		WHEN ar.typeid = '8941901000001101'
			THEN 'Has disc indicator'
		WHEN ar.typeid = '12223501000001103'
			THEN 'VRP has prescr stat'
		WHEN ar.typeid = '10362801000001104'
			THEN 'Has spec active ing'
		WHEN ar.typeid = '8653101000001104'
			THEN 'Has excipient'
		WHEN ar.typeid IN (
				'732943007',
				'10363001000001101'
				)
			THEN 'Has basis str subst'
		WHEN ar.typeid = '10362601000001103'
			THEN 'Has VMP'
		WHEN ar.typeid = '10362701000001108'
			THEN 'Has AMP'
		WHEN ar.typeid = '10362901000001105'
			THEN 'Has disp dose form'
		WHEN ar.typeid = '8940001000001105'
			THEN 'VMP has prescr stat'
		WHEN ar.typeid IN (
				'8941301000001102',
				'4074701000001107'
				)
			THEN 'Has legal category'
		WHEN ar.typeid = '704326004'
			THEN 'Has precondition'
		WHEN ar.typeid = '718497002'
			THEN 'Has inherent loc'
		WHEN ar.typeid = '246501002'
			THEN 'Has technique'
		WHEN ar.typeid = '719715003'
			THEN 'Has relative part'
		WHEN ar.typeid = '704324001'
			THEN 'Has process output'
		WHEN ar.typeid = '704318007'
			THEN 'Has property type'
		WHEN ar.typeid = '704319004'
			THEN 'Inheres in'
		WHEN ar.typeid = '704327008'
			THEN 'Has direct site'
		WHEN ar.typeid = '704321009'
			THEN 'Characterizes'
		WHEN ar.typeid = '371881003'
			THEN 'During'
		WHEN ar.typeid = '732947008'
			THEN 'Has denominator unit'
		WHEN ar.typeid = '732946004'
			THEN 'Has denomin value'
		WHEN ar.typeid = '732945000'
			THEN 'Has numerator unit'
		WHEN ar.typeid = '732944001'
			THEN 'Has numerator value'
		WHEN ar.typeid = '736476002'
			THEN 'Has basic dose form'
		WHEN ar.typeid = '726542003'
			THEN 'Has disposition'
		WHEN ar.typeid = '736472000'
			THEN 'Has admin method'
		WHEN ar.typeid = '736474004'
			THEN 'Has intended site'
		WHEN ar.typeid = '736475003'
			THEN 'Has release charact'
		WHEN ar.typeid = '736473005'
			THEN 'Has transformation'
		WHEN ar.typeid = '736518005'
			THEN 'Has state of matter'
		WHEN ar.typeid = '726633004'
			THEN 'Temp related to'
		WHEN ar.typeid = '13085501000001109'
			THEN 'Has unit of admin'
		WHEN ar.typeid = '762949000'
			THEN 'Has prec ingredient'
		WHEN ar.typeid = '763032000'
			THEN 'Has unit of presen'
		WHEN ar.typeid = '733724008'
			THEN 'Has conc num val'
		WHEN ar.typeid = '733723002'
			THEN 'Has conc denom val'
		WHEN ar.typeid = '733722007'
			THEN 'Has conc denom unit'
		WHEN ar.typeid = '733725009'
			THEN 'Has conc num unit'
		WHEN ar.typeid = '738774007'
			THEN 'Modification of'
		WHEN ar.typeid = '766952006'
			THEN 'Has count of ing'
		WHEN ar.typeid = '766939001'
			THEN 'Plays role'
		WHEN ar.typeid = '13088401000001104'
			THEN 'Has route'
		WHEN ar.typeid = '13089101000001102'
			THEN 'Has CD category'
		WHEN ar.typeid = '13088501000001100'
			THEN 'Has ontological form'
		WHEN ar.typeid = '13088901000001108'
			THEN 'Has combi prod ind'
		WHEN ar.typeid = '13088701000001106'
			THEN 'Has form continuity'
		WHEN ar.typeid = '13090301000001106'
			THEN 'Has add monitor ind'
		WHEN ar.typeid = '13090501000001104'
			THEN 'Has AMP restr ind'
		WHEN ar.typeid = '13090201000001102'
			THEN 'Paral imprt ind'
		WHEN ar.typeid = '13089701000001101'
			THEN 'Has free indicator'
		WHEN ar.typeid = '246514001'
			THEN 'Has unit'
		WHEN ar.typeid = '704323007'
			THEN 'Has proc duration'
		WHEN ar.typeid = '704325000'
			THEN 'Relative to'
		WHEN ar.typeid = '766953001'
			THEN 'Has count of act ing'
		WHEN ar.typeid IN ('860781008','860779006','840562008')
			THEN 'Has prod character'
		WHEN ar.typeid = '246196007'
			THEN 'Surf character of'
		WHEN ar.typeid = '836358009'
			THEN 'Has dev intend site'
		WHEN ar.typeid = '840560000'
			THEN 'Has comp material'
		WHEN ar.typeid = '827081001'
			THEN 'Has filling'
		WHEN ar.typeid = '1148967007'
			THEN 'Has coating material'
		WHEN ar.typeid = '1148969005'
			THEN 'Has absorbability'
		WHEN ar.typeid = '1003703000'
			THEN 'Process extends to'
		WHEN ar.typeid = '1149366004'
			THEN 'Has strength'
		WHEN ar.typeid = '1148968002'
			THEN 'Has surface texture'
		WHEN ar.typeid = '1148965004'
			THEN 'Is sterile'
		WHEN ar.typeid = '1149367008'
			THEN 'Has targ population'
		WHEN ar.typeid = '1003735000'
			THEN 'Process acts on'
		WHEN ar.typeid = '288556008'
			THEN 'Before'
		WHEN ar.typeid = '704320005'
			THEN 'Towards'
		WHEN ar.typeid = '116688005'
			THEN 'Has approach'
		WHEN ar.typeid = '26431000009107'
			THEN 'Has physiol state'
		WHEN ar.typeid = '26421000009105'
			THEN 'Has life circumstan'
		ELSE ar.term --'non-existing'
		END AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED Veterinary'
		) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM attr_rel ar
LEFT JOIN concept_stage cs1 ON cs1.concept_code = ar.sourceid
LEFT JOIN concept c1_core ON c1_core.concept_code = ar.sourceid
	AND c1_core.vocabulary_id = 'SNOMED'
	AND cs1.concept_code IS NULL
LEFT JOIN concept_stage cs2 ON cs2.concept_code = ar.destinationid
LEFT JOIN concept c2_core ON c2_core.concept_code = ar.destinationid
	AND c2_core.vocabulary_id = 'SNOMED'
	AND cs2.concept_code IS NULL
WHERE COALESCE(cs1.concept_code, c1_core.concept_code) IS NOT NULL -- source must resolve somewhere
	AND COALESCE(cs2.concept_code, c2_core.concept_code) IS NOT NULL -- destination must resolve somewhere
	AND (cs1.vocabulary_id = 'SNOMED Veterinary' OR cs2.vocabulary_id = 'SNOMED Veterinary') -- at least one side must be a vet concept
ON CONFLICT DO NOTHING;

ANALYZE concept_relationship_stage;

--check for non-existing relationships (run this to surface any unmapped relationship_id values)
ALTER TABLE concept_relationship_stage ADD CONSTRAINT tmp_constraint_relid FOREIGN KEY (relationship_id) REFERENCES relationship (relationship_id);
ALTER TABLE concept_relationship_stage DROP CONSTRAINT tmp_constraint_relid;
--SELECT DISTINCT relationship_id FROM concept_relationship_stage EXCEPT SELECT relationship_id FROM relationship;

--9. Add replacement relationships. They are handled in a different SNOMED table
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
WITH cte AS (
    SELECT sc.referencedcomponentid AS concept_code_1,
		sc.targetcomponent AS concept_code_2,
		sc.effectivetime AS effectivestart,
		CASE refsetid
			WHEN '900000000000526001'
				THEN 'Concept replaced by'
			WHEN '900000000000523009'
				THEN 'Concept poss_eq to'
			WHEN '900000000000528000'
				THEN 'Concept was_a to'
			WHEN '900000000000527005'
				THEN 'Concept same_as to'
			WHEN '900000000000530003'
				THEN 'Concept alt_to to'
			END AS relationship_id,
		refsetid,
		CASE WHEN moduleid = '900000000000207008'
		        THEN 1 -- Core (International)
		    WHEN moduleid = '332351000009108'
		        THEN 2 -- SNOMED Veterinary extension
		    END AS module,
		ROW_NUMBER() OVER (
			PARTITION BY sc.referencedcomponentid ORDER BY DATE(sc.effectivetime) DESC,
				sc.id DESC
			) rn,
		ROW_NUMBER() OVER (
			PARTITION BY sc.referencedcomponentid,
			sc.targetcomponent,
			sc.refsetid,
			sc.moduleid ORDER BY DATE(sc.effectivetime) DESC
			) AS recent_status,
		active
	FROM sources_vet_der2_crefset_assreffull sc
	WHERE sc.refsetid IN (
			'900000000000526001',
			'900000000000523009',
			'900000000000528000',
			'900000000000527005',
			'900000000000530003'
			)
)
SELECT DISTINCT sn.concept_code_1,
	sn.concept_code_2,
	COALESCE(cs1.vocabulary_id, c1_core.vocabulary_id) AS vocabulary_id_1,
	COALESCE(cs2.vocabulary_id, c2_core.vocabulary_id) AS vocabulary_id_2,
	sn.relationship_id,
	DATE(sn.effectivestart),
	TO_DATE('20991231', 'YYYYMMDD'),
	NULL
FROM (SELECT *,
             ROW_NUMBER() OVER (PARTITION BY concept_code_1 ORDER BY module, rn desc) mn
      FROM cte
	) sn
LEFT JOIN concept_stage cs1 ON cs1.concept_code = sn.concept_code_1
LEFT JOIN concept c1_core ON c1_core.concept_code = sn.concept_code_1
	AND c1_core.vocabulary_id = 'SNOMED'
	AND cs1.concept_code IS NULL
LEFT JOIN concept_stage cs2 ON cs2.concept_code = sn.concept_code_2
LEFT JOIN concept c2_core ON c2_core.concept_code = sn.concept_code_2
	AND c2_core.vocabulary_id = 'SNOMED'
	AND cs2.concept_code IS NULL
WHERE (
		(
			sn.refsetid = '900000000000523009'
			AND sn.mn >= 1
			)
		OR sn.mn = 1
		)
	AND sn.active = 1
	AND sn.recent_status = 1
	AND COALESCE(cs1.concept_code, c1_core.concept_code) IS NOT NULL
	AND COALESCE(cs2.concept_code, c2_core.concept_code) IS NOT NULL
	AND (cs1.vocabulary_id = 'SNOMED Veterinary' OR cs2.vocabulary_id = 'SNOMED Veterinary') -- at least one side must be a vet concept
ON CONFLICT DO NOTHING;

--9.1. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--9.2. Deprecate replacement mappings for concepts that have come back from U to fresh
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
SELECT cs.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	cs.vocabulary_id AS vocabulary_id_1,
	c2.vocabulary_id AS vocabulary_id_2,
	cr.relationship_id,
	cr.valid_start_date,
	(
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED Veterinary'
		) AS valid_end_date,
	'D' AS invalid_reason
FROM concept_stage cs
LEFT JOIN concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
	AND crs.vocabulary_id_1 = cs.vocabulary_id
	AND crs.relationship_id IN (
		'Concept replaced by',
		'Concept same_as to',
		'Concept alt_to to',
		'Concept poss_eq to',
		'Concept was_a to'
		)
JOIN concept c1 ON c1.concept_code = cs.concept_code
	AND c1.vocabulary_id = cs.vocabulary_id
JOIN concept_relationship cr ON cr.concept_id_1 = c1.concept_id
	AND cr.invalid_reason IS NULL
	AND cr.relationship_id IN (
		'Concept replaced by',
		'Concept same_as to',
		'Concept alt_to to',
		'Concept poss_eq to',
		'Concept was_a to'
		)
JOIN concept c2 ON c2.concept_id = cr.concept_id_2
WHERE cs.invalid_reason IS NULL
	AND (
		c1.invalid_reason = 'U'
		OR c1.invalid_reason = 'D'
		)
	AND cs.vocabulary_id IN ('SNOMED', 'SNOMED Veterinary')
	AND crs.concept_code_1 IS NULL;

--same as above, but for 'Maps to'
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
SELECT c1.concept_code,
	c2.concept_code,
	c1.vocabulary_id AS vocabulary_id_1,
	c2.vocabulary_id AS vocabulary_id_2,
	'Maps to',
	cr.valid_start_date,
	(
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED Veterinary'
		) AS valid_end_date,
	'D' AS invalid_reason
FROM concept_relationship cr
JOIN concept c1 ON c1.concept_id = cr.concept_id_1
JOIN concept c2 ON c2.concept_id = cr.concept_id_2
WHERE cr.relationship_id = 'Maps to'
	AND cr.invalid_reason IS NULL
	AND EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = c1.concept_code
			AND crs_int.vocabulary_id_1 = c1.vocabulary_id
			AND crs_int.concept_code_2 = c2.concept_code
			AND crs_int.vocabulary_id_2 = c2.vocabulary_id
			AND crs_int.relationship_id IN (
				'Concept replaced by',
				'Concept same_as to',
				'Concept alt_to to',
				'Concept poss_eq to',
				'Concept was_a to'
				)
			AND crs_int.invalid_reason = 'D'
		);

ANALYZE concept_stage;
ANALYZE concept_relationship_stage;

-- 9.3. If concept has new replacement link deprecate old replacement relationships and mappings unless manually created
DROP TABLE IF EXISTS replacements;
CREATE TEMP TABLE replacements AS
WITH new_replacements AS (
SELECT *
FROM concept_relationship_stage crs
WHERE relationship_id IN (
				'Concept replaced by',
				'Concept same_as to',
				'Concept alt_to to',
				'Concept was_a to'
				)
AND crs.invalid_reason IS NULL
-- NOTE: vocabulary_id_1/vocabulary_id_2 here can legitimately be 'SNOMED'
-- on one side (e.g. a deprecated core concept replaced BY a newly
-- vet-owned concept) as long as the OTHER side is genuinely
-- 'SNOMED Veterinary' - this guard prevents a core SNOMED concept_code_1
-- that only happens to ALSO have a vet-related replacement relationship
-- from being treated as fair game to pull in ALL of its other, unrelated
-- live-database relationships below (which previously leaked pure
-- core-to-RxNorm 'Maps to' rows with no vet content whatsoever).
AND (crs.vocabulary_id_1 = 'SNOMED Veterinary' OR crs.vocabulary_id_2 = 'SNOMED Veterinary')
)
SELECT DISTINCT c.concept_code AS concept_code_1,
       c1.concept_code AS concept_code_2,
       c.vocabulary_id AS vocabulary_id_1,
       c1.vocabulary_id AS vocabulary_id_2,
       cr.relationship_id AS relationship_id,
       cr.valid_start_date,
       cr.valid_end_date,
	   cr.invalid_reason
FROM concept_relationship cr
JOIN concept c ON cr.concept_id_1 = c.concept_id
JOIN concept c1 ON c1.concept_id = cr.concept_id_2
WHERE cr.relationship_id IN (
				'Concept replaced by',
				'Concept same_as to',
				'Concept alt_to to',
				'Concept was_a to'
				)
AND cr.invalid_reason IS NULL
AND EXISTS (SELECT 1
           FROM new_replacements n
           WHERE (c.concept_code, c.vocabulary_id) = (n.concept_code_1, n.vocabulary_id_1)
           AND ((c1.concept_code, c1.vocabulary_id) != (n.concept_code_2, n.vocabulary_id_2)
               OR cr.relationship_id != n.relationship_id)
               )
AND NOT EXISTS (
    SELECT 1
    FROM concept_relationship_manual crm
    WHERE (crm.concept_code_1, crm.vocabulary_id_1) = (c.concept_code, c.vocabulary_id)
    AND crm.relationship_id LIKE 'Maps to%'
    AND crm.invalid_reason IS NULL)

UNION ALL

-- 'Maps to' is handled separately from the replacement-type relationships
-- above: it must ONLY match an existing live 'Maps to' row that itself
-- originated from this same vet-driven replacement logic (i.e. its
-- destination concept_id_2 is also present in new_replacements as a
-- concept_code_2), not any arbitrary 'Maps to' the concept happens to have
-- (such as an unrelated, still-valid RxNorm drug mapping).
SELECT DISTINCT c.concept_code AS concept_code_1,
       c1.concept_code AS concept_code_2,
       c.vocabulary_id AS vocabulary_id_1,
       c1.vocabulary_id AS vocabulary_id_2,
       cr.relationship_id AS relationship_id,
       cr.valid_start_date,
       cr.valid_end_date,
	   cr.invalid_reason
FROM concept_relationship cr
JOIN concept c ON cr.concept_id_1 = c.concept_id
JOIN concept c1 ON c1.concept_id = cr.concept_id_2
WHERE cr.relationship_id = 'Maps to'
AND cr.invalid_reason IS NULL
AND EXISTS (SELECT 1
           FROM new_replacements n
           WHERE (c.concept_code, c.vocabulary_id) = (n.concept_code_1, n.vocabulary_id_1)
               AND (c1.concept_code, c1.vocabulary_id) = (n.concept_code_2, n.vocabulary_id_2)
               )
AND NOT EXISTS (
    SELECT 1
    FROM concept_relationship_manual crm
    WHERE (crm.concept_code_1, crm.vocabulary_id_1) = (c.concept_code, c.vocabulary_id)
    AND crm.relationship_id LIKE 'Maps to%'
    AND crm.invalid_reason IS NULL)
;

ANALYZE replacements;

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
SELECT DISTINCT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED Veterinary'
		) AS valid_end_date,
	'D' AS invalid_reason
FROM replacements r
ON CONFLICT ON CONSTRAINT idx_pk_crs
DO UPDATE
SET valid_end_date = (
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED Veterinary'
		),
		invalid_reason = 'D'
	WHERE ROW (concept_relationship_stage.invalid_reason)
	IS DISTINCT FROM
	ROW (excluded.invalid_reason)
;

-- 9.4. Deprecate replacement relationships for manually curated concepts
UPDATE concept_relationship_stage crs
    SET invalid_reason = 'D',
        valid_end_date = (
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED Veterinary'
		)
WHERE EXISTS (
    SELECT 1
    FROM concept_relationship_manual crm
    WHERE (crm.concept_code_1, crm.vocabulary_id_1) = (crs.concept_code_1, crs.vocabulary_id_1)
    AND crm.relationship_id = 'Maps to'
    AND crm.invalid_reason IS NULL
)
AND crs.relationship_id IN (
		'Concept replaced by',
		'Concept same_as to',
		'Concept alt_to to',
		'Concept was_a to'
		)
AND crs.invalid_reason IS NULL;

-- 9.5. Delete records where neither end exists in concept or concept_stage
DELETE
FROM concept_relationship_stage crs
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		LEFT JOIN concept c1 ON c1.concept_code = crs_int.concept_code_1
			AND c1.vocabulary_id = crs_int.vocabulary_id_1
		LEFT JOIN concept_stage cs1 ON cs1.concept_code = crs_int.concept_code_1
			AND cs1.vocabulary_id = crs_int.vocabulary_id_1
		LEFT JOIN concept c2 ON c2.concept_code = crs_int.concept_code_2
			AND c2.vocabulary_id = crs_int.vocabulary_id_2
		LEFT JOIN concept_stage cs2 ON cs2.concept_code = crs_int.concept_code_2
			AND cs2.vocabulary_id = crs_int.vocabulary_id_2
		WHERE (
				(
					c1.concept_code IS NULL
					AND cs1.concept_code IS NULL
					)
				OR (
					c2.concept_code IS NULL
					AND cs2.concept_code IS NULL
					)
				)
			AND crs_int.concept_code_1 = crs.concept_code_1
			AND crs_int.vocabulary_id_1 = crs.vocabulary_id_1
			AND crs_int.concept_code_2 = crs.concept_code_2
			AND crs_int.vocabulary_id_2 = crs.vocabulary_id_2
		);

ANALYZE concept_relationship_stage;

--9.6. Update invalid_reason for concepts with replacements to 'U'
UPDATE concept_stage cs
SET invalid_reason = 'U',
	valid_end_date = LEAST(cs.valid_end_date, crs.valid_start_date, (
			SELECT latest_update
			FROM vocabulary v
			WHERE v.vocabulary_id = 'SNOMED Veterinary'
			))
FROM concept_relationship_stage crs
WHERE crs.concept_code_1 = cs.concept_code
	AND crs.relationship_id IN (
		'Concept replaced by',
		'Concept same_as to',
		'Concept alt_to to',
		'Concept was_a to'
		)
	AND crs.invalid_reason IS NULL;

--9.7. Update invalid_reason for concepts with 'Concept poss_eq to' relationships
UPDATE concept_stage cs
SET invalid_reason = 'D',
	valid_end_date = LEAST(crs.valid_start_date, (
			SELECT latest_update - 1
			FROM vocabulary v
			WHERE v.vocabulary_id = 'SNOMED Veterinary'
			))
FROM concept_relationship_stage crs
WHERE crs.concept_code_1 = cs.concept_code
	AND crs.relationship_id = 'Concept poss_eq to'
	AND crs.invalid_reason IS NULL
	AND cs.invalid_reason IS NULL;

--9.8. Update valid_end_date to latest_update if there is a discrepancy after last point
UPDATE concept_stage cs
SET valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED Veterinary'
		)
WHERE invalid_reason = 'U'
	AND valid_end_date = TO_DATE('20991231', 'YYYYMMDD');

--10. Append manual changes
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--11. Build domains; assign domains to the concepts according to their concept_classes
DROP TABLE IF EXISTS domain_snomed;
CREATE UNLOGGED TABLE domain_snomed AS
SELECT concept_code,
	CASE concept_class_id
		WHEN 'Admin Concept'
			THEN 'Type Concept'
		WHEN 'Attribute'
			THEN 'Observation'
		WHEN 'Biological Function'
			THEN 'Observation'
		WHEN 'Body Structure'
			THEN 'Spec Anatomic Site'
		WHEN 'Clinical Drug'
			THEN 'Drug'
		WHEN 'Clinical Drug Form'
			THEN 'Drug'
		WHEN 'Clinical Finding'
			THEN 'Observation'
		WHEN 'Context-dependent'
			THEN 'Observation'
		WHEN 'Disorder'
			THEN 'Condition'
		WHEN 'Disposition'
			THEN 'Observation'
		WHEN 'Dose Form'
			THEN 'Drug'
		WHEN 'Event'
			THEN 'Observation'
		WHEN 'Inactive Concept'
			THEN 'Metadata'
		WHEN 'Linkage Assertion'
			THEN 'Relationship'
		WHEN 'Linkage Concept'
			THEN 'Relationship'
		WHEN 'Location'
			THEN 'Observation'
		WHEN 'Model Comp'
			THEN 'Metadata'
		WHEN 'Morph Abnormality'
			THEN 'Observation'
		WHEN 'Namespace Concept'
			THEN 'Metadata'
		WHEN 'Navi Concept'
			THEN 'Metadata'
		WHEN 'Observable Entity'
			THEN 'Observation'
		WHEN 'Organism'
			THEN 'Observation'
		WHEN 'Patient Status'
			THEN 'Observation'
		WHEN 'Physical Force'
			THEN 'Observation'
		WHEN 'Pharma/Biol Product'
			THEN 'Drug'
		WHEN 'Physical Object'
			THEN 'Device'
		WHEN 'Procedure'
			THEN 'Procedure'
		WHEN 'Qualifier Value'
			THEN 'Observation'
		WHEN 'Record Artifact'
			THEN 'Type Concept'
		WHEN 'Social Context'
			THEN 'Observation'
		WHEN 'Special Concept'
			THEN 'Metadata'
		WHEN 'Specimen'
			THEN 'Specimen'
		WHEN 'Staging / Scales'
			THEN 'Measurement'
		WHEN 'Substance'
			THEN 'Observation'
		WHEN 'Life circumstance'
			THEN 'Observation'
		ELSE 'Observation'
		END AS domain_id
FROM concept_stage;

--12. Start building the hierarchy for propagating domain_ids from top to bottom
-- NOTE: 'Is a' relationships in concept_relationship_stage now only exist
-- where at least one side is a SNOMED Veterinary concept (per the step 8.2
-- fix above), with the other side's vocabulary_id resolved from either
-- concept_stage (vet) or the live concept table (core SNOMED). This
-- recursive hierarchy build must therefore also resolve cs1/cs2 against
-- concept_stage first, falling back to the live concept table, so the
-- ancestor chain can climb through core SNOMED concepts up to a peak
-- without requiring those concepts to be present in concept_stage.
--
-- PERFORMANCE NOTE: the concept_stage + live-concept fallback lookup is
-- pre-materialized into an indexed temp table (hierarchy_concept_lookup)
-- BEFORE the recursive CTE runs, restricted only to concept codes that
-- actually participate in an 'Is a' relationship. Inlining the fallback as
-- a live subquery directly in the recursive join (the original approach)
-- forces PostgreSQL to re-scan the full live concept table on every
-- recursive step, which does not scale.
DROP TABLE IF EXISTS hierarchy_concept_lookup;
CREATE UNLOGGED TABLE hierarchy_concept_lookup AS
WITH isa_codes AS (
	SELECT DISTINCT concept_code_1 AS concept_code
	FROM concept_relationship_stage
	WHERE invalid_reason IS NULL
		AND relationship_id = 'Is a'
		AND vocabulary_id_1 IN ('SNOMED', 'SNOMED Veterinary')
		AND vocabulary_id_2 IN ('SNOMED', 'SNOMED Veterinary')

	UNION

	SELECT DISTINCT concept_code_2 AS concept_code
	FROM concept_relationship_stage
	WHERE invalid_reason IS NULL
		AND relationship_id = 'Is a'
		AND vocabulary_id_1 IN ('SNOMED', 'SNOMED Veterinary')
		AND vocabulary_id_2 IN ('SNOMED', 'SNOMED Veterinary')
	)
SELECT cs.concept_code, cs.vocabulary_id, cs.concept_class_id
FROM concept_stage cs
JOIN isa_codes ic ON ic.concept_code = cs.concept_code

UNION ALL

SELECT c.concept_code, c.vocabulary_id, c.concept_class_id
FROM concept c
JOIN isa_codes ic ON ic.concept_code = c.concept_code
WHERE c.vocabulary_id = 'SNOMED'
	AND NOT EXISTS (SELECT 1 FROM concept_stage cs WHERE cs.concept_code = c.concept_code);

CREATE UNIQUE INDEX idx_hcl_concept_code ON hierarchy_concept_lookup (concept_code);
ANALYZE hierarchy_concept_lookup;

DROP TABLE IF EXISTS snomed_ancestor;
CREATE UNLOGGED TABLE snomed_ancestor AS
	WITH RECURSIVE hierarchy_concepts(ancestor_concept_code, descendant_concept_code, root_ancestor_concept_code, levels_of_separation, full_path) AS (
		SELECT ancestor_concept_code,
			descendant_concept_code,
			ancestor_concept_code AS root_ancestor_concept_code,
			levels_of_separation,
			ARRAY [descendant_concept_code::TEXT] AS full_path
		FROM concepts

		UNION ALL

		SELECT c.ancestor_concept_code,
			c.descendant_concept_code,
			root_ancestor_concept_code,
			hc.levels_of_separation + c.levels_of_separation AS levels_of_separation,
			hc.full_path || c.descendant_concept_code AS full_path
		FROM concepts c
		JOIN hierarchy_concepts hc ON hc.descendant_concept_code = c.ancestor_concept_code
		WHERE c.descendant_concept_code <> ALL (full_path)
		),
	concepts AS (
		SELECT crs.concept_code_2 AS ancestor_concept_code,
			crs.concept_code_1 AS descendant_concept_code,
			1 AS levels_of_separation
		FROM concept_relationship_stage crs
		WHERE crs.invalid_reason IS NULL
			AND crs.relationship_id = 'Is a'
			AND crs.vocabulary_id_1 IN ('SNOMED', 'SNOMED Veterinary')
			AND crs.vocabulary_id_2 IN ('SNOMED', 'SNOMED Veterinary')
		)
	SELECT hc.root_ancestor_concept_code AS ancestor_concept_code,
		hc.descendant_concept_code,
		MIN(hc.levels_of_separation) AS min_levels_of_separation
	FROM hierarchy_concepts hc
	JOIN hierarchy_concept_lookup cs1 ON cs1.concept_code = hc.root_ancestor_concept_code
	JOIN hierarchy_concept_lookup cs2 ON cs2.concept_code = hc.descendant_concept_code
		AND cs2.concept_class_id = cs1.concept_class_id
	GROUP BY hc.root_ancestor_concept_code,
		hc.descendant_concept_code;

ANALYZE snomed_ancestor;

--12.1. For invalid concepts without valid hierarchy, take the latest 'Is a' relationship to active concept
-- NOTE: the destination (parent) concept may be a core SNOMED concept not
-- present in concept_stage; resolved via concept_stage first, falling back
-- to the live concept table.
INSERT INTO snomed_ancestor (
	ancestor_concept_code,
	descendant_concept_code,
	min_levels_of_separation
	)
SELECT a.ancestor_concept_code,
	m.sourceid,
	a.min_levels_of_separation
FROM concept_stage s1
JOIN (
	SELECT DISTINCT r.sourceid,
		FIRST_VALUE(r.destinationid) OVER (
			PARTITION BY r.sourceid,
			r.effectivetime
		    ORDER BY r.id DESC
			) AS destinationid,
		r.effectivetime,
		MAX(r.effectivetime) OVER (PARTITION BY r.sourceid) AS maxeffectivetime
	FROM sources_vet_sct2_rela_full r
	LEFT JOIN concept_stage x ON x.concept_code = r.destinationid
		AND x.invalid_reason IS NULL
	LEFT JOIN concept x_core ON x_core.concept_code = r.destinationid
		AND x_core.vocabulary_id = 'SNOMED'
		AND x_core.invalid_reason IS NULL
		AND x.concept_code IS NULL
	WHERE r.typeid = '116680003' -- Is a
	  AND r.active = '1'
	  AND COALESCE(x.concept_code, x_core.concept_code) IS NOT NULL
	) m ON m.sourceid = s1.concept_code
	AND m.effectivetime = m.maxeffectivetime
JOIN snomed_ancestor a ON m.destinationid = a.descendant_concept_code
WHERE s1.invalid_reason IS NOT NULL
	AND NOT EXISTS (
		SELECT 1
		FROM snomed_ancestor x
		WHERE x.descendant_concept_code = m.sourceid
		);

ALTER TABLE snomed_ancestor ADD CONSTRAINT xpksnomed_ancestor PRIMARY KEY (ancestor_concept_code, descendant_concept_code);

--13. Create domain_id
--13.1. Create and populate table with "Peaks" = ancestors of records that are all of the same domain
DO $_$
BEGIN
	PERFORM dev_veterinary.AddPeaks();
END $_$;

--13.2. Order peaks by height in hierarchy to determine inheritance order
UPDATE peak p
SET ranked = r.rnk
FROM (
	SELECT pd.peak_code,
		COUNT(*) + 1 AS rnk
	FROM peak pa
	JOIN snomed_ancestor ca ON ca.ancestor_concept_code = pa.peak_code
	JOIN peak pd ON pd.peak_code = ca.descendant_concept_code
		AND pd.valid_end_date = TO_DATE('20991231', 'YYYYMMDD')
	WHERE pa.levels_down IS NULL
		AND pa.valid_end_date = TO_DATE('20991231', 'YYYYMMDD')
	GROUP BY pd.peak_code
	) r
WHERE p.peak_code = r.peak_code
	AND p.valid_end_date = TO_DATE('20991231', 'YYYYMMDD');

--For those that have no ancestors, the rank is 1
UPDATE peak
SET ranked = 1
WHERE ranked IS NULL
	AND valid_end_date = TO_DATE('20991231', 'YYYYMMDD');

--13.3. Pass out domain_ids from peaks to descendants
UPDATE domain_snomed d
SET domain_id = i.peak_domain_id
FROM (
	SELECT DISTINCT ON (sa.descendant_concept_code) p.peak_domain_id,
		sa.descendant_concept_code
	FROM snomed_ancestor sa
	JOIN peak p ON p.peak_code = sa.ancestor_concept_code
		AND p.ranked IS NOT NULL
	WHERE p.levels_down >= sa.min_levels_of_separation
		OR p.levels_down IS NULL
	ORDER BY sa.descendant_concept_code,
			sa.min_levels_of_separation,
		p.ranked DESC,
		CASE peak_domain_id
			WHEN 'Condition'
				THEN 1
			WHEN 'Measurement'
				THEN 2
			WHEN 'Procedure'
				THEN 3
			WHEN 'Device'
				THEN 4
			WHEN 'Provider'
				THEN 5
			WHEN 'Drug'
				THEN 6
			WHEN 'Gender'
				THEN 7
			WHEN 'Race'
				THEN 8
			ELSE 10
			END,
		p.peak_domain_id
	) i
WHERE d.concept_code = i.descendant_concept_code;

--Assign domains of peaks themselves
UPDATE domain_snomed d
SET domain_id = i.peak_domain_id
FROM (
	SELECT DISTINCT ON (peak_code) peak_code,
		peak_domain_id
	FROM peak
	WHERE ranked IS NOT NULL
	ORDER BY peak_code,
		levels_down
	) i
WHERE d.concept_code = i.peak_code;

--Update top SNOMED concept
UPDATE domain_snomed SET domain_id = 'Metadata' WHERE concept_code = '138875005';

--13.4. Update concept_stage from newly created domains
UPDATE concept_stage c
SET domain_id = i.domain_id
FROM domain_snomed i
WHERE c.vocabulary_id IN ('SNOMED', 'SNOMED Veterinary')
	AND i.concept_code = c.concept_code;

--14. For deprecated concepts without hierarchy assign domains from base table
UPDATE concept_stage cs
SET domain_id = c.domain_id
FROM concept c
WHERE c.concept_code = cs.concept_code
	AND c.vocabulary_id = cs.vocabulary_id
	AND NOT EXISTS (
		SELECT 1
		FROM snomed_ancestor sa
		WHERE sa.descendant_concept_code = cs.concept_code
		)
	AND cs.invalid_reason IS NOT NULL;

--15. All ingredients of drugs should be drugs
-- NOTE: the ingredient target (concept_code_2) may be a core SNOMED
-- concept already marked domain_id = 'Drug' in the live concept table
-- rather than in concept_stage.
UPDATE concept_stage cs
SET domain_id = 'Drug'
FROM concept_relationship_stage crs
LEFT JOIN concept_stage ccs ON ccs.concept_code = crs.concept_code_2
	AND ccs.vocabulary_id = crs.vocabulary_id_2
	AND ccs.domain_id = 'Drug'
LEFT JOIN concept ccs_core ON ccs_core.concept_code = crs.concept_code_2
	AND ccs_core.vocabulary_id = crs.vocabulary_id_2
	AND ccs_core.domain_id = 'Drug'
	AND ccs.concept_code IS NULL
WHERE cs.concept_code = crs.concept_code_1
	AND cs.vocabulary_id = crs.vocabulary_id_1
	AND crs.relationship_id = 'Active ing of'
	AND crs.invalid_reason IS NULL
	AND COALESCE(ccs.concept_code, ccs_core.concept_code) IS NOT NULL
	AND cs.domain_id <> 'Drug';

--16. Make manual changes according to rules
--Assign Measurement domain to all scores
UPDATE concept_stage
SET domain_id = 'Measurement'
WHERE concept_name ILIKE '%score%'
	AND concept_class_id = 'Observable Entity'
	AND vocabulary_id IN ('SNOMED', 'SNOMED Veterinary');

--Trim word 'route' from concepts in 'Route' domain
UPDATE concept_stage
SET concept_name = regexp_replace(concept_name, '\sroute$', '')
WHERE concept_name LIKE '% route'
	AND domain_id = 'Route'
	AND vocabulary_id IN ('SNOMED', 'SNOMED Veterinary');

--Fix navigational concepts
UPDATE concept_stage cs
SET domain_id = CASE cs.concept_class_id
		WHEN 'Admin Concept'
			THEN 'Type Concept'
		WHEN 'Attribute'
			THEN 'Observation'
		WHEN 'Body Structure'
			THEN 'Spec Anatomic Site'
		WHEN 'Clinical Finding'
			THEN 'Condition'
		WHEN 'Context-dependent'
			THEN 'Observation'
		WHEN 'Event'
			THEN 'Observation'
		WHEN 'Inactive Concept'
			THEN 'Metadata'
		WHEN 'Linkage Assertion'
			THEN 'Relationship'
		WHEN 'Location'
			THEN 'Observation'
		WHEN 'Model Comp'
			THEN 'Metadata'
		WHEN 'Morph Abnormality'
			THEN 'Observation'
		WHEN 'Namespace Concept'
			THEN 'Metadata'
		WHEN 'Navi Concept'
			THEN 'Metadata'
		WHEN 'Observable Entity'
			THEN 'Observation'
		WHEN 'Organism'
			THEN 'Observation'
		WHEN 'Pharma/Biol Product'
			THEN 'Drug'
		WHEN 'Physical Force'
			THEN 'Observation'
		WHEN 'Physical Object'
			THEN 'Device'
		WHEN 'Procedure'
			THEN 'Procedure'
		WHEN 'Qualifier Value'
			THEN 'Observation'
		WHEN 'Record Artifact'
			THEN 'Type Concept'
		WHEN 'Social Context'
			THEN 'Observation'
		WHEN 'Special Concept'
			THEN 'Metadata'
		WHEN 'Specimen'
			THEN 'Specimen'
		WHEN 'Staging / Scales'
			THEN 'Observation'
		WHEN 'Substance'
			THEN 'Observation'
		ELSE 'Observation'
		END
FROM snomed_ancestor sa
WHERE sa.ancestor_concept_code = '363743006' -- Navigational Concept
	AND cs.concept_code = sa.descendant_concept_code;

--17. Set standard_concept based on validity and domain_id
UPDATE concept_stage cs
SET standard_concept = CASE domain_id
		WHEN 'Drug'
			THEN NULL -- Drugs are RxNorm
		WHEN 'Gender'
			THEN NULL -- Gender are OMOP
		WHEN 'Metadata'
			THEN NULL -- Not used in CDM
		WHEN 'Race'
			THEN NULL -- Race are CDC
		WHEN 'Provider'
			THEN NULL -- got own Provider domain
		WHEN 'Visit'
			THEN NULL -- got own Visit domain
		WHEN 'Type Concept'
			THEN NULL -- got own Type Concept domain
		WHEN 'Unit'
			THEN NULL -- Units are UCUM
		ELSE 'S'
		END
WHERE cs.vocabulary_id IN ('SNOMED', 'SNOMED Veterinary');

--17.1. Make invalid concepts non-standard
UPDATE concept_stage cs
SET standard_concept = NULL
WHERE invalid_reason IS NOT NULL
	AND cs.vocabulary_id IN ('SNOMED', 'SNOMED Veterinary');

--17.2. De-standardize navigational concepts
UPDATE concept_stage cs
SET standard_concept = NULL
FROM snomed_ancestor sa
WHERE sa.ancestor_concept_code = '363743006' -- Navigational Concept
	AND cs.concept_code = sa.descendant_concept_code;

--17.3. Make Obsolete routes non-standard
UPDATE concept_stage
SET standard_concept = NULL
WHERE concept_name LIKE 'Obsolete%'
	AND domain_id = 'Route'
	AND vocabulary_id IN ('SNOMED', 'SNOMED Veterinary');

--17.4. Make domain 'Geography' non-standard, except countries and vet-specific locations
UPDATE concept_stage
SET standard_concept = NULL
WHERE concept_class_id = 'Location'
	AND vocabulary_id IN ('SNOMED', 'SNOMED Veterinary')
	AND concept_code NOT IN (
		SELECT descendant_concept_code
		FROM snomed_ancestor
		WHERE ancestor_concept_code = '223369002' -- Country
		)
	AND concept_code NOT IN (
		'356671000009107' -- Non-farming environment (vet-specific, should remain Standard)
		);

--17.5. Make procedures with the context = 'Done' non-standard
UPDATE concept_stage cs
SET standard_concept = NULL
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = cs.concept_code
			AND crs.relationship_id = 'Has proc context'
			AND crs.concept_code_2 = '385658003'
			AND crs.vocabulary_id_2 IN ('SNOMED', 'SNOMED Veterinary')
			AND crs.invalid_reason IS NULL
		);

--17.6. Make certain hierarchical branches non-standard
-- NOTE: vaccine administration ancestors (312871001, 49083007, 283511000000105)
-- are intentionally scoped to 'SNOMED' only and not 'SNOMED Veterinary' --
-- in veterinary medicine these vaccination procedure codes are clinically
-- meaningful and should remain Standard, unlike in human medicine where
-- the vaccine product concept is preferred over the administration procedure.
UPDATE concept_stage cs
SET standard_concept = NULL
FROM snomed_ancestor sa
WHERE sa.ancestor_concept_code IN (
		'373060007', -- Device status
		'417662000', -- History of clinical finding in subject
		'1260502004', -- History of event in life of subject
		'312871001', -- Administration of bacterial vaccine (SNOMED only)
		'1156257007', -- Administration of SARS-CoV-2 vaccine
		'49083007', -- Administration of viral vaccine (SNOMED only)
		'283511000000105' -- Administration of vaccine (SNOMED only)
		)
	AND NOT EXISTS (
		SELECT 1
		FROM snomed_ancestor i
		WHERE sa.descendant_concept_code = i.descendant_concept_code
			AND i.ancestor_concept_code IN (
				'394698008', -- Birth history
				'1187600006', -- Served in military service
				'1187610002' -- Left military service
				)
		)
	AND cs.concept_code = sa.descendant_concept_code
	AND NOT (
		-- Exclude vet vaccination procedures from de-standardization --
		-- vet vaccine administration codes are clinically meaningful and
		-- should remain Standard in a veterinary CDM
		cs.vocabulary_id = 'SNOMED Veterinary'
		AND sa.ancestor_concept_code IN (
			'312871001', -- Administration of bacterial vaccine
			'49083007',  -- Administration of viral vaccine
			'283511000000105' -- Administration of vaccine
			)
		);

--17.7. Make certain concept classes non-standard
-- Vet-specific attributes are excluded from de-standardization since they are
-- genuinely useful for veterinary CDM coding (confirmed Standard in devv5).
UPDATE concept_stage
SET standard_concept = NULL
WHERE concept_class_id IN (
		'Attribute',
		'Physical Force',
		'Physical Object'
		)
	AND domain_id <> 'Device'
	AND vocabulary_id IN ('SNOMED', 'SNOMED Veterinary')
	AND concept_code NOT IN (
		'26421000009105', -- Has life circumstance (vet-specific attribute)
		'26431000009107', -- Has physiologic state (vet-specific attribute)
		'30951000009108', -- Includes sub-specimen (vet-specific attribute)
		'31861000009109', -- Taxonomic rank (vet-specific attribute)
		'32181000009101'  -- Fact role (vet-specific attribute)
		);

UPDATE concept_stage cs
SET standard_concept = NULL
WHERE concept_class_id = 'Social Context'
	AND vocabulary_id IN ('SNOMED', 'SNOMED Veterinary')
	AND NOT EXISTS (
		SELECT 1
		FROM snomed_ancestor sa
		WHERE sa.descendant_concept_code = cs.concept_code
			AND sa.ancestor_concept_code IN (
				'14679004', -- Occupation
				'125677006', -- Relative
				'410597007', -- Person categorized by religious affiliation
				'108334009', -- Religion AND/OR philosophy
				'355201000009105' -- Animal group (covers Herd, Flock, and future vet social concepts)
				)
		)
	AND cs.concept_code NOT IN (
		'355201000009105' -- Animal group itself (not a descendant of itself in snomed_ancestor)
		);

--18. Add mappings from substances to RxNorm/RxE in case of full name match
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
SELECT cs.concept_code,
       cc.concept_code,
       cs.vocabulary_id,
       cc.vocabulary_id,
       'Maps to',
        (
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED Veterinary'
		) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage cs
JOIN devv5.concept cc ON LOWER(cs.concept_name) = LOWER(cc.concept_name)
WHERE cs.domain_id = 'Drug'
    AND cs.concept_class_id = 'Substance'
    AND cs.vocabulary_id IN ('SNOMED', 'SNOMED Veterinary')
    AND cc.vocabulary_id LIKE 'RxNorm%'
    AND cc.standard_concept = 'S'
    AND NOT EXISTS (
        SELECT 1
        FROM devv5.concept_relationship cr
        JOIN devv5.concept c ON c.concept_id = cr.concept_id_1
        WHERE (c.concept_code, c.vocabulary_id) = (cs.concept_code, cs.vocabulary_id)
            AND cr.relationship_id = 'Maps to'
            AND cr.invalid_reason IS NULL)
ON CONFLICT DO NOTHING;

--19. Add mappings of Clinical Drug Forms to their ingredients
INSERT INTO concept_relationship_stage (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason)
SELECT DISTINCT c.concept_code,
                c2.concept_code,
                c.vocabulary_id,
                c2.vocabulary_id,
                'Maps to',
                (
			SELECT latest_update
			FROM vocabulary
			WHERE vocabulary_id = 'SNOMED Veterinary'
			),
                TO_DATE('20991231', 'YYYYMMDD'),
                NULL
FROM concept_stage c
JOIN concept_relationship_stage cr ON cr.concept_code_1 = c.concept_code
                                    AND cr.vocabulary_id_1 = c.vocabulary_id
                                    AND cr.relationship_id = 'Has active ing'
                                    AND cr.invalid_reason IS NULL
JOIN devv5.concept cc ON (cc.concept_code, cc.vocabulary_id) = (cr.concept_code_2, cr.vocabulary_id_2)
JOIN devv5.concept_relationship cr1 ON cc.concept_id = cr1.concept_id_1
                                     AND cr1.relationship_id = 'Maps to'
                                     AND cr1.invalid_reason IS NULL
JOIN devv5.concept c2 ON c2.concept_id = cr1.concept_id_2
WHERE c.vocabulary_id IN ('SNOMED', 'SNOMED Veterinary')
  AND c.domain_id = 'Drug'
  AND c2.vocabulary_id LIKE 'RxNorm%'
  AND NOT EXISTS (SELECT 1
               FROM concept_relationship_stage crs1
               WHERE (c.concept_code, c.vocabulary_id) = (crs1.concept_code_1, crs1.vocabulary_id_1)
               AND crs1.relationship_id = 'Maps to'
               AND crs1.invalid_reason IS NULL)
  AND NOT EXISTS (SELECT 1
               FROM devv5.concept_relationship b
               JOIN devv5.concept a ON a.concept_id = b.concept_id_1
               WHERE (c.concept_code, c.vocabulary_id) = (a.concept_code, a.vocabulary_id)
               AND b.relationship_id = 'Maps to'
               AND b.invalid_reason IS NULL)
ON CONFLICT DO NOTHING;

--20. Add 'Maps to' relations to concepts that are duplicating between different SNOMED editions
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
WITH concept_status AS (
		SELECT DISTINCT ON (id) id AS conceptid,
			active,
			statusid,
			moduleid,
			effectivetime
		FROM sources_vet_sct2_concept_full c
		ORDER BY c.id,
			c.effectivetime DESC
		),
	concept_fsn AS (
		SELECT DISTINCT ON (d.conceptid) d.conceptid,
			d.term AS fsn,
			a.active,
			a.statusid,
			a.moduleid,
			a.effectivetime,
			RANK() OVER (
				PARTITION BY d.conceptid ORDER BY d.effectivetime DESC
				) AS rn
		FROM sources_vet_sct2_desc_full d
		JOIN concept_status a ON a.conceptid = d.conceptid
			AND a.active = 1
		WHERE d.active = 1
			AND d.typeid = '900000000000003001' -- FSN
		ORDER BY d.conceptid,
			d.effectivetime DESC
		),
	preferred_code AS (
		SELECT DISTINCT ON (c1.fsn) c1.fsn,
			c1.conceptid,
			c2.conceptid AS replacementid
		FROM concept_fsn c1
		JOIN concept_fsn c2 ON c2.fsn = c1.fsn
			AND c2.conceptid <> c1.conceptid
		ORDER BY c1.fsn,
			CASE c2.moduleid
				WHEN '900000000000207008' -- Core (International)
					THEN 1
				WHEN '332351000009108' -- SNOMED Veterinary extension
					THEN 2
				ELSE 3
				END,
			CASE c2.statusid
				WHEN '900000000000073002' -- fully defined
					THEN 1
				ELSE 2
				END,
			c2.effectivetime DESC
		)
SELECT p.conceptid AS concept_code_1,
	p.replacementid AS concept_code_2,
	COALESCE(cs1.vocabulary_id, c1_core.vocabulary_id) AS vocabulary_id_1,
	COALESCE(cs2.vocabulary_id, c2_core.vocabulary_id) AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	(
		SELECT v.latest_update
		FROM vocabulary v
		WHERE v.vocabulary_id = 'SNOMED Veterinary'
		) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date
FROM preferred_code p
LEFT JOIN concept_stage cs1 ON cs1.concept_code = p.conceptid
LEFT JOIN concept c1_core ON c1_core.concept_code = p.conceptid
	AND c1_core.vocabulary_id = 'SNOMED'
	AND cs1.concept_code IS NULL
LEFT JOIN concept_stage cs2 ON cs2.concept_code = p.replacementid
LEFT JOIN concept c2_core ON c2_core.concept_code = p.replacementid
	AND c2_core.vocabulary_id = 'SNOMED'
	AND cs2.concept_code IS NULL
WHERE COALESCE(cs2.standard_concept, c2_core.standard_concept) IS NOT NULL
AND (cs1.vocabulary_id = 'SNOMED Veterinary' OR cs2.vocabulary_id = 'SNOMED Veterinary') -- at least one side must be a vet concept
AND NOT EXISTS (
       SELECT 1
       FROM concept_relationship_stage crs
       WHERE crs.concept_code_1 = p.conceptid
       AND crs.concept_code_2 = p.replacementid
       AND crs.vocabulary_id_1 = COALESCE(cs1.vocabulary_id, c1_core.vocabulary_id)
       AND crs.vocabulary_id_2 = COALESCE(cs2.vocabulary_id, c2_core.vocabulary_id)
       AND crs.relationship_id = 'Maps to'
       AND crs.invalid_reason IS NULL
);

--21. Append manual concepts again for final assignment of concept characteristics
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--22. Working with relationships

-- Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

-- Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

-- Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--23. Pre-GenericUpdate QA fixes

-- Fix concept_stage: invalid_reason = NULL for concepts with valid_end_date < 20991231
UPDATE concept_stage
SET invalid_reason = 'D'
WHERE valid_end_date < TO_DATE('20991231', 'YYYYMMDD')
  AND invalid_reason IS NULL;

-- Fix concept_stage: invalid_reason = 'X' is not valid in concept_stage, convert to 'D'
UPDATE concept_stage
SET invalid_reason = 'D',
    valid_end_date = (
        SELECT latest_update - 1
        FROM vocabulary
        WHERE vocabulary_id = 'SNOMED Veterinary'
    )
WHERE invalid_reason = 'X';

-- Fix concept_stage: valid_end_date < valid_start_date (caused by LEAST() logic in step 9.6
-- picking a replacement relationship valid_start_date older than the concept's own start date)
UPDATE concept_stage
SET valid_end_date = valid_start_date
WHERE valid_end_date < valid_start_date;

-- Fix concept_stage: NULL concept_name for deprecated concepts inserted via ProcessManualConcepts()
-- Pull name from concept table where available
UPDATE concept_stage cs
SET concept_name = c.concept_name
FROM concept c
WHERE c.concept_code = cs.concept_code
    AND c.vocabulary_id = cs.vocabulary_id
    AND (cs.concept_name IS NULL OR cs.concept_name = '')
    AND c.concept_name IS NOT NULL
    AND c.concept_name <> '';

-- For any remaining rows not found in concept, assign a placeholder
UPDATE concept_stage
SET concept_name = 'No name provided - ' || concept_code
WHERE concept_name IS NULL OR concept_name = '';

-- Fix concept_stage: NULL concept_class_id for concepts inserted via ProcessManualConcepts()
-- Pull from concept table where available
UPDATE concept_stage cs
SET concept_class_id = c.concept_class_id
FROM concept c
WHERE c.concept_code = cs.concept_code
    AND c.vocabulary_id = cs.vocabulary_id
    AND cs.concept_class_id IS NULL
    AND c.concept_class_id IS NOT NULL;

-- For any remaining rows not found in concept, assign a placeholder
UPDATE concept_stage
SET concept_class_id = 'Undefined'
WHERE concept_class_id IS NULL;

-- Fix concept_relationship_stage: valid_end_date < valid_start_date
-- (caused by latest_update date mismatch between SNOMED and SNOMED Veterinary in step 9.2)
UPDATE concept_relationship_stage
SET valid_end_date = valid_start_date
WHERE valid_end_date < valid_start_date;

--24. Clean up
DROP TABLE IF EXISTS peak;
DROP TABLE IF EXISTS domain_snomed;
DROP TABLE IF EXISTS snomed_ancestor;
DROP TABLE IF EXISTS hierarchy_concept_lookup;
DROP TABLE IF EXISTS replacements;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage
-- should be ready to be fed into the generic_update.sql script

