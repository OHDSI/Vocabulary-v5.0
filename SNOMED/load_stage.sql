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
* Date: 2016
**************************************************************************/

--1. Extract each component (International, UK & US) versions to porperly date the combined source in next step
drop view if exists module_date;
create view module_date as
with maxdate as
--Module content is at most as old as latest available module version
	(
		select distinct
			id,
			max (effectivetime) over 
				(partition by id) as effectivetime
		from sources.der2_ssrefset_moduledependency_merged
	)
select distinct
	m1.moduleid,
	to_char (m1.sourceeffectivetime, 'yyyy-mm-dd') as version
from sources.der2_ssrefset_moduledependency_merged m1
join maxdate m2 using (id, effectivetime)
where
	m1.active = 1 and
	m1.referencedcomponentid = 900000000000012004 and --Model component module; Synthetic target, contains source version in each row
	m1.moduleid in
	(
		900000000000207008, --Core (international) module
		999000041000000102, --UK edition
		731000124108 --US edition
	)
;

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
		(SELECT version FROM module_date where moduleid = 999000041000000102) || ' SNOMED CT UK Edition'
		,
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
	to_date (effectivestart	,'yyyymmdd') AS valid_start_date,
	TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT SUBSTR(d.term, 1, 255) AS concept_name,
		d.conceptid::TEXT AS concept_code,
		c.active,
		min (c.effectivetime) over
		 (
		 	partition by c.id
		 	order by c.active desc --if there ever were active versions of the concept, take the earliest one
		) as effectivestart,
		ROW_NUMBER() OVER (
			PARTITION BY d.conceptid
			-- Order of preference: 
			-- Active descriptions first, characterised as Preferred Synonym, prefer SNOMED Int, then US, then UK, then take the latest term
			order by
				c.active desc,
				d.active desc,
				l.active desc,
				case l.acceptabilityid
					when 900000000000548007 then 1 --Preferred
					when 900000000000549004 then 2 --Acceptable
					else 99
				end asc,
				case d.typeid
					when 900000000000013009 then 1 --Synonym (PT)
					when 900000000000003001 then 2 --Fully specified name
					else 99
				end asc,
				case l.source_file_id
					when 'INT' then 1 -- International release
					when 'US' then 2 -- SNOMED US
					when 'GB_DE' then 3 -- SNOMED UK Drug extension, updated more often
					when 'UK' then 4 -- SNOMED UK
					else 99
				end asc,
				l.effectivetime desc
			) AS rn
	FROM sources.sct2_concept_full_merged c,
		sources.sct2_desc_full_merged d,
		sources.der2_crefset_language_merged l
	WHERE 
		c.id = d.conceptid and 
		d.id = l.referencedcomponentid
		AND term IS NOT NULL
	) sct2
WHERE sct2.rn = 1

;
--4.1 For concepts with latest entry in sct2_concept having active = 0, preserve invalid_reason and valid_end date
with inactive as
	(
		select c.id :: varchar, max (c.effectivetime) over (partition by c.id) as effectiveend
		from sources.sct2_concept_full_merged c
		left join sources.sct2_concept_full_merged c2 on --ignore all entries before latest one with active = 1
			c2.active = 1 and
			c.id = c2.id and
			c.effectivetime < c2.effectivetime
		where 
			c2.id is null and
			c.active = 0
	)
update concept_stage cs
set 
	invalid_reason = 'D',
	valid_end_date = to_date (i.effectiveend,'yyyymmdd')
from inactive i
where
	i.id = cs.concept_code
;
--Some concepts were never alive; we don't know what their valid_start_date would be, so we set it to default minimum
update concept_stage
set valid_start_date = to_date ('19700101','yyyymmdd')
where valid_start_date = valid_end_date
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
								END,
							rnb
						) AS rnc
				FROM (
					SELECT concept_code,
						active,
						substring(term, '\(([^(]+)\)$') AS f7,
						rna AS rnb -- row number in sct2_desc_full_merged
					FROM (
						SELECT c.concept_code,
							d.term,
							d.active,
							ROW_NUMBER() OVER (
								PARTITION BY c.concept_code ORDER
								BY
									d.active DESC, -- active ones
									d.effectivetime desc -- latest active ones
								) rna -- row number in sct2_desc_full_merged
						FROM concept_stage c
						JOIN sources.sct2_desc_full_merged d ON d.conceptid::TEXT = c.concept_code
						WHERE 
							c.vocabulary_id = 'SNOMED' and
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

--5.1 --Some old deprecated concepts from UK drug extension module never have had correct FSN, so we can't get explicit hierarchy tag and keep them as Context-dependent class
update concept_stage c
set concept_class_id = 'Context-dependent'
where
	c.concept_class_id = 'Undefined' and
	c.invalid_reason is not null and --Make sure we only affect old concepts and not mask new classes additions
	exists
		(
			select 1
			from sources.sct2_concept_full_merged m
			where
				m.id :: varchar = c.concept_code and
				m.moduleid = 999000011000001104 --SNOMED CT United Kingdom drug extension module
		)
;

--7. Get all the synonyms from UMLS ('PT', 'PTGB', 'SY', 'SYGB', 'MTH_PT', 'FN', 'MTH_SY', 'SB') into concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)
SELECT DISTINCT m.code,
	'SNOMED',
	trim(SUBSTR(m.str, 1, 1000)),
	4180186 -- English
FROM sources.mrconso m
join concept_stage s on
	s.concept_code = m.code
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
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_synonym_stage css_int
		WHERE css_int.synonym_concept_code = m.code
			AND css_int.synonym_name = trim(SUBSTR(m.str, 1, 1000))
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
	trim(SUBSTR(d.term, 1, 1000)),
	4180186 -- English
FROM 
	(
		select
			m.id,
			m.conceptid :: varchar,
			m.term,
			first_value (active) over 
				(
					partition by id
					order by effectivetime desc
				) as active_status
		from sources.sct2_desc_full_merged m 
	) d
join concept_stage s on
	s.concept_code = d.conceptid
where 
	d.active_status = 1
	AND NOT EXISTS (
		SELECT 1
		FROM concept_synonym_stage css_int
		WHERE css_int.synonym_concept_code = d.conceptid
			AND css_int.synonym_name = trim(SUBSTR(d.term, 1, 1000))
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
					) AS rn, -- get the latest in a sequence of relationships, to decide wether it is still active
				r.active
			FROM sources.sct2_rela_full_merged r
			JOIN sources.sct2_desc_full_merged d ON r.typeid = d.conceptid
			) AS s0
		WHERE rn = 1
			AND active = 1
			AND sourceid IS NOT NULL
			AND destinationid IS NOT NULL
			AND term <> 'PBCL flag true'
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
			when term = 'Has NHS dm+d (dictionary of medicines and devices) AMP (actual medicinal product) availability restriction indicator'
				then 'Has AMP restr ind'
			WHEN term = 'Has NHS dm+d parallel import indicator'
				then 'Paral imprt ind'
			WHEN term = 'Has NHS dm+d freeness indicator'
				then 'Has free indicator'
			WHEN term = 'Units'
				then 'Has unit'
			WHEN term = 'Process duration'
				then 'Has proc duration'
			--20201023
			when term = 'Relative to'
				then 'Relative to'
			when term = 'Count of active ingredient'
				then 'Has count of act ing'
			when term = 'Has product characteristic'
				then 'Has prod character'
			when term = 'Has ingredient characteristic'
				then 'Has prod character'
			when term = 'Has surface characteristic'
				then 'Surf character of'
			when term = 'Has device intended site'
				then 'Has dev intend site'
			when term = 'Has device characteristic'
				then 'Has prod character'
			when term = 'Has compositional material'
				then 'Has comp material'
			when term = 'Has filling'
				then 'Has filling'
			ELSE term--'non-existing'
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
	coalesce (
		cs.valid_end_date,
		(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED'
		)
	),
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
		ROW_NUMBER() OVER (
			PARTITION BY sc.referencedcomponentid ORDER BY TO_DATE(sc.effectivetime, 'YYYYMMDD') DESC,
			sc.id DESC --same as of AVOF-650
			) rn,
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
LEFT JOIN concept_stage cs on -- for valid_end_date
	cs.concept_code = sn.concept_code_1 and
	cs.invalid_reason is not null
WHERE sn.rn = 1
	AND sn.active = 1
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
update concept_stage cs
set invalid_reason = 'U'
from concept_relationship_stage crs
where
	crs.concept_code_1 = cs.concept_code and
	crs.relationship_id in
		(
			'Concept replaced by',
			'Concept same_as to',
			'Concept alt_to to',
			'Concept poss_eq to',
			'Concept was_a to'
		) and
	crs.invalid_reason is null
;
--10.3. Update valid_end_date to latest_update if there is a discrepancy after last point
update concept_stage cs
set valid_end_date = (select latest_update from vocabulary where vocabulary_id = 'SNOMED') - 1
where
	invalid_reason = 'U' and
	valid_end_date = to_date ('20991231','yyyymmdd')
;
--11. Append resulting file from Medical Coder (in concept_relationship_stage format) to concept_relationship_stage
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--12. Append resulting file from Medical Coder (in concept_relationship_stage format) to concept_stage
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;


--13. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--13.1. Inherit concept class for updated concepts from mapping target -- some of them never had hierarchy tags to extract them
update concept_stage cs
set concept_class_id = x.concept_class_id
from concept_relationship_stage r, concept_stage x
where
	r.concept_code_1 = cs.concept_code and
	r.relationship_id = 'Maps to' and
	r.invalid_reason is null and
	r.concept_code_2 = x.concept_code and
	cs.concept_class_id = 'Undefined'
;

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

--17. Start building the hierarchy for progagating domain_ids from toop to bottom
DROP TABLE IF EXISTS snomed_ancestor;
CREATE UNLOGGED TABLE snomed_ancestor AS (
	WITH recursive hierarchy_concepts(ancestor_concept_code, descendant_concept_code, root_ancestor_concept_code, full_path) AS (
		SELECT ancestor_concept_code,
			descendant_concept_code,
			ancestor_concept_code AS root_ancestor_concept_code,
			ARRAY [descendant_concept_code::text] AS full_path
		FROM concepts
		
		UNION ALL
		
		SELECT c.ancestor_concept_code,
			c.descendant_concept_code,
			root_ancestor_concept_code,
			hc.full_path || c.descendant_concept_code::TEXT AS full_path
		FROM concepts c
		JOIN hierarchy_concepts hc ON hc.descendant_concept_code = c.ancestor_concept_code
		WHERE c.descendant_concept_code::TEXT <> ALL (full_path)
		),
	concepts AS (
		SELECT crs.concept_code_2 AS ancestor_concept_code,
			crs.concept_code_1 AS descendant_concept_code
		FROM concept_relationship_stage crs
		WHERE crs.invalid_reason IS NULL
			AND crs.relationship_id = 'Is a'
			AND crs.vocabulary_id_1 = 'SNOMED'
		) 
	SELECT DISTINCT hc.root_ancestor_concept_code::BIGINT AS ancestor_concept_code, hc.descendant_concept_code::BIGINT
	FROM hierarchy_concepts hc
	JOIN concept_stage cs1 ON cs1.concept_code = hc.root_ancestor_concept_code AND cs1.vocabulary_id = 'SNOMED'
	JOIN concept_stage cs2 ON cs2.concept_code = hc.descendant_concept_code AND cs2.vocabulary_id = 'SNOMED'
);

ALTER TABLE snomed_ancestor ADD CONSTRAINT xpksnomed_ancestor PRIMARY KEY (ancestor_concept_code,descendant_concept_code);

ANALYZE snomed_ancestor;

--17.1. Append deprecated concepts that have mappings as extensions of their mapping target
insert into snomed_ancestor (ancestor_concept_code,descendant_concept_code)
select
	a.ancestor_concept_code,
	s1.concept_code :: bigint
from concept_stage s1
join concept_relationship_stage r on
	s1.invalid_reason is not null and
	s1.concept_code = r.concept_code_1 and
	r.relationship_id = 'Maps to' and
	r.invalid_reason is null
join snomed_ancestor a on
	r.concept_code_2 = a.descendant_concept_code :: varchar
where
	not exists
		(
			select from snomed_ancestor x
			where x.descendant_concept_code = s1.concept_code :: bigint
		)
;
ANALYZE snomed_ancestor;
;
--17.2. For deprecated concepts without mappings, take the latest 116680003 'Is a' relationship to active concept
insert into snomed_ancestor (ancestor_concept_code,descendant_concept_code)
select
	a.ancestor_concept_code,
	m.sourceid
from concept_stage s1
join
	(
		select distinct
			r.sourceid,
			first_value (r.destinationid) over (partition by r.sourceid, r.effectivetime) as destinationid, --pick one parent at random
			r.effectivetime,
			max (r.effectivetime) over (partition by r.sourceid) as maxeffectivetime
		from sources.sct2_rela_full_merged r
		join concept_stage x on
			x.concept_code = r.destinationid :: varchar and
			x.invalid_reason is null
		where r.typeid = 116680003 -- Is a
	) m 
on
	s1.invalid_reason is not null and
	m.sourceid = s1.concept_code :: bigint and
	m.effectivetime = m.maxeffectivetime
join snomed_ancestor a on
	m.destinationid = a.descendant_concept_code
where
	not exists
		(
			select from snomed_ancestor x
			where x.descendant_concept_code = m.sourceid
		)
;
--18. Create domain_id
--18.1. Manually create table with "Peaks" = ancestors of records that are all of the same domain

DROP TABLE IF EXISTS peak;
CREATE UNLOGGED TABLE peak (
	peak_code BIGINT, --the id of the top ancestor
	peak_domain_id VARCHAR(20), -- the domain to assign to all its children
	ranked INTEGER -- number for the order in which to assign
	);

--18.2 Fill in the various peak concepts
INSERT INTO peak
VALUES (138875005, 'Metadata'), -- root
	(900000000000441003, 'Metadata'), -- SNOMED CT Model Component
	(105590001, 'Observation'), -- Substances
	(123038009, 'Specimen'), -- Specimen
	(48176007, 'Observation'), -- Social context
	(243796009, 'Observation'), -- Situation with explicit context
	(272379006, 'Observation'), -- Events
	(260787004, 'Observation'), -- Physical object
	(362981000, 'Observation'), -- Qualifier value
	(363787002, 'Observation'), -- Observable entity
	(410607006, 'Observation'), -- Organism
	(419891008, 'Type Concept'), -- Record artifact
	(78621006, 'Observation'), -- Physical force
	(123037004, 'Spec Anatomic Site'), -- Body structure
	(118956008, 'Observation'), -- Body structure, altered from its original anatomical structure, reverted from 123037004
	(254291000, 'Measurement'), -- Staging / Scales [changed Observation->Measurement AVOF-1295]
	(370115009, 'Metadata'), -- Special Concept
	(308916002, 'Observation'), -- Environment or geographical location
	(223366009, 'Provider'), (43741000, 'Place of Service'), -- Site of care
	(420056007, 'Drug'), -- Aromatherapy agent
	(373873005, 'Drug'), -- Pharmaceutical / biologic product
	(410942007, 'Drug'), -- Drug or medicament
	(385285004, 'Drug'), -- dialysis dosage form
	(421967003, 'Drug'), -- drug dose form
	(424387007, 'Drug'), -- dose form by site prepared for 
	(421563008, 'Drug'), -- complementary medicine dose form
	(284009009, 'Route'), -- Route of administration value
	(373783004, 'Device'), -- dietary product, exception of Pharmaceutical / biologic product
	(419572002, 'Observation'), -- alcohol agent, exception of drug
	(373782009, 'Device'), -- diagnostic substance, exception of drug
	(2949005, 'Observation'), -- diagnostic aid (exclusion from drugs)
	(404684003, 'Condition'), -- Clinical Finding
	(313413008, 'Condition'), -- Calculus observation
	(405533003, 'Observation'), -- Adverse incident outcome categories
	(365854008, 'Observation'), -- History finding
	(118233009, 'Observation'), -- Finding of activity of daily living
	(307824009, 'Observation'), -- Administrative statuses
	(162408000, 'Observation'), -- Symptom description
	(105729006, 'Observation'), -- Health perception, health management pattern
	(162566001, 'Observation'), --Patient not aware of diagnosis
	(122869004, 'Measurement'), --Measurement
	(71388002, 'Procedure'), -- Procedure
	(304252001, 'Observation'), -- Resuscitate
	(304253006, 'Observation'), -- DNR
	(113021009, 'Procedure'), -- Cardiovascular measurement
	(297249002, 'Observation'), -- Family history of procedure
	(14734007, 'Observation'), -- Administrative procedure
	(416940007, 'Observation'), -- Past history of procedure
	(183932001, 'Observation'), -- Procedure contraindicated
	(438833006, 'Observation'), -- Administration of drug or medicament contraindicated
	(410684002, 'Observation'), -- Drug therapy status
	(17636008, 'Procedure'), -- Specimen collection treatments and procedures - - bad child of 4028908 Laboratory procedure
	(365873007, 'Gender'), -- Gender
	(372148003, 'Race'), --Ethnic group
	(415229000, 'Race'), -- Racial group
	(106237007, 'Observation'), -- Linkage concept
	(767524001, 'Unit'), --  Unit of measure (Top unit)
	(260245000, 'Meas Value'), -- Meas Value
	(125677006, 'Relationship'), -- Relationship
	(264301008, 'Observation'), -- Psychoactive substance of abuse - non-pharmaceutical
	(226465004, 'Observation'), -- Drinks
	(49062001, 'Device'), -- Device
	(289964002, 'Device'), -- Surgical material
	(260667007, 'Device'), -- Graft
	(418920007, 'Device'), -- Adhesive agent
	(255922001, 'Device'), -- Dental material
	(413674002, 'Observation'), -- Body material
	(118417008, 'Device'), -- Filling material
	(445214009, 'Device'), -- corneal storage medium
	(69449002, 'Observation'), -- Drug action
	(79899007, 'Observation'), -- Drug interaction
	(365858006, 'Observation'), -- Prognosis/outlook finding
	(444332001, 'Observation'), -- Aware of prognosis
	(444143004, 'Observation'), -- Carries emergency treatment
	(13197004, 'Observation'), -- Contraception
	(251859005, 'Observation'), -- Dialysis finding
	(422704000, 'Observation'), -- Difficulty obtaining contraception
	(250869005, 'Observation'), -- Equipment finding
	(217315002, 'Observation'), -- Onset of illness
	(127362006, 'Observation'), -- Previous pregnancies
	(162511002, 'Observation'), -- Rare history finding
	(118226009, 'Observation'),	-- Temporal finding
	(366154003, 'Observation'), -- Respiratory flow rate - finding
	(243826008, 'Observation'), -- Antenatal care status 
	(418038007, 'Observation'), --Propensity to adverse reactions to substance
	(413296003, 'Condition'), -- Depression requiring intervention
	(72670004, 'Condition'), -- Sign
	(124083000, 'Condition'), -- Urobilinogenemia
	(59524001, 'Observation'), -- Blood bank procedure
	(389067005, 'Observation'), -- Community health procedure
	(225288009, 'Observation'), -- Environmental care procedure
	(308335008, 'Observation'), -- Patient encounter procedure
	(389084004, 'Observation'), -- Staff related procedure
	(110461004, 'Observation'), -- Adjunctive care
	(372038002, 'Observation'), -- Advocacy
	(225365006, 'Observation'), -- Care regime
	(228114008, 'Observation'), -- Child health procedures
	(309466006, 'Observation'), -- Clinical observation regime
	(225318000, 'Observation'), -- Personal and environmental management regime
	(133877004, 'Observation'), -- Therapeutic regimen
	(225367003, 'Observation'), -- Toileting regime
	(303163003, 'Observation'), -- Treatments administered under the provisions of the law
	(429159005, 'Procedure'), -- Child psychotherapy
	(15220000, 'Measurement'), -- Laboratory test
	(441742003, 'Condition'), -- Evaluation finding
	(365605003, 'Observation'), -- Body measurement finding
	(106019003, 'Condition'), -- Elimination pattern
	(106146005, 'Condition'), -- Reflex finding
	(103020000, 'Condition'), -- Adrenarche
	(405729008, 'Condition'), -- Hematochezia
	(165816005, 'Condition'), -- HIV positive
	(300391003, 'Condition'), -- Finding of appearance of stool
	(300393000, 'Condition'), -- Finding of odor of stool
	(239516002, 'Observation'), -- Monitoring procedure
	(243114000, 'Observation'), -- Support
	(300893006, 'Observation'), -- Nutritional finding
	(116336009, 'Observation'), -- Eating / feeding / drinking finding
	(448717002, 'Condition'), -- Decline in Edinburgh postnatal depression scale score
	(449413009, 'Condition'), -- Decline in Edinburgh postnatal depression scale score at 8 months
	(118227000, 'Condition'), -- Vital signs finding
	(363259005, 'Observation'), -- Patient management procedure
	(278414003, 'Procedure'), -- Pain management
	-- Added Jan 2017
	(225831004, 'Observation'), -- Finding relating to advocacy
	(134436002, 'Observation'), -- Lifestyle
	(365980008, 'Observation'), -- Tobacco use and exposure - finding
	(386091000, 'Observation'), -- Finding related to compliance with treatment
	(424092004, 'Observation'), -- Questionable explanation of injury
	(364721000000101, 'Measurement'), -- DFT: dynamic function test
	(749211000000106, 'Observation'), -- NHS Sickle Cell and Thalassaemia Screening Programme family origin
	(91291000000109, 'Observation'), -- Health of the Nation Outcome Scale interpretation
	(900781000000102, 'Observation'), -- Noncompliance with dietetic intervention
	(784891000000108, 'Observation'), -- Injury inconsistent with history given
	(863811000000102, 'Observation'), -- Injury within last 48 hours
	(920911000000100, 'Observation'), -- Appropriate use of accident and emergency service
	(927031000000106, 'Observation'), -- Inappropriate use of walk-in centre
	(927041000000102, 'Observation'), -- Inappropriate use of accident and emergency service
	(927901000000101, 'Observation'), -- Inappropriate triage decision
	(927921000000105, 'Observation'), -- Appropriate triage decision
	(921071000000100, 'Observation'), -- Appropriate use of walk-in centre
	(962871000000107, 'Observation'), -- Aware of overall cardiovascular disease risk
	(968521000000109, 'Observation'), -- Inappropriate use of general practitioner service
	--added 8/25/2017, these concepts should be in Observation, so people can put causative agent into 
	(282100009, 'Observation'), -- Adverse reaction caused by substance
	(473010000, 'Condition'), -- Hypersensitivity condition
	(419199007, 'Observation'), -- Allergy to substance
	(10628711000119101, 'Condition'), -- Allergic contact dermatitis caused by plant (this is only one child of 419199007 Allergy to substance that has exact condition mentioned
	--added 8/30/2017
	(310611001, 'Measurement'), -- Cardiovascular measure
	(424122007, 'Observation'), -- ECOG performance status finding
	(698289004, 'Observation'), -- Hooka whatever Observation  -- http://forums.ohdsi.org/t/hookah-concept/3515
	(248627000, 'Measurement'), -- Pulse characteristics
	--added 20171128 (AVOF-731)
	(410652009, 'Device'), -- Blood product
	--added 20180208
	(105904009, 'Drug'), -- Type of drug preparation
	--Azaribine, Pegaptanib sodium, Cutaneous aerosol, Pegaptanib, etc. - exclusion without nice hierarchy
	(373447009, 'Drug'),
	(416058004, 'Drug'),
	(387111009, 'Drug'),
	(423490007, 'Drug'),
	(1536005, 'Drug'),
	(386925003, 'Drug'),
	(126154004, 'Drug'),
	(421347001, 'Drug'),
	(61483006, 'Drug'),
	(373749006, 'Drug'),
	--added 20180820
	(709080004, 'Observation'),
	--added 20181005
	(414916001, 'Condition'), -- Obesity
	--added 20181106 [AVOF-1295]
	(125123008, 'Measurement'), -- Organ Weight
	(125125001, 'Observation'), --Abnormal organ weight
	(125124002, 'Observation'),-- Normal organ weight
	(268444004, 'Measurement'), -- Radionuclide red cell mass measurement
	(251880004, 'Measurement'), -- Respiratory measure
	--added 20190418 [AVOF-1198]
	(327838005, 'Device'), -- Intravenous nutrition
	(116178008, 'Device'), -- Dialysis fluid
	(407935004, 'Device'), -- Contrast media
	(385420005, 'Device'), -- Contrast media
	(332525008, 'Device'),  --Camouflaging preparations
	(768697005, 'Device'), --Barium and barium compound product -- contrast media subcathegory
	--added 20190827
	(8653201000001106, 'Drug'),
	(48176007, 'Observation'), -- Social context
	(397731000, 'Race'), -- Ethnic group finding
	--added 20191112
	(108246006, 'Measurement'), --Tonometry AND/OR tonography procedure
	--added 20200312
	(61746007, 'Measurement'), --Taking patient vital signs
	(771387000,'Drug'), --Substance with effector mechanism of action
	--added 20200317
	(365866002,'Measurement'), --Finding of HIV status
	(438508001,'Measurement'), --Virus present
	(710954001,'Measurement'), --Bacteria present
	(871000124102,'Measurement'), --Virus not detected
	(426000000,'Measurement'), --Fever greater than 100.4 Fahrenheit
	(164304001,'Measurement'), --O/E - hyperpyrexia - greater than 40.5 degrees Celsius
	(163633002,'Measurement'), --O/E -skin temperature abnormal
	(164294007,'Measurement'), --O/E - rectal temperature
	(164295008,'Measurement'), --O/E - core temperature
	(164300005,'Measurement'), --O/E - temperature normal
	(164303007,'Measurement'), --O/E - temperature elevated
	(164293001,'Measurement'), --O/E - groin temperature
	(164301009,'Measurement'), --O/E - temperature low
	(164292006,'Measurement'), --O/E - axillary temperature
	(275874003,'Measurement'), --O/E - oral temperature
	(315632006,'Measurement'), --O/E - tympanic temperature
	(274308003,'Measurement'), --O/E - hyperpyrexia
	(164285001,'Measurement'), --O/E - fever - general
	(164290003,'Measurement'), --O/E - method fever registered
	(1240591000000102,'Measurement'), --2019 novel coronavirus not detected
	(162913005,'Measurement'), --O/E - rate of respiration
	--added 20200427
	(117617002,'Measurement'), --Immunohistochemistry procedure
	--added 20200518
	(395098000, 'Condition'), --'Disorder confirmed'
	(1321161000000104, 'Visit'),
	(1321151000000102, 'Visit'),
	(1321141000000100, 'Visit'),
	(1321131000000109, 'Visit'), -- Self quarantine and similar
	--added 20201028
	(734539000,'Drug'), --Effector
	(441742003,'Measurement'), --Evaluation finding
	(1032021000000100,'Measurement'), --Protein level
	(364711002,'Measurement'), --Specific test feature
	(364066008,'Measurement'), --Cardiovascular observable
	(248326004,'Measurement'), --Body measure
	(396238001,'Measurement'), --Tumor measureable
	(371508000,'Measurement'), --Tumour stage
	(246116008,'Measurement'), --Lesion size
	(445536008,'Measurement'), --Assessment using assessment scale
	(404933001,'Measurement'), --Berg balance test
	(766739005,'Drug'), --Substance categorized by disposition
	(365341008,'Observation'), --Finding related to ability to perform community living activities
	(365242003,'Observation'), --Finding related to ability to perform domestic activities
	(284530008,'Observation'), --Communication, speech and language finding
	(29164008,'Condition'), --Disturbance in speech
	(288579009,'Condition'), --Difficulty communicating
	(288576002,'Condition'), --Unable to communicate
	(229621000,'Condition'), --Disorder of fluency
	--AVOF-2893
	(260299005,'Meas Value'),--Number
	(272063003,'Meas Value') --Alphanumeric
;
--18.3. Ancestors inherit the domain_id and standard_concept of their Peaks. However, the ancestors of Peaks are overlapping.
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
				) ranked
			GROUP BY ranked.pd
			) r
		WHERE r.peak_code = p.peak_code
		);

