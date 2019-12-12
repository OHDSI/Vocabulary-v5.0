CREATE OR REPLACE FUNCTION devv5.genericupdate (
)
RETURNS void AS
$body$
BEGIN
	-- Prerequisites:
	-- Check stage tables for incorrect rows
	DO $_$
	BEGIN
		PERFORM QA_TESTS.Check_Stage_Tables();
	END $_$;

	-- Update concept_id in concept_stage from concept for existing concepts
	UPDATE concept_stage cs
		SET concept_id = c.concept_id
	FROM concept c
	WHERE cs.concept_code = c.concept_code
		AND cs.vocabulary_id = c.vocabulary_id;

	-- ANALYSING
	ANALYSE concept_stage;
	ANALYSE concept_relationship_stage;
	ANALYSE concept_synonym_stage;

	-- 1. Clearing

	-- 1.1 Clearing the concept_name
	--remove double spaces, carriage return, newline, vertical tab and form feed
	UPDATE concept_stage
	SET concept_name = REGEXP_REPLACE(concept_name, '[[:cntrl:]]+', ' ')
	WHERE concept_name ~ '[[:cntrl:]]';

	UPDATE concept_stage
	SET concept_name = REGEXP_REPLACE(concept_name, ' {2,}', ' ')
	WHERE concept_name ~ ' {2,}';

	--remove leading and trailing spaces
	UPDATE concept_stage
	SET concept_name = TRIM(concept_name)
	WHERE concept_name <> TRIM(concept_name)
		AND NOT (
			concept_name = ' '
			AND vocabulary_id = 'GPI'
			);--exclude GPI empty names

	--remove long dashes
	UPDATE concept_stage
	SET concept_name = REPLACE(concept_name, '–', '-')
	WHERE concept_name LIKE '%–%';

	-- 1.2 Clearing the synonym_name
	--remove double spaces, carriage return, newline, vertical tab and form feed
	UPDATE concept_synonym_stage
	SET synonym_name = REGEXP_REPLACE(synonym_name, '[[:cntrl:]]+', ' ')
	WHERE synonym_name ~ '[[:cntrl:]]';

	UPDATE concept_synonym_stage
	SET synonym_name = REGEXP_REPLACE(synonym_name, ' {2,}', ' ')
	WHERE synonym_name ~ ' {2,}';

	--remove leading and trailing spaces
	UPDATE concept_synonym_stage
	SET synonym_name = TRIM(synonym_name)
	WHERE synonym_name <> TRIM(synonym_name)
		AND NOT (
			synonym_name = ' '
			AND synonym_vocabulary_id = 'GPI'
			);--exclude GPI empty names

	--remove long dashes
	UPDATE concept_synonym_stage
	SET synonym_name = REPLACE(synonym_name, '–', '-')
	WHERE synonym_name LIKE '%–%';

	/***************************
	* Update the concept table *
	****************************/

	-- 2. Update existing concept details from concept_stage.
	-- All fields (concept_name, domain_id, concept_class_id, standard_concept, valid_start_date, valid_end_date, invalid_reason) are updated

	-- 2.1. For 'concept_name'
	UPDATE concept c
	SET concept_name = cs.concept_name
	FROM concept_stage cs
	WHERE c.concept_id = cs.concept_id
		AND c.concept_name <> cs.concept_name;

	-- 2.2. For 'domain_id'
	UPDATE concept c
	SET domain_id = cs.domain_id
	FROM concept_stage cs
	WHERE c.concept_id = cs.concept_id
		AND c.domain_id <> cs.domain_id;

	-- 2.3. For 'concept_class_id'
	UPDATE concept c
	SET concept_class_id = cs.concept_class_id
	FROM concept_stage cs
	WHERE c.concept_id = cs.concept_id
		AND c.concept_class_id <> cs.concept_class_id;

	-- 2.4. For 'standard_concept'
	UPDATE concept c
	SET standard_concept = cs.standard_concept
	FROM concept_stage cs
	WHERE c.concept_id = cs.concept_id
		AND COALESCE(c.standard_concept, 'X') <> COALESCE(cs.standard_concept, 'X');

	-- 2.5. For 'valid_start_date'
	UPDATE concept c
	SET valid_start_date = cs.valid_start_date
	FROM concept_stage cs,
		vocabulary v
	WHERE c.concept_id = cs.concept_id
		AND v.vocabulary_id = cs.vocabulary_id
		AND c.valid_start_date <> cs.valid_start_date
		AND cs.valid_start_date <> v.latest_update; -- if we have a real date in concept_stage, use it. If it is only the release date, use the existing

	-- 2.6. For 'valid_end_date'
	UPDATE concept c
	SET valid_end_date = cs.valid_end_date
	FROM concept_stage cs
	WHERE c.concept_id = cs.concept_id
		AND c.valid_end_date <> cs.valid_end_date;

	-- 2.7. For 'invalid_reason'
	UPDATE concept c
	SET invalid_reason = cs.invalid_reason
	FROM concept_stage cs
	WHERE c.concept_id = cs.concept_id
		AND COALESCE(c.invalid_reason, 'X') <> COALESCE(cs.invalid_reason, 'X');

	-- 3. Deprecate concepts missing from concept_stage and are not already deprecated.
	-- This only works for vocabularies where we expect a full set of active concepts in concept_stage.
	-- If the vocabulary only provides changed concepts, this should not be run, and the update information is already dealt with in step 1.
	-- 23-May-2018: new rule for CPT4, ICD9Proc and HCPCS: http://forums.ohdsi.org/t/proposal-to-keep-outdated-standard-concepts-active-and-standard/3695/22 and AVOF-981
	-- 3.1. Update the concept for non-CPT4, non-ICD9Proc and non-HCPCS vocabularies
	UPDATE concept c SET
		invalid_reason = 'D',
		valid_end_date = (SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = c.vocabulary_id)
	WHERE NOT EXISTS (SELECT 1 FROM concept_stage cs WHERE cs.concept_id = c.concept_id AND cs.vocabulary_id = c.vocabulary_id) -- if concept missing from concept_stage
	AND c.vocabulary_id IN (SELECT vocabulary_id FROM vocabulary WHERE latest_update IS NOT NULL) -- only for current vocabularies
	AND c.invalid_reason IS NULL -- not already deprecated
	AND CASE -- all vocabularies that give us a full list of active concepts at each release we can safely assume to deprecate missing ones (THEN 1)
		WHEN c.vocabulary_id = 'SNOMED' THEN 1
		WHEN c.vocabulary_id = 'LOINC' AND c.concept_class_id = 'LOINC Answers' THEN 1 -- Only LOINC answers are full lists
		WHEN c.vocabulary_id = 'LOINC' THEN 0 -- LOINC gives full account of all concepts
		WHEN c.vocabulary_id = 'ICD9CM' THEN 1
		WHEN c.vocabulary_id = 'ICD10' THEN 1
		WHEN c.vocabulary_id = 'RxNorm' THEN 1
		WHEN c.vocabulary_id = 'NDFRT' THEN 1
		WHEN c.vocabulary_id = 'VA Product' THEN 1
		WHEN c.vocabulary_id = 'VA Class' THEN 1
		WHEN c.vocabulary_id = 'ATC' THEN 1
		WHEN c.vocabulary_id = 'NDC' THEN 0
		WHEN c.vocabulary_id = 'SPL' THEN 0
		WHEN c.vocabulary_id = 'MedDRA' THEN 1
		WHEN c.vocabulary_id = 'Read' THEN 1
		WHEN c.vocabulary_id = 'ICD10CM' THEN 1
		WHEN c.vocabulary_id = 'GPI' THEN 1
		WHEN c.vocabulary_id = 'OPCS4' THEN 1
		WHEN c.vocabulary_id = 'MeSH' THEN 1
		WHEN c.vocabulary_id = 'GCN_SEQNO' THEN 1
		WHEN c.vocabulary_id = 'ETC' THEN 1
		WHEN c.vocabulary_id = 'Indication' THEN 1
		WHEN c.vocabulary_id = 'DA_France' THEN 0
		WHEN c.vocabulary_id = 'DPD' THEN 1
		WHEN c.vocabulary_id = 'NFC' THEN 1
		WHEN c.vocabulary_id = 'ICD10PCS' THEN 1
		WHEN c.vocabulary_id = 'EphMRA ATC' THEN 1
		WHEN c.vocabulary_id = 'dm+d' THEN 1
		WHEN c.vocabulary_id = 'RxNorm Extension' THEN 0
		WHEN c.vocabulary_id = 'Gemscript' THEN 1
		WHEN c.vocabulary_id = 'Cost Type' THEN 1
		WHEN c.vocabulary_id = 'BDPM' THEN 1
		WHEN c.vocabulary_id = 'AMT' THEN 1
		WHEN c.vocabulary_id = 'GRR' THEN 0
		WHEN c.vocabulary_id = 'CVX' THEN 1
		WHEN c.vocabulary_id = 'LPD_Australia' THEN 0
		WHEN c.vocabulary_id = 'PPI' THEN 1
		WHEN c.vocabulary_id = 'ICDO3' THEN 1
		WHEN c.vocabulary_id = 'CDT' THEN 1
		WHEN c.vocabulary_id = 'ISBT' THEN 0
		WHEN c.vocabulary_id = 'ISBT Attributes' THEN 0
		WHEN c.vocabulary_id = 'GGR' THEN 1
		WHEN c.vocabulary_id = 'LPD_Belgium' THEN 1
		WHEN c.vocabulary_id = 'APC' THEN 1
		WHEN c.vocabulary_id = 'KDC' THEN 1
		WHEN c.vocabulary_id = 'SUS' THEN 1
		WHEN c.vocabulary_id = 'CDM' THEN 0
		WHEN c.vocabulary_id = 'SNOMED Veterinary' THEN 1
		WHEN c.vocabulary_id = 'OSM' THEN 1
		WHEN c.vocabulary_id = 'US Census' THEN 1
		WHEN c.vocabulary_id = 'HemOnc' THEN 1
		WHEN c.vocabulary_id = 'NAACCR' THEN 1
		WHEN c.vocabulary_id = 'JMDC' THEN 1
		WHEN c.vocabulary_id = 'KCD7' THEN 1
		ELSE 0 -- in default we will not deprecate
	END = 1
	AND c.vocabulary_id NOT IN ('CPT4', 'HCPCS', 'ICD9Proc');

	-- 3.2. Update the concept for CPT4, ICD9Proc and HCPCS
	UPDATE concept c SET
		valid_end_date = (SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = c.vocabulary_id)
	WHERE NOT EXISTS (SELECT 1 FROM concept_stage cs WHERE cs.concept_id = c.concept_id AND cs.vocabulary_id = c.vocabulary_id) -- if concept missing from concept_stage
	AND c.vocabulary_id IN (SELECT vocabulary_id FROM vocabulary WHERE latest_update IS NOT NULL) -- only for current vocabularies
	AND c.valid_end_date = TO_DATE('20991231', 'YYYYMMDD') -- not already deprecated
	AND c.vocabulary_id IN ('CPT4', 'HCPCS', 'ICD9Proc'); /*new rule for these vocabularies: http://forums.ohdsi.org/t/proposal-to-keep-outdated-standard-concepts-active-and-standard/3695/22 and AVOF-981*/

	-- 4. Add new concepts from concept_stage
	-- Create sequence after last valid one
	DO $$
	DECLARE
		ex INTEGER;
	BEGIN
		--SELECT MAX(concept_id)+1 INTO ex FROM concept WHERE concept_id<500000000; -- Last valid below HOI concept_id
		DROP SEQUENCE IF EXISTS v5_concept;
		SELECT concept_id + 1 INTO ex FROM (
			SELECT concept_id, next_id, next_id - concept_id - 1 free_concept_ids
			FROM (SELECT concept_id, LEAD (concept_id) OVER (ORDER BY concept_id) next_id FROM concept where concept_id >= 581480 and concept_id < 500000000) AS t
			WHERE concept_id <> next_id - 1 AND next_id - concept_id > (SELECT COUNT (*) FROM concept_stage WHERE concept_id IS NULL)
			ORDER BY next_id - concept_id
			FETCH FIRST 1 ROW ONLY
		) AS sq;
		EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
	END$$;

	INSERT INTO concept (
		concept_id,
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
	SELECT NEXTVAL('v5_concept'),
		cs.concept_name,
		cs.domain_id,
		cs.vocabulary_id,
		cs.concept_class_id,
		cs.standard_concept,
		cs.concept_code,
		cs.valid_start_date,
		cs.valid_end_date,
		cs.invalid_reason
	FROM concept_stage cs
	WHERE cs.concept_id IS NULL;-- new because no concept_id could be found for the concept_code/vocabulary_id combination

	DROP SEQUENCE v5_concept;

	ANALYZE concept;

	-- 5. Make sure that invalid concepts are standard_concept = NULL
	-- 5.1. For non-CPT4, non-ICD9Proc and non-HCPCS vocabularies
	UPDATE concept c
	SET standard_concept = NULL
	WHERE c.invalid_reason IS NOT NULL
		AND c.standard_concept IS NOT NULL
		AND c.vocabulary_id IN (
			SELECT vocabulary_id
			FROM vocabulary
			WHERE latest_update IS NOT NULL
			) -- only for current vocabularies
		AND c.vocabulary_id NOT IN (
			'CPT4',
			'HCPCS',
			'ICD9Proc'
			);

	-- 5.2. For CPT4, ICD9Proc and HCPCS
	UPDATE concept c
	SET standard_concept = NULL
	WHERE c.invalid_reason IN (
			'D',
			'U'
			)
		AND c.standard_concept IS NOT NULL
		AND c.vocabulary_id IN (
			SELECT vocabulary_id
			FROM vocabulary
			WHERE latest_update IS NOT NULL
			) -- only for current vocabularies
		AND c.vocabulary_id IN (
			'CPT4',
			'HCPCS',
			'ICD9Proc'
			);

	/****************************************
	* Update the concept_relationship table *
	****************************************/

	-- 6. Turn all relationship records so they are symmetrical if necessary
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
	SELECT crs.concept_code_2,
		crs.concept_code_1,
		crs.vocabulary_id_2,
		crs.vocabulary_id_1,
		r.reverse_relationship_id,
		crs.valid_start_date,
		crs.valid_end_date,
		crs.invalid_reason
	FROM concept_relationship_stage crs
	JOIN relationship r ON r.relationship_id = crs.relationship_id
	WHERE NOT EXISTS (
			-- the inverse record
			SELECT 1
			FROM concept_relationship_stage i
			WHERE crs.concept_code_1 = i.concept_code_2
				AND crs.concept_code_2 = i.concept_code_1
				AND crs.vocabulary_id_1 = i.vocabulary_id_2
				AND crs.vocabulary_id_2 = i.vocabulary_id_1
				AND r.reverse_relationship_id = i.relationship_id
			);

	-- 7. Update all relationships existing in concept_relationship_stage, including undeprecation of formerly deprecated ones
	ANALYZE concept_relationship_stage;

	WITH crs
	AS (
		SELECT c1.concept_id c_id1,
			c2.concept_id c_id2,
			crs.relationship_id,
			crs.valid_end_date,
			crs.invalid_reason
		FROM concept_relationship_stage crs
		JOIN concept c1 ON c1.concept_code = crs.concept_code_1
			AND c1.vocabulary_id = crs.vocabulary_id_1
		JOIN concept c2 ON c2.concept_code = crs.concept_code_2
			AND c2.vocabulary_id = crs.vocabulary_id_2
		)
	UPDATE concept_relationship cr
	SET valid_end_date = crs.valid_end_date,
		invalid_reason = crs.invalid_reason
	FROM crs
	WHERE cr.concept_id_1 = crs.c_id1
		AND cr.concept_id_2 = crs.c_id2
		AND cr.relationship_id = crs.relationship_id
		AND cr.valid_end_date <> crs.valid_end_date;

	-- 8. Deprecate missing relationships, but only if the concepts are fresh. If relationships are missing because of deprecated concepts, leave them intact.
	-- Also, only relationships are considered missing if the combination of vocabulary_id_1, vocabulary_id_2 AND relationship_id is present in concept_relationship_stage
	-- The latter will prevent large-scale deprecations of relationships between vocabularies where the relationship is defined not here, but together with the other vocab

	-- Do the deprecation
	WITH relationships AS (
	SELECT * FROM UNNEST(ARRAY[
		'Concept replaced by',
		'Concept same_as to',
		'Concept alt_to to',
		'Concept poss_eq to',
		'Concept was_a to',
		'Maps to']) AS relationship_id
	), 
	vocab_combinations as (
		-- Create a list of vocab1, vocab2 and relationship_id existing in concept_relationship_stage, except 'Maps' to and replacement relationships
		-- Also excludes manual mappings from concept_relationship_manual
		SELECT vocabulary_id_1, vocabulary_id_2, relationship_id
		FROM (
			SELECT concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id FROM concept_relationship_stage
			EXCEPT
			(
				SELECT concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id FROM concept_relationship_manual
				UNION ALL
				--add reverse mappings for exclude
				SELECT concept_code_2, concept_code_1, vocabulary_id_2, vocabulary_id_1, reverse_relationship_id
				FROM concept_relationship_manual JOIN relationship USING (relationship_id)
			)
		) AS s1
		WHERE vocabulary_id_1 NOT IN ('SPL','RxNorm Extension','CDM')
		AND vocabulary_id_2 NOT IN ('SPL','RxNorm Extension','CDM')
		AND relationship_id NOT IN (
			SELECT relationship_id FROM relationships
			UNION ALL
			SELECT reverse_relationship_id FROM relationships JOIN relationship USING (relationship_id)
		)
		GROUP BY vocabulary_id_1, vocabulary_id_2, relationship_id
	)
	UPDATE concept_relationship d
	SET valid_end_date = (SELECT MAX(v.latest_update)-1 FROM vocabulary v WHERE v.vocabulary_id=c1.vocabulary_id OR v.vocabulary_id=c2.vocabulary_id),
		invalid_reason = 'D'
	-- Whether the combination of vocab1, vocab2 and relationship exists (in subquery)
	-- (intended to be covered by this particular vocab udpate)
	-- And both concepts exist (don't deprecate relationships of deprecated concepts)
	FROM concept c1, concept c2
	WHERE c1.concept_id = d.concept_id_1 AND c2.concept_id = d.concept_id_2
	AND (c1.vocabulary_id,c2.vocabulary_id,d.relationship_id) IN (SELECT vocabulary_id_1,vocabulary_id_2,relationship_id FROM vocab_combinations)
	AND c1.valid_end_date = TO_DATE('20991231', 'YYYYMMDD')
	AND c2.valid_end_date = TO_DATE('20991231', 'YYYYMMDD')
	-- And the record is currently fresh and not already deprecated
	AND d.invalid_reason IS NULL
	-- And it was started before or equal the release date
	AND d.valid_start_date <= (
		-- One of latest_update (if we have more than one vocabulary in concept_relationship_stage) may be NULL, therefore use aggregate function MAX() to get one non-null date
		SELECT MAX(v.latest_update) FROM vocabulary v WHERE v.vocabulary_id=c1.vocabulary_id OR v.vocabulary_id=c2.vocabulary_id --take both concept ids to get proper latest_update
	)
	-- And it is missing from the new concept_relationship_stage
	AND NOT EXISTS (
		SELECT 1 FROM concept_relationship_stage crs
		WHERE crs.concept_code_1=c1.concept_code
		AND crs.vocabulary_id_1=c1.vocabulary_id
		AND crs.concept_code_2=c2.concept_code
		AND crs.vocabulary_id_2=c2.vocabulary_id
		AND crs.relationship_id = d.relationship_id
	);

	--9. Deprecate old 'Maps to', 'Maps to value' and replacement records, but only if we have a new one in concept_relationship_stage with the same source concept
	--part 1 (direct mappings)
	WITH relationships AS (
		SELECT relationship_id FROM relationship
		WHERE relationship_id IN (
			'Concept replaced by',
			'Concept same_as to',
			'Concept alt_to to',
			'Concept poss_eq to',
			'Concept was_a to',
			'Maps to',
			'Maps to value',
			'Source - RxNorm eq' -- AVOF-2118
		)
	)
	UPDATE concept_relationship r
	SET valid_end_date  =
			GREATEST(r.valid_start_date, (SELECT MAX(v.latest_update) -1 -- one of latest_update (if we have more than one vocabulary in concept_relationship_stage) may be NULL, therefore use aggregate function MAX() to get one non-null date
				FROM vocabulary v
			WHERE v.vocabulary_id IN (c1.vocabulary_id, c2.vocabulary_id) --take both concept ids to get proper latest_update
			)),
			invalid_reason = 'D'
	FROM concept c1, concept c2, relationships rel
	WHERE r.concept_id_1=c1.concept_id
	AND r.concept_id_2=c2.concept_id
	AND r.invalid_reason IS NULL
	AND r.relationship_id=rel.relationship_id
	AND r.concept_id_1<>r.concept_id_2
	AND EXISTS (
		SELECT 1 FROM concept_relationship_stage crs
		WHERE crs.concept_code_1=c1.concept_code
		AND crs.vocabulary_id_1=c1.vocabulary_id
		AND crs.relationship_id=r.relationship_id
		AND crs.invalid_reason IS NULL
		AND (
			crs.vocabulary_id_2=c2.vocabulary_id
			OR (/*AVOF-459*/
				crs.vocabulary_id_2 IN ('RxNorm','RxNorm Extension') AND c2.vocabulary_id IN ('RxNorm','RxNorm Extension')
			)
			OR (/*AVOF-1439*/
				crs.vocabulary_id_2 IN ('SNOMED','SNOMED Veterinary') AND c2.vocabulary_id IN ('SNOMED','SNOMED Veterinary')
			)
		)
	)
	AND NOT EXISTS (
		SELECT 1 FROM concept_relationship_stage crs
		WHERE crs.concept_code_1=c1.concept_code
		AND crs.vocabulary_id_1=c1.vocabulary_id
		AND crs.concept_code_2=c2.concept_code
		AND crs.vocabulary_id_2=c2.vocabulary_id
		AND crs.relationship_id=r.relationship_id
		AND crs.invalid_reason IS NULL
	);

	--part 2 (reverse mappings)
	WITH relationships AS (
		SELECT reverse_relationship_id FROM relationship
		WHERE relationship_id in (
			'Concept replaced by',
			'Concept same_as to',
			'Concept alt_to to',
			'Concept poss_eq to',
			'Concept was_a to',
			'Maps to',
			'Maps to value',
			'Source - RxNorm eq' -- AVOF-2118
		)
	)
	UPDATE concept_relationship r
	SET valid_end_date  =
			GREATEST(r.valid_start_date, (SELECT MAX(v.latest_update) -1 -- one of latest_update (if we have more than one vocabulary in concept_relationship_stage) may be NULL, therefore use aggregate function MAX() to get one non-null date
				FROM vocabulary v
			WHERE v.vocabulary_id IN (c1.vocabulary_id, c2.vocabulary_id) --take both concept ids to get proper latest_update
			)),
		invalid_reason = 'D'
	FROM concept c1, concept c2, relationships rel
	WHERE r.concept_id_1=c1.concept_id
	AND r.concept_id_2=c2.concept_id
	AND r.invalid_reason IS NULL
	AND r.relationship_id=rel.reverse_relationship_id
	AND r.concept_id_1<>r.concept_id_2
	AND EXISTS (
		SELECT 1 FROM concept_relationship_stage crs
		WHERE crs.concept_code_2=c2.concept_code
		AND crs.vocabulary_id_2=c2.vocabulary_id
		AND crs.relationship_id=r.relationship_id
		AND crs.invalid_reason IS NULL
		AND (
			crs.vocabulary_id_1=c1.vocabulary_id 
			OR (/*AVOF-459*/
				crs.vocabulary_id_1 IN ('RxNorm','RxNorm Extension') AND c1.vocabulary_id IN ('RxNorm','RxNorm Extension')
			)
			OR (/*AVOF-1439*/
				crs.vocabulary_id_1 IN ('SNOMED','SNOMED Veterinary') AND c1.vocabulary_id IN ('SNOMED','SNOMED Veterinary')
			)
		)
	)
	AND NOT EXISTS (
		SELECT 1 FROM concept_relationship_stage crs
		WHERE crs.concept_code_1=c1.concept_code
		AND crs.vocabulary_id_1=c1.vocabulary_id
		AND crs.concept_code_2=c2.concept_code
		AND crs.vocabulary_id_2=c2.vocabulary_id
		AND crs.relationship_id=r.relationship_id
		AND crs.invalid_reason IS NULL
	);

	-- 10. Insert new relationships if they don't already exist
	INSERT INTO concept_relationship
	SELECT c1.concept_id AS concept_id_1,
		c2.concept_id AS concept_id_2,
		crs.relationship_id,
		crs.valid_start_date,
		crs.valid_end_date,
		crs.invalid_reason
	FROM concept_relationship_stage crs
	JOIN concept c1 ON c1.concept_code = crs.concept_code_1 AND c1.vocabulary_id = crs.vocabulary_id_1
	JOIN concept c2 ON c2.concept_code = crs.concept_code_2 AND c2.vocabulary_id = crs.vocabulary_id_2
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_relationship cr_int
			WHERE cr_int.concept_id_1 = c1.concept_id
				AND cr_int.concept_id_2 = c2.concept_id
				AND cr_int.relationship_id = crs.relationship_id
			);

	/*********************************************************
	* Update the correct invalid reason in the concept table *
	* This should rarely happen                              *
	*********************************************************/

	-- 11. Make sure invalid_reason = 'U' if we have an active replacement record in the concept_relationship table
	UPDATE concept c
	SET valid_end_date = v.latest_update - 1, -- day before release day
		invalid_reason = 'U',
		standard_concept = NULL
	FROM concept_relationship cr, vocabulary v
	WHERE c.vocabulary_id = v.vocabulary_id
		AND cr.concept_id_1 = c.concept_id
		AND cr.invalid_reason IS NULL
		AND cr.relationship_id IN (
			'Concept replaced by',
			'Concept same_as to',
			'Concept alt_to to',
			'Concept poss_eq to',
			'Concept was_a to'
			)
		AND v.latest_update IS NOT NULL -- only for current vocabularies
		AND (c.invalid_reason IS NULL OR c.invalid_reason = 'D'); -- not already upgraded

	-- 12. Make sure invalid_reason = 'D' if we have no active replacement record in the concept_relationship table for upgraded concepts
	UPDATE concept c
	SET valid_end_date = (
			SELECT v.latest_update
			FROM vocabulary v
			WHERE c.vocabulary_id = v.vocabulary_id
			) - 1, -- day before release day
		invalid_reason = 'D',
		standard_concept = NULL
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.invalid_reason IS NULL
				AND r.relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept poss_eq to',
					'Concept was_a to'
					)
			)
		AND c.vocabulary_id IN (
			SELECT vocabulary_id
			FROM vocabulary
			WHERE latest_update IS NOT NULL
			) -- only for current vocabularies
		AND c.invalid_reason = 'U';-- not already deprecated

	-- The following are a bunch of rules for Maps to and Maps from relationships.
	-- Since they work outside the _stage tables, they will be restricted to the vocabularies worked on

	-- 13. 'Maps to' and 'Mapped from' relationships from concepts to self should exist for all concepts where standard_concept = 'S'
	WITH to_be_upserted AS (
		SELECT c.concept_id, v.latest_update, lat.relationship_id 
		FROM concept c,	vocabulary v, LATERAL (SELECT case when generate_series=1 then 'Maps to' ELSE 'Mapped from' END AS relationship_id FROM generate_series(1,2)) lat
		WHERE v.vocabulary_id = c.vocabulary_id AND v.latest_update IS NOT NULL AND c.standard_concept = 'S' AND invalid_reason IS NULL
	),
	to_be_updated AS (
		UPDATE concept_relationship cr
		SET invalid_reason = NULL, valid_end_date = TO_DATE ('20991231', 'yyyymmdd')
		FROM to_be_upserted up
		WHERE cr.invalid_reason IS NOT NULL
		AND cr.concept_id_1 = up.concept_id AND cr.concept_id_2 = up.concept_id AND cr.relationship_id = up.relationship_id
		RETURNING cr.*
	)
		INSERT INTO concept_relationship
		SELECT tpu.concept_id, tpu.concept_id, tpu.relationship_id, tpu.latest_update, TO_DATE ('20991231', 'yyyymmdd'), NULL 
		FROM to_be_upserted tpu 
		WHERE (tpu.concept_id, tpu.concept_id, tpu.relationship_id) 
		NOT IN (
			SELECT up.concept_id_1, up.concept_id_2, up.relationship_id FROM to_be_updated up
			UNION ALL
			SELECT cr_int.concept_id_1, cr_int.concept_id_2, cr_int.relationship_id FROM concept_relationship cr_int 
			WHERE cr_int.concept_id_1=cr_int.concept_id_2 AND cr_int.relationship_id IN ('Maps to','Mapped from')
		);

	-- 14. 'Maps to' or 'Maps to value' relationships should not exist where
	-- a) the source concept has standard_concept = 'S', unless it is to self
	-- b) the target concept has standard_concept = 'C' or NULL
	-- c) the target concept has invalid_reason='D' or 'U'

	UPDATE concept_relationship r
	SET valid_end_date = GREATEST(r.valid_start_date, (SELECT MAX(v.latest_update)-1 FROM vocabulary v WHERE v.vocabulary_id=c1.vocabulary_id OR v.vocabulary_id=c2.vocabulary_id)), -- day before release day or valid_start_date
		invalid_reason = 'D'
	FROM concept c1, concept c2, vocabulary v
	WHERE r.concept_id_1 = c1.concept_id
	AND r.concept_id_2 = c2.concept_id
	AND (
		(c1.standard_concept = 'S' AND c1.concept_id != c2.concept_id) -- rule a)
		OR COALESCE (c2.standard_concept, 'X') != 'S' -- rule b)
		OR c2.invalid_reason IN ('U', 'D') -- rule c)
	)
	AND v.vocabulary_id IN (c1.vocabulary_id, c2.vocabulary_id)
	AND v.latest_update IS NOT NULL -- only the current vocabularies
	AND r.relationship_id IN ('Maps to','Maps to value')
	AND r.invalid_reason IS NULL;

	-- And reverse
	UPDATE concept_relationship r
	SET valid_end_date = GREATEST(r.valid_start_date, (SELECT MAX(v.latest_update)-1 FROM vocabulary v WHERE v.vocabulary_id=c1.vocabulary_id OR v.vocabulary_id=c2.vocabulary_id)), -- day before release day or valid_start_date
		invalid_reason = 'D'
	FROM concept c1, concept c2, vocabulary v
	WHERE r.concept_id_1 = c1.concept_id
	AND r.concept_id_2 = c2.concept_id
	AND (
		(c2.standard_concept = 'S' AND c1.concept_id != c2.concept_id) -- rule a)
		OR COALESCE (c1.standard_concept, 'X') != 'S' -- rule b)
		OR c1.invalid_reason IN ('U', 'D') -- rule c)
	)
	AND v.vocabulary_id IN (c1.vocabulary_id, c2.vocabulary_id)
	AND v.latest_update IS NOT NULL -- only the current vocabularies
	AND r.relationship_id IN ('Mapped from','Value mapped from')
	AND r.invalid_reason IS NULL;

	-- 15. Make sure invalid_reason = null if the valid_end_date is 31-Dec-2099
	UPDATE concept 
		SET invalid_reason = NULL
	WHERE valid_end_date = TO_DATE ('20991231', 'YYYYMMDD') -- deprecated date
	AND vocabulary_id IN (SELECT vocabulary_id FROM vocabulary WHERE latest_update IS NOT NULL) -- only for current vocabularies
	AND invalid_reason IS NOT NULL; -- if wrongly deprecated

	--16 Post-processing (some concepts might be deprecated when they missed in source, so load_stage doesn't know about them and DO NOT deprecate relationships proper)
	--Deprecate replacement records if target concept was deprecated
	UPDATE concept_relationship cr
		SET invalid_reason = 'D', 
		valid_end_date = (SELECT MAX (v.latest_update) FROM concept c JOIN vocabulary v ON c.vocabulary_id = v.vocabulary_id WHERE c.concept_id IN (cr.concept_id_1, cr.concept_id_2))-1
	FROM (
			WITH RECURSIVE hierarchy_concepts (concept_id_1, concept_id_2, relationship_id, full_path) AS
			(
				SELECT concept_id_1, concept_id_2, relationship_id, ARRAY [concept_id_1] AS full_path
				FROM upgraded_concepts 
				WHERE concept_id_2 IN (SELECT concept_id_2 FROM upgraded_concepts WHERE invalid_reason = 'D')
				UNION ALL
				SELECT c.concept_id_1, c.concept_id_2, c.relationship_id, hc.full_path || c.concept_id_1 AS full_path
				FROM upgraded_concepts c
				JOIN hierarchy_concepts hc on hc.concept_id_1=c.concept_id_2
				WHERE c.concept_id_1 <> ALL (full_path)
			),
			upgraded_concepts AS (
				SELECT r.concept_id_1,
				r.concept_id_2,
				r.relationship_id,
				c2.invalid_reason
				FROM concept c1, concept c2, concept_relationship r
				WHERE r.relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept poss_eq to',
					'Concept was_a to'
				)
				AND r.invalid_reason IS NULL
				AND c1.concept_id = r.concept_id_1
				AND c2.concept_id = r.concept_id_2
				AND EXISTS (SELECT 1 FROM vocabulary WHERE latest_update IS NOT NULL AND vocabulary_id IN (c1.vocabulary_id,c2.vocabulary_id))
				AND c2.concept_code <> 'OMOP generated'
				AND r.concept_id_1 <> r.concept_id_2
			)
			SELECT concept_id_1, concept_id_2, relationship_id FROM hierarchy_concepts
	) i
	WHERE cr.concept_id_1 = i.concept_id_1 AND cr.concept_id_2 = i.concept_id_2 AND cr.relationship_id = i.relationship_id;

	--Deprecate concepts if we have no active replacement record in the concept_relationship
	UPDATE concept c
	SET valid_end_date = (
			SELECT v.latest_update
			FROM vocabulary v
			WHERE c.vocabulary_id = v.vocabulary_id
			) - 1, -- day before release day
		invalid_reason = 'D',
		standard_concept = NULL
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.invalid_reason IS NULL
				AND r.relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept poss_eq to',
					'Concept was_a to'
					)
			)
		AND c.vocabulary_id IN (
			SELECT vocabulary_id
			FROM vocabulary
			WHERE latest_update IS NOT NULL
			) -- only for current vocabularies
		AND c.invalid_reason = 'U';-- not already deprecated

	--Deprecate 'Maps to' mappings to deprecated and upgraded concepts
	UPDATE concept_relationship r
	SET valid_end_date = (
			SELECT MAX(v.latest_update)
			FROM concept c
			JOIN vocabulary v ON c.vocabulary_id = v.vocabulary_id
			WHERE c.concept_id IN (
					r.concept_id_1,
					r.concept_id_2
					)
			) - 1,
		invalid_reason = 'D'
	WHERE r.relationship_id = 'Maps to'
		AND r.invalid_reason IS NULL
		AND EXISTS (
			SELECT 1
			FROM concept c
			WHERE c.concept_id = r.concept_id_2
				AND c.invalid_reason IN (
					'U',
					'D'
					)
			)
		AND EXISTS (
			SELECT 1
			FROM concept c
			JOIN vocabulary v ON c.vocabulary_id = v.vocabulary_id
			WHERE c.concept_id IN (
					r.concept_id_1,
					r.concept_id_2
					)
				AND v.latest_update IS NOT NULL
			);

	--Reverse for deprecating
	UPDATE concept_relationship r
	SET invalid_reason = r1.invalid_reason,
		valid_end_date = r1.valid_end_date
	FROM concept_relationship r1
	JOIN relationship rel ON r1.relationship_id = rel.relationship_id
	WHERE r1.relationship_id IN (
			'Concept replaced by',
			'Concept same_as to',
			'Concept alt_to to',
			'Concept poss_eq to',
			'Concept was_a to',
			'Maps to'
			)
		AND EXISTS (
			SELECT 1
			FROM concept c
			JOIN vocabulary v ON c.vocabulary_id = v.vocabulary_id
			WHERE c.concept_id IN (
					r1.concept_id_1,
					r1.concept_id_2
					)
				AND v.latest_update IS NOT NULL
			)
		AND r.concept_id_1 = r1.concept_id_2
		AND r.concept_id_2 = r1.concept_id_1
		AND r.relationship_id = rel.reverse_relationship_id
		AND r.valid_end_date <> r1.valid_end_date;

	--17. fix valid_start_date for incorrect concepts (bad data in sources)
	UPDATE concept c
	SET valid_start_date = valid_end_date - 1
	WHERE c.valid_end_date < c.valid_start_date
		AND c.vocabulary_id IN (
			SELECT vocabulary_id
			FROM vocabulary
			WHERE latest_update IS NOT NULL
			);-- only for current vocabularies

	/***********************************
	* Update the concept_synonym table *
	************************************/

	-- 18. Add all missing synonyms
	INSERT INTO concept_synonym_stage (
		synonym_concept_id,
		synonym_concept_code,
		synonym_name,
		synonym_vocabulary_id,
		language_concept_id
		)
	SELECT NULL AS synonym_concept_id,
		c.concept_code AS synonym_concept_code,
		c.concept_name AS synonym_name,
		c.vocabulary_id AS synonym_vocabulary_id,
		4180186 AS language_concept_id
	FROM concept_stage c
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_synonym_stage css
			WHERE css.synonym_concept_code = c.concept_code
				AND css.synonym_vocabulary_id = c.vocabulary_id
			);

	-- 19. Remove all existing synonyms for concepts that are in concept_stage
	-- Synonyms are built from scratch each time, no life cycle

	ANALYZE concept_synonym_stage;

	DELETE
	FROM concept_synonym csyn
	WHERE csyn.concept_id IN (
			SELECT c.concept_id
			FROM concept c,
				concept_stage cs
			WHERE c.concept_code = cs.concept_code
				AND cs.vocabulary_id = c.vocabulary_id
			);

	-- 20. Add new synonyms for existing concepts
	INSERT INTO concept_synonym (
		concept_id,
		concept_synonym_name,
		language_concept_id
		)
	SELECT DISTINCT c.concept_id,
		REGEXP_REPLACE(TRIM(synonym_name), '[[:space:]]+', ' '),
		css.language_concept_id
	FROM concept_synonym_stage css,
		concept c,
		concept_stage cs
	WHERE css.synonym_concept_code = c.concept_code
		AND css.synonym_vocabulary_id = c.vocabulary_id
		AND cs.concept_code = c.concept_code
		AND cs.vocabulary_id = c.vocabulary_id
		AND REGEXP_REPLACE(TRIM(synonym_name), '[[:space:]]+', ' ') IS NOT NULL; --fix for empty GPI names

	-- 21. Fillig drug_strength
	-- Special rules for RxNorm Extension: same as 'Maps to' rules, but records from deprecated concepts will be deleted
	DELETE
	FROM drug_strength
	WHERE drug_concept_id IN (
			SELECT c.concept_id
			FROM concept c
			JOIN vocabulary v ON c.vocabulary_id = v.vocabulary_id
			WHERE latest_update IS NOT NULL
				AND v.vocabulary_id <> 'RxNorm Extension'
			);

	-- Replace with fresh records (only for 'RxNorm Extension')
	DELETE
	FROM drug_strength ds
	WHERE EXISTS (
			SELECT 1
			FROM drug_strength_stage dss
			JOIN concept c1 ON c1.concept_code = dss.drug_concept_code
				AND c1.vocabulary_id = dss.vocabulary_id_1
				AND ds.drug_concept_id = c1.concept_id
			JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
			WHERE v.latest_update IS NOT NULL
				AND v.vocabulary_id = 'RxNorm Extension'
			);

	-- Insert new records
	INSERT INTO drug_strength (
		drug_concept_id,
		ingredient_concept_id,
		amount_value,
		amount_unit_concept_id,
		numerator_value,
		numerator_unit_concept_id,
		denominator_value,
		denominator_unit_concept_id,
		box_size,
		valid_start_date,
		valid_end_date,
		invalid_reason
		)
	SELECT c1.concept_id,
		c2.concept_id,
		ds.amount_value,
		ds.amount_unit_concept_id,
		ds.numerator_value,
		ds.numerator_unit_concept_id,
		ds.denominator_value,
		ds.denominator_unit_concept_id,
		regexp_replace(bs.concept_name, '.+Box of ([0-9]+).*', '\1')::INT AS box_size,
		ds.valid_start_date,
		ds.valid_end_date,
		ds.invalid_reason
	FROM drug_strength_stage ds
	JOIN concept c1 ON c1.concept_code = ds.drug_concept_code
		AND c1.vocabulary_id = ds.vocabulary_id_1
	JOIN concept c2 ON c2.concept_code = ds.ingredient_concept_code
		AND c2.vocabulary_id = ds.vocabulary_id_2
	JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
	LEFT JOIN concept bs ON bs.concept_id = c1.concept_id
		AND bs.vocabulary_id = 'RxNorm Extension'
		AND bs.concept_name LIKE '%Box of%'
	WHERE v.latest_update IS NOT NULL;

	-- Delete drug if concept is deprecated (only for 'RxNorm Extension')
	DELETE
	FROM drug_strength ds
	WHERE EXISTS (
			SELECT 1
			FROM concept c1
			JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
			WHERE ds.drug_concept_id = c1.concept_id
				AND v.latest_update IS NOT NULL
				AND v.vocabulary_id = 'RxNorm Extension'
				AND c1.invalid_reason IS NOT NULL
			);

	-- 22. Fillig pack_content
	-- Special rules for RxNorm Extension: same as 'Maps to' rules, but records from deprecated concepts will be deleted
	DELETE
	FROM pack_content
	WHERE pack_concept_id IN (
			SELECT c.concept_id
			FROM concept c
			JOIN vocabulary v ON c.vocabulary_id = v.vocabulary_id
			WHERE latest_update IS NOT NULL
				AND v.vocabulary_id <> 'RxNorm Extension'
			);

	-- Replace with fresh records (only for 'RxNorm Extension')
	DELETE
	FROM pack_content pc
	WHERE EXISTS (
			SELECT 1
			FROM pack_content_stage pcs
			JOIN concept c1 ON c1.concept_code = pcs.pack_concept_code
				AND c1.vocabulary_id = pcs.pack_vocabulary_id
				AND pc.pack_concept_id = c1.concept_id
			JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
			WHERE v.latest_update IS NOT NULL
				AND v.vocabulary_id = 'RxNorm Extension'
			);

	INSERT INTO pack_content (
		pack_concept_id,
		drug_concept_id,
		amount,
		box_size
		)
	SELECT c1.concept_id,
		c2.concept_id,
		ds.amount,
		ds.box_size
	FROM pack_content_stage ds
	JOIN concept c1 ON c1.concept_code = ds.pack_concept_code
		AND c1.vocabulary_id = ds.pack_vocabulary_id
	JOIN concept c2 ON c2.concept_code = ds.drug_concept_code
		AND c2.vocabulary_id = ds.drug_vocabulary_id
	JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
	WHERE v.latest_update IS NOT NULL;

	-- Delete if concept is deprecated (only for 'RxNorm Extension')
	DELETE
	FROM pack_content pc
	WHERE EXISTS (
			SELECT 1
			FROM concept c1
			JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
			WHERE pc.pack_concept_id = c1.concept_id
				AND v.latest_update IS NOT NULL
				AND v.vocabulary_id = 'RxNorm Extension'
				AND c1.invalid_reason IS NOT NULL
			);

	-- 23. check if current vocabulary exists in vocabulary_conversion table
	INSERT INTO vocabulary_conversion (
		vocabulary_id_v4,
		vocabulary_id_v5
		)
	SELECT rownum + (
			SELECT MAX(vocabulary_id_v4)
			FROM vocabulary_conversion
			) AS rn,
		a [rownum] AS vocabulary_id
	FROM (
		SELECT a,
			generate_series(1, array_upper(a, 1)) AS rownum
		FROM (
			SELECT ARRAY(SELECT vocabulary_id FROM vocabulary
				
				EXCEPT
					
					SELECT vocabulary_id_v5 FROM vocabulary_conversion) AS a
			) AS s1
		) AS s2;

	-- 24. update latest_update on vocabulary_conversion
	UPDATE vocabulary_conversion vc
	SET latest_update = v.latest_update
	FROM vocabulary v
	WHERE v.latest_update IS NOT NULL
		AND v.vocabulary_id = vc.vocabulary_id_v5;

	-- 25. drop column latest_update
	ALTER TABLE vocabulary DROP COLUMN latest_update;
	ALTER TABLE vocabulary DROP COLUMN dev_schema_name;

	-- 26. Final ANALYSING for base tables
	ANALYZE concept;
	ANALYZE concept_relationship;
	ANALYZE concept_synonym;
	-- QA (should return NULL)
	-- select * from QA_TESTS.GET_CHECKS();
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100
SET client_min_messages = error;