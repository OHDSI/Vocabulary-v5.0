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
* Authors: Eduard Korchmar, Alexander Davydov, Timur Vakhitov, Christian Reich
* Date: 2021
**************************************************************************/

--1. Extract each component (International, UK & US) versions to properly date the combined source in next step
DROP VIEW IF EXISTS module_date;
CREATE VIEW module_date
AS
WITH maxdate
AS
	--Module content is at most as old as latest available module version
	(
	SELECT id,
		MAX(effectivetime) AS effectivetime
	FROM sources.der2_ssrefset_moduledependency_merged
	GROUP BY id
	)
SELECT DISTINCT m1.moduleid,
	TO_CHAR(m1.sourceeffectivetime, 'yyyy-mm-dd') AS version
FROM sources.der2_ssrefset_moduledependency_merged m1
JOIN maxdate m2 USING (id,effectivetime)
WHERE m1.active = 1
	AND m1.referencedcomponentid = 900000000000012004
	AND --Model component module; Synthetic target, contains source version in each row
	m1.moduleid IN (
		900000000000207008, --Core (international) module
		999000011000000103, --UK edition
		731000124108 --US edition
		);

--2. Update latest_update field to new date
--Use the latest of the release dates of all source versions. Usually, the UK is the latest.
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'SNOMED',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.sct2_concept_full_merged LIMIT 1),
	pVocabularyVersion		=>
		(SELECT version FROM module_date where moduleid = 900000000000207008) || ' SNOMED CT International Edition; ' ||
		(SELECT version FROM module_date where moduleid = 731000124108) || ' SNOMED CT US Edition; ' ||
		(SELECT version FROM module_date where moduleid = 999000011000000103) || ' SNOMED CT UK Edition',
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
	TO_DATE(effectivestart, 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT vocabulary_pack.CutConceptName(d.term) AS concept_name,
		d.conceptid::TEXT AS concept_code,
		c.active,
		MIN(c.effectivetime) OVER (
			PARTITION BY c.id ORDER BY c.active DESC --if there ever were active versions of the concept, take the earliest one
			) AS effectivestart,
		ROW_NUMBER() OVER (
			PARTITION BY d.conceptid
			-- Order of preference:
			-- Active descriptions first, characterised as Preferred Synonym, prefer SNOMED Int, then US, then UK, then take the latest term
			ORDER BY c.active DESC,
				d.active DESC,
				l.active DESC,
				CASE l.acceptabilityid
					WHEN 900000000000548007
						THEN 1 --Preferred
					WHEN 900000000000549004
						THEN 2 --Acceptable
					ELSE 99
					END ASC,
				CASE d.typeid
					WHEN 900000000000013009
						THEN 1 --Synonym (PT)
					WHEN 900000000000003001
						THEN 2 --Fully specified name
					ELSE 99
					END ASC,
				CASE l.refsetid
					WHEN 900000000000509007
						THEN 1 --US English language reference set
					WHEN 900000000000508004
						THEN 2 --UK English language reference set
					ELSE 99 -- Various UK specific refsets
					END,
				CASE l.source_file_id
					WHEN 'INT'
						THEN 1 -- International release
					WHEN 'US'
						THEN 2 -- SNOMED US
					WHEN 'GB_DE'
						THEN 3 -- SNOMED UK Drug extension, updated more often
					WHEN 'UK'
						THEN 4 -- SNOMED UK
					ELSE 99
					END ASC,
				l.effectivetime DESC
			) AS rn
	FROM sources.sct2_concept_full_merged c
	JOIN sources.sct2_desc_full_merged d ON d.conceptid = c.id
	JOIN sources.der2_crefset_language_merged l ON l.referencedcomponentid = d.id
	) sct2
WHERE sct2.rn = 1;

--4.1 For concepts with latest entry in sct2_concept having active = 0, preserve invalid_reason and valid_end date
WITH inactive
AS (
	SELECT c.id,
		MAX(c.effectivetime) AS effectiveend
	FROM sources.sct2_concept_full_merged c
	LEFT JOIN sources.sct2_concept_full_merged c2 ON --ignore all entries before latest one with active = 1
		c2.active = 1
		AND c.id = c2.id
		AND c.effectivetime < c2.effectivetime
	WHERE c2.id IS NULL
		AND c.active = 0
	GROUP BY c.id
	)
UPDATE concept_stage cs
SET invalid_reason = 'D',
	valid_end_date = TO_DATE(i.effectiveend, 'yyyymmdd')
FROM inactive i
WHERE i.id::TEXT = cs.concept_code;

--4.2 Some concepts were never alive; we don't know what their valid_start_date would be, so we set it to default minimum
UPDATE concept_stage
SET valid_start_date = TO_DATE('19700101', 'yyyymmdd')
WHERE valid_start_date = valid_end_date;

--4.3 Fix concept names: change vitamin B>12< deficiency to vitamin B-12 deficiency; NAD(P)^+^ to NAD(P)+
UPDATE concept_stage
SET concept_name = vocabulary_pack.CutConceptName(translate(concept_name, '>,<,^', '-'))
WHERE (concept_name LIKE '%>%' AND concept_name LIKE '%<%')
OR (concept_name LIKE '%^%^%')
;

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
						-- Might be redundant, as normally concepts will never have more than 1 hierarchy tag, but we have concurrent sources, so this may prevent problems and breaks nothing
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
						JOIN sources.sct2_desc_full_merged d ON d.conceptid::TEXT = c.concept_code
						WHERE
							c.vocabulary_id = 'SNOMED' AND
							d.typeid = 900000000000003001 -- only Fully Specified Names
						) AS s0
					) AS s1
				) AS s2
			WHERE rnc = 1
			)
	SELECT concept_code,
		CASE
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
WHERE i.concept_code = cs.concept_code;

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

--6. --Some old deprecated concepts from UK drug extension module never have had correct FSN, so we can't get explicit hierarchy tag and keep them as Context-dependent class
UPDATE concept_stage c
SET concept_class_id = 'Context-dependent'
WHERE c.concept_class_id = 'Undefined'
	AND c.invalid_reason IS NOT NULL
	AND --Make sure we only affect old concepts and not mask new classes additions
	EXISTS (
		SELECT 1
		FROM sources.sct2_concept_full_merged m
		WHERE m.id::TEXT = c.concept_code
			AND m.moduleid = 999000011000001104 --SNOMED CT United Kingdom drug extension module
		);

--7. Get all the synonyms from UMLS ('PT', 'PTGB', 'SY', 'SYGB', 'MTH_PT', 'FN', 'MTH_SY', 'SB') into concept_synonym_stage
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

--8. Add active synonyms from merged descriptions list
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
	SELECT m.id,
		m.conceptid::TEXT,
		m.term,
		FIRST_VALUE(active) OVER (
			PARTITION BY id ORDER BY effectivetime DESC
			) AS active_status
	FROM sources.sct2_desc_full_merged m
	) d
JOIN concept_stage s ON s.concept_code = d.conceptid
WHERE d.active_status = 1
	AND NOT EXISTS (
		SELECT 1
		FROM concept_synonym_stage css_int
		WHERE css_int.synonym_concept_code = d.conceptid
			AND css_int.synonym_name = vocabulary_pack.CutConceptSynonymName(d.term)
		);

--9. Fill concept_relationship_stage from merged SNOMED source
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
WITH tmp_rel AS (
		-- get relationships from latest records that are active
		SELECT sourceid::TEXT,
			destinationid::TEXT,
			REPLACE(term, ' (attribute)', '') term
		FROM (
			SELECT r.sourceid,
				r.destinationid,
				d.term,
				ROW_NUMBER() OVER (
					PARTITION BY r.id ORDER BY r.effectivetime DESC,
						d.id DESC -- fix for AVOF-650
					) AS rn, -- get the latest in a sequence of relationships, to decide whether it is still active
				r.active
			FROM sources.sct2_rela_full_merged r
			JOIN sources.sct2_desc_full_merged d ON d.conceptid = r.typeid
			) AS s0
		WHERE rn = 1
			AND active = 1
			AND sourceid IS NOT NULL
			AND destinationid IS NOT NULL
			AND term <> 'PBCL flag true'

    UNION
--add relationships from concept to module
		SELECT cs.concept_code::TEXT,
		       moduleid::TEXT,
		       'Has Module' AS term
		FROM sources.sct2_concept_full_merged c
		JOIN concept_stage cs ON c.id::TEXT = cs.concept_code
		    AND cs.vocabulary_id = 'SNOMED'
		WHERE moduleid IN (
		900000000000207008, --Core (international) module
		999000011000000103, --UK edition
		731000124108, --US edition
        999000011000001104, --SNOMED CT United Kingdom drug extension module
		900000000000012004, --SNOMED CT model component
        999000021000001108  --SNOMED CT United Kingdom drug extension reference set module
		)

    UNION
--add relationship from concept to status
		SELECT st.concept_code::TEXT,
		       st.statusid::TEXT,
		       'Has status'
		FROM
        (SELECT cs.concept_code,
               statusid::TEXT,
       		ROW_NUMBER() OVER (
			PARTITION BY id ORDER BY TO_DATE(effectivetime, 'YYYYMMDD') DESC
			) rn
        FROM SOURCES.SCT2_CONCEPT_FULL_MERGED c
        JOIN concept_stage cs ON c.id::TEXT = cs.concept_code
            AND cs.vocabulary_id = 'SNOMED'
        WHERE statusid IN (
		900000000000073002, --Defined
		900000000000074008  --Primitive
		)) st
    WHERE st.rn = 1

		)
SELECT concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM (
	--convert SNOMED to OMOP-type relationship_id
	--TODO: this deserves a massive overhaul using raw typeid instead of extracted terms; however, it works in current state with no reported issues
	SELECT DISTINCT sourceid AS concept_code_1,
		destinationid AS concept_code_2,
		'SNOMED' AS vocabulary_id_1,
		'SNOMED' AS vocabulary_id_2,
		CASE
			WHEN term = 'Access'
				THEN 'Has access'
			WHEN term = 'Associated aetiologic finding'
				THEN 'Has etiology'
			WHEN term = 'After'
				THEN 'Followed by'
			WHEN term = 'Approach'
				THEN 'Has surgical appr' -- looks like old version
			WHEN term = 'Associated finding'
				THEN 'Has asso finding'
			WHEN term = 'Associated morphology'
				THEN 'Has asso morph'
			WHEN term = 'Associated procedure'
				THEN 'Has asso proc'
			WHEN term = 'Associated with'
				THEN 'Finding asso with'
			WHEN term = 'AW'
				THEN 'Finding asso with'
			WHEN term = 'Causative agent'
				THEN 'Has causative agent'
			WHEN term = 'Clinical course'
				THEN 'Has clinical course'
			WHEN term = 'Component'
				THEN 'Has component'
			WHEN term = 'Direct device'
				THEN 'Has dir device'
			WHEN term = 'Direct morphology'
				THEN 'Has dir morph'
			WHEN term = 'Direct substance'
				THEN 'Has dir subst'
			WHEN term = 'Due to'
				THEN 'Has due to'
			WHEN term = 'Episodicity'
				THEN 'Has episodicity'
			WHEN term = 'Extent'
				THEN 'Has extent'
			WHEN term = 'Finding context'
				THEN 'Has finding context'
			WHEN term = 'Finding informer'
				THEN 'Using finding inform'
			WHEN term = 'Finding method'
				THEN 'Using finding method'
			WHEN term = 'Finding site'
				THEN 'Has finding site'
			WHEN term = 'Has active ingredient'
				THEN 'Has active ing'
			WHEN term = 'Has definitional manifestation'
				THEN 'Has manifestation'
			WHEN term = 'Has dose form'
				THEN 'Has dose form'
			WHEN term = 'Has focus'
				THEN 'Has focus'
			WHEN term = 'Has interpretation'
				THEN 'Has interpretation'
			WHEN term = 'Has measured component'
				THEN 'Has meas component'
			WHEN term = 'Has specimen'
				THEN 'Has specimen'
			WHEN term = 'Stage'
				THEN 'Has stage'
			WHEN term = 'Indirect device'
				THEN 'Has indir device'
			WHEN term = 'Indirect morphology'
				THEN 'Has indir morph'
			WHEN term = 'Instrumentation'
				THEN 'Using device' -- looks like an old version
			WHEN term IN (
					'Intent',
					'Has intent'
					)
				THEN 'Has intent'
			WHEN term = 'Interprets'
				THEN 'Has interprets'
			WHEN term = 'Is a'
				THEN 'Is a'
			WHEN term = 'Laterality'
				THEN 'Has laterality'
			WHEN term = 'Measurement method'
				THEN 'Has measurement'
			WHEN term = 'Measurement Method'
				THEN 'Has measurement' -- looks like misspelling
			WHEN term = 'Method'
				THEN 'Has method'
			WHEN term = 'Morphology'
				THEN 'Has asso morph' -- changed to the same thing as 'Has Morphology'
			WHEN term = 'Occurrence'
				THEN 'Has occurrence'
			WHEN term = 'Onset'
				THEN 'Has clinical course' -- looks like old version
			WHEN term = 'Part of'
				THEN 'Part of'
			WHEN term = 'Pathological process'
				THEN 'Has pathology'
			WHEN term = 'Pathological process (qualifier value)'
				THEN 'Has pathology'
			WHEN term = 'Priority'
				THEN 'Has priority'
			WHEN term = 'Procedure context'
				THEN 'Has proc context'
			WHEN term = 'Procedure device'
				THEN 'Has proc device'
			WHEN term = 'Procedure morphology'
				THEN 'Has proc morph'
			WHEN term = 'Procedure site - Direct'
				THEN 'Has dir proc site'
			WHEN term = 'Procedure site - Indirect'
				THEN 'Has indir proc site'
			WHEN term = 'Procedure site'
				THEN 'Has proc site'
			WHEN term = 'Property'
				THEN 'Has property'
			WHEN term = 'Recipient category'
				THEN 'Has recipient cat'
			WHEN term = 'Revision status'
				THEN 'Has revision status'
			WHEN term = 'Route of administration'
				THEN 'Has route of admin'
			WHEN term = 'Route of administration - attribute'
				THEN 'Has route of admin'
			WHEN term = 'Scale type'
				THEN 'Has scale type'
			WHEN term = 'Severity'
				THEN 'Has severity'
			WHEN term = 'Specimen procedure'
				THEN 'Has specimen proc'
			WHEN term = 'Specimen source identity'
				THEN 'Has specimen source'
			WHEN term = 'Specimen source morphology'
				THEN 'Has specimen morph'
			WHEN term = 'Specimen source topography'
				THEN 'Has specimen topo'
			WHEN term = 'Specimen substance'
				THEN 'Has specimen subst'
			WHEN term = 'Subject relationship context'
				THEN 'Has relat context'
			WHEN term = 'Surgical approach'
				THEN 'Has surgical appr'
			WHEN term = 'Temporal context'
				THEN 'Has temporal context'
			WHEN term = 'Temporally follows'
				THEN 'Occurs after' -- looks like an old version
			WHEN term = 'Time aspect'
				THEN 'Has time aspect'
			WHEN term = 'Using access device'
				THEN 'Using acc device'
			WHEN term = 'Using device'
				THEN 'Using device'
			WHEN term = 'Using energy'
				THEN 'Using energy'
			WHEN term = 'Using substance'
				THEN 'Using subst'
			WHEN term = 'Following'
				THEN 'Followed by'
			WHEN term = 'VMP non-availability indicator'
				THEN 'Has non-avail ind'
			WHEN term = 'Has ARP'
				THEN 'Has ARP'
			WHEN term = 'Has VRP'
				THEN 'Has VRP'
			WHEN term = 'Has trade family group'
				THEN 'Has trade family grp'
			WHEN term = 'Flavour'
				THEN 'Has flavor'
			WHEN term = 'Discontinued indicator'
				THEN 'Has disc indicator'
			WHEN term = 'VRP prescribing status'
				THEN 'VRP has prescr stat'
			WHEN term = 'Has specific active ingredient'
				THEN 'Has spec active ing'
			WHEN term = 'Has excipient'
				THEN 'Has excipient'
			WHEN term = 'Has basis of strength substance'
				THEN 'Has basis str subst'
			WHEN term = 'Has VMP'
				THEN 'Has VMP'
			WHEN term = 'Has AMP'
				THEN 'Has AMP'
			WHEN term = 'Has dispensed dose form'
				THEN 'Has disp dose form'
			WHEN term = 'VMP prescribing status'
				THEN 'VMP has prescr stat'
			WHEN term = 'Legal category'
				THEN 'Has legal category'
			WHEN term = 'Caused by'
				THEN 'Caused by'
			WHEN term = 'Precondition'
				THEN 'Has precondition'
			WHEN term = 'Inherent location'
				THEN 'Has inherent loc'
			WHEN term = 'Technique'
				THEN 'Has technique'
			WHEN term = 'Relative to part of'
				THEN 'Has relative part'
			WHEN term = 'Process output'
				THEN 'Has process output'
			WHEN term = 'Property type'
				THEN 'Has property type'
			WHEN term = 'Inheres in'
				THEN 'Inheres in'
			WHEN term = 'Direct site'
				THEN 'Has direct site'
			WHEN term = 'Characterizes'
				THEN 'Characterizes'
					--added 20171116
			WHEN term = 'During'
				THEN 'During'
			WHEN term = 'Has BoSS'
				THEN 'Has basis str subst' -- use existing relationship
			WHEN term = 'Has manufactured dose form'
				THEN 'Has dose form' -- use existing relationship
			WHEN term = 'Has presentation strength denominator unit'
				THEN 'Has denominator unit'
			WHEN term = 'Has presentation strength denominator value'
				THEN 'Has denomin value'
			WHEN term = 'Has presentation strength numerator unit'
				THEN 'Has numerator unit'
			WHEN term = 'Has presentation strength numerator value'
				THEN 'Has numerator value'
					--added 20180205
			WHEN term = 'Has basic dose form'
				THEN 'Has basic dose form'
			WHEN term = 'Has disposition'
				THEN 'Has disposition'
			WHEN term = 'Has dose form administration method'
				THEN 'Has admin method'
			WHEN term = 'Has dose form intended site'
				THEN 'Has intended site'
			WHEN term = 'Has dose form release characteristic'
				THEN 'Has release charact'
			WHEN term = 'Has dose form transformation'
				THEN 'Has transformation'
			WHEN term = 'Has state of matter'
				THEN 'Has state of matter'
			WHEN term = 'Temporally related to'
				THEN 'Temp related to'
					--added 20180622
			WHEN term = 'Has NHS dm+d basis of strength substance'
				THEN 'Has basis str subst'
			WHEN term = 'Has unit of administration'
				THEN 'Has unit of admin'
			WHEN term = 'Has precise active ingredient'
				THEN 'Has prec ingredient'
			WHEN term = 'Has unit of presentation'
				THEN 'Has unit of presen'
			WHEN term = 'Has concentration strength numerator value'
				THEN 'Has conc num val'
			WHEN term = 'Has concentration strength denominator value'
				THEN 'Has conc denom val'
			WHEN term = 'Has concentration strength denominator unit'
				THEN 'Has conc denom unit'
			WHEN term = 'Has concentration strength numerator unit'
				THEN 'Has conc num unit'
			WHEN term = 'Is modification of'
				THEN 'Modification of'
			WHEN term = 'Count of base of active ingredient'
				THEN 'Has count of ing'
					--20190204
			WHEN term = 'Has realization'
				THEN 'Has pathology'
			WHEN term = 'Plays role'
				THEN 'Plays role'
					--20190823
			WHEN term = 'Has NHS dm+d (dictionary of medicines and devices) VMP (Virtual Medicinal Product) route of administration'
				THEN 'Has route'
			WHEN term = 'Has NHS dm+d (dictionary of medicines and devices) controlled drug category'
				THEN 'Has CD category'
			WHEN term = 'Has NHS dm+d (dictionary of medicines and devices) VMP (Virtual Medicinal Product) ontology form and route'
				THEN 'Has ontological form'
			WHEN term = 'VMP combination product indicator'
				THEN 'Has combi prod ind'
			WHEN term = 'Has NHS dm+d (dictionary of medicines and devices) dose form indicator'
				THEN 'Has form continuity'
					--20200312
			WHEN term = 'Has NHS dm+d (dictionary of medicines and devices) additional monitoring indicator'
				THEN 'Has add monitor ind'
			WHEN term = 'Has NHS dm+d (dictionary of medicines and devices) AMP (actual medicinal product) availability restriction indicator'
				THEN 'Has AMP restr ind'
			WHEN term = 'Has NHS dm+d parallel import indicator'
				THEN 'Paral imprt ind'
			WHEN term = 'Has NHS dm+d freeness indicator'
				THEN 'Has free indicator'
			WHEN term = 'Units'
				THEN 'Has unit'
			WHEN term = 'Process duration'
				THEN 'Has proc duration'
					--20201023
			WHEN term = 'Relative to'
				THEN 'Relative to'
			WHEN term = 'Count of active ingredient'
				THEN 'Has count of act ing'
			WHEN term = 'Has product characteristic'
				THEN 'Has prod character'
			WHEN term = 'Has ingredient characteristic'
				THEN 'Has prod character'
			WHEN term = 'Has surface characteristic'
				THEN 'Surf character of'
			WHEN term = 'Has device intended site'
				THEN 'Has dev intend site'
			WHEN term = 'Has device characteristic'
				THEN 'Has prod character'
			WHEN term = 'Has compositional material'
				THEN 'Has comp material'
			WHEN term = 'Has filling'
				THEN 'Has filling'
		    --January 2022
		    WHEN term = 'Has coating material'
		        THEN 'Has coating material'
		    WHEN term = 'Has absorbability'
		        THEN 'Has absorbability'
		    WHEN term = 'Process extends to'
		        THEN 'Process extends to'
		    WHEN term = 'Has ingredient qualitative strength'
		        THEN 'Has strength'
		    WHEN term = 'Has surface texture'
		        THEN 'Has surface texture'
		    WHEN term = 'Is sterile'
		        THEN 'Is sterile'
		    WHEN term = 'Has target population'
		        THEN 'Has targ population'
		    WHEN term = 'Has Module'
		        THEN 'Has Module'
		    WHEN term = 'Has status'
		        THEN 'Has status'
			ELSE term --'non-existing'
			END AS relationship_id,
		(
			SELECT latest_update
			FROM vocabulary
			WHERE vocabulary_id = 'SNOMED'
			) AS valid_start_date,
		TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
		NULL AS invalid_reason
	FROM tmp_rel
	) sn
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = sn.concept_code_1
			AND crs.concept_code_2 = sn.concept_code_2
			AND crs.relationship_id = sn.relationship_id
		);

--check for non-existing relationships
ALTER TABLE concept_relationship_stage ADD CONSTRAINT tmp_constraint_relid FOREIGN KEY (relationship_id) REFERENCES relationship (relationship_id);
ALTER TABLE concept_relationship_stage DROP CONSTRAINT tmp_constraint_relid;
--SELECT relationship_id FROM concept_relationship_stage EXCEPT SELECT relationship_id FROM relationship;

--10. Add replacement relationships. They are handled in a different SNOMED table
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
	COALESCE(cs.valid_end_date, (
			SELECT latest_update
			FROM vocabulary
			WHERE vocabulary_id = 'SNOMED'
			)),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM (
	SELECT sc.referencedcomponentid::TEXT AS concept_code_1,
		sc.targetcomponent::TEXT AS concept_code_2,
		CASE refsetid
			WHEN 900000000000526001
				THEN 'Concept replaced by'
			WHEN 900000000000523009
				THEN 'Concept poss_eq to'
			WHEN 900000000000528000
				THEN 'Concept was_a to'
			WHEN 900000000000527005
				THEN 'Concept same_as to'
			WHEN 900000000000530003
				THEN 'Concept alt_to to'
			END AS relationship_id,
	       refsetid,
		ROW_NUMBER() OVER (
			PARTITION BY sc.referencedcomponentid ORDER BY TO_DATE(sc.effectivetime, 'YYYYMMDD') DESC,
				sc.id DESC --same as of AVOF-650
			) rn,
	       	    ROW_NUMBER() OVER (
	        PARTITION BY sc.referencedcomponentid, sc.targetcomponent, sc.moduleid ORDER BY TO_DATE(sc.effectivetime, 'YYYYMMDD') DESC) AS recent_status,   --recent status of the relationship. To be used with 'active' field
		active
	FROM sources.der2_crefset_assreffull_merged sc
	WHERE sc.refsetid IN (
			900000000000526001,
			900000000000523009,
			900000000000528000,
			900000000000527005,
			900000000000530003
			)
	) sn
LEFT JOIN concept_stage cs ON -- for valid_end_date
	cs.concept_code = sn.concept_code_1
	AND cs.invalid_reason IS NOT NULL
WHERE CASE WHEN sn.refsetid = '900000000000523009' THEN sn.rn >= 1     --Bring all Concept poss_eq to concept_relationship table and do not build new Maps to based on them
            ELSE sn.rn = 1 END
	AND sn.active = 1
    AND sn.recent_status = 1    --no row with the same target concept, but more recent relationship with active = 0
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = sn.concept_code_1
			AND crs.concept_code_2 = sn.concept_code_2
			AND crs.relationship_id = sn.relationship_id
		);

--10.1 Sometimes concept are back from U to fresh, we need to deprecate our replacement mappings
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
	AND c1.invalid_reason = 'U'
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

ANALYZE concept_stage;
ANALYZE concept_relationship_stage;

--10.2. Update invalid reason for concepts with replacements to 'U', to ensure we keep correct date
UPDATE concept_stage cs
SET invalid_reason = 'U'
FROM concept_relationship_stage crs
WHERE crs.concept_code_1 = cs.concept_code
	AND crs.relationship_id IN (
		'Concept replaced by',
		'Concept same_as to',
		'Concept alt_to to',
		'Concept was_a to'
		)
	AND crs.invalid_reason IS NULL;

--10.3. Update invalid reason for concepts with 'Concept poss_eq to' relationships. They are no longer considered replacement relationships.
UPDATE concept_stage cs
SET invalid_reason = 'D'
FROM concept_relationship_stage crs
WHERE crs.concept_code_1 = cs.concept_code
	AND crs.relationship_id IN (
		'Concept poss_eq to'
		)
	AND crs.invalid_reason IS NULL
    AND cs.invalid_reason != 'U'
;

--10.4. Update valid_end_date to latest_update if there is a discrepancy after last point
UPDATE concept_stage cs
SET valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED'
		)
WHERE invalid_reason = 'U'
	AND valid_end_date = TO_DATE('20991231', 'yyyymmdd');

--11. Append manual concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--12. Append manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--13. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--14. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--15. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--16. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--17. Inherit concept class for updated concepts from mapping target -- some of them never had hierarchy tags to extract them
UPDATE concept_stage cs
SET concept_class_id = x.concept_class_id
FROM concept_relationship_stage r,
	concept_stage x
WHERE r.concept_code_1 = cs.concept_code
	AND r.relationship_id = 'Maps to'
	AND r.invalid_reason IS NULL
	AND r.concept_code_2 = x.concept_code
	AND cs.concept_class_id = 'Undefined';

--18. Start building the hierarchy for propagating domain_ids from top to bottom
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
			hc.full_path || c.descendant_concept_code::TEXT AS full_path
		FROM concepts c
		JOIN hierarchy_concepts hc ON hc.descendant_concept_code = c.ancestor_concept_code
		WHERE c.descendant_concept_code::TEXT <> ALL (full_path)
		),
	concepts AS (
		SELECT crs.concept_code_2 AS ancestor_concept_code,
			crs.concept_code_1 AS descendant_concept_code,
			1 AS levels_of_separation
		FROM concept_relationship_stage crs
		WHERE crs.invalid_reason IS NULL
			AND crs.relationship_id = 'Is a'
			AND crs.vocabulary_id_1 = 'SNOMED'
		)
	SELECT hc.root_ancestor_concept_code::BIGINT AS ancestor_concept_code,
		hc.descendant_concept_code::BIGINT,
		MIN(hc.levels_of_separation) AS min_levels_of_separation
	FROM hierarchy_concepts hc
	JOIN concept_stage cs1 ON cs1.concept_code = hc.root_ancestor_concept_code
		AND cs1.vocabulary_id = 'SNOMED'
	JOIN concept_stage cs2 ON cs2.concept_code = hc.descendant_concept_code
		AND cs2.vocabulary_id = 'SNOMED'
	GROUP BY hc.root_ancestor_concept_code,
		hc.descendant_concept_code;

ALTER TABLE snomed_ancestor ADD CONSTRAINT xpksnomed_ancestor PRIMARY KEY (ancestor_concept_code,descendant_concept_code);
ANALYZE snomed_ancestor;

--18.1. Append deprecated concepts that have mappings as extensions of their mapping target
INSERT INTO snomed_ancestor (
	ancestor_concept_code,
	descendant_concept_code,
	min_levels_of_separation
	)
SELECT a.ancestor_concept_code,
	s1.concept_code::BIGINT,
	a.min_levels_of_separation
FROM concept_stage s1
JOIN concept_relationship_stage r ON s1.invalid_reason IS NOT NULL
	AND s1.concept_code = r.concept_code_1
	AND r.relationship_id = 'Maps to'
	AND r.invalid_reason IS NULL
JOIN snomed_ancestor a ON r.concept_code_2 = a.descendant_concept_code::TEXT
WHERE NOT EXISTS (
		SELECT
		FROM snomed_ancestor x
		WHERE x.descendant_concept_code::TEXT = s1.concept_code
		);

ANALYZE snomed_ancestor;


--18.2. For deprecated concepts without mappings, take the latest 116680003 'Is a' relationship to active concept
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
		max(r.effectivetime) OVER (PARTITION BY r.sourceid) AS maxeffectivetime
	FROM sources.sct2_rela_full_merged r
	JOIN concept_stage x ON x.concept_code = r.destinationid::TEXT
		AND x.invalid_reason IS NULL
	WHERE r.typeid = 116680003 -- Is a
	) m ON m.sourceid::TEXT = s1.concept_code
	AND m.effectivetime = m.maxeffectivetime
JOIN snomed_ancestor a ON m.destinationid = a.descendant_concept_code
WHERE s1.invalid_reason IS NOT NULL
	AND NOT EXISTS (
		SELECT
		FROM snomed_ancestor x
		WHERE x.descendant_concept_code = m.sourceid
		);

--19. Create domain_id
--19.1. Manually create table with "Peaks" = ancestors of records that are all of the same domain
DROP TABLE IF EXISTS peak;
CREATE UNLOGGED TABLE peak (
	peak_code BIGINT, --the id of the top ancestor
	peak_domain_id VARCHAR(20), -- the domain to assign to all its children
	valid_start_date DATE, --a date when a peak with a mentioned Domain was introduced
	valid_end_date DATE, --a date when a peak with a mentioned Domain was deprecated
	levels_down INT, --a number of levels down in hierarchy the peak has effect. When levels_down IS NOT NULL, this peak record won't affect the priority of another peaks
	ranked INT -- number for the order in which to assign the Domain. The more "ranked" is, the later it updates the Domain in the script.
	);

--19.2 Fill in the various peak concepts
--TODO: For debug purposes all new and changed peaks may be found by searching date: 20220504
INSERT INTO peak
SELECT a.*, NULL FROM ( VALUES
--19.2.1 Outdated

	--2014-Dec-18
	(218496004,         'Condition',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20170810', 'YYYYMMDD')), -- Adverse reaction to primarily systemic agents
	(118245000,         'Measurement',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Finding by measurement
	--history:on
	(65367001,          'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Victim status
	(65367001,          'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20150311', 'YYYYMMDD')), -- Victim status
	(65367001,          'Observation',  TO_DATE('20150311', 'YYYYMMDD'), TO_DATE('20170106', 'YYYYMMDD')), -- Victim status
	--history:off
	(162565002,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Patient aware of diagnosis
	(418138009,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Patient condition finding
	(405503005,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Staff member inattention
	(405536006,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Staff member ill
	(405502000,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Staff member distraction
	(398051009,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Staff member fatigued
	(398087002,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Staff member inadequately assisted
	(397976005,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Staff member inadequately supervised
	(162568000,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Family not aware of diagnosis
	(162567005,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Family aware of diagnosis
	(42045007,          'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Acceptance of illness
	(108329005,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Social context condition
	(48340000,          'Condition',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Incontinence
	(108252007,         'Measurement',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Laboratory procedures
	(118246004,         'Measurement',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Laboratory test finding' - child of excluded Sample observation
	(442564008,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Evaluation of urine specimen
	(64108007,          'Procedure',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Blood unit processing - inside Measurements
	(258666001,         'Unit',         TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20190211', 'YYYYMMDD')), -- Top unit
	--2014-Dec-31
	(369443003,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- bedpan
	(398146001,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- armband
	(272181003,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- clinical equipment and/or device
	(445316008,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- component of optical microscope
	(419818001,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- Contact lens storage case
	(228167008,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- Corset
	(42380001,          'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- Ear plug, device
	(1333003,           'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- Emesis basin, device
	(360306007,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- Environmental control system
	(33894003,          'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- Experimental device
	(116250002,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- filter
	(59432006,          'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- ligature
	(360174002,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- nabeya capsule
	(311767007,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- special bed
	(360173008,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- watson capsule
	(367561004,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- xenon arc photocoagulator
	--2015-Jan-19
	(80631005,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Clinical stage finding
	(281037003,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Child health observations
	(105499002,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Convalescence
	(301886001,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Drawing up knees
	(298304004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Finding of balance
	(298339004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Finding of body control
	(300577008,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Finding of lesion
	(298325004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Finding of movement
	(427955007,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Finding related to status of agreement with prior finding
	(118222006,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- General finding of observation of patient
	(249857004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Loss of midline awareness
	(300232005,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Oral cavity, dental and salivary finding
	(364830008,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Position of body and posture - finding
	(248982007,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Pregnancy, childbirth and puerperium finding
	(128254003,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Respiratory auscultation finding
	(397773008,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Surgical contraindication
	(386053000,         'Measurement',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20150311', 'YYYYMMDD')), -- evaluation procedure
	(127789004,         'Measurement',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20150311', 'YYYYMMDD')), -- laboratory procedure categorized by method
	(395557000,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Tumor finding
	(422989001,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Appendix with tumor involvement, with perforation not at tumor
	(384980008,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Atelectasis AND/OR obstructive pneumonitis of entire lung associated with direct extension of malignant neoplasm
	(396895006,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Endocrine pancreas tumor finding
	(422805009,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Erosion of esophageal tumor into bronchus
	(423018005,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Erosion of esophageal tumor into trachea
	(399527001,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Invasive ovarian tumor omental implants present
	(399600009,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Lymphoma finding
	(405928008,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Renal sinus vessel involved by tumor
	(405966006,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Renal tumor finding
	(385356007,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Tumor stage finding
	(13104003,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Clinical stage I
	(60333009,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Clinical stage II
	(50283003,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Clinical stage III
	(2640006,           'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Clinical stage IV
	(385358008,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Dukes stage finding
	(385362002,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- FIGO stage finding for gynecological malignancy
	(405917009,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Intergroup rhabdomyosarcoma study post-surgical clinical group finding
	(409721000,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- International neuroblastoma staging system stage finding
	(385389007,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Lymphoma stage finding
	(396532004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Stage I: Tumor confined to gland, 5 cm or less
	(396533009,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Stage II: Tumor confined to gland, greater than 5 cm
	(396534003,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Stage III: Extraglandular extension of tumor without other organ involvement
	(396535002,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Stage IV: Distant metastasis or extension into other organs
	(399517007,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Tumor stage cannot be determined
	(67101007,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- TX category
	(385385001,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- pT category finding
	(385382003,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Node category finding
	(385380006,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Metastasis category finding
	(386702006,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Victim of abuse
	(95930005,          'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Victim of neglect
	(248536006,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Finding of functional performance and activity
	(37448008,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Disturbance in intuition
	(12200008,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Impaired insight
	(5988002,           'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Lack of intuition
	(1230003,           'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- No diagnosis on Axis I
	(10125004,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- No diagnosis on Axis II
	(51112002,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- No diagnosis on Axis III
	(54427008,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- No diagnosis on Axis IV
	(37768003,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- No diagnosis on Axis V
	(6811007,           'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Prejudice
	--2015-Aug-17
	(46680005,          'Measurement',  TO_DATE('20150817', 'YYYYMMDD'), TO_DATE('20170810', 'YYYYMMDD')), -- Vital signs
	--2016-Mar-22
	(57797005,          'Procedure',    TO_DATE('20160322', 'YYYYMMDD'), TO_DATE('20171024', 'YYYYMMDD')), -- Termination of pregnancy
	--2017-Aug-10
	--history:on
	(62014003,          'Condition',    TO_DATE('20170810', 'YYYYMMDD'), TO_DATE('20180820', 'YYYYMMDD')), -- Adverse reaction to drug
	(62014003,          'Observation',  TO_DATE('20180820', 'YYYYMMDD'), TO_DATE('20201110', 'YYYYMMDD')), -- Adverse reaction to drug
	--history:off
	--2017-Aug-25
	(7895008,           'Observation',  TO_DATE('20170825', 'YYYYMMDD'), TO_DATE('20171116', 'YYYYMMDD')), -- Poisoning caused by drug AND/OR medicinal substance
	(55680006,          'Observation',  TO_DATE('20170825', 'YYYYMMDD'), TO_DATE('20171116', 'YYYYMMDD')), -- Drug overdose
	(292545003,         'Observation',  TO_DATE('20170825', 'YYYYMMDD'), TO_DATE('20171116', 'YYYYMMDD')), -- Oxitropium adverse reaction --somehow it sneaks through domain definition above, so define this one separately
	--2020-Mar-17
	(41769001,          'Condition',    TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20200428', 'YYYYMMDD')), --Disease suspected
	--2020-Nov-04
	(734539000,         'Drug',         TO_DATE('20201104', 'YYYYMMDD'), TO_DATE('20210211', 'YYYYMMDD')), --Effector

	--19.2.2 Relevant
	--history:on
	(138875005,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150104', 'YYYYMMDD')), -- root
	(138875005,         'Metadata',     TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- root
	--history:off
	(900000000000441003,'Metadata',     TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SNOMED CT Model Component
	(105590001,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Substances
	(123038009,         'Specimen',     TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Specimen
	(48176007,          'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Social context
	(243796009,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Situation with explicit context
	(272379006,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Events
	(260787004,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Physical object
	(362981000,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Qualifier value
	(363787002,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Observable entity
	(410607006,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Organism
	--history:on
	(419891008,         'Note Type',    TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20151009', 'YYYYMMDD')), -- Record artifact
	(419891008,         'Type Concept', TO_DATE('20151009', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Record artifact
	--history:off
	(78621006,          'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Physical force
	(123037004,   'Spec Anatomic Site', TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Body structure
	(118956008,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Body structure, altered from its original anatomical structure, reverted from 123037004
	--history:on
	(254291000,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20181107', 'YYYYMMDD')), -- Staging / Scales
	(254291000,         'Measurement',  TO_DATE('20181107', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Staging / Scales [AVOF-1295]
	--history:off
	(370115009,         'Metadata',     TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Special Concept
	(308916002,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Environment or geographical location
	--history:on
	(223366009,   'Provider Specialty', TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20190201', 'YYYYMMDD')), -- Site of care
	(223366009,         'Provider',     TO_DATE('20190201', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Site of care
	--history:off
	--history:on
	(43741000,      'Place of Service', TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20210217', 'YYYYMMDD')), -- Site of care
	(43741000,      'Visit',            TO_DATE('20210217', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Site of care
	--history:off
	(420056007,         'Drug',         TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Aromatherapy agent
	(373873005,         'Drug',         TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pharmaceutical / biologic product
	(410942007,         'Drug',         TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Drug or medicament
	(385285004,         'Drug',         TO_DATE('20150518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- dialysis dosage form
	(421967003,         'Drug',         TO_DATE('20150518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- drug dose form
	(424387007,         'Drug',         TO_DATE('20150518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- dose form by site prepared for
	(421563008,         'Drug',         TO_DATE('20150518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- complementary medicine dose form
	--history:on
	(284009009,         'Drug',         TO_DATE('20150518', 'YYYYMMDD'), TO_DATE('20171116', 'YYYYMMDD')), -- Route of administration value
	(284009009,         'Route',        TO_DATE('20171116', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Route of administration value
	--history:off
	--history:on
	(373783004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20190418', 'YYYYMMDD')), -- dietary product, exception of Pharmaceutical / biologic product
	(373783004,         'Device',       TO_DATE('20190418', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- dietary product, exception of Pharmaceutical / biologic product
	--history:off
	(419572002,         'Observation',  TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- alcohol agent, exception of drug
	--history:on
	(373782009,         'Observation',  TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20180208', 'YYYYMMDD')), -- diagnostic substance, exception of drug
	(373782009,         'Device',       TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- diagnostic substance, exception of drug
	--history:off
	(2949005,           'Observation',  TO_DATE('20150518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- diagnostic aid (exclusion from drugs)
	(404684003,         'Condition',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Clinical Finding
	(313413008,         'Condition',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Calculus observation
	(405533003,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adverse incident outcome categories
	(365854008,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- History finding
	(118233009,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of activity of daily living
	(307824009,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Administrative statuses
	(162408000,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Symptom description
	(105729006,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Health perception, health management pattern
	(162566001,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Patient not aware of diagnosis
	--history:on
	(122869004,         'Measurement',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), --Measurement
	(122869004,         'Measurement',  TO_DATE('20150311', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measurement
	--history:off
	(71388002,          'Procedure',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Procedure
	--history:on
	(304252001,         'Procedure',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Resuscitate
	(304252001,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Resuscitate
	--history:off
	(304253006,         'Procedure',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150104', 'YYYYMMDD')), -- DNR
	(304253006,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- DNR
	--history:on
	(113021009,         'Procedure',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Cardiovascular measurement
	(113021009,         'Procedure',    TO_DATE('20150311', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cardiovascular measurement
	--history:off
	(297249002,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Family history of procedure
	(14734007,          'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Administrative procedure
	(416940007,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Past history of procedure
	(183932001,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Procedure contraindicated
	(438833006,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Administration of drug or medicament contraindicated
	(410684002,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Drug therapy status
	(17636008,          'Procedure',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Specimen collection treatments and procedures - - bad child of 4028908 Laboratory procedure
	(365873007,         'Gender',       TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Gender
	(372148003,         'Race',         TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Ethnic group
	(415229000,         'Race',         TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Racial group
	(106237007,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Linkage concept
	(767524001,         'Unit',         TO_DATE('20190211', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --  Unit of measure (Top unit)
	(260245000,         'Meas Value',   TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Meas Value
	(125677006,         'Relationship', TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Relationship
	(264301008,         'Observation',  TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Psychoactive substance of abuse - non-pharmaceutical
	(226465004,         'Observation',  TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Drinks
	--history:on
	(49062001,          'Device',       TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20141231', 'YYYYMMDD')), -- Device
	(49062001,          'Device',       TO_DATE('20150518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Device
	--history:off
	(289964002,         'Device',       TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Surgical material
	(260667007,         'Device',       TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Graft
	(418920007,         'Device',       TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adhesive agent
	(255922001,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dental material
	--history:on
	(413674002,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150104', 'YYYYMMDD')), -- Body material
	(413674002,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Body material
	--history:off
	(118417008,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Filling material
	(445214009,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- corneal storage medium
	(69449002,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Drug action
	(79899007,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Drug interaction
	(365858006,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Prognosis/outlook finding
	(444332001,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Aware of prognosis
	(444143004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Carries emergency treatment
	(13197004,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Contraception
	(251859005,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dialysis finding
	(422704000,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Difficulty obtaining contraception
	(250869005,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Equipment finding
	(217315002,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Onset of illness
	(127362006,         'Observation',  TO_DATE('20160322', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Previous pregnancies
	(162511002,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Rare history finding
	(118226009,         'Observation',  TO_DATE('20190211', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),	-- Temporal finding
	(366154003,         'Observation',  TO_DATE('20190211', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Respiratory flow rate - finding
	(243826008,         'Observation',  TO_DATE('20190211', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Antenatal care status
	(418038007,         'Observation',  TO_DATE('20190211', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Propensity to adverse reactions to substance
	(413296003,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Depression requiring intervention
	(72670004,          'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Sign
	(124083000,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Urobilinogenemia
	(59524001,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Blood bank procedure
	(389067005,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Community health procedure
	(225288009,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Environmental care procedure
	(308335008,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Patient encounter procedure
	(389084004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Staff related procedure
	(110461004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adjunctive care
	(372038002,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Advocacy
	(225365006,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Care regime
	(228114008,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Child health procedures
	(309466006,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Clinical observation regime
	(225318000,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Personal and environmental management regime
	(133877004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Therapeutic regimen
	(225367003,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Toileting regime
	(303163003,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Treatments administered under the provisions of the law
	(429159005,         'Procedure',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Child psychotherapy
	(15220000,          'Measurement',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Laboratory test
	--history:on
	--TODO: postponed for the next SNOMED release - deStandardize, split and map over
	(441742003,         'Measurement',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20170810', 'YYYYMMDD')), -- Evaluation finding
	(441742003,         'Condition',    TO_DATE('20170810', 'YYYYMMDD'), TO_DATE('20201104', 'YYYYMMDD')), -- Evaluation finding
	(441742003,         'Measurement',  TO_DATE('20201104', 'YYYYMMDD'), TO_DATE('20201210', 'YYYYMMDD')), -- Evaluation finding
	(441742003,         'Condition',    TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Evaluation finding
	--history:off
	--history:on
	(365605003,         'Measurement',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20170810', 'YYYYMMDD')), -- Body measurement finding
	(365605003,         'Observation',  TO_DATE('20170810', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Body measurement finding
	--history:off
	(106019003,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Elimination pattern
	(106146005,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Reflex finding
	(103020000,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adrenarche
	(405729008,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hematochezia
	--TODO: deStandardize, split and map over
	(165816005,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- HIV positive
	(300391003,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of appearance of stool
	(300393000,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of odor of stool
	(239516002,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Monitoring procedure
	(243114000,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Support
	(300893006,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Nutritional finding
	(116336009,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Eating / feeding / drinking finding
	--history:on
	(448717002,         'Measurement',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20170810', 'YYYYMMDD')), -- Decline in Edinburgh postnatal depression scale score
	(448717002,         'Condition',    TO_DATE('20170810', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Decline in Edinburgh postnatal depression scale score
	--history:off
	--history:on
	(449413009,         'Measurement',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20170810', 'YYYYMMDD')), -- Decline in Edinburgh postnatal depression scale score at 8 months
	(449413009,         'Condition',    TO_DATE('20170810', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Decline in Edinburgh postnatal depression scale score at 8 months
	--history:off
	(118227000,         'Condition',    TO_DATE('20170810', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Vital signs finding
	(363259005,         'Observation',  TO_DATE('20160616', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Patient management procedure
	(278414003,         'Procedure',    TO_DATE('20160616', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pain management
	(225831004,         'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding relating to advocacy
	(134436002,         'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Lifestyle
	(365980008,         'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Tobacco use and exposure - finding
	(386091000,         'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding related to compliance with treatment
	--history:on
	(424092004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Questionable explanation of injury
	(424092004,         'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Questionable explanation of injury
	--history:off
	(364721000000101,   'Measurement',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- DFT: dynamic function test
	(749211000000106,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- NHS Sickle Cell and Thalassaemia Screening Programme family origin
	(91291000000109,    'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Health of the Nation Outcome Scale interpretation
	(900781000000102,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Noncompliance with dietetic intervention
	(784891000000108,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Injury inconsistent with history given
	(863811000000102,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Injury within last 48 hours
	(920911000000100,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Appropriate use of accident and emergency service
	(927031000000106,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Inappropriate use of walk-in centre
	(927041000000102,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Inappropriate use of accident and emergency service
	(927901000000101,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Inappropriate triage decision
	(927921000000105,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Appropriate triage decision
	(921071000000100,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Appropriate use of walk-in centre
	(962871000000107,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Aware of overall cardiovascular disease risk
	(968521000000109,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Inappropriate use of general practitioner service
	--2017-Aug-25 these concepts should be in Observation, so people can put causative agent into
	--history:on
	(282100009,         'Observation',  TO_DATE('20170825', 'YYYYMMDD'), TO_DATE('20171116', 'YYYYMMDD')), -- Adverse reaction caused by substance
	(282100009,         'Observation',  TO_DATE('20180820', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adverse reaction caused by substance
	--history:off
	(473010000,         'Condition',    TO_DATE('20171116', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hypersensitivity condition
	(419199007,         'Observation',  TO_DATE('20170825', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Allergy to substance
	(10628711000119101, 'Condition',    TO_DATE('20171116', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Allergic contact dermatitis caused by plant (this is only one child of 419199007 Allergy to substance that has exact condition mentioned
	--2017-Aug-30
	(310611001,         'Measurement',  TO_DATE('20170830', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cardiovascular measure
	(424122007,         'Observation',  TO_DATE('20170830', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- ECOG performance status finding
	(698289004,         'Observation',  TO_DATE('20171116', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hooka whatever Observation  -- http://forums.ohdsi.org/t/hookah-concept/3515
	(248627000,         'Measurement',  TO_DATE('20171116', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pulse characteristics
	--2017-Nov-28 [AVOF-731]
	(410652009,         'Device',       TO_DATE('20171128', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Blood product
	(105904009,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Type of drug preparation
	--Azaribine, Pegaptanib sodium, Cutaneous aerosol, Pegaptanib, etc. - exclusion without nice hierarchy
	(373447009,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(416058004,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(387111009,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(423490007,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(1536005,           'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(386925003,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(126154004,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(421347001,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(61483006,          'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(373749006,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	--2018-Aug-21
	(709080004,         'Observation',  TO_DATE('20180821', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	--2018-Oct-06
	(414916001,         'Condition',    TO_DATE('20181006', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Obesity
	--2018-Nov-07 [AVOF-1295]
	(125123008,         'Measurement',  TO_DATE('20181107', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Organ Weight
	(125125001,         'Observation',  TO_DATE('20181107', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Abnormal organ weight
	(125124002,         'Observation',  TO_DATE('20181107', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),-- Normal organ weight
	(268444004,         'Measurement',  TO_DATE('20181107', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Radionuclide red cell mass measurement
	--2019-Apr-18 [AVOF-1198]
	(327838005,         'Device',       TO_DATE('20190418', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Intravenous nutrition
	(116178008,         'Device',       TO_DATE('20190418', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dialysis fluid
	(407935004,         'Device',       TO_DATE('20190418', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Contrast media
	(385420005,         'Device',       TO_DATE('20190418', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Contrast media
	(332525008,         'Device',       TO_DATE('20190418', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),  --Camouflaging preparations
	(768697005,         'Device',       TO_DATE('20190418', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Barium and barium compound product -- contrast media subcathegory
	--2019-Aug-27
	(8653201000001106,  'Drug',         TO_DATE('20190827', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --dm+d value
	(397731000,         'Race',         TO_DATE('20190827', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Ethnic group finding
	--2019-Mov-13
	(108246006,         'Measurement',  TO_DATE('20191113', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Tonometry AND/OR tonography procedure
	--2020-Mar-12
	(61746007,          'Measurement',  TO_DATE('20200312', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Taking patient vital signs
	(771387000,         'Drug',         TO_DATE('20200312', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Substance with effector mechanism of action
	--2020-Mar-17
	(365866002,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Finding of HIV status
	(438508001,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Virus present
	--history:on
	(710954001,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20220504', 'YYYYMMDD')), --Bacteria present
	(710954001,         'Condition',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Bacteria present
	--history:off
	(871000124102,      'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Virus not detected
	(426000000,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Fever greater than 100.4 Fahrenheit
	(164304001,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - hyperpyrexia - greater than 40.5 degrees Celsius
	(163633002,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E -skin temperature abnormal
	(164294007,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - rectal temperature
	(164295008,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - core temperature
	(164300005,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - temperature normal
	(164303007,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - temperature elevated
	(164293001,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - groin temperature
	(164301009,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - temperature low
	(164292006,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - axillary temperature
	(275874003,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - oral temperature
	(315632006,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - tympanic temperature
	(274308003,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - hyperpyrexia
	(164285001,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - fever - general
	(164290003,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - method fever registered
	(1240591000000102,  'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --2019 novel coronavirus not detected
	(162913005,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - rate of respiration
	--2020-Apr-28
	(117617002,         'Measurement',  TO_DATE('20200428', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Immunohistochemistry procedure
	--2020-May-18
	(395098000,         'Condition',    TO_DATE('20200518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Disorder confirmed
	(1321161000000104,  'Visit',        TO_DATE('20200518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Household quarantine to prevent exposure of community to contagion
	(1321151000000102,  'Visit',        TO_DATE('20200518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Reverse self-isolation of uninfected subject to prevent exposure to contagion
	(1321141000000100,  'Visit',        TO_DATE('20200518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Reverse isolation of household to prevent exposure of uninfected subject to contagion
	(1321131000000109,  'Visit',        TO_DATE('20200518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Self quarantine and similar
	--2020-Nov-04
	(1032021000000100,  'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Protein level
	(364711002,         'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')) --Specific test feature
	) AS a
	UNION ALL
	SELECT b.* FROM (VALUES
	--history:on
	(364066008,         'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20201210', 'YYYYMMDD'), NULL), --Cardiovascular observable
	(364066008,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 1), --Cardiovascular observable
	(364066008,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0), --Cardiovascular observable
	--history:off
	(405805006,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0), --Cardiac resuscitation outcome
	(405801002,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0), --Coronary reperfusion type
	(364072008,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0), --Cardiac feature
	(364087003,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0),  --Blood vessel feature
	(364069001,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0),  --Cardiac conduction system feature
	(427751006,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0),  --Extent of cardiac perfusion defect
	(429162008,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0),  --Extent of myocardial stress ischemia
	(1099111000000105,  'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 1)  --Thrombolysis In Myocardial Infarction risk score for unstable angina or non-ST-segment-elevation myocardial infarction
) AS b
UNION ALL
SELECT c.*, NULL FROM (VALUES
	(248326004,         'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Body measure
	(396238001,         'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Tumor measureable
	(371508000,         'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Tumour stage
	(246116008,         'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Lesion size
	(404933001,         'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Berg balance test
	(766739005,         'Drug',         TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Substance categorized by disposition
	(365341008,         'Observation',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Finding related to ability to perform community living activities
	(365031000,         'Observation',  TO_DATE('20201124', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Finding related to ability to perform activities of everyday life
	(365242003,         'Observation',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Finding related to ability to perform domestic activities
--history:on
	(284530008,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), --Communication, speech and language finding
	(284530008,         'Observation',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20211027', 'YYYYMMDD')), --Communication, speech and language finding
--history:off
	(29164008,          'Condition',    TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Disturbance in speech
	(288579009,         'Condition',    TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Difficulty communicating
	(288576002,         'Condition',    TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Unable to communicate
	(229621000,         'Condition',    TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Disorder of fluency
	--AVOF-2893
	(260299005,         'Meas Value',   TO_DATE('20201117', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Number
	(272063003,         'Meas Value',   TO_DATE('20201117', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Alphanumeric
--history:on
	(397745006,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), --Medical contraindication
	(397745006,         'Observation',  TO_DATE('20201124', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Medical contraindication
--history:off
	(373063009,         'Measurement',  TO_DATE('20201130', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Substance observable
--2020-Dec-10
	(252124009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Test distance
--branches of 364676005 Anesthetic observable
	(302132005,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --American Society of Anesthesiologists physical status class
	(250808000,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Arteriovenous difference
--TODO: deStandardize and map over Observable Entities that have Staging / Scales equivalent
	(787475007,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Post Anesthetic Recovery score
	(364678006,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Neuromuscular blockade observable
	(364681001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Waveform observable
	(373629008,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Capillary carbon dioxide tension

	(364048003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Respiratory observable
	(400987003,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Asthma trigger
	(364053008,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Characteristic of respiratory tract function
	(364049006,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Lower respiratory tract observable
	(366874008,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Number of asthma exacerbations in past year
	(723245007,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Number of chronic obstructive pulmonary disease exacerbations in past year
	(364062005,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Respiration observable
	(250822000,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Inspiration/expiration time ratio
	(250811004,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Minute volume
	(251880004,         'Measurement',  TO_DATE('20181107', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Respiratory measure [AVOF-1295]
	(404988002,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Respiratory gas exchange status
	(404996007,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Airway patency status
	(75098008,          'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Flow history
	(364055001,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Respiratory characteristics of chest

	(386725007,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Body temperature
	(434912009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Blood glucose concentration
	(934171000000101,   'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Blood lead level
	(934191000000102,   'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Blood lead level
	(1107241000000102,  'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Calcium substance concentration in plasma adjusted for albumin
	(1107251000000104,  'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Calcium substance concentration in serum adjusted for albumin
	(434910001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Interstitial fluid glucose concentration
	(395527009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Microscopic specimen observable
	(397504000,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Organ AND/OR tissue microscopically involved by tumor
	(371509008,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Status of peritumoral lymphocyte response

	(434911002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Plasma glucose concentration
	(935051000000108,   'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Serum adjusted calcium concentration
	(399435001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Specimen measurable
	(102485007,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Personal risk factor
	(364684009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Body product observable
	(250430006,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Color of specimen
	(115598002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Consistency of specimen
	(314037008,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Serum appearance
	(412835001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Calculus appearance
	(250434002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Odor of specimen
	(364575001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Bone observable
	(804361000000106,   'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Bone density scan due date
	(405043008,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Bone healing status
	(364576000,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Form of bone
	(364577009,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Movement of bone

	(364566003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of joint
	(249948009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Grade of muscle power
	(364574002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of skeletal muscle
	(364580005,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Musculoskeletal measure
	  (404977008,       'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Skeletal functioning status

	(396277003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Fluid observable
	(439260001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Thromboelastography observable
	(364362002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Obstetric investigative observable
	(364200006,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of urination
	(1240461000000109,  'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measurement of Severe acute respiratory syndrome coronavirus 2 antibody
--branch 414236006 Feature of anatomical entity
	(703489001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Anogenital distance
	(246792000,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Eye measure
	(364499003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of lower limb
	(364313002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of menstruation
	(364036001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of nose
	(364247002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of vagina
	(364259003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of uterus
	(364278003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of gravid uterus
	(364467009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of upper limb
	(364276004,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of uterine contractions
	(364292009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of cervix
	(364295006,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of ovary
	(364486001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of hand
	(364519002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of foot
	(397274003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Exophthalmometry measurement
	(363978004,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of lacrimation
	(364309009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Duration measure of menstruation
	(363939003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measure of globe

	(364097007,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Feature of pulmonary arterial pressure
	(399048009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Main pulmonary artery peak velocity
	(252091007,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Distal vessel patency
	(364679003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Intracerebral vascular observable
	(398992002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Pulmonary vein feature
	(251191008,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Cardiac axis
	(251131006,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --AH interval
	(251127000,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Effective refractory period
	(251132004,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --HV interval
	(251133009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Wenckebach cycle length
	(408719002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Cardiac end-diastolic volume
	(408718005,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Cardiac end-systolic volume
	(364077002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Characteristic of heart sound
	(399137004,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Feature of left atrium
	(364080001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Feature of left ventricle
	(364081002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Feature of right ventricle
	(364082009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Heart valve feature
	(364067004,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Cardiac investigative observable
	(399231008,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Cardiovascular orifice observable
	(364071001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Cardiovascular shunt feature
	(364068009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --ECG feature
	(371846000,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Pulmonary valve flow
	(397417004,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Regurgitant flow
	(399301000,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Regurgitant fraction
--2021-Jan-27
	(871562009,         'Measurement',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Detection of Severe acute respiratory syndrome coronavirus 2
	(1240471000000102,  'Measurement',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measurement of Severe acute respiratory syndrome coronavirus 2 antigen
	(1240581000000104,  'Measurement',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Severe acute respiratory syndrome coronavirus 2 detected
	(62305002,          'Condition',    TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Disorder of language
	(129063003,         'Observation',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Instrumental activity of daily living
	(289161009,         'Condition',    TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Finding of appetite
--history:on
	(309298003,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), --Drug therapy observations
	(309298003,         'Observation',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Drug therapy finding
--history:off
	(271807003,         'Condition',    TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Eruption
	(28926001,          'Condition',    TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Eruption due to drug
	(402752000,         'Condition',    TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Dermatosis resulting from cytotoxic therapy
	(238986007,         'Condition',    TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Chemical-induced dermatological disorder
	(293104008,         'Observation',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Adverse reaction to vaccine product
	(863903001,         'Observation',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Allergy to vaccine product
	(20135006,          'Measurement',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Screening procedure
	(80943009,          'Measurement',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Risk factor
	(58915005,          'Measurement',  TO_DATE('20210215', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Immune status

    --2022-May-04
    --Found during step 19.2.3
    (163166004,          'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - tongue examined
    (164399004,          'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - skin scar
    (231466009,          'Condition',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Acute drug intoxication
    (268935007,          'Condition',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --On examination - peripheral pulses right leg
    (268936008,          'Condition',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --On examination - peripheral pulses left leg
    (365726006,          'Condition',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Finding related to ability to process information accurately
    (365737007,          'Condition',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Finding related to ability to process information at normal speed
    (365748000,          'Condition',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Finding related to ability to analyze information
    (59274003,          'Condition',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Intentional drug overdose
    (401783003,          'Device',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Disposable insulin U100 syringe+needle
    (401826003,          'Device',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Hypodermic U100 insulin syringe sterile single use / single patient use 0.5ml with 12mm needle 0.33mm/29gauge
    (401830000,          'Device',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Hypodermic U100 insulin syringe sterile single use / single patient use 1ml with 12mm needle 0.33mm/29gauge

    --Found during manual check after generic stage
    (91723000,          'Spec Anatomic Site',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Anatomical structure
    (284648005,          'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Dietary intake finding
    (911001000000101,     'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Serum norclomipramine measurement
    (288533004, 'Meas Value', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Change values
    (782964007, 'Condition', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Genetic disease
    (237834000, 'Condition', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Disorder of stature
    (400038003, 'Condition', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Congenital malformation syndrome
    (407674008, 'Condition', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Aspirin-induced asthma
    (263605001, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Length dimension of neoplasm
    (4370001000004107, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Length of excised tissue specimen
    (443527007, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Number of lymph nodes containing metastatic neoplasm in excised specimen
    (396236002, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Depth of invasion by tumour
    (396239009, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Horizontal extent of stromal invasion by tumour
    (371490004, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Distance of tumour from anal verge
    (258261001, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Tumour volume
    (371503009, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Tumour weight
    (444916005, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Percentage of carcinoma in situ in neoplasm
    (444901007, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Proportion score of neoplastic cells positive for hormone receptors using immunohistochemistry
    (444775005, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Average intensity of positive staining neoplastic cells
    (385404000, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Tumour quantitation
    (405930005, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Number of tumour nodules
    (385300008, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Linear extent of involvement of carcinoma
    (444025001, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Number of lymph nodes examined by microscopy in excised specimen
    (444644009, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Number fraction of oestrogen receptors in neoplasm using immune stain
    (445104009, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Allred score for neoplasm
    (445366002, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Number fraction of progesterone receptors in neoplasm using immune stain
    (399514000, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Distance of anterior margin of tumour base from limbus of cornea at cut edge, after sectioning
    (396988001, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Distance of posterior margin of tumour base from edge of optic disc, after sectioning
    (405921002, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Percentage of tumour involved by necrosis
    (396987006, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Distance from anterior edge of tumour to limbus of cornea at cut edge, after sectioning
    (786458005, 'Measurement', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Self reported usual body weight
    (162300006, 'Observation', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Unilateral headache
    (428264009, 'Observation', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Painful gait
    (905231000000103, 'Observation', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Imbalanced intake of fibre
    (896531000000104, 'Observation', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Imbalanced dietary intake of fat
    (735643002, 'Observation', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Short stature of childhood
    (948391000000106, 'Observation', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --O/E - antalgic gait
    (43528001, 'Observation', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Distomolar supernumerary tooth
    (371234007, 'Meas Value', TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Colour modifier

    --Found during github search and/or Vocabulary team reports
    (165109007,          'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Basal metabolic rate
    (7928001,          'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Body oxygen consumption
    (698834005,          'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Metabolic equivalent of task
    (251836004,          'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Nitrogen balance
    (16206004,          'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Oxygen delivery
    (251831009,          'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Oxygen extraction ratio
    (251832002,          'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Oxygen uptake
    (74427007,          'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Respiratory quotient
    (251838003,          'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Total body potassium
    (409652008,          'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Population statistic
    (165815009,          'Condition',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --HIV negative
    (59000001,          'Procedure',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Surgical pathology consultation and report on referred slides prepared elsewhere
    (365956009,          'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Finding of sexual orientation
    (443938003,          'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')) --Procedure carried out on subject


) as c;

--19.2.3 To be reviewed in the future
--TODO: disabled for now to avoid duplication with standard Measurements
--(445536008,         'Measurement',  TO_DATE('new', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')) --Assessment using assessment scale
--TODO: sort it out
--(364709006,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Hematology observable
--TODO: sort it out
--(414236006,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Feature of anatomical entity
--118222006 General finding of observation of patient !!!already defined above!!!
-- 364599001 Fetal observable
-- 415823006 Vision observable, including 363983007 Visual acuity
-- 251837008 Total body water
-- 364328002 Labor observable
-- 716138005 Hoehn and Yahr Scale score
-- 37859006 Pulmonary ventilation perfusion study
-- 397852001 V/Q - Ventilation/perfusion ratio
-- 364539003 Measure of skin
--TODO: review scales (A Mixture of scores and Observations)
--(363870007,        'Measurement',  TO_DATE('new', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Mental state, behavior / psychosocial function observable
--(86084001,        'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('19700101', 'YYYYMMDD')), --Hematologic function    --Postponed

--19.3. Ancestors inherit the domain_id and standard_concept of their Peaks. However, the ancestors of Peaks are overlapping.
--Therefore, the order by which the inheritance is passed depends on the "height" in the hierarchy: The lower the peak, the later it should be run
--The following creates the right order by counting the number of ancestors: The more ancestors the lower in the hierarchy.
--This could cause trouble if a parallel fork happens at the same height, but it is resolved by domain precedence.
UPDATE peak p
SET ranked = (
		SELECT rnk
		FROM (
			SELECT ranked.pd AS peak_code,
				COUNT(*) + 1 AS rnk -- +1 so the top most who have an ancestor are ranked 2, and the ancestor can be ranked 1 (see below)
			FROM (
				SELECT DISTINCT pa.peak_code AS pa,
					pd.peak_code AS pd
				FROM peak pa,
					snomed_ancestor a,
					peak pd
				WHERE a.ancestor_concept_code = pa.peak_code
					AND a.descendant_concept_code = pd.peak_code
					AND pa.levels_down IS NULL
					AND pa.valid_end_date = TO_DATE('20991231', 'YYYYMMDD') --consider only active peaks
					AND pd.valid_end_date = TO_DATE('20991231', 'YYYYMMDD') --consider only active peaks
				) ranked
			GROUP BY ranked.pd
			) r
		WHERE r.peak_code = p.peak_code
		)
WHERE valid_end_date = TO_DATE('20991231', 'YYYYMMDD');--rank only active peaks

--For those that have no ancestors, the rank is 1
UPDATE peak
SET ranked = 1
WHERE ranked IS NULL
	AND valid_end_date = TO_DATE('20991231', 'YYYYMMDD');--rank only active peaks

--19.4. Find other peak concepts (orphans) that are missed from the above manual list, and assign them a domain_id based on heuristic.
/* TODO: Temporaly commented to facilitate code run
--This is a crude catch for those circumstances if the SNOMED hierarchy as changed and the peak list is no longer complete
--this should retrive nothing, otherwise add these peaks manually
DO $$
DECLARE
r RECORD;
BEGIN
	SELECT DISTINCT c.concept_code::BIGINT AS peak_code,
		CASE
			WHEN c.concept_class_id = 'Clinical finding'
				THEN 'Condition'
			WHEN c.concept_class_id = 'Model Comp'
				THEN 'Metadata'
			WHEN c.concept_class_id = 'Namespace Concept'
				THEN 'Metadata'
			WHEN c.concept_class_id = 'Observable Entity'
				THEN 'Observation'
			WHEN c.concept_class_id = 'Organism'
				THEN 'Observation'
			WHEN c.concept_class_id = 'Pharma/Biol Product'
				THEN 'Drug'
			ELSE 'Observation'
			END AS peak_domain_id,
		NULL::INT AS ranked
--	INTO r --remove "into r" to run as generic query
	FROM snomed_ancestor a,
		concept_stage c
	WHERE c.concept_code::BIGINT = a.ancestor_concept_code
		AND a.ancestor_concept_code NOT IN (
			SELECT DISTINCT -- find those where ancestors are not also a descendant, i.e. a top of a tree
				descendant_concept_code
			FROM snomed_ancestor
			)
		AND a.ancestor_concept_code NOT IN (
			--but exclude those we already have
			SELECT peak_code
			FROM peak
			WHERE valid_end_date = TO_DATE('20991231', 'YYYYMMDD') --consider only active peaks
			)
		AND c.vocabulary_id = 'SNOMED' LIMIT 1;
	IF FOUND THEN
		RAISE EXCEPTION 'critical error';
	END IF;
END $$;

 */

--19.5. Build domains, preassign all them with "Not assigned"
DROP TABLE IF EXISTS domain_snomed;
CREATE UNLOGGED TABLE domain_snomed AS
SELECT concept_code::BIGINT,
	CAST('Not assigned' AS VARCHAR(20)) AS domain_id
FROM concept_stage
WHERE vocabulary_id = 'SNOMED';

--20. Pass out domain_ids
--Method 1: Assign domains to children of peak concepts in the order rank, and within rank by order of precedence
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
		    ELSE 10 END, -- everything else is Observation
		p.peak_domain_id
	) i
WHERE d.concept_code = i.descendant_concept_code;

--Assign domains of peaks themselves (snomed_ancestor doesn't include self-descendants)
UPDATE domain_snomed d
SET domain_id = i.peak_domain_id
FROM (
	SELECT DISTINCT peak_code,
		-- if there are several records for 1 peak, use the following ORDER: levels_down = 0 > 1 ... x > NULL
		FIRST_VALUE(peak_domain_id) OVER (
			PARTITION BY peak_code ORDER BY levels_down ASC NULLS LAST
			) AS peak_domain_id
	FROM peak
	WHERE ranked IS NOT NULL --consider active peaks only
	) i
WHERE i.peak_code = d.concept_code;

--Update top guy
UPDATE domain_snomed SET domain_id = 'Metadata' WHERE concept_code = 138875005;

--Method 2: For those that slipped through the cracks assign domains by using the class_concept_id
--This is a crude method, and Method 1 should be revised to cover all concepts.
--If Local editions are based on outdated versions of International release, there always will be rows in here. This is unavoidable on our end.
UPDATE domain_snomed d
SET domain_id = i.domain_id
FROM (
	SELECT CASE c.concept_class_id
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
				THEN 'Observation'
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
			END AS domain_id,
		c.concept_code::BIGINT
	FROM concept_stage c
	WHERE c.VOCABULARY_ID = 'SNOMED'
	) i
WHERE d.domain_id = 'Not assigned'
	AND i.concept_code = d.concept_code;

--20.1. Update concept_stage from newly created domains.
UPDATE concept_stage c
SET domain_id = i.domain_id
FROM (
	SELECT d.domain_id,
		d.concept_code
	FROM domain_snomed d
	) i
WHERE c.vocabulary_id = 'SNOMED'
	AND i.concept_code::TEXT = c.concept_code;

--20.2. Make manual changes according to rules
--Manual correction
UPDATE concept_stage
SET domain_id = 'Measurement'
WHERE concept_code IN (
		'77667008', --Therapeutic drug monitoring, qualitative
		'68555003', --Therapeutic drug monitoring, quantitative
		'30058000', --Therapeutic drug monitoring assay
		'88884005',	--Alpha-1-antitrypsin phenotyping
		'851211000000105' --Assessment of sedation level
		);

UPDATE concept_stage
SET domain_id = 'Condition'
WHERE concept_code IN (
		'312963001', --Methanol retinopathy
		'424909003', --Toxic retinopathy
		'44115007', --Toxic maculopathy
		'702809001', --Drug reaction with eosinophilia and systemic symptoms
		'702810006', --Allopurinol hypersensitivity syndrome
		'702811005' --Drug reaction with eosinophilia and systemic symptoms caused by strontium ranelate
		);

UPDATE concept_stage
SET domain_id = 'Observation'
WHERE concept_code IN (
		'294854007' --Allergy to albumin solution
		);

UPDATE concept_stage
SET domain_id = 'Procedure'
WHERE concept_code IN (
		'128967005' --Exercise challenge
		);

--Create Specimen Anatomical Site
UPDATE concept_stage
SET domain_id = 'Spec Anatomic Site'
WHERE concept_class_id = 'Body Structure'
	AND vocabulary_id = 'SNOMED';

--Create Specimen
UPDATE concept_stage
SET domain_id = 'Specimen'
WHERE concept_class_id = 'Specimen'
	AND vocabulary_id = 'SNOMED';

--Create Measurement Value Operator
UPDATE concept_stage
SET domain_id = 'Meas Value Operator'
WHERE concept_code IN (
		'276136004',
		'276140008',
		'276137008',
		'276138003',
		'276139006'
		)
	AND vocabulary_id = 'SNOMED';

--Create Speciment Disease Status
UPDATE concept_stage
SET domain_id = 'Spec Disease Status'
WHERE concept_code IN (
		'21594007',
		'17621005',
		'263654008'
		)
	AND vocabulary_id = 'SNOMED';

--Fix navigational concepts
UPDATE concept_stage
SET domain_id = CASE concept_class_id
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
			THEN 'Observation'
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
WHERE vocabulary_id = 'SNOMED'
	AND concept_code IN (
		SELECT descendant_concept_code::TEXT
		FROM snomed_ancestor
		WHERE ancestor_concept_code = 363743006 -- Navigational Concept, contains all sorts of orphan codes
		);

--21. Set standard_concept based on validity and domain_id
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
WHERE cs.invalid_reason IS NULL
	AND --if the concept has outside mapping from manual table, do not update it's Standard status
	NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.invalid_reason IS NULL
			AND (
				crs_int.concept_code_1,
				crs_int.vocabulary_id_1
				) <> (
				crs_int.concept_code_2,
				crs_int.vocabulary_id_2
				)
			AND crs_int.concept_code_1 = cs.concept_code
			AND crs_int.relationship_id = 'Maps to'
		);

--21.1. Split and destandardise History of concepts according to the following rules:
--Descendants of SNOMED’s History of clinical finding in subject (HoCFS)/Past history of procedure (PHoP) -> Other concepts may be added in future
--Definition status id of the concept is “Fully defined”
--All concepts that sit in hierarchy between the concept and HoCFS/PHoP are “Fully defined”
--Attributes that define concept are limited to “has associated finding” & standard definitions
--! Check these concepts manually
with hist_of_value AS
(SELECT DISTINCT c.concept_code,
                 c.valid_start_date,
                 c.vocabulary_id,
                 cc.vocabulary_id AS target_vocabulary,
                 cc.concept_code AS target_concept_code
 FROM dev_snomed.snomed_ancestor sa
JOIN dev_snomed.concept_stage c
    ON sa.descendant_concept_code::varchar = c.concept_code AND c.vocabulary_id = 'SNOMED'
LEFT JOIN dev_snomed.concept_relationship_stage cr
    ON c.concept_code = cr.concept_code_1 AND cr.relationship_id IN ('Has asso finding', 'Has asso proc') AND cr.invalid_reason IS NULL
LEFT JOIN dev_snomed.concept_stage cc
    ON cr.concept_code_2 = cc.concept_code AND cc.vocabulary_id = 'SNOMED'

WHERE ancestor_concept_code IN (417662000, 416940007)   --History of clinical finding in subject / Past history of procedure
  AND c.invalid_reason IS NULL
  AND EXISTS(SELECT * FROM dev_snomed.concept_relationship_stage crs
            WHERE crs.concept_code_1 = c.concept_code AND crs.concept_code_2 = '900000000000073002' --All concepts are defined
                AND crs.relationship_id = 'Has status' AND crs.invalid_reason IS NULL)
  AND NOT EXISTS(SELECT * FROM dev_snomed.snomed_ancestor saa
        JOIN dev_snomed.concept_relationship_stage crr
        ON crr.concept_code_1 = saa.ancestor_concept_code::varchar AND crr.concept_code_2 = '900000000000074008' --All concepts are defined (not exists primitive concepts)
      WHERE saa.descendant_concept_code::varchar = c.concept_code
        AND saa.min_levels_of_separation < sa.min_levels_of_separation --All concepts between 'Personal history'/'History of procedure' and target concept
      )

    AND cc.standard_concept = 'S' AND cc.invalid_reason IS NULL --Maps to value leads to standard valid concept

    AND NOT EXISTS(SELECT * FROM dev_snomed.concept_relationship_stage crs --Not mapped manually
        WHERE crs.concept_code_1 = c.concept_code AND crs.relationship_id = 'Maps to' AND crs.invalid_reason IS NULL)
ORDER BY c.concept_code)

INSERT INTO concept_relationship_stage (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT hist_of_value.concept_code AS concept_code_1,
       hist_of_value.target_concept_code AS concept_code_2,
       hist_of_value.vocabulary_id AS vocabulary_id_1,
       hist_of_value.target_vocabulary AS vocabulary_id_2,
       'Maps to value' AS relationship_id,
       valid_start_date,
       TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
       NULL AS invalid_reason

FROM hist_of_value

UNION

SELECT hist_of_value.concept_code AS concept_code_1,
       'OMOP5165859' AS concept_code_2,     --History of event
       hist_of_value.vocabulary_id AS vocabulary_id_1,
       'OMOP Extension' AS vocabulary_id_2,
       'Maps to' AS relationship_id,
       hist_of_value.valid_start_date,
       TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
       NULL AS invalid_reason

FROM hist_of_value

ORDER BY concept_code_1, relationship_id
;

--21.2. De-standardize navigational concepts
UPDATE concept_stage
SET standard_concept = NULL
WHERE vocabulary_id = 'SNOMED'
	AND concept_code IN (
		SELECT descendant_concept_code::TEXT
		FROM snomed_ancestor
		WHERE ancestor_concept_code = 363743006 -- Navigational Concept
		);

--21.3. Make those Obsolete routes non-standard
UPDATE concept_stage
SET standard_concept = NULL
WHERE concept_name LIKE 'Obsolete%'
	AND domain_id = 'Route';

--21.4. Add 'Maps to' relations to concepts that are duplicating between different SNOMED editions
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
		SELECT *
		FROM (
			SELECT id AS conceptid,
				active,
				statusid,
				moduleid,
				effectivetime,
				rank() OVER (
					PARTITION BY id ORDER BY effectivetime DESC
					) AS rn
			FROM sources.sct2_concept_full_merged c
			) AS s0
		WHERE rn = 1
		),
	concept_fsn AS (
		SELECT *
		FROM (
			SELECT d.conceptid,
				d.term AS fsn,
				a.active,
				a.statusid,
				a.moduleid,
				a.effectivetime,
				rank() OVER (
					PARTITION BY d.conceptid ORDER BY d.effectivetime DESC
					) AS rn
			FROM sources.sct2_desc_full_merged d
			JOIN concept_status a ON a.conceptid = d.conceptid
				AND a.active = 1
			WHERE d.active = 1
				AND d.typeid = 900000000000003001 -- FSN
			) AS s0
		WHERE rn = 1
		),
	dupes AS (
		SELECT fsn
		FROM concept_fsn
		GROUP BY fsn
		HAVING COUNT(conceptid) > 1
		),
	preferred_code AS
	--1. International concept over local
	--2. Defined concept over primitive
	--3. Newest concept
	(
		SELECT d.fsn,
			c.conceptid,
			first_value(c.conceptid) OVER (
				PARTITION BY d.fsn ORDER BY CASE c.moduleid
						WHEN 900000000000207008 -- Core (International)
							THEN 1
						ELSE 2
						END,
					CASE c.statusid
						WHEN 900000000000073002 --fully defined
							THEN 1
						ELSE 2
						END,
					effectivetime DESC
				) AS replacementid
		FROM dupes d
		JOIN concept_fsn c ON c.fsn = d.fsn
		)
SELECT p.conceptid::VARCHAR,
	p.replacementid::VARCHAR,
	'SNOMED',
	'SNOMED',
	'Maps to',
	TO_DATE('19700101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd')
FROM preferred_code p
JOIN concept_stage c ON c.concept_code = p.replacementid::VARCHAR
	AND c.standard_concept IS NOT NULL
WHERE p.conceptid <> p.replacementid
AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = p.conceptid::VARCHAR
			AND crs_int.vocabulary_id_1='SNOMED'
			AND crs_int.concept_code_2 = p.replacementid::VARCHAR
			AND crs_int.vocabulary_id_2='SNOMED'
			AND crs_int.relationship_id = 'Maps to'
		);

--21.5. Make concepts non standard if they have a 'Maps to' relationship
UPDATE concept_stage cs
SET standard_concept = NULL
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.relationship_id = 'Maps to'
			AND crs.invalid_reason IS NULL
			AND cs.concept_code = crs.concept_code_1
			AND cs.vocabulary_id = crs.vocabulary_id_1
		)
	AND cs.standard_concept = 'S';

--21.6. Make concepts non standard if they represent no information
UPDATE concept_stage cs
SET standard_concept = NULL
WHERE cs.concept_code IN (
		'1321581000000100', --SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgM detection result unknown
		'1321641000000107', --SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgG detection result unknown
		'1321651000000105', --SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) immunity status unknown
		'1321691000000102', --SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) RNA (ribonucleic acid) detection result unknown
		'1321781000000107', --SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgA detection result unknown
		'1322821000000105', --SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result unknown
		'1322911000000106' --SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antibody detection result unknown
		)
	AND cs.standard_concept = 'S';

--22. Clean up
--TODO: commented for debug purposes
--DROP TABLE peak;
--DROP TABLE domain_snomed;
--DROP TABLE snomed_ancestor;
--DROP VIEW module_date;

--22. Need to check domains before runnig the generic_update
/*temporary disabled for later use
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