--For those that have no ancestors, the rank is 1
UPDATE peak SET ranked = 1 WHERE ranked IS NULL;

--18.4. Find other peak concepts (orphans) that are missed from the above manual list, and assign them a domain_id based on heuristic. 
--This is a crude catch for those circumstances if the SNOMED hierarchy as changed and the peak list is no longer complete
--The result should say "0 rows inserted"
INSERT INTO peak -- before doing that check first out without the insert
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
FROM snomed_ancestor a,
	concept_stage c
WHERE c.concept_code::BIGINT = a.ancestor_concept_code
	AND a.ancestor_concept_code NOT IN (
		SELECT DISTINCT -- find those where ancestors are not also a descendant, i.e. a top of a tree
			descendant_concept_code
		FROM snomed_ancestor
		)
	AND a.ancestor_concept_code NOT IN (
		SELECT peak_code
		FROM peak
		) -- but exclude those we already have
	AND c.vocabulary_id = 'SNOMED';

--18.5. Build domains, preassign all them with "Not assigned"
DROP TABLE IF EXISTS domain_snomed;
CREATE UNLOGGED TABLE domain_snomed AS
SELECT concept_code::BIGINT,
	CAST('Not assigned' AS VARCHAR(20)) AS domain_id
FROM concept_stage
WHERE vocabulary_id = 'SNOMED';

--19. Pass out domain_ids
--Method 1: Assign domains to children of peak concepts in the order rank, and within rank by order of precedence
--Do that for all peaks by order of ranks. The highest first, the lower ones second, etc.
DO $_$
DECLARE
A INT;
BEGIN
	FOR A IN (  SELECT DISTINCT ranked
				 FROM peak
			 ORDER BY ranked)
	LOOP
		UPDATE domain_snomed d
		SET domain_id = child.peak_domain_id
		FROM (
			SELECT DISTINCT
				-- if there are two conflicting domains in the rank (both equally distant from the ancestor) then use precedence
				FIRST_VALUE(p.peak_domain_id) OVER (
					PARTITION BY sa.descendant_concept_code ORDER BY CASE peak_domain_id
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
							END -- everything else is Observation
					) AS peak_domain_id,
				sa.descendant_concept_code AS concept_code
			FROM peak p,
				snomed_ancestor sa
			WHERE sa.ancestor_concept_code = p.peak_code
				AND p.ranked = A
			) child
		WHERE child.concept_code = d.concept_code;
	END LOOP;
END $_$;

--Assign domains of peaks themselves (snomed_ancestor doesn't include self-descendants)
UPDATE domain_snomed d
SET domain_id = i.peak_domain_id
FROM (
	SELECT peak_code,
		peak_domain_id
	FROM peak
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

--19.1. Update concept_stage from newly created domains.
UPDATE concept_stage c
SET domain_id = i.domain_id
FROM (
	SELECT d.domain_id,
		d.concept_code
	FROM domain_snomed d
	) i
WHERE c.vocabulary_id = 'SNOMED'
	AND i.concept_code = c.concept_code::BIGINT;

--19.2. Make manual changes according to rules
--Manual correction
UPDATE concept_stage
SET domain_id = 'Measurement'
WHERE concept_code IN (
		'839501000000106', --Nelfinavir measurement
		'839511000000108', --Ritonavir measurement
		'839571000000103', --Saquinavir measurement
		'839601000000105', --Tipranavir measurement
		'30058000', --Therapeutic drug monitoring assay
		'839381000000107', --Darunavir measurement
		'839421000000103', --Indinavir measurement
		'839451000000108', --Lopinavir measurement
		'222481000000103', --Valaciclovir measurement
		'840721000000103', --Nevirapine measurement
		'791931000000104', --Efavirenz measurement
		'77667008', --Therapeutic drug monitoring, qualitative
		'68555003', --Therapeutic drug monitoring, quantitative
		'200311000000109', --Oxcarbazepine level
		'194251000000108', --Bisacodyl level
		'194521000000101',	--2-ethylidene-1,5-dimethyl-3,3-diphenylpyrrolidine measurement
		'839251000000109',	--Abacavir measurement
		'840761000000106',	--Adefovir dipivoxil measurement
		'88884005',	--Alpha-1-antitrypsin phenotyping
		'840811000000104',	--Asunaprevir measurement
		'791951000000106',	--Atazanavir measurement
		'194261000000106',	--Bisacodyl metabolite measurement
		'840871000000109',	--Boceprevir measurement
		'838901000000107',	--Cidofovir measurement
		'788101000000102',	--Citalopram measurement
		'840801000000101',	--Daclatasvir measurement
		'194481000000101',	--Desmethyldothiepin measurement
		'839261000000107',	--Didanosine measurement
		'781401000000100',	--Dihydrocodeine screen
		'839271000000100',	--Emtricitabine measurement
		'840731000000101',	--Enfuvirtide measurement
		'840771000000104',	--Entecavir measurement
		'816911000000102',	--Etravirine measurement
		'838751000000106',	--Famciclovir measurement
		'839411000000109',	--Fosamprenavir measurement
		'838831000000105',	--Foscarnet sodium measurement
		'838781000000100',	--Inosine pranobex measurement
		'839281000000103',	--Lamivudine measurement
		'194701000000102',	--Levetiracetam measurement
		'840741000000105',	--Maraviroc measurement
		'194951000000104',	--Moclobemide measurement
		'377561000000103',	--Oral fluid 6-monoacetylmorphine measurement
		'377681000000108',	--Oral fluid 7-aminonitrazepam measurement
		'377711000000107',	--Oral fluid benzoylecgonine measurement
		'816211000000108',	--Oral fluid cannabis measurement
		'377741000000108',	--Oral fluid codeine measurement
		'377801000000104',	--Oral fluid diazepam measurement
		'377771000000102',	--Oral fluid dihydrocodeine measurement
		'377831000000105',	--Oral fluid nitrazepam measurement
		'377861000000100',	--Oral fluid nordiazepam measurement
		'377891000000106',	--Oral fluid temazepam measurement
		'838871000000107',	--Oseltamivir measurement
		'195031000000106',	--Perhexiline measurement
		'912521000000105',	--Plasma rivaroxaban measurement
		'840751000000108',	--Raltegravir measurement
		'840861000000102',	--Ribavirin measurement
		'792051000000104',	--Screening test for diuretic drug
		'900061000000109',	--Serum darunavir concentration measurement
		'900181000000101',	--Serum efavirenz concentration measurement
		'901781000000106',	--Serum indinavir concentration measurement
		'901911000000102',	--Serum lopinavir concentration measurement
		'901991000000106',	--Serum nelfinavir concentration measurement
		'902031000000103',	--Serum nevirapine concentration measurement
		'902091000000102',	--Serum oxcarbazepine concentration measurement
		'958101000000104',	--Serum pentobarbital concentration measurement
		'902381000000102',	--Serum posaconazole concentration measurement
		'902621000000108',	--Serum ritonavir concentration measurement
		'911041000000103',	--Serum saquinavir measurement
		'902721000000102',	--Serum tipranavir concentration measurement
		'910941000000105',	--Serum valaciclovir measurement
		'902861000000101',	--Serum voriconazole concentration measurement
		'902901000000108',	--Serum zopiclone concentration measurement
		'839301000000102',	--Stavudine measurement
		'840821000000105',	--Telaprevir measurement
		'840781000000102',	--Telbivudine measurement
		'839321000000106',	--Tenofovir disoproxil measurement
		'783131000000103',	--Thioguanine measurement
		'792061000000101',	--Tricyclic drug screening test
		'903351000000103',	--Urine amphetamine concentration measurement
		'957851000000106',	--Urine sulphonylurea screening test
		'910891000000106',	--Whole blood everolimus concentration measurement
		'838881000000109',	--Zanamivir measurement
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

--20. Set standard_concept based on validity and domain_id
UPDATE concept_stage
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
			THEN NULL -- got CMS and ABMS specialty
		WHEN 'Place of Service'
			THEN NULL -- got own place of service
		WHEN 'Type Concept'
			THEN NULL -- Type Concept in own OMOP vocabulary
		WHEN 'Unit'
			THEN NULL -- Units are UCUM
		ELSE 'S'
		END
WHERE invalid_reason is null and --if the concept has outside mapping from manual table, do not update it's Standard status
	not exists
		(
			select 1
			from concept_relationship_stage
			where
				invalid_reason is null and
				(concept_code_1,vocabulary_id_1) != (concept_code_2,vocabulary_id_2) and
				concept_code_1 = concept_code and
				relationship_id = 'Maps to'
		)
;

--20.1 De-standardize navigational concepts
UPDATE concept_stage
SET standard_concept = NULL
WHERE vocabulary_id = 'SNOMED'
	AND concept_code IN (
		SELECT descendant_concept_code::TEXT
		FROM snomed_ancestor
		WHERE ancestor_concept_code = 363743006 -- Navigational Concept
		);


--20.2. Make those Obsolete routes non-standard
UPDATE concept_stage
SET standard_concept = NULL
WHERE concept_name LIKE 'Obsolete%'
	AND domain_id = 'Route';

--20.3. Make concepts non standard if they have a 'Maps to' relationship
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

--21. Insert new synonyms from manual source
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)
VALUES ('1240461000000109','SNOMED','Measurement of SARS-CoV-2 antibody',4180186),
	('1240531000000103','SNOMED','Myocarditis due to COVID-19',4180186),
	('1240521000000100','SNOMED','Otitis media caused by 2019 novel coronavirus',4180186),
	('1240571000000101','SNOMED','Gastroenteritis caused by 2019 novel coronavirus',4180186),
	('1240551000000105','SNOMED','Pneumonia due to COVID-19',4180186),
	('1240541000000107','SNOMED','Infection of upper respiratory tract caused by 2019 novel coronavirus',4180186),
	('1240541000000107','SNOMED','Infection of upper respiratory tract due to COVID-19',4180186),
	('1240441000000108','SNOMED','Close exposure to 2019 novel coronavirus infection',4180186),
	('1240491000000103','SNOMED','2019 novel coronavirus vaccination',4180186),
	('1240751000000100','SNOMED','Disease caused by 2019 novel coronavirus',4180186),
	('1240401000000105','SNOMED','Antibody to 2019 novel coronavirus',4180186),
	('1240561000000108','SNOMED','Encephalopathy caused by 2019 novel coronavirus',4180186),
	('1240461000000109','SNOMED','Measurement of 2019 novel coronavirus antibody',4180186),
	('1240531000000103','SNOMED','Myocarditis caused by 2019 novel coronavirus',4180186),
	('1240511000000106','SNOMED','Detection of SARS-CoV-2 using polymerase chain reaction technique',4180186),
	('1240471000000102','SNOMED','Measurement of 2019 novel coronavirus antigen',4180186),
	('1240511000000106','SNOMED','Detection of 2019 novel coronavirus using polymerase chain reaction technique',4180186),
	('1240551000000105','SNOMED','Pneumonia caused by 2019 novel coronavirus',4180186),
	('1240571000000101','SNOMED','Gastroenteritis due to COVID-19',4180186),
	('1240431000000104','SNOMED','Exposure to 2019 novel coronavirus infection',4180186),
	('1240381000000105','SNOMED','2019 novel coronavirus',4180186),
	('840544004','SNOMED','Suspected disease caused by severe acute respiratory coronavirus 2',4180186),
	('1240581000000104','SNOMED','2019 novel coronavirus detected',4180186),
	('1240581000000104','SNOMED','SARS-CoV-2 detected',4180186),
	('1240561000000108','SNOMED','Encephalopathy due to COVID-19',4180186),
	('1240761000000102','SNOMED','Suspected disease caused by 2019 novel coronavirus',4180186),
	('1240391000000107','SNOMED','Antigen of 2019 novel coronavirus',4180186),
	('1240591000000102','SNOMED','2019 novel coronavirus not detected',4180186),
	('1240591000000102','SNOMED','SARS-CoV-2 not detected',4180186),
	('1240441000000108','SNOMED','Close exposure to SARS-CoV-2',4180186),
	('1240521000000100','SNOMED','Otitis media due to COVID-19',4180186),
	('1240471000000102','SNOMED','Measurement of SARS-CoV-2 antigen',4180186);

--22. Clean up
DROP TABLE peak;
DROP TABLE domain_snomed;
DROP TABLE snomed_ancestor;
DROP VIEW module_date;

--23. Need to check domains before runnig the generic_update
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