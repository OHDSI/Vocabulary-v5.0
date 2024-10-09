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
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'SNOMED Veterinary',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.vet_sct2_concept_full LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.vet_sct2_concept_full LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_VETERINARY'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Create core version of SNOMED Veterinary
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT TRIM(regexp_replace(sct2.concept_name, ' (\([^)]*\))$', '')), -- pick the umls one first (if there) and trim something like "(procedure)"
	'SNOMED Veterinary' AS vocabulary_id,
	sct2.concept_code,
	sct2.valid_start_date,
	CASE 
		WHEN sct2.active = 1
			THEN TO_DATE('20991231', 'yyyymmdd')
		ELSE sct2.valid_end_date
		END AS valid_end_date,
	CASE 
		WHEN sct2.active = 1
			THEN NULL
		ELSE 'D'
		END AS invalid_reason
FROM (
	SELECT SUBSTR(d.term, 1, 255) AS concept_name,
		d.conceptid AS concept_code,
		c.active,
		ROW_NUMBER() OVER (
			PARTITION BY d.conceptid
			-- Order of preference: newest in sct2_concept, in sct2_desc, synonym, does not contain class in parenthesis
			ORDER BY c.effectivetime DESC,
				d.effectivetime DESC,
				CASE 
					WHEN typeid = '900000000000013009'
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
			) AS rn,
		MIN(c.effectivetime::DATE) OVER (PARTITION BY d.conceptid) AS valid_start_date,
		d.effectivetime AS valid_end_date
	FROM sources.vet_sct2_concept_full c,
		sources.vet_sct2_desc_full d
	WHERE c.id = d.conceptid
	    AND d.languagecode = 'en'
		AND term IS NOT NULL
	) sct2
WHERE sct2.rn = 1
	--AND sct2.active = 1
	--exclude core SNOMED concepts
	AND NOT EXISTS (
		SELECT 1
		FROM concept c
		WHERE c.concept_code = sct2.concept_code
			AND c.vocabulary_id = 'SNOMED'
		);

--4. Update concept_class_id from extracted class information and terms ordered by some good precedence
UPDATE concept_stage cs
SET concept_class_id = i.concept_class_id
FROM (
	WITH tmp_concept_class AS (
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
								WHEN 'body structure'
									THEN 6
								WHEN 'cell'
									THEN 7
								WHEN 'cell structure'
									THEN 8
								WHEN 'organism'
									THEN 9
								WHEN 'physical object'
									THEN 10
								WHEN 'social concept'
									THEN 11
								WHEN 'event'
									THEN 12
								WHEN 'product'
									THEN 13
								WHEN 'substance'
									THEN 14
								WHEN 'specimen'
									THEN 15
								WHEN 'observable entity'
									THEN 16
								WHEN 'morphologic abnormality'
									THEN 17
								WHEN 'foundation metadata concept'
									THEN 18
								WHEN 'core metadata concept'
									THEN 19
								WHEN 'metadata'
									THEN 20
								WHEN 'environment'
									THEN 21
								WHEN 'attribute'
									THEN 22
								WHEN 'navigational concept'
									THEN 23
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
						rna AS rnb -- row number in vet_sct2_desc_full
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
								) rna -- row number in vet_sct2_desc_full
						FROM concept_stage c
						JOIN sources.vet_sct2_desc_full d ON d.conceptid = c.concept_code
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
			WHEN F7 IN (
					'organism',
					'Ac chicken breed',
					'oranism'
					)
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
			WHEN F7 = 'attribute'
				THEN 'Attribute'
			WHEN F7 = 'cell'
				THEN 'Body Structure'
			WHEN F7 = 'cell structure'
				THEN 'Body Structure'
			WHEN F7 = 'foundation metadata concept'
				THEN 'Model Comp'
			WHEN F7 = 'social concept'
				THEN 'Social Context'
			WHEN F7 = 'core metadata concept'
				THEN 'Model Comp'
			WHEN F7 = 'metadata'
				THEN 'Model Comp'
			WHEN F7 = 'navigational concept'
				THEN 'Navi Concept'
			WHEN F7 = 'animal life circumstance'
				THEN 'Life circumstance'
			ELSE 'Undefined'
			END AS concept_class_id
	FROM tmp_concept_class
	) i
WHERE i.concept_code = cs.concept_code;

-- 5. Add attribute relationships:
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
WITH tmp_rel AS (
		-- get relationships from latest records that are active
		SELECT sourceid,
			destinationid,
			REPLACE(term, ' (attribute)', '') term
		FROM (
			SELECT r.sourceid,
				r.destinationid,
				d.term,
				ROW_NUMBER() OVER (
					PARTITION BY r.id ORDER BY r.effectivetime DESC,
						d.id DESC
					) AS rn, -- get the latest in a sequence of relationships, to decide wether it is still active
				r.active
			FROM (
				/*SELECT *
				FROM sources.sct2_rela_full_merged --use the SNOMED sources as well for 'Is a' relationships

				UNION*/ --use descriptions from SNOMED, but only for Veterinarians relationships

				SELECT *
				FROM sources.vet_sct2_rela_full
				) r
			JOIN (
				SELECT conceptid::VARCHAR,term,id::VARCHAR
				FROM sources.sct2_desc_full_merged --use the SNOMED sources as well for 'Is a' relationships

				UNION

				SELECT conceptid,term,id
				FROM sources.vet_sct2_desc_full
				) d ON r.typeid = d.conceptid
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
	valid_end_date
FROM (
	--convert SNOMED to OMOP-type relationship_id
	SELECT DISTINCT sourceid AS concept_code_1,
		destinationid AS concept_code_2,
		COALESCE(c1.vocabulary_id, 'SNOMED Veterinary') AS vocabulary_id_1,
		COALESCE(c2.vocabulary_id, 'SNOMED Veterinary') AS vocabulary_id_2,
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
			WHEN term IN (
					'Clinical course',
					'Course'
					)
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
				THEN 'Has part of'
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
			WHEN term = 'Has physiologic state'
				THEN 'Has physiol state'
			WHEN term = 'Includes sub-specimen'
				THEN 'Has sub-specimen'
			WHEN term = 'Has life circumstance'
				THEN 'Has life circumstan'
			ELSE term --'non-existing'
			END AS relationship_id,
		(
			SELECT latest_update
			FROM vocabulary
			WHERE vocabulary_id = 'SNOMED Veterinary'
			) AS valid_start_date,
		TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
	FROM tmp_rel
	--we don't know about concepts in relationships to set the proper vocabulary_id, so we need to check SNOMED vocabulary
	LEFT JOIN concept c1 ON c1.concept_code = sourceid
		AND c1.vocabulary_id = 'SNOMED'
	LEFT JOIN concept c2 ON c2.concept_code = destinationid
		AND c2.vocabulary_id = 'SNOMED'
	) sn
WHERE NOT (
		sn.vocabulary_id_1 = 'SNOMED'
		AND sn.vocabulary_id_2 = 'SNOMED'
		AND sn.relationship_id <> 'Is a'
		);--we need SNOMED 'Is a' SNOMED for snomed_ancestor, other relationships between SNOMED and SNOMED we don't want

--check for non-existing relationships
ALTER TABLE concept_relationship_stage ADD CONSTRAINT tmp_constraint_relid FOREIGN KEY (relationship_id) REFERENCES relationship (relationship_id);
ALTER TABLE concept_relationship_stage DROP CONSTRAINT tmp_constraint_relid;
--SELECT relationship_id FROM concept_relationship_stage EXCEPT SELECT relationship_id FROM relationship;

--6. Add replacement relationships. They are handled in a different SNOMED Veterinary table
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT *
FROM (
	SELECT DISTINCT sn.concept_code_1,
		sn.concept_code_2,
		COALESCE(c1.vocabulary_id, 'SNOMED Veterinary') AS vocabulary_id_1,
		COALESCE(c2.vocabulary_id, 'SNOMED Veterinary') AS vocabulary_id_2,
		sn.relationship_id,
		(
			SELECT latest_update
			FROM vocabulary
			WHERE vocabulary_id = 'SNOMED Veterinary'
			),
		TO_DATE('20991231', 'yyyymmdd')
	FROM (
		SELECT sc.referencedcomponentid AS concept_code_1,
			sc.targetcomponent AS concept_code_2,
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
			ROW_NUMBER() OVER (
				PARTITION BY sc.referencedcomponentid ORDER BY sc.effectivetime DESC,
					sc.id DESC
				) rn,
			active
		FROM sources.vet_der2_crefset_assreffull sc
		WHERE sc.refsetid IN (
				'900000000000526001',
				'900000000000523009',
				'900000000000528000',
				'900000000000527005',
				'900000000000530003'
				)
		) sn
	--we don't know about concepts in relationships to set the proper vocabulary_id, so we need to check SNOMED vocabulary
	LEFT JOIN concept c1 ON c1.concept_code = sn.concept_code_1
		AND c1.vocabulary_id = 'SNOMED'
	LEFT JOIN concept c2 ON c2.concept_code = sn.concept_code_2
		AND c2.vocabulary_id = 'SNOMED'
	WHERE sn.rn = 1
		AND sn.active = 1
	) s0
WHERE vocabulary_id_1 <> 'SNOMED';--remove mappings if vocabulary_id_1 is SNOMED

--7. Sometimes concept are back from U to fresh, we need to deprecate our replacement mappings
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
	AND c1.invalid_reason = 'U'
	AND cs.vocabulary_id = 'SNOMED Veterinary'
	AND crs.concept_code_1 IS NULL;

--8. Same as above, but for 'Maps to' (we need to add the manual deprecation for proper work of the VOCABULARY_PACK.AddFreshMAPSTO)
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

--9. Delete records that does not exists in the concept and concept_stage
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

--10. Set 'U' for updated concepts
UPDATE concept_stage cs
SET invalid_reason = 'U',
	standard_concept = NULL,
	valid_end_date = CASE 
		WHEN cs.invalid_reason IS NULL
			THEN (
					SELECT latest_update - 1
					FROM vocabulary
					WHERE vocabulary_id = 'SNOMED Veterinary'
					)
		ELSE cs.valid_end_date
		END
FROM concept_relationship_stage crs
WHERE crs.concept_code_1 = cs.concept_code
	AND crs.vocabulary_id_1 = cs.vocabulary_id
	AND crs.relationship_id IN (
		'Concept replaced by',
		'Concept same_as to',
		'Concept alt_to to',
		'Concept poss_eq to',
		'Concept was_a to'
		)
	AND crs.invalid_reason IS NULL;

--11. Working with replacement mappings
ANALYZE concept_stage;
ANALYZE concept_relationship_stage;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--12. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--13. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--14. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--15. Start building the hierarchy for progagating domain_ids from toop to bottom
DROP TABLE IF EXISTS snomed_ancestor;
CREATE UNLOGGED TABLE snomed_ancestor AS (
	WITH recursive hierarchy_concepts(ancestor_concept_code, descendant_concept_code, root_ancestor_concept_code, full_path) AS (
		SELECT ancestor_concept_code,
			descendant_concept_code,
			ancestor_concept_code AS root_ancestor_concept_code,
			ARRAY [descendant_concept_code::TEXT] AS full_path
		FROM concepts
		
		UNION ALL
		
		SELECT c.ancestor_concept_code,
			c.descendant_concept_code,
			root_ancestor_concept_code,
			hc.full_path || c.descendant_concept_code::TEXT AS full_path
		FROM concepts c
		JOIN hierarchy_concepts hc ON hc.descendant_concept_code = c.ancestor_concept_code
		WHERE c.descendant_concept_code <> ALL (full_path)
		),
	concepts AS (
		SELECT crs.concept_code_2 AS ancestor_concept_code,
			crs.concept_code_1 AS descendant_concept_code
		FROM concept_relationship_stage crs
		WHERE crs.invalid_reason IS NULL
			AND crs.relationship_id = 'Is a'
		)
	SELECT DISTINCT hc.root_ancestor_concept_code AS ancestor_concept_code, hc.descendant_concept_code
	FROM hierarchy_concepts hc
);

ALTER TABLE snomed_ancestor ADD CONSTRAINT xpksnomed_ancestor PRIMARY KEY (ancestor_concept_code,descendant_concept_code);

ANALYZE snomed_ancestor;

--16. Create domain_id
--16.1. Manually create table with "Peaks" = ancestors of records that are all of the same domain
DROP TABLE IF EXISTS peak;
CREATE UNLOGGED TABLE peak (
	peak_code VARCHAR(100), --the id of the top ancestor
	peak_domain_id VARCHAR(20), -- the domain to assign to all its children
	ranked INTEGER -- number for the order in which to assign
	);

--16.2 Fill in the various peak concepts
INSERT INTO peak
VALUES ('138875005', 'Metadata'), -- root
	('900000000000441003', 'Metadata'), -- SNOMED CT Model Component
	('105590001', 'Observation'), -- Substances
	('123038009', 'Specimen'), -- Specimen
	('48176007', 'Observation'), -- Social context
	('243796009', 'Observation'), -- Situation with explicit context
	('272379006', 'Observation'), -- Events
	('260787004', 'Observation'), -- Physical object
	('362981000', 'Observation'), -- Qualifier value
	('363787002', 'Observation'), -- Observable entity
	('410607006', 'Observation'), -- Organism
	('419891008', 'Type Concept'), -- Record artifact
	('78621006', 'Observation'), -- Physical force
	('123037004', 'Spec Anatomic Site'), -- Body structure
	('118956008', 'Observation'), -- Body structure, altered from its original anatomical structure, reverted from 123037004
	('254291000', 'Measurement'), -- Staging / Scales [changed Observation->Measurement AVOF-1295]
	('370115009', 'Metadata'), -- Special Concept
	('308916002', 'Observation'), -- Environment or geographical location
	('223366009', 'Provider'),
	('43741000', 'Visit'), -- Site of care
	('420056007', 'Drug'), -- Aromatherapy agent
	('373873005', 'Drug'), -- Pharmaceutical / biologic product
	('410942007', 'Drug'), -- Drug or medicament
	('385285004', 'Drug'), -- dialysis dosage form
	('421967003', 'Drug'), -- drug dose form
	('424387007', 'Drug'), -- dose form by site prepared for 
	('421563008', 'Drug'), -- complementary medicine dose form
	('284009009', 'Route'), -- Route of administration value
	('373783004', 'Observation'), -- dietary product, exception of Pharmaceutical / biologic product
	('419572002', 'Observation'), -- alcohol agent, exception of drug
	('373782009', 'Device'), -- diagnostic substance, exception of drug
	('2949005', 'Observation'), -- diagnostic aid (exclusion from drugs)
	('404684003', 'Condition'), -- Clinical Finding
	('62014003', 'Observation'), -- Adverse reaction to drug
	('313413008', 'Condition'), -- Calculus observation
	('405533003', 'Observation'), -- Adverse incident outcome categories
	('365854008', 'Observation'), -- History finding
	('118233009', 'Observation'), -- Finding of activity of daily living
	('307824009', 'Observation'), -- Administrative statuses
	('162408000', 'Observation'), -- Symptom description
	('105729006', 'Observation'), -- Health perception, health management pattern
	('162566001', 'Observation'), --Patient not aware of diagnosis
	('122869004', 'Measurement'), --Measurement
	('71388002', 'Procedure'), -- Procedure
	('304252001', 'Observation'), -- Resuscitate
	('304253006', 'Observation'), -- DNR
	('113021009', 'Procedure'), -- Cardiovascular measurement
	('297249002', 'Observation'), -- Family history of procedure
	('14734007', 'Observation'), -- Administrative procedure
	('416940007', 'Observation'), -- Past history of procedure
	('183932001', 'Observation'), -- Procedure contraindicated
	('438833006', 'Observation'), -- Administration of drug or medicament contraindicated
	('410684002', 'Observation'), -- Drug therapy status
	('17636008', 'Procedure'), -- Specimen collection treatments and procedures - - bad child of 4028908 Laboratory procedure
	('365873007', 'Gender'), -- Gender
	('372148003', 'Race'), --Ethnic group
	('415229000', 'Race'), -- Racial group
	('106237007', 'Observation'), -- Linkage concept
	('767524001', 'Unit'), --  Unit of measure (Top unit)
	('260245000', 'Meas Value'), -- Meas Value
	('125677006', 'Relationship'), -- Relationship
	('264301008', 'Observation'), -- Psychoactive substance of abuse - non-pharmaceutical
	('226465004', 'Observation'), -- Drinks
	('49062001', 'Device'), -- Device
	('289964002', 'Device'), -- Surgical material
	('260667007', 'Device'), -- Graft
	('418920007', 'Device'), -- Adhesive agent
	('255922001', 'Device'), -- Dental material
	('413674002', 'Observation'), -- Body material
	('118417008', 'Device'), -- Filling material
	('445214009', 'Device'), -- corneal storage medium
	('69449002', 'Observation'), -- Drug action
	('79899007', 'Observation'), -- Drug interaction
	('365858006', 'Observation'), -- Prognosis/outlook finding
	('444332001', 'Observation'), -- Aware of prognosis
	('444143004', 'Observation'), -- Carries emergency treatment
	('13197004', 'Observation'), -- Contraception
	('251859005', 'Observation'), -- Dialysis finding
	('422704000', 'Observation'), -- Difficulty obtaining contraception
	('250869005', 'Observation'), -- Equipment finding
	('217315002', 'Observation'), -- Onset of illness
	('127362006', 'Observation'), -- Previous pregnancies
	('162511002', 'Observation'), -- Rare history finding
	('118226009', 'Observation'),	-- Temporal finding
	('366154003', 'Observation'), -- Respiratory flow rate - finding
	('243826008', 'Observation'), -- Antenatal care status 
	('418038007', 'Observation'), --Propensity to adverse reactions to substance
	('413296003', 'Condition'), -- Depression requiring intervention
	('72670004', 'Condition'), -- Sign
	('124083000', 'Condition'), -- Urobilinogenemia
	('59524001', 'Observation'), -- Blood bank procedure
	('389067005', 'Observation'), -- Community health procedure
	('225288009', 'Observation'), -- Environmental care procedure
	('308335008', 'Observation'), -- Patient encounter procedure
	('389084004', 'Observation'), -- Staff related procedure
	('110461004', 'Observation'), -- Adjunctive care
	('372038002', 'Observation'), -- Advocacy
	('225365006', 'Observation'), -- Care regime
	('228114008', 'Observation'), -- Child health procedures
	('309466006', 'Observation'), -- Clinical observation regime
	('225318000', 'Observation'), -- Personal and environmental management regime
	('133877004', 'Observation'), -- Therapeutic regimen
	('225367003', 'Observation'), -- Toileting regime
	('303163003', 'Observation'), -- Treatments administered under the provisions of the law
	('429159005', 'Procedure'), -- Child psychotherapy
	('15220000', 'Measurement'), -- Laboratory test
	('441742003', 'Condition'), -- Evaluation finding
	('365605003', 'Observation'), -- Body measurement finding
	('106019003', 'Condition'), -- Elimination pattern
	('106146005', 'Condition'), -- Reflex finding
	('103020000', 'Condition'), -- Adrenarche
	('405729008', 'Condition'), -- Hematochezia
	('165816005', 'Condition'), -- HIV positive
	('300391003', 'Condition'), -- Finding of appearance of stool
	('300393000', 'Condition'), -- Finding of odor of stool
	('239516002', 'Observation'), -- Monitoring procedure
	('243114000', 'Observation'), -- Support
	('300893006', 'Observation'), -- Nutritional finding
	('116336009', 'Observation'), -- Eating / feeding / drinking finding
	('448717002', 'Condition'), -- Decline in Edinburgh postnatal depression scale score
	('449413009', 'Condition'), -- Decline in Edinburgh postnatal depression scale score at 8 months
	('118227000', 'Condition'), -- Vital signs finding
	('363259005', 'Observation'), -- Patient management procedure
	('278414003', 'Procedure'), -- Pain management
	-- Added Jan 2017
	('225831004', 'Observation'), -- Finding relating to advocacy
	('134436002', 'Observation'), -- Lifestyle
	('365980008', 'Observation'), -- Tobacco use and exposure - finding
	('386091000', 'Observation'), -- Finding related to compliance with treatment
	('424092004', 'Observation'), -- Questionable explanation of injury
	('364721000000101', 'Measurement'), -- DFT: dynamic function test
	('749211000000106', 'Observation'), -- NHS Sickle Cell and Thalassaemia Screening Programme family origin
	('91291000000109', 'Observation'), -- Health of the Nation Outcome Scale interpretation
	('900781000000102', 'Observation'), -- Noncompliance with dietetic intervention
	('784891000000108', 'Observation'), -- Injury inconsistent with history given
	('863811000000102', 'Observation'), -- Injury within last 48 hours
	('920911000000100', 'Observation'), -- Appropriate use of accident and emergency service
	('927031000000106', 'Observation'), -- Inappropriate use of walk-in centre
	('927041000000102', 'Observation'), -- Inappropriate use of accident and emergency service
	('927901000000101', 'Observation'), -- Inappropriate triage decision
	('927921000000105', 'Observation'), -- Appropriate triage decision
	('921071000000100', 'Observation'), -- Appropriate use of walk-in centre
	('962871000000107', 'Observation'), -- Aware of overall cardiovascular disease risk
	('968521000000109', 'Observation'), -- Inappropriate use of general practitioner service
	--added 8/25/2017, these concepts should be in Observation, so people can put causative agent into 
	('282100009', 'Observation'), -- Adverse reaction caused by substance
	('473010000', 'Condition'), -- Hypersensitivity condition
	('419199007', 'Observation'), -- Allergy to substance
	('10628711000119101', 'Condition'), -- Allergic contact dermatitis caused by plant (this is only one child of 419199007 Allergy to substance that has exact condition mentioned
	--added 8/30/2017
	('310611001', 'Measurement'), -- Cardiovascular measure
	('424122007', 'Observation'), -- ECOG performance status finding
	('698289004', 'Observation'), -- Hooka whatever Observation  -- http://forums.ohdsi.org/t/hookah-concept/3515
	('248627000', 'Measurement'), -- Pulse characteristics
	--added 20171128 (AVOF-731)
	('410652009', 'Device'), -- Blood product
	--added 20180208
	('105904009', 'Drug'), -- Type of drug preparation
	--Azaribine, Pegaptanib sodium, Cutaneous aerosol, Pegaptanib, etc. - exclusion without nice hierarchy
	('373447009', 'Drug'),
	('416058004', 'Drug'),
	('387111009', 'Drug'),
	('423490007', 'Drug'),
	('1536005', 'Drug'),
	('386925003', 'Drug'),
	('126154004', 'Drug'),
	('421347001', 'Drug'),
	('61483006', 'Drug'),
	('373749006', 'Drug'),
	--added 20180820
	('709080004', 'Observation'),
	--added 20181005
	('414916001', 'Condition'), -- Obesity
	--added 20181106 [AVOF-1295]
	('125123008', 'Measurement'), -- Organ Weight
	('125125001', 'Observation'), --Abnormal organ weight
	('125124002', 'Observation'),-- Normal organ weight
	('268444004', 'Measurement'), -- Radionuclide red cell mass measurement
	('251880004', 'Measurement'), -- Respiratory measure
	('26291000009107','Observation'); -- Animal life circumstance

--16.3. Ancestors inherit the domain_id and standard_concept of their Peaks. However, the ancestors of Peaks are overlapping.
--Therefore, the order by which the inheritance is passed depends on the "height" in the hierarchy: The lower the peak, the later it should be run
--The following creates the right order by counting the number of ancestors: The more ancestors the lower in the hierarchy.
--This could cause trouble if a parallel fork happens at the same height
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

-- For those that have no ancestors, the rank is 1
UPDATE peak SET ranked = 1 WHERE ranked IS NULL;

--16.4. Find other peak concepts (orphans) that are missed from the above manual list, and assign them a domain_id based on heuristic.
--This is a crude catch for those circumstances if the SNOMED hierarchy as changed and the peak list is no longer complete
--The result should say "0 rows inserted"
INSERT INTO peak -- before doing that check first out without the insert
SELECT DISTINCT c.concept_code AS peak_code,
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
WHERE c.concept_code = a.ancestor_concept_code
	AND a.ancestor_concept_code NOT IN (
		SELECT -- find those where ancestors are not also a descendant, i.e. a top of a tree
			descendant_concept_code
		FROM snomed_ancestor
		)
	AND a.ancestor_concept_code NOT IN (
		SELECT peak_code
		FROM peak
		); -- but exclude those we already have

--16.5. Build domains, preassign all them with "Not assigned"
DROP TABLE IF EXISTS domain_snomed;
CREATE UNLOGGED TABLE domain_snomed AS
SELECT concept_code,
	CAST('Not assigned' AS VARCHAR(20)) AS domain_id
FROM concept_stage;

--Pass out domain_ids
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
							WHEN 'Measurement'
								THEN 1
							WHEN 'Procedure'
								THEN 2
							WHEN 'Device'
								THEN 3
							WHEN 'Condition'
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
FROM peak i
WHERE i.peak_code = d.concept_code;

--Method 2: For those that slipped through the cracks assign domains by using the class_concept_id
--This is a crude method, and Method 1 should be revised to cover all concepts.
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
		c.concept_code
	FROM concept_stage c
	) i
WHERE d.domain_id = 'Not assigned'
	AND i.concept_code = d.concept_code;

--16.6. Update concept_stage from newly created domains.
UPDATE concept_stage c
SET domain_id = i.domain_id
FROM domain_snomed i
WHERE i.concept_code = c.concept_code;

--Create Specimen Anatomical Site
UPDATE concept_stage
SET domain_id = 'Spec Anatomic Site'
WHERE concept_class_id = 'Body Structure';

--Create Specimen
UPDATE concept_stage
SET domain_id = 'Specimen'
WHERE concept_class_id = 'Specimen';

--Fix navigational concepts
UPDATE concept_stage cs
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
FROM snomed_ancestor sa
WHERE cs.concept_code = sa.descendant_concept_code
	AND sa.ancestor_concept_code = '363743006';-- Navigational Concept, contains all sorts of orphan codes

--16.7. Set standard_concept based on domain_id
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
			THEN NULL -- got own Provider domain
		WHEN 'Visit'
			THEN NULL -- got own Visit domain
		WHEN 'Type Concept'
			THEN NULL -- got own Type Concept domain
		WHEN 'Unit'
			THEN NULL -- Units are UCUM
		ELSE 'S'
		END
WHERE invalid_reason IS NULL;

--And de-standardize navigational concepts
UPDATE concept_stage cs
SET standard_concept = NULL
FROM snomed_ancestor sa
WHERE cs.concept_code = sa.descendant_concept_code
	AND sa.ancestor_concept_code = '363743006'; -- Navigational Concept

--17. Make those Obsolete routes non-standard
UPDATE concept_stage
SET standard_concept = NULL
WHERE concept_name LIKE 'Obsolete%'
	AND domain_id = 'Route';

--18. Delete mappings between concepts that are not represented at the "latest_update" at this moment (e.g. SNOMED <-> RxNorm, but currently we are updating SNOMED Veterinary)
--This is because we have SNOMED <-> SNOMED Veterinary in concept_relationship_stage, but AddFreshMAPSTO adds SNOMED <-> RxNorm from concept_relationship
DELETE
FROM concept_relationship_stage crs_o
WHERE (
		crs_o.concept_code_1,
		crs_o.vocabulary_id_1,
		crs_o.concept_code_2,
		crs_o.vocabulary_id_2
		) IN (
		SELECT crs.concept_code_1,
			crs.vocabulary_id_1,
			crs.concept_code_2,
			crs.vocabulary_id_2
		FROM concept_relationship_stage crs
		LEFT JOIN vocabulary v1 ON v1.vocabulary_id = crs.vocabulary_id_1
			AND v1.latest_update IS NOT NULL
		LEFT JOIN vocabulary v2 ON v2.vocabulary_id = crs.vocabulary_id_2
			AND v2.latest_update IS NOT NULL
		WHERE COALESCE(v1.latest_update, v2.latest_update) IS NULL
		);

--19. Clean up
DROP TABLE peak;
DROP TABLE domain_snomed;
DROP TABLE snomed_ancestor;

DO $_$
   BEGIN
       PERFORM devv5.GenericUpdate();
   END $_$;

DO $_$
	BEGIN
		PERFORM vocabulary_pack.pConceptAncestor();
	END $_$;
-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script