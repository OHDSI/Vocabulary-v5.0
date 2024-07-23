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
* Authors: Eduard Korchmar, Alexander Davydov, Timur Vakhitov,
* Christian Reich, Oleg Zhuk, Masha Khitrun
* Date: 2024
**************************************************************************/

--1. Extract each component (International, UK & US) versions to properly date the combined source in next step
CREATE OR REPLACE VIEW module_date AS
SELECT s0.moduleid,
	CASE 
		WHEN s0.moduleid = '900000000000207008'
			THEN TO_CHAR(MAX(s0.int_version) OVER (), 'yyyy-mm-dd')
		ELSE s0.local_version
		END AS version
FROM (
	SELECT DISTINCT ON (m.id) m.moduleid,
		TO_CHAR(m.sourceeffectivetime, 'yyyy-mm-dd') AS local_version,
		m.targeteffectivetime AS int_version
	FROM sources.der2_ssrefset_moduledependency_merged m
	WHERE m.active = 1
		AND m.referencedcomponentid = '900000000000012004'
		AND --Model component module; Synthetic target, contains source version in each row
		m.moduleid IN (
			'900000000000207008', --Core (international) module
			'999000011000000103', --UK edition
			'731000124108' --US edition
			)
	ORDER BY m.id,
		m.effectivetime DESC
	) s0;

--2. Update latest_update field to new date
--Use the latest of the release dates of all source versions. Usually, the UK is the latest.
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'SNOMED',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.sct2_concept_full_merged LIMIT 1),
	pVocabularyVersion		=>
		(SELECT version FROM module_date where moduleid = '900000000000207008') || ' SNOMED CT International Edition; ' ||
		(SELECT version FROM module_date where moduleid = '731000124108') || ' SNOMED CT US Edition; ' ||
		(SELECT version FROM module_date where moduleid = '999000011000000103') || ' SNOMED CT UK Edition',
	pVocabularyDevSchema	=> 'DEV_SNOMED'
);
END $_$;

--3. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--4. Create core version of SNOMED without concept_id, domain_id, concept_class_id, standard_concept
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT sct2.concept_name,
	'SNOMED' AS vocabulary_id,
	sct2.concept_code,
	TO_DATE(effectivestart, 'YYYYMMDD') AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM (
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
					WHEN '900000000000509007'
						THEN 1 --US English language reference set
					WHEN '900000000000508004'
						THEN 2 --UK English language reference set
					ELSE 99 -- Various UK specific refsets
					END,
				CASE l.source_file_id
					WHEN 'INT'
						THEN 1 -- International release
					WHEN 'US'
						THEN 2 -- SNOMED US
					WHEN 'UK'
						THEN 3 -- SNOMED UK
					ELSE 99
					END ASC,
				l.effectivetime DESC,
				d.term
			) AS rn
	FROM sources.sct2_concept_full_merged c
	JOIN sources.sct2_desc_full_merged d ON d.conceptid = c.id
	JOIN sources.der2_crefset_language_merged l ON l.referencedcomponentid = d.id
	WHERE c.moduleid NOT IN (
			'999000011000001104', --UK Drug extension
			'999000021000001108' --UK Drug extension reference set module
			)
	) sct2
WHERE sct2.rn = 1;

ANALYZE concept_stage;

--4.1 For concepts with latest entry in sct2_concept having active = 0, preserve invalid_reason and valid_end date
UPDATE concept_stage cs
SET invalid_reason = 'D',
	valid_end_date = i.effectiveend
FROM (
	SELECT s0.*
	FROM (
		SELECT DISTINCT ON (c.id) c.id,
			TO_DATE(c.effectivetime, 'YYYYMMDD') AS effectiveend,
			c.active
		FROM sources.sct2_concept_full_merged c
		WHERE c.moduleid NOT IN (
				'999000011000001104', --UK Drug extension
				'999000021000001108' --UK Drug extension reference set module
				)
		ORDER BY c.id,
			TO_DATE(c.effectivetime, 'YYYYMMDD') DESC
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
								ELSE 99
								END
						) AS rnc
				FROM (
					SELECT concept_code,
						active,
						SUBSTRING(term, '\(([^(]+)\)$') AS f7,
						rna AS rnb -- row number in sct2_desc_full_merged
					FROM (
						SELECT c.concept_code,
							d.term,
							d.active,
							ROW_NUMBER() OVER (
								PARTITION BY c.concept_code ORDER
								BY
									d.active DESC, -- active ones
									d.effectivetime DESC -- latest active ones
								) rna -- row number in sct2_desc_full_merged
						FROM concept_stage c
						JOIN sources.sct2_desc_full_merged d ON d.conceptid = c.concept_code
						WHERE c.vocabulary_id = 'SNOMED'
							AND d.typeid = '900000000000003001' -- only Fully Specified Names
							AND d.moduleid NOT IN (
								'999000011000001104', --UK Drug extension
								'999000021000001108'  --UK Drug extension reference set module
							)
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
					--added 20190109 (AVOF-1369)
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
					--Metadata concepts
			WHEN F7 = 'OWL metadata concept'
				THEN 'Model Comp'
					--Specific drug qualifiers
			WHEN F7 = 'supplier'
				THEN 'Qualifier Value'
			WHEN F7 = 'product name'
				THEN 'Qualifier Value'
			ELSE 'Undefined'
			END AS concept_class_id
	FROM tmp_concept_class
	) i
WHERE i.concept_code = cs.concept_code
	AND cs.vocabulary_id = 'SNOMED'
;

--Assign top SNOMED concept
UPDATE concept_stage
SET concept_class_id = 'Model Comp'
WHERE concept_code = '138875005'
	AND vocabulary_id = 'SNOMED';

--Deprecated Concepts with broken fully specified name
UPDATE concept_stage
SET concept_class_id = 'Procedure'
WHERE vocabulary_id = 'SNOMED'
	AND concept_code IN (
		'712611000000106', --Assessment using childhood health assessment questionnaire
		'193371000000106' --Fluoroscopic angioplasty of carotid artery
		);

UPDATE concept_stage
SET concept_class_id = 'Staging / Scales'
WHERE vocabulary_id = 'SNOMED'
	AND concept_code IN (
		'821611000000108',
		'821551000000108',
		'821591000000100',
		'821561000000106',
		'821581000000102',
		'1090511000000109'
		);

--6. Get all the synonyms from UMLS ('PT', 'PTGB', 'SY', 'SYGB', 'MTH_PT', 'FN', 'MTH_SY', 'SB') into concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)
SELECT DISTINCT m.code,
	'SNOMED',
	vocabulary_pack.CutConceptSynonymName(m.str),
	4180186 -- English
FROM sources.mrconso m
JOIN concept_stage s ON s.concept_code = m.code
WHERE m.sab = 'SNOMEDCT_US'
	AND m.tty IN (
		'PT',
		'PTGB',
		'SY',
		'SYGB',
		'MTH_PT',
		'FN',
		'MTH_SY',
		'SB'
		);

--7. Add active synonyms from merged descriptions list
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)
SELECT DISTINCT d.conceptid,
	'SNOMED',
	vocabulary_pack.CutConceptSynonymName(d.term),
	4180186 -- English
FROM (
	SELECT m.conceptid,
		m.term,
		FIRST_VALUE(m.active) OVER (
			PARTITION BY m.id ORDER BY TO_DATE(m.effectivetime, 'YYYYMMDD') DESC
			) AS active_status
	FROM sources.sct2_desc_full_merged m
	WHERE m.moduleid NOT IN (
			'999000011000001104', -- UK Drug extension
			'999000021000001108' -- UK Drug extension reference set module
			)
	) d
WHERE EXISTS (
		SELECT 1
		FROM concept_stage s
		WHERE s.concept_code = d.conceptid
		)
	AND d.active_status = 1
ON CONFLICT DO NOTHING;

--8. Fill concept_relationship_stage from merged SNOMED source
-- 8.1 Add relationships from concept to module and from concept to status:
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
	c.moduleid AS concept_code_2,
	'SNOMED' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	'Has Module' AS relationship_id,
	cs.valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.sct2_concept_full_merged c
JOIN concept_stage cs ON cs.concept_code = c.id
	AND cs.vocabulary_id = 'SNOMED'
WHERE c.moduleid IN (
		'900000000000207008', --Core (international) module
		'999000011000000103', --UK edition
		'731000124108', --US edition
		'900000000000012004' --SNOMED CT model component
		)

UNION ALL

--add relationship from concept to status
(
	SELECT DISTINCT ON (c.id) c.id AS concept_code_1,
		c.statusid AS concept_code_2,
		'SNOMED' AS vocabulary_id_1,
		'SNOMED' AS vocabulary_id_2,
		'Has status' AS relationship_id,
		TO_DATE(c.effectivetime, 'YYYYMMDD') AS valid_start_date,
		TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
		NULL AS invalid_reason
	FROM sources.sct2_concept_full_merged c
	WHERE EXISTS (
			SELECT 1
			FROM concept_stage s
			WHERE s.concept_code = c.id
			)
		AND c.statusid IN (
			'900000000000073002', --Defined
			'900000000000074008' --Primitive
			)
		AND c.active = 1
		AND c.moduleid NOT IN (
			'999000011000001104', --SNOMED CT United Kingdom drug extension module
			'999000021000001108' --SNOMED CT United Kingdom drug extension reference set module
			)
	ORDER BY c.id,
		TO_DATE(c.effectivetime, 'YYYYMMDD') DESC
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
			FROM sources.sct2_rela_full_merged r
			JOIN sources.sct2_desc_full_merged d ON d.conceptid = r.typeid
			WHERE r.moduleid NOT IN (
					'999000011000001104', --UK Drug extension
					'999000021000001108' --UK Drug extension reference set module
					)
			-- get the latest in a sequence of relationships, to decide whether it is still active
			ORDER BY r.id,
				TO_DATE(r.effectivetime, 'YYYYMMDD') DESC,
				d.id DESC -- fix for AVOF-650
			) AS s0
		WHERE s0.active = 1
			AND s0.sourceid IS NOT NULL
			AND s0.destinationid IS NOT NULL
			AND s0.term <> 'PBCL flag true'
		)
--convert SNOMED to OMOP-type relationship_id
SELECT DISTINCT sourceid AS concept_code_1,
	destinationid AS concept_code_2,
	'SNOMED' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	CASE
		WHEN typeid = '260507000'
			THEN 'Has access'
		WHEN typeid = '363715002'
			THEN 'Has etiology'
		WHEN typeid = '255234002'
			THEN 'Followed by'
		WHEN typeid = '260669005'
			THEN 'Has surgical appr'
		WHEN typeid = '246090004'
			THEN 'Has asso finding'
		WHEN typeid = '116676008'
			THEN 'Has asso morph'
		WHEN typeid = '363589002'
			THEN 'Has asso proc'
		WHEN typeid = '47429007'
			THEN 'Finding asso with'
		WHEN typeid = '246075003'
			THEN 'Has causative agent'
		WHEN typeid = '246093002'
			THEN 'Has component'
		WHEN typeid = '363699004'
			THEN 'Has dir device'
		WHEN typeid = '363700003'
			THEN 'Has dir morph'
		WHEN typeid = '363701004'
			THEN 'Has dir subst'
		WHEN typeid = '42752001'
			THEN 'Has due to'
		WHEN typeid = '246456000'
			THEN 'Has episodicity'
		WHEN typeid = '260858005'
			THEN 'Has extent'
		WHEN typeid = '408729009'
			THEN 'Has finding context'
		WHEN typeid = '419066007'
			THEN 'Using finding inform'
		WHEN typeid = '418775008'
			THEN 'Using finding method'
		WHEN typeid = '363698007'
			THEN 'Has finding site'
		WHEN typeid = '127489000'
			THEN 'Has active ing'
		WHEN typeid = '363705008'
			THEN 'Has manifestation'
		WHEN typeid IN (
				'411116001',
				'411116001'
				)
			THEN 'Has dose form'
		WHEN typeid = '363702006'
			THEN 'Has focus'
		WHEN typeid = '363713009'
			THEN 'Has interpretation'
		WHEN typeid = '116678009'
			THEN 'Has meas component'
		WHEN typeid = '116686009'
			THEN 'Has specimen'
		WHEN typeid = '258214002'
			THEN 'Has stage'
		WHEN typeid = '363710007'
			THEN 'Has indir device'
		WHEN typeid = '363709002'
			THEN 'Has indir morph'
		WHEN typeid = '309824003'
			THEN 'Using device'
		WHEN typeid = '363703001'
			THEN 'Has intent'
		WHEN typeid = '363714003'
			THEN 'Has interprets'
		WHEN typeid = '116680003'
			THEN 'Is a'
		WHEN typeid = '272741003'
			THEN 'Has laterality'
		WHEN typeid = '370129005'
			THEN 'Has measurement'
		WHEN typeid = '260686004'
			THEN 'Has method'
		WHEN typeid = '246454002'
			THEN 'Has occurrence'
		WHEN typeid IN (
		        '246100006',
		        '263502005',
		   		'260908002'
		        )
			THEN 'Has clinical course'
		WHEN typeid = '123005000'
			THEN 'Part of'
		WHEN typeid IN (
				'308489006',
				'370135005',
				'719722006'
				)
			THEN 'Has pathology'
		WHEN typeid = '260870009'
			THEN 'Has priority'
		WHEN typeid = '408730004'
			THEN 'Has proc context'
		WHEN typeid = '405815000'
			THEN 'Has proc device'
		WHEN typeid = '405816004'
			THEN 'Has proc morph'
		WHEN typeid = '405813007'
			THEN 'Has dir proc site'
		WHEN typeid = '405814001'
			THEN 'Has indir proc site'
		WHEN typeid = '363704007'
			THEN 'Has proc site'
		WHEN typeid = '370130000'
			THEN 'Has property'
		WHEN typeid = '370131001'
			THEN 'Has recipient cat'
		WHEN typeid = '246513007'
			THEN 'Has revision status'
		WHEN typeid = '410675002'
			THEN 'Has route of admin'
		WHEN typeid = '370132008'
			THEN 'Has scale type'
		WHEN typeid = '246112005'
			THEN 'Has severity'
		WHEN typeid = '118171006'
			THEN 'Has specimen proc'
		WHEN typeid = '118170007'
			THEN 'Has specimen source'
		WHEN typeid = '118168003'
			THEN 'Has specimen morph'
		WHEN typeid = '118169006'
			THEN 'Has specimen topo'
		WHEN typeid = '370133003'
			THEN 'Has specimen subst'
		WHEN typeid = '408732007'
			THEN 'Has relat context'
		WHEN typeid = '424876005'
			THEN 'Has surgical appr'
		WHEN typeid = '408731000'
			THEN 'Has temporal context'
		WHEN typeid = '363708005'
			THEN 'Occurs after'
		WHEN typeid = '370134009'
			THEN 'Has time aspect'
		WHEN typeid = '425391005'
			THEN 'Using acc device'
		WHEN typeid = '424226004'
			THEN 'Using device'
		WHEN typeid = '424244007'
			THEN 'Using energy'
		WHEN typeid = '424361007'
			THEN 'Using subst'
		WHEN typeid = '255234002'
			THEN 'Followed by'
		WHEN typeid = '8940601000001102'
			THEN 'Has non-avail ind'
		WHEN typeid = '12223201000001101'
			THEN 'Has ARP'
		WHEN typeid = '12223101000001108'
			THEN 'Has VRP'
		WHEN typeid = '9191701000001107'
			THEN 'Has trade family grp'
		WHEN typeid = '8941101000001104'
			THEN 'Has flavor'
		WHEN typeid = '8941901000001101'
			THEN 'Has disc indicator'
		WHEN typeid = '12223501000001103'
			THEN 'VRP has prescr stat'
		WHEN typeid = '10362801000001104'
			THEN 'Has spec active ing'
		WHEN typeid = '8653101000001104'
			THEN 'Has excipient'
		WHEN typeid IN (
				'732943007',
				'10363001000001101'
				)
			THEN 'Has basis str subst'
		WHEN typeid = '10362601000001103'
			THEN 'Has VMP'
		WHEN typeid = '10362701000001108'
			THEN 'Has AMP'
		WHEN typeid = '10362901000001105'
			THEN 'Has disp dose form'
		WHEN typeid = '8940001000001105'
			THEN 'VMP has prescr stat'
		WHEN typeid IN (
				'8941301000001102',
				'4074701000001107'
				)
			THEN 'Has legal category'
		WHEN typeid = '42752001'
			THEN 'Caused by'
		WHEN typeid = '704326004'
			THEN 'Has precondition'
		WHEN typeid = '718497002'
			THEN 'Has inherent loc'
		WHEN typeid = '246501002'
			THEN 'Has technique'
		WHEN typeid = '719715003'
			THEN 'Has relative part'
		WHEN typeid = '704324001'
			THEN 'Has process output'
		WHEN typeid = '704318007'
			THEN 'Has property type'
		WHEN typeid = '704319004'
			THEN 'Inheres in'
		WHEN typeid = '704327008'
			THEN 'Has direct site'
		WHEN typeid = '704321009'
			THEN 'Characterizes'
				--added 20171116
		WHEN typeid = '371881003'
			THEN 'During'
		WHEN typeid = '732947008'
			THEN 'Has denominator unit'
		WHEN typeid = '732946004'
			THEN 'Has denomin value'
		WHEN typeid = '732945000'
			THEN 'Has numerator unit'
		WHEN typeid = '732944001'
			THEN 'Has numerator value'
				--added 20180205
		WHEN typeid = '736476002'
			THEN 'Has basic dose form'
		WHEN typeid = '726542003'
			THEN 'Has disposition'
		WHEN typeid = '736472000'
			THEN 'Has admin method'
		WHEN typeid = '736474004'
			THEN 'Has intended site'
		WHEN typeid = '736475003'
			THEN 'Has release charact'
		WHEN typeid = '736473005'
			THEN 'Has transformation'
		WHEN typeid = '736518005'
			THEN 'Has state of matter'
		WHEN typeid = '726633004'
			THEN 'Temp related to'
				--added 20180622
		WHEN typeid = '13085501000001109'
			THEN 'Has unit of admin'
		WHEN typeid = '762949000'
			THEN 'Has prec ingredient'
		WHEN typeid = '763032000'
			THEN 'Has unit of presen'
		WHEN typeid = '733724008'
			THEN 'Has conc num val'
		WHEN typeid = '733723002'
			THEN 'Has conc denom val'
		WHEN typeid = '733722007'
			THEN 'Has conc denom unit'
		WHEN typeid = '733725009'
			THEN 'Has conc num unit'
		WHEN typeid = '738774007'
			THEN 'Modification of'
		WHEN typeid = '766952006'
			THEN 'Has count of ing'
				--20190204
		WHEN typeid = '766939001'
			THEN 'Plays role'
				--20190823
		WHEN typeid = '13088401000001104'
			THEN 'Has route'
		WHEN typeid = '13089101000001102'
			THEN 'Has CD category'
		WHEN typeid = '13088501000001100'
			THEN 'Has ontological form'
		WHEN typeid = '13088901000001108'
			THEN 'Has combi prod ind'
		WHEN typeid = '13088701000001106'
			THEN 'Has form continuity'
				--20200312
		WHEN typeid = '13090301000001106'
			THEN 'Has add monitor ind'
		WHEN typeid = '13090501000001104'
			THEN 'Has AMP restr ind'
		WHEN typeid = '13090201000001102'
			THEN 'Paral imprt ind'
		WHEN typeid = '13089701000001101'
			THEN 'Has free indicator'
		WHEN typeid = '246514001'
			THEN 'Has unit'
		WHEN typeid = '704323007'
			THEN 'Has proc duration'
				--20201023
		WHEN typeid = '704325000'
			THEN 'Relative to'
		WHEN typeid = '766953001'
			THEN 'Has count of act ing'
		WHEN typeid = '860781008'
			THEN 'Has prod character'
		WHEN typeid = '860779006'
			THEN 'Has prod character'
		WHEN typeid = '246196007'
			THEN 'Surf character of'
		WHEN typeid = '836358009'
			THEN 'Has dev intend site'
		WHEN typeid = '840562008'
			THEN 'Has prod character'
		WHEN typeid = '840560000'
			THEN 'Has comp material'
		WHEN typeid = '827081001'
			THEN 'Has filling'
				--January 2022
		WHEN typeid = '1148967007'
			THEN 'Has coating material'
		WHEN typeid = '1148969005'
			THEN 'Has absorbability'
		WHEN typeid = '1003703000'
			THEN 'Process extends to'
		WHEN typeid = '1149366004'
			THEN 'Has strength'
		WHEN typeid = '1148968002'
			THEN 'Has surface texture'
		WHEN typeid = '1148965004'
			THEN 'Is sterile'
		WHEN typeid = '1149367008'
			THEN 'Has targ population'
				-- August 2023
		WHEN typeid = '1003735000'
			THEN 'Process acts on'
		WHEN typeid = '288556008'
			THEN 'Before'
		WHEN typeid = '704320005'
			THEN 'Towards'
		ELSE term --'non-existing'
		END AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED'
		) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM attr_rel
ON CONFLICT DO NOTHING;

--check for non-existing relationships
ALTER TABLE concept_relationship_stage ADD CONSTRAINT tmp_constraint_relid FOREIGN KEY (relationship_id) REFERENCES relationship (relationship_id);
ALTER TABLE concept_relationship_stage DROP CONSTRAINT tmp_constraint_relid;
--SELECT relationship_id FROM concept_relationship_stage EXCEPT SELECT relationship_id FROM relationship;

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
SELECT DISTINCT sn.concept_code_1,
	sn.concept_code_2,
	'SNOMED',
	'SNOMED',
	sn.relationship_id,
	TO_DATE(sn.effectivestart, 'YYYYMMDD'),
	TO_DATE('20991231', 'YYYYMMDD'),
	NULL
FROM (
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
		ROW_NUMBER() OVER (
			PARTITION BY sc.referencedcomponentid ORDER BY TO_DATE(sc.effectivetime, 'YYYYMMDD') DESC,
				sc.id DESC --same as of AVOF-650
			) rn,
		ROW_NUMBER() OVER (
			PARTITION BY sc.referencedcomponentid,
			sc.targetcomponent,
			sc.moduleid ORDER BY TO_DATE(sc.effectivetime, 'YYYYMMDD') DESC
			) AS recent_status, --recent status of the relationship. To be used with 'active' field
		active
	FROM sources.der2_crefset_assreffull_merged sc
	WHERE sc.refsetid IN (
			'900000000000526001',
			'900000000000523009',
			'900000000000528000',
			'900000000000527005',
			'900000000000530003'
			)
		AND sc.moduleid NOT IN (
			'999000011000001104', --UK Drug extension
			'999000021000001108' --UK Drug extension reference set module
			)
	) sn
WHERE EXISTS (
		SELECT 1
		FROM concept_stage s
		WHERE s.concept_code = sn.concept_code_2
		)
	AND (
		(
			--Bring all Concept poss_eq to concept_relationship table and do not build new Maps to based on them
			sn.refsetid = '900000000000523009'
			AND sn.rn >= 1
			)
		OR sn.rn = 1
		)
	AND sn.active = 1
	AND sn.recent_status = 1 --no row with the same target concept, but more recent relationship with active = 0
ON CONFLICT DO NOTHING;

--9.1 Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--9.2 Sometimes concept are back from U to fresh, we need to deprecate our replacement mappings
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
	'SNOMED' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	cr.relationship_id,
	cr.valid_start_date,
	(
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED'
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
	AND cs.vocabulary_id = 'SNOMED'
	AND crs.concept_code_1 IS NULL;

--same as above, but for 'Maps to' (we need to add the manual deprecation for proper work of the VOCABULARY_PACK.AddFreshMAPSTO)
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
	'SNOMED' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	'Maps to',
	cr.valid_start_date,
	(
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED'
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

--delete records that do not exist in the concept and concept_stage
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

--9.3. Update invalid reason for concepts with replacements to 'U', to ensure we keep correct date
UPDATE concept_stage cs
SET invalid_reason = 'U',
	valid_end_date = LEAST(cs.valid_end_date, crs.valid_start_date, (
			SELECT latest_update
			FROM vocabulary v
			WHERE v.vocabulary_id = 'SNOMED'
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

--9.4. Update invalid reason for concepts with 'Concept poss_eq to' relationships. They are no longer considered replacement relationships.
UPDATE concept_stage cs
SET invalid_reason = 'D',
	valid_end_date = LEAST(crs.valid_start_date, (
			SELECT latest_update - 1
			FROM vocabulary v
			WHERE v.vocabulary_id = 'SNOMED'
			))
FROM concept_relationship_stage crs
WHERE crs.concept_code_1 = cs.concept_code
	AND crs.relationship_id = 'Concept poss_eq to'
	AND crs.invalid_reason IS NULL
	AND cs.invalid_reason IS NULL;

--9.5. Update valid_end_date to latest_update if there is a discrepancy after last point
UPDATE concept_stage cs
SET valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED'
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
			THEN 'Measurement' --domain changed
		WHEN 'Substance'
			THEN 'Observation' --domain changed
		ELSE 'Observation'
		END AS domain_id
FROM concept_stage;

--12. Start building the hierarchy for propagating domain_ids from top to bottom
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
			AND crs.vocabulary_id_1 = 'SNOMED'
			AND crs.vocabulary_id_2 = 'SNOMED'
		)
	SELECT hc.root_ancestor_concept_code AS ancestor_concept_code,
		hc.descendant_concept_code,
		MIN(hc.levels_of_separation) AS min_levels_of_separation
	FROM hierarchy_concepts hc
	JOIN concept_stage cs1 ON cs1.concept_code = hc.root_ancestor_concept_code
		AND cs1.vocabulary_id = 'SNOMED'
	JOIN concept_stage cs2 ON cs2.concept_code = hc.descendant_concept_code
		AND cs2.vocabulary_id = 'SNOMED'
		AND cs2.concept_class_id = cs1.concept_class_id
	GROUP BY hc.root_ancestor_concept_code,
		hc.descendant_concept_code;

ANALYZE snomed_ancestor;

--12.1. For invalid concepts without valid hierarchy, take the latest 116680003 'Is a' relationship to active concept
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
			) AS destinationid, --pick one parent at random
		r.effectivetime,
		MAX(r.effectivetime) OVER (PARTITION BY r.sourceid) AS maxeffectivetime
	FROM sources.sct2_rela_full_merged r
	JOIN concept_stage x ON x.concept_code = r.destinationid
		AND x.invalid_reason IS NULL
	WHERE r.typeid = '116680003' -- Is a
		AND r.moduleid NOT IN (
			'999000021000001108', --SNOMED CT United Kingdom drug extension reference set module
			'999000011000001104' --SNOMED CT United Kingdom drug extension module
			)
	) m ON m.sourceid = s1.concept_code
	AND m.effectivetime = m.maxeffectivetime
JOIN snomed_ancestor a ON m.destinationid = a.descendant_concept_code
WHERE s1.invalid_reason IS NOT NULL
	AND NOT EXISTS (
		SELECT
		FROM snomed_ancestor x
		WHERE x.descendant_concept_code = m.sourceid
		);

ALTER TABLE snomed_ancestor ADD CONSTRAINT xpksnomed_ancestor PRIMARY KEY (ancestor_concept_code,descendant_concept_code);

--13. Create domain_id
--13.1. Create and populate table with "Peaks" = ancestors of records that are all of the same domain
DO $_$
BEGIN
	PERFORM dev_snomed.AddPeaks();
END $_$;

--13.2. Ancestors inherit the domain_id and standard_concept of their Peaks. However, the ancestors of Peaks are overlapping.
--Therefore, the order by which the inheritance is passed depends on the "height" in the hierarchy: The lower the peak, the later it should be run
--The following creates the right order by counting the number of ancestors: The more ancestors the lower in the hierarchy.
--This could cause trouble if a parallel fork happens at the same height, but it is resolved by domain precedence.

UPDATE peak p
SET ranked = r.rnk
FROM (
	SELECT pd.peak_code,
		COUNT(*) + 1 AS rnk -- +1 so the top most who have an ancestor are ranked 2, and the ancestor can be ranked 1 (see below)
	FROM peak pa
	JOIN snomed_ancestor ca ON ca.ancestor_concept_code = pa.peak_code
	JOIN peak pd ON pd.peak_code = ca.descendant_concept_code
		AND pd.valid_end_date = TO_DATE('20991231', 'YYYYMMDD') --consider only active peaks
	WHERE pa.levels_down IS NULL
		AND pa.valid_end_date = TO_DATE('20991231', 'YYYYMMDD') --consider only active peaks
	GROUP BY pd.peak_code
	) r
WHERE p.peak_code = r.peak_code
	AND p.valid_end_date = TO_DATE('20991231', 'YYYYMMDD'); --rank only active peaks

--For those that have no ancestors, the rank is 1
UPDATE peak
SET ranked = 1
WHERE ranked IS NULL
	AND valid_end_date = TO_DATE('20991231', 'YYYYMMDD');--rank only active peaks

--13.3. Pass out domain_ids
--Assign domains to children of peak concepts in the order rank, and within rank by order of precedence
--Do that for all peaks by order of ranks. The highest first, the lower ones second, etc.
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
		p.ranked DESC,
		sa.min_levels_of_separation,
		-- if there are two conflicting domains in the rank (both equally distant from the ancestor) then use precedence
		CASE peak_domain_id WHEN 'Condition'
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
		ELSE
			10
		END, -- everything else is Observation
		p.peak_domain_id
	) i
WHERE d.concept_code = i.descendant_concept_code;

--Assign domains of peaks themselves (snomed_ancestor doesn't include self-descendants)
UPDATE domain_snomed d
SET domain_id = i.peak_domain_id
FROM (
	SELECT DISTINCT ON (peak_code) peak_code,
		peak_domain_id
	FROM peak
	WHERE ranked IS NOT NULL --consider active peaks only
	ORDER BY peak_code,
		levels_down -- if there are several records for 1 peak, use the following ORDER: levels_down = 0 > 1 ... x > NULL
	) i
WHERE d.concept_code = i.peak_code;

--Update top guy
UPDATE domain_snomed SET domain_id = 'Metadata' WHERE concept_code = '138875005';

--13.4. Update concept_stage from newly created domains.
UPDATE concept_stage c
SET domain_id = i.domain_id
FROM domain_snomed i
WHERE c.vocabulary_id = 'SNOMED'
	AND i.concept_code = c.concept_code;

--14. For deprecated concepts without hierarchy assign domains from base table.
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
UPDATE concept_stage cs
SET domain_id = 'Drug'
FROM concept_relationship_stage crs
JOIN concept_stage ccs ON ccs.concept_code = crs.concept_code_2
	AND ccs.vocabulary_id = crs.vocabulary_id_2
	AND ccs.domain_id = 'Drug'
WHERE cs.concept_code = crs.concept_code_1
	AND cs.vocabulary_id = crs.vocabulary_id_1
	AND crs.relationship_id = 'Active ing of'
	AND crs.invalid_reason IS NULL
	AND cs.domain_id <> 'Drug';

--16. Make manual changes according to rules
--Manual correction
---Assign Measurement domain to all scores:
UPDATE concept_stage
SET domain_id = 'Measurement'
WHERE concept_name ILIKE '%score%'
	AND concept_class_id = 'Observable Entity'
	AND vocabulary_id = 'SNOMED';

--Trim word 'route' from the concepts in 'Route' domain [AVOC-4087]
UPDATE concept_stage
SET concept_name = regexp_replace(concept_name, '\sroute$', '')
WHERE concept_name LIKE '% route'
	AND domain_id = 'Route';

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
WHERE sa.ancestor_concept_code = '363743006' -- Navigational Concept, contains all sorts of orphan codes
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
		END;

-- 17.1. Make invalid concepts non-standard:
UPDATE concept_stage cs
SET standard_concept = NULL
WHERE invalid_reason IS NOT NULL;

--17.2. De-standardize navigational concepts
UPDATE concept_stage cs
SET standard_concept = NULL
FROM snomed_ancestor sa
WHERE sa.ancestor_concept_code = '363743006' -- Navigational Concept
	AND cs.concept_code = sa.descendant_concept_code;

--17.3. Make those Obsolete routes non-standard
UPDATE concept_stage
SET standard_concept = NULL
WHERE concept_name LIKE 'Obsolete%'
	AND domain_id = 'Route';

--17.4 Make domain 'Geography' non-standard, except countries:
UPDATE concept_stage
SET standard_concept = NULL
WHERE concept_class_id = 'Location'
AND concept_code NOT IN (
		SELECT descendant_concept_code
		FROM snomed_ancestor
		WHERE ancestor_concept_code = '223369002' -- Country
		);

--17.5 Make procedures with the context = 'Done' non-standard:
UPDATE concept_stage cs
SET standard_concept = NULL
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = cs.concept_code
			AND crs.relationship_id = 'Has proc context'
			AND crs.concept_code_2 = '385658003'
			AND crs.vocabulary_id_2 = 'SNOMED'
			AND crs.invalid_reason IS NULL
		);

--17.6 Make certain hierarchical branches non-standard:
UPDATE concept_stage cs
SET standard_concept = NULL
FROM snomed_ancestor sa
WHERE sa.ancestor_concept_code IN (
		'373060007', -- Device status
		'417662000', -- History of clinical finding in subject
		'312871001', --Administration of bacterial vaccine
		'1156257007', -- Administration of SARS-CoV-2 vaccine
		'49083007', --Administration of viral vaccine
		'283511000000105' --Administration of vaccine
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
	AND cs.concept_code = sa.descendant_concept_code;

--17.7 Make certain concept classes non-standard:
UPDATE concept_stage
SET standard_concept = NULL
WHERE concept_class_id IN (
		'Attribute',
		'Physical Force',
		'Physical Object'
		)
	AND domain_id <> 'Device';

UPDATE concept_stage cs
SET standard_concept = NULL
WHERE concept_class_id = 'Social Context'
	AND NOT EXISTS (
		SELECT 1
		FROM snomed_ancestor sa
		WHERE sa.descendant_concept_code = cs.concept_code
			AND sa.ancestor_concept_code IN (
				'14679004', -- Occupation
				'125677006', -- Relative
				'410597007', -- Person categorized by religious affiliation
				'108334009' -- Religion AND/OR philosophy
				)
		);

--18. Add 'Maps to' relations to concepts that are duplicating between different SNOMED editions
--https://github.com/OHDSI/Vocabulary-v5.0/issues/431
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
		FROM sources.sct2_concept_full_merged c
		WHERE c.moduleid NOT IN (
				'999000021000001108', --SNOMED CT United Kingdom drug extension reference set module
				'999000011000001104' --SNOMED CT United Kingdom drug extension module
				)
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
		FROM sources.sct2_desc_full_merged d
		JOIN concept_status a ON a.conceptid = d.conceptid
			AND a.active = 1
		WHERE d.active = 1
			AND d.typeid = '900000000000003001' -- FSN
			AND d.moduleid NOT IN (
				'999000021000001108', --SNOMED CT United Kingdom drug extension reference set module
				'999000011000001104' --SNOMED CT United Kingdom drug extension module
				)
		ORDER BY d.conceptid,
			d.effectivetime DESC
		),
	preferred_code AS (
		--1. International concept over local
		--2. Defined concept over primitive
		--3. Newest concept
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
				ELSE 2
				END,
			CASE c2.statusid
				WHEN '900000000000073002' --fully defined
					THEN 1
				ELSE 2
				END,
			c2.effectivetime DESC
		)
SELECT p.conceptid AS concept_code_1,
	p.replacementid AS concept_code_2,
	'SNOMED' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	'Maps to' AS  relationship_id,
	(
		SELECT v.latest_update
		FROM vocabulary v
		WHERE v.vocabulary_id = 'SNOMED'
		) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date
FROM preferred_code p
WHERE EXISTS (
		SELECT 1
		FROM concept_stage c
		WHERE c.concept_code = p.replacementid
			AND c.standard_concept IS NOT NULL
		)
AND NOT EXISTS(
       SELECT 1
       FROM concept_relationship_stage crs
       WHERE crs.concept_code_1 = p.conceptid
       AND crs.concept_code_2 = p.replacementid
       AND crs.vocabulary_id_1 = 'SNOMED'
       AND crs.vocabulary_id_2 = 'SNOMED'
       AND crs.relationship_id = 'Maps to'
       AND crs.invalid_reason IS NULL
);

--19. Append manual concepts again for final assignment of concept characteristics
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--20. Working with relationships

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

--21. Clean up
DROP TABLE peak;
DROP TABLE domain_snomed;
DROP TABLE snomed_ancestor;
DROP VIEW module_date;

--22. Need to check domains before running the generic_update
/*temporary disabled for later use
DO $_$
DO $_$
DECLARE
	z INT;
BEGIN
    SELECT COUNT (*)
      INTO z
      FROM concept_stage cs JOIN concept c USING (concept_code)
     WHERE c.vocabulary_id = 'SNOMED' AND cs.domain_id <> c.domain_id;

    IF z <> 0
    THEN
        RAISE EXCEPTION 'Please check domain_ids for SNOMED';
    END IF;
END $_$;*/

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
