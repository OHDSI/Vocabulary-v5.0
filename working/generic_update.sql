CREATE OR REPLACE FUNCTION devv5.GenericUpdate (
)
RETURNS void AS
$BODY$
BEGIN
	--1. Prerequisites:
	--1.1 Check vocabulary table, at least one vocabulary must have the latest_update field set
	PERFORM FROM vocabulary WHERE latest_update IS NOT NULL LIMIT 1;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'At least one vocabulary must have the latest_update field set'
			USING HINT = 'Forgot to execute SetLatestUpdate?';
	END IF;

	--1.2 Check stage tables for incorrect rows
	DO $$
	DECLARE
	z TEXT;
	crlf TEXT:=E'\r\n';
	BEGIN
		SELECT STRING_AGG(error_text||' [rows_count='||rows_count||']', crlf) INTO z FROM qa_tests.Check_Stage_Tables();
		IF LENGTH(z)>10000 THEN
			z:=SUBSTR(z,1,10000)||'... (cut)';
		END IF;
		IF z IS NOT NULL THEN
			z:=crlf||z||crlf||crlf||'NOTE: You can also run SELECT * FROM qa_tests.Check_Stage_Tables();';
			RAISE EXCEPTION '%', z;
		END IF;
	END $$;

	--1.3 Start logging manual work
	PERFORM admin_pack.LogManualChanges();
	
	--1.4 Clear concept_id's just in case
	UPDATE concept_stage
	SET concept_id = NULL
	WHERE concept_id IS NOT NULL;
	
	UPDATE concept_relationship_stage
	SET concept_id_1 = NULL,
		concept_id_2 = NULL
	WHERE COALESCE(concept_id_1, concept_id_2) IS NOT NULL;
	
	UPDATE concept_synonym_stage
	SET synonym_concept_id = NULL
	WHERE synonym_concept_id IS NOT NULL;

	--2. Make sure that invalid concepts are standard_concept = NULL
	UPDATE concept_stage cs
	SET standard_concept = NULL
	WHERE cs.invalid_reason IS NOT NULL
		AND cs.standard_concept IS NOT NULL;

	--3. Make sure invalid_reason = null if the valid_end_date is 31-Dec-2099
	UPDATE concept_stage cs
		SET invalid_reason = NULL
	WHERE cs.valid_end_date = TO_DATE ('20991231', 'YYYYMMDD')
	AND cs.invalid_reason IS NOT NULL;

	--4. Update concept_id in concept_stage from concept for existing concepts
	UPDATE concept_stage cs
		SET concept_id = c.concept_id
	FROM concept c
	WHERE cs.concept_code = c.concept_code
		AND cs.vocabulary_id = c.vocabulary_id;

	--5. Analyzing
	ANALYZE concept_stage;
	ANALYZE concept_relationship_stage;

	--6. Clearing the concept_name
	--Remove double spaces, carriage return, newline, vertical tab, form feed, unicode spaces
	UPDATE concept_stage
	SET concept_name = TRIM(REGEXP_REPLACE(concept_name, '[[:cntrl:]\u00a0\u180e\u2007\u200b-\u200f\u202f\u2060\ufeff]+', ' ', 'g'))
	WHERE concept_name ~ '[[:cntrl:]\u00a0\u180e\u2007\u200b-\u200f\u202f\u2060\ufeff]';

	UPDATE concept_stage
	SET concept_name = REGEXP_REPLACE(concept_name, ' {2,}', ' ', 'g')
	WHERE concept_name ~ ' {2,}';

	--Remove long dashes
	UPDATE concept_stage
	SET concept_name = REPLACE(concept_name, '–', '-')
	WHERE concept_name LIKE '%–%';

	--Remove trailing escape character (\)
	UPDATE concept_stage
	SET concept_name = RTRIM(concept_name, $c$\$c$)
	WHERE concept_name LIKE '%\\';

	--7. Clearing the synonym_name
	--Remove double spaces, carriage return, newline, vertical tab and form feed
	WITH del
	AS (
		DELETE
		FROM concept_synonym_stage
		WHERE synonym_name ~ '[[:cntrl:]\u00a0\u180e\u2007\u200b-\u200f\u202f\u2060\ufeff]'
		RETURNING *
		)
	INSERT INTO concept_synonym_stage
	SELECT d.synonym_concept_id,
		TRIM(REGEXP_REPLACE(d.synonym_name, '[[:cntrl:]\u00a0\u180e\u2007\u200b-\u200f\u202f\u2060\ufeff]+', ' ', 'g')) AS synonym_name,
		d.synonym_concept_code,
		d.synonym_vocabulary_id,
		d.language_concept_id
	FROM del d
	ON CONFLICT DO NOTHING;

	--Remove double spaces
	WITH del
	AS (
		DELETE
		FROM concept_synonym_stage
		WHERE synonym_name ~ ' {2,}'
		RETURNING *
		)
	INSERT INTO concept_synonym_stage
	SELECT d.synonym_concept_id,
		REGEXP_REPLACE(d.synonym_name, ' {2,}', ' ', 'g') AS synonym_name,
		d.synonym_concept_code,
		d.synonym_vocabulary_id,
		d.language_concept_id
	FROM del d
	ON CONFLICT DO NOTHING;

	--Remove long dashes
	WITH del
	AS (
		DELETE
		FROM concept_synonym_stage
		WHERE synonym_name LIKE '%–%'
		RETURNING *
		)
	INSERT INTO concept_synonym_stage
	SELECT d.synonym_concept_id,
		REPLACE(d.synonym_name, '–', '-') AS synonym_name,
		d.synonym_concept_code,
		d.synonym_vocabulary_id,
		d.language_concept_id
	FROM del d
	ON CONFLICT DO NOTHING;

	--Remove trailing escape character (\)
	WITH del
	AS (
		DELETE
		FROM concept_synonym_stage
		WHERE synonym_name LIKE '%\\'
		RETURNING *
		)
	INSERT INTO concept_synonym_stage
	SELECT d.synonym_concept_id,
		RTRIM(d.synonym_name, $c$\$c$) AS synonym_name,
		d.synonym_concept_code,
		d.synonym_vocabulary_id,
		d.language_concept_id
	FROM del d
	ON CONFLICT DO NOTHING;

	/***************************
	* Update the concept table *
	****************************/

	--8. Update existing concept details from concept_stage.
	--All fields (concept_name, domain_id, concept_class_id, standard_concept, valid_start_date, valid_end_date, invalid_reason) are updated
	UPDATE concept c
	SET (
			concept_name,
			domain_id,
			concept_class_id,
			standard_concept,
			valid_start_date,
			valid_end_date,
			invalid_reason
			) = (
			cs.concept_name,
			cs.domain_id,
			cs.concept_class_id,
			cs.standard_concept,
			CASE 
				WHEN cs.valid_start_date <> v.latest_update --if we have a real date in the concept_stage, use it. If it is only the release date, use the existing
					THEN cs.valid_start_date
				ELSE c.valid_start_date
				END,
			cs.valid_end_date,
			cs.invalid_reason
			)
	FROM concept_stage cs
	JOIN vocabulary v USING (vocabulary_id)
	WHERE c.concept_id = cs.concept_id
		AND ROW(c.concept_name, c.domain_id, c.concept_class_id, c.standard_concept, c.valid_start_date, c.valid_end_date, c.invalid_reason)
		IS DISTINCT FROM
		ROW(cs.concept_name, cs.domain_id, cs.concept_class_id, cs.standard_concept, cs.valid_start_date, cs.valid_end_date, cs.invalid_reason);

	--9. Deprecate concepts missing from concept_stage and are not already deprecated.
	--This only works for vocabularies where we expect a full set of active concepts in concept_stage.
	--If the vocabulary only provides changed concepts, this should not be run, and the update information is already dealt with in step 1.
	--20180523: new rule for some vocabularies, see http://forums.ohdsi.org/t/proposal-to-keep-outdated-standard-concepts-active-and-standard/3695/22 and AVOF-981
	--20200730 added ICD10PCS
	--9.1. Update the concept for 'regular' vocabularies
	UPDATE concept c
	SET invalid_reason = 'D',
		standard_concept = NULL,
		valid_end_date = v.latest_update - 1
	FROM vocabulary v
	WHERE c.vocabulary_id = v.vocabulary_id
		AND COALESCE(v.vocabulary_params ->> 'is_full', '0') = '1' --all vocabularies that give us a full list of active concepts at each release we can safely assume to deprecate missing ones (in default we will not deprecate)
		AND NOT (COALESCE(v.vocabulary_params ->> 'special_deprecation', '0') = '1')
		AND v.latest_update IS NOT NULL --only for current vocabularies
		AND NOT EXISTS (
			SELECT 1
			FROM concept_stage cs
			WHERE cs.concept_id = c.concept_id
				AND cs.vocabulary_id = c.vocabulary_id
			) --if concept missing from concept_stage
		AND c.invalid_reason IS NULL;--not already deprecated

	--9.2. Update the concept for 'special' vocabs
	UPDATE concept c
	SET valid_end_date = v.latest_update - 1
	FROM vocabulary v
	WHERE c.vocabulary_id = v.vocabulary_id
		AND v.vocabulary_params ->> 'special_deprecation' = '1'
		AND v.latest_update IS NOT NULL --only for current vocabularies
		AND NOT EXISTS (
			SELECT 1
			FROM concept_stage cs
			WHERE cs.concept_id = c.concept_id
				AND cs.vocabulary_id = c.vocabulary_id
			) --if concept missing from concept_stage
		AND c.valid_end_date = TO_DATE('20991231', 'YYYYMMDD');--not already deprecated

	--10. Add new concepts from concept_stage
	--Create sequence after last valid one
	DO $$
	DECLARE
		ex INTEGER;
	BEGIN
		--SELECT MAX(concept_id)+1 INTO ex FROM concept WHERE concept_id<500000000; -- Last valid below HOI concept_id
		DROP SEQUENCE IF EXISTS v5_concept;
		SELECT concept_id + 1 INTO ex FROM (
			SELECT concept_id, next_id, next_id - concept_id - 1 free_concept_ids
			FROM (
				SELECT concept_id, LEAD (concept_id) OVER (ORDER BY concept_id) next_id FROM 
				(
					SELECT concept_id FROM concept
					UNION ALL
					SELECT concept_id FROM devv5.concept_blacklisted --blacklisted concept_id's (AVOF-2395)
				) AS i
				WHERE concept_id >= 581480 AND concept_id < 500000000
			) AS t
			WHERE concept_id <> next_id - 1 AND next_id - concept_id > (SELECT COUNT (*) FROM concept_stage WHERE concept_id IS NULL)
			ORDER BY next_id - concept_id
			LIMIT 1
		) AS sq;
		EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
	END$$;

	--11. Insert new concepts
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

	--12. Update concept_id for new concepts
	UPDATE concept_stage cs
		SET concept_id = c.concept_id
	FROM concept c
	WHERE cs.concept_code = c.concept_code
		AND cs.vocabulary_id = c.vocabulary_id
		AND cs.concept_id IS NULL;
	ANALYZE concept_stage;

	--13. Update concept_id_1 and concept_id_2 in concept_relationship_stage from concept_stage and concept
	UPDATE concept_relationship_stage crs
	SET concept_id_1 = c1.concept_id,
		concept_id_2 = c2.concept_id
	FROM concept_stage c1,
		concept_stage c2
	WHERE c1.concept_code = crs.concept_code_1
		AND c1.vocabulary_id = crs.vocabulary_id_1
		AND c2.concept_code = crs.concept_code_2
		AND c2.vocabulary_id = crs.vocabulary_id_2;

	UPDATE concept_relationship_stage crs
	SET concept_id_1 = c.concept_id
	FROM concept c
	WHERE c.concept_code = crs.concept_code_1
		AND c.vocabulary_id = crs.vocabulary_id_1
		AND crs.concept_id_1 IS NULL;

	UPDATE concept_relationship_stage crs
	SET concept_id_2 = c.concept_id
	FROM concept c
	WHERE c.concept_code = crs.concept_code_2
		AND c.vocabulary_id = crs.vocabulary_id_2
		AND crs.concept_id_2 IS NULL;

	/****************************************
	* Update the concept_relationship table *
	****************************************/

	--14. Turn all relationship records so they are symmetrical if necessary and create an index
	INSERT INTO concept_relationship_stage (
		concept_id_1,
		concept_id_2,
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
		)
	SELECT crs.concept_id_2,
		crs.concept_id_1,
		crs.concept_code_2,
		crs.concept_code_1,
		crs.vocabulary_id_2,
		crs.vocabulary_id_1,
		r.reverse_relationship_id,
		crs.valid_start_date,
		crs.valid_end_date,
		crs.invalid_reason
	FROM concept_relationship_stage crs
	JOIN relationship r USING (relationship_id)
	ON CONFLICT DO NOTHING;

	CREATE INDEX idx_crs_ids_generic_temp ON concept_relationship_stage (
		concept_id_1,
		concept_id_2,
		relationship_id
		);
	ANALYZE concept_relationship_stage;

	--15. Update all relationships existing in concept_relationship_stage, including undeprecation of formerly deprecated ones
	UPDATE concept_relationship cr
	SET valid_end_date = crs.valid_end_date,
		invalid_reason = crs.invalid_reason
	FROM concept_relationship_stage crs
	WHERE crs.concept_id_1 = cr.concept_id_1
		AND crs.concept_id_2 = cr.concept_id_2
		AND crs.relationship_id = cr.relationship_id
		AND crs.valid_end_date <> cr.valid_end_date;

	--16. Deprecate missing relationships, but only if the concepts are fresh. If relationships are missing because of deprecated concepts, leave them intact.
	--Also, only relationships are considered missing if the combination of vocabulary_id_1, vocabulary_id_2 AND relationship_id is present in concept_relationship_stage
	--The latter will prevent large-scale deprecations of relationships between vocabularies where the relationship is defined not here, but together with the other vocab

	--Do the deprecation
	--Prepare temp table vocab_combinations$
	CREATE UNLOGGED TABLE vocab_combinations$ AS
		WITH relationships AS (
				SELECT *
				FROM UNNEST(ARRAY [
				'Concept replaced by',
				'Concept same_as to',
				'Concept alt_to to',
				'Concept was_a to',
				'Maps to',
				'CPT4 - SNOMED cat', -- AVOC-4022
				'CPT4 - SNOMED eq' -- AVOC-4022
				]) AS relationship_id
				)
	--Create a list of vocab1, vocab2 and relationship_id existing in concept_relationship_stage, except 'Maps' to and replacement relationships
	--Also excludes manual mappings from concept_relationship_manual
	SELECT DISTINCT s0.vocabulary_id_1,
		s0.vocabulary_id_2,
		s0.relationship_id,
		-- One of latest_update (if we have more than one vocabulary in concept_relationship_stage) may be NULL, therefore use GREATEST to get one non-null date
		GREATEST(v1.latest_update, v2.latest_update) AS max_latest_update
	FROM (
		SELECT concept_code_1,
			concept_code_2,
			vocabulary_id_1,
			vocabulary_id_2,
			relationship_id
		FROM concept_relationship_stage
		
		EXCEPT
		
		(
			SELECT concept_code_1,
				concept_code_2,
				vocabulary_id_1,
				vocabulary_id_2,
				relationship_id
			FROM concept_relationship_manual
			
			UNION ALL
			
			--Add reverse mappings
			SELECT concept_code_2,
				concept_code_1,
				vocabulary_id_2,
				vocabulary_id_1,
				reverse_relationship_id
			FROM concept_relationship_manual
			JOIN relationship USING (relationship_id)
			)
		) AS s0
	JOIN vocabulary v1 ON v1.vocabulary_id = s0.vocabulary_id_1
	JOIN vocabulary v2 ON v2.vocabulary_id = s0.vocabulary_id_2
	WHERE s0.vocabulary_id_1 NOT IN (
			'SPL',
			'RxNorm Extension',
			'CDM'
			)
		AND s0.vocabulary_id_2 NOT IN (
			'SPL',
			'RxNorm Extension',
			'CDM'
			)
		AND s0.relationship_id NOT IN (
			SELECT relationship_id
			FROM relationships
			
			UNION ALL
			
			SELECT reverse_relationship_id
			FROM relationships
			JOIN relationship USING (relationship_id)
			)
		AND COALESCE(v1.latest_update, v2.latest_update) IS NOT NULL;

	ANALYZE vocab_combinations$;

	--prepare temp table concept_relationship_upd$
    CREATE UNLOGGED TABLE IF NOT EXISTS concept_rel_temp$ AS
    SELECT  cr.concept_id_1,
            cr.concept_id_2,
            cr.relationship_id,
            vc.max_latest_update
    FROM concept_relationship cr
        JOIN concept c1 ON c1.concept_id = cr.concept_id_1
            AND c1.valid_end_date = TO_DATE('20991231', 'YYYYMMDD')
        JOIN concept c2 ON c2.concept_id = cr.concept_id_2
            AND c2.valid_end_date = TO_DATE('20991231', 'YYYYMMDD')
        JOIN vocab_combinations$ vc ON vc.vocabulary_id_1 = c1.vocabulary_id
            AND vc.vocabulary_id_2 = c2.vocabulary_id
            AND vc.relationship_id = cr.relationship_id
        WHERE  cr.invalid_reason IS NULL --And the record is currently fresh and not already deprecated
            --And it was started before or equal the release date
            AND cr.valid_start_date <= vc.max_latest_update;

    CREATE INDEX concept_rel_temp_idx ON concept_rel_temp$(concept_id_1, concept_id_2, relationship_id);

    ANALYZE concept_rel_temp$;

    CREATE UNLOGGED TABLE concept_relationship_upd$ AS
    SELECT cr.concept_id_1,
            cr.concept_id_2,
            cr.relationship_id,
            cr.max_latest_update
    FROM concept_rel_temp$ cr
    LEFT JOIN concept_relationship_stage crs 
           ON crs.concept_id_1 = cr.concept_id_1
          AND crs.concept_id_2 = cr.concept_id_2
          AND crs.relationship_id = cr.relationship_id
    WHERE crs.concept_id_1 IS NULL --And it is missing from the new concept_relationship_stage;

	ANALYZE concept_relationship_upd$;

	--update 'main' table from a temporary table
	UPDATE concept_relationship cr
	SET valid_end_date = CASE 
                              WHEN (crt.max_latest_update - 1) < cr.valid_start_date 
                              THEN CURRENT_DATE - 1
                              ELSE crt.max_latest_update - 1 
                         END,
		invalid_reason = 'D'
	FROM concept_relationship_upd$ crt
	WHERE cr.concept_id_1 = crt.concept_id_1
		AND cr.concept_id_2 = crt.concept_id_2
		AND cr.relationship_id = crt.relationship_id;

	--clean up
	DROP TABLE vocab_combinations$, concept_relationship_upd$, concept_rel_temp$;

	--17. Deprecate old 'Maps to', 'Maps to value' and replacement records, but only if we have a new one in concept_relationship_stage with the same source concept
	--part 1 (direct mappings)
	WITH relationships AS (
		SELECT relationship_id FROM relationship
		WHERE relationship_id IN (
			'Concept replaced by',
			'Concept same_as to',
			'Concept alt_to to',
			'Concept was_a to',
			'Maps to',
			'Maps to value',
			'Source - RxNorm eq', -- AVOF-2118
			'CPT4 - SNOMED cat', -- AVOC-4022
			'CPT4 - SNOMED eq' -- AVOC-4022
		)
	)
	UPDATE concept_relationship r
	SET valid_end_date  =
			CASE 
                WHEN GREATEST(r.valid_start_date, 
                              (SELECT MAX(v.latest_update) -1 -- one of latest_update (if we have more than one vocabulary in   concept_relationship_stage) may be NULL, therefore use aggregate function MAX() to get one non-null date
                                 FROM vocabulary v
                                WHERE v.vocabulary_id IN (c1.vocabulary_id, c2.vocabulary_id)) --take both concept ids to get proper latest_update
                     ) < r.valid_start_date
                THEN CURRENT_DATE - 1
                ELSE GREATEST(r.valid_start_date, 
                              (SELECT MAX(v.latest_update) -1 -- one of latest_update (if we have more than one vocabulary in   concept_relationship_stage) may be NULL, therefore use aggregate function MAX() to get one non-null date
                                 FROM vocabulary v
                                WHERE v.vocabulary_id IN (c1.vocabulary_id, c2.vocabulary_id)) --take both concept ids to get proper latest_update
                     )
                END,
        invalid_reason = 'D'
	FROM concept c1, concept c2, relationships rel
	WHERE r.concept_id_1=c1.concept_id
	AND r.concept_id_2=c2.concept_id
	AND r.invalid_reason IS NULL
	AND r.relationship_id=rel.relationship_id
	AND r.concept_id_1<>r.concept_id_2
	AND EXISTS (
		SELECT 1 FROM concept_relationship_stage crs
		WHERE crs.concept_id_1=r.concept_id_1
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
		WHERE crs.concept_id_1=r.concept_id_1
		AND crs.concept_id_2=r.concept_id_2
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
			'Concept was_a to',
			'Maps to',
			'Maps to value',
			'Source - RxNorm eq', -- AVOF-2118
			'CPT4 - SNOMED cat', -- AVOC-4022
			'CPT4 - SNOMED eq' -- AVOC-4022
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
		WHERE crs.concept_id_2=r.concept_id_2
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
		WHERE crs.concept_id_1=r.concept_id_1
		AND crs.concept_id_2=r.concept_id_2
		AND crs.relationship_id=r.relationship_id
		AND crs.invalid_reason IS NULL
	);

	--18. Insert new relationships if they don't already exist
	INSERT INTO concept_relationship
	SELECT crs.concept_id_1,
		crs.concept_id_2,
		crs.relationship_id,
		crs.valid_start_date,
		crs.valid_end_date,
		crs.invalid_reason
	FROM concept_relationship_stage crs
	ON CONFLICT DO NOTHING;

	/*********************************************************
	* Update the correct invalid reason in the concept table *
	* This should rarely happen                              *
	*********************************************************/

	--19. Make sure invalid_reason = 'U' if we have an active replacement record in the concept_relationship table
	UPDATE concept c
	SET valid_end_date = LEAST(c.valid_end_date, v.latest_update - 1), -- day before release day
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
			'Concept was_a to'
			)
		AND v.latest_update IS NOT NULL -- only for current vocabularies
		AND (c.invalid_reason IS NULL OR c.invalid_reason = 'D'); -- not already upgraded

	--20. Make sure invalid_reason = 'D' if we have no active replacement record in the concept_relationship table for upgraded concepts
	UPDATE concept c
	SET valid_end_date = LEAST(c.valid_end_date, v.latest_update - 1),
		invalid_reason = 'D',
		standard_concept = NULL
	FROM vocabulary v
	WHERE v.vocabulary_id = c.vocabulary_id
		AND NOT EXISTS (
				SELECT 1
				FROM concept_relationship r
				WHERE r.concept_id_1 = c.concept_id
					AND r.invalid_reason IS NULL
					AND r.relationship_id IN (
						'Concept replaced by',
						'Concept same_as to',
						'Concept alt_to to',
						'Concept was_a to'
						)
				)
			AND v.latest_update IS NOT NULL -- only for current vocabularies
			AND c.invalid_reason = 'U';-- not already deprecated

	--The following are a bunch of rules for Maps to and Maps from relationships.
	--Since they work outside the _stage tables, they will be restricted to the vocabularies worked on

	--21. 'Maps to' and 'Mapped from' relationships from concepts to self should exist for all concepts where standard_concept = 'S'
	INSERT INTO concept_relationship AS cr
	SELECT c.concept_id AS concept_id_1,
		c.concept_id AS concept_id_2,
		r.relationship_id,
		v.latest_update AS valid_start_date,
		TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
		NULL AS invalid_reason
	FROM concept c
	JOIN vocabulary v ON v.vocabulary_id = c.vocabulary_id
		AND v.latest_update IS NOT NULL
	CROSS JOIN (
		SELECT 'Maps to' AS relationship_id
		
		UNION ALL
		
		SELECT 'Mapped from'
		) r
	WHERE c.standard_concept = 'S'
		AND c.invalid_reason IS NULL
	ON CONFLICT ON CONSTRAINT xpk_concept_relationship
	DO UPDATE
	SET valid_end_date = excluded.valid_end_date,
		invalid_reason = excluded.invalid_reason
	WHERE cr.invalid_reason IS NOT NULL;

	--22. 'Maps to' or 'Maps to value' relationships should not exist where
	--a) the source concept has standard_concept = 'S', unless it is to self
	--b) the target concept has standard_concept = 'C' or NULL
	--c) the target concept has invalid_reason='D' or 'U'

	UPDATE concept_relationship r
	SET valid_end_date = GREATEST(r.valid_start_date, (SELECT MAX(v.latest_update)-1 FROM vocabulary v WHERE v.vocabulary_id=c1.vocabulary_id OR v.vocabulary_id=c2.vocabulary_id)), -- day before release day or valid_start_date
		invalid_reason = 'D'
	FROM concept c1, concept c2, vocabulary v
	WHERE r.concept_id_1 = c1.concept_id
	AND r.concept_id_2 = c2.concept_id
	AND (
		(c1.standard_concept = 'S' AND c1.concept_id <> c2.concept_id) -- rule a)
		OR COALESCE (c2.standard_concept, 'X') <> 'S' -- rule b)
		OR c2.invalid_reason IN ('U', 'D') -- rule c)
	)
	AND v.vocabulary_id IN (c1.vocabulary_id, c2.vocabulary_id)
	AND v.latest_update IS NOT NULL -- only the current vocabularies
	AND r.relationship_id IN ('Maps to','Maps to value')
	AND r.invalid_reason IS NULL;

	--And reverse
	UPDATE concept_relationship r
	SET valid_end_date = GREATEST(r.valid_start_date, (SELECT MAX(v.latest_update)-1 FROM vocabulary v WHERE v.vocabulary_id=c1.vocabulary_id OR v.vocabulary_id=c2.vocabulary_id)), -- day before release day or valid_start_date
		invalid_reason = 'D'
	FROM concept c1, concept c2, vocabulary v
	WHERE r.concept_id_1 = c1.concept_id
	AND r.concept_id_2 = c2.concept_id
	AND (
		(c2.standard_concept = 'S' AND c1.concept_id <> c2.concept_id) -- rule a)
		OR COALESCE (c1.standard_concept, 'X') <> 'S' -- rule b)
		OR c1.invalid_reason IN ('U', 'D') -- rule c)
	)
	AND v.vocabulary_id IN (c1.vocabulary_id, c2.vocabulary_id)
	AND v.latest_update IS NOT NULL -- only the current vocabularies
	AND r.relationship_id IN ('Mapped from','Value mapped from')
	AND r.invalid_reason IS NULL;

	--23. Post-processing (some concepts might be deprecated when they missed in source, so load_stage doesn't know about them and DO NOT deprecate relationships proper)
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
	SET valid_end_date = LEAST(c.valid_end_date, v.latest_update - 1),
		invalid_reason = 'D',
		standard_concept = NULL
	FROM vocabulary v
	WHERE v.vocabulary_id = c.vocabulary_id
		AND NOT EXISTS (
				SELECT 1
				FROM concept_relationship r
				WHERE r.concept_id_1 = c.concept_id
					AND r.invalid_reason IS NULL
					AND r.relationship_id IN (
						'Concept replaced by',
						'Concept same_as to',
						'Concept alt_to to',
						'Concept was_a to'
						)
				)
			AND v.latest_update IS NOT NULL -- only for current vocabularies
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

	/***********************************
	* Update the concept_synonym table *
	************************************/

	--24. Remove duplicates from concept_synonym_stage that might appear after concept_name corrections
	DELETE
	FROM concept_synonym_stage css
	WHERE EXISTS (
			SELECT 1
			FROM concept_synonym_stage css_int
			WHERE css_int.synonym_name = css.synonym_name
				AND css_int.synonym_concept_code = css.synonym_concept_code
				AND css_int.synonym_vocabulary_id = css.synonym_vocabulary_id
				AND css_int.language_concept_id = css.language_concept_id
				AND css_int.ctid > css.ctid
			);

	--25. Remove synonyms from concept_synonym_stage if synonym_name alreay exists in concept_stage, but only for English
	DELETE
	FROM concept_synonym_stage css
	WHERE EXISTS (
			SELECT 1
			FROM concept_stage cs
			WHERE cs.concept_code = css.synonym_concept_code
				AND cs.vocabulary_id = css.synonym_vocabulary_id
				AND LOWER(cs.concept_name) = LOWER(css.synonym_name)
				AND css.language_concept_id = 4180186
			);

	--26. Update synonym_concept_id
	UPDATE concept_synonym_stage css
	SET synonym_concept_id = cs.concept_id
	FROM concept_stage cs
	WHERE cs.concept_code = css.synonym_concept_code
		AND cs.vocabulary_id = css.synonym_vocabulary_id
		AND css.synonym_concept_id IS NULL;

	--27. Remove all existing synonyms for concepts that are in concept_stage
	--Synonyms are built from scratch each time, no life cycle
	DELETE
	FROM concept_synonym csyn
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_synonym_stage css_int
			WHERE css_int.synonym_concept_id = csyn.concept_id
				AND css_int.synonym_name = csyn.concept_synonym_name
				AND css_int.language_concept_id = csyn.language_concept_id
			)
		AND EXISTS (
			SELECT 1
			FROM concept_stage c_int
			WHERE c_int.concept_id = csyn.concept_id
			);

	--28. Add new synonyms
	INSERT INTO concept_synonym (
		concept_id,
		concept_synonym_name,
		language_concept_id
		)
	SELECT css.synonym_concept_id,
		css.synonym_name,
		css.language_concept_id
	FROM concept_synonym_stage css
	ON CONFLICT ON CONSTRAINT unique_synonyms DO NOTHING;

	--29. Fillig drug_strength
	--Special rules for RxNorm Extension: same as 'Maps to' rules, but records from deprecated concepts will be deleted
	DELETE
	FROM drug_strength
	WHERE drug_concept_id IN (
			SELECT c.concept_id
			FROM concept c
			JOIN vocabulary v ON c.vocabulary_id = v.vocabulary_id
			WHERE latest_update IS NOT NULL
				AND v.vocabulary_id <> 'RxNorm Extension'
			);

	--Replace with fresh records (only for 'RxNorm Extension')
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

	--Insert new records
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
		REGEXP_REPLACE(bs.concept_name, '.+Box of ([0-9]+).*', '\1')::INT2 AS box_size,
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

	--Delete drug if concept is deprecated (only for 'RxNorm Extension')
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

	--30. Fillig pack_content
	--Special rules for RxNorm Extension: same as 'Maps to' rules, but records from deprecated concepts will be deleted
	DELETE
	FROM pack_content
	WHERE pack_concept_id IN (
			SELECT c.concept_id
			FROM concept c
			JOIN vocabulary v ON c.vocabulary_id = v.vocabulary_id
			WHERE latest_update IS NOT NULL
				AND v.vocabulary_id <> 'RxNorm Extension'
			);

	--Replace with fresh records (only for 'RxNorm Extension')
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

	--Delete if concept is deprecated (only for 'RxNorm Extension')
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

	--31. Fix empty concept names, new rules [AVOF-2206]
	UPDATE concept c
	SET concept_name = i.concept_name
	FROM (
		SELECT c1.concept_id,
			vocabulary_pack.CutConceptName(CONCAT (
					'No name provided',
					' - mapped to ' || STRING_AGG(c2.concept_name, ' | ' ORDER BY c2.concept_name)
					)) AS concept_name
		FROM concept c1
		JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
		LEFT JOIN concept_relationship cr ON cr.concept_id_1 = c1.concept_id
			AND cr.relationship_id = 'Maps to'
			AND cr.invalid_reason IS NULL
		LEFT JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		WHERE c1.vocabulary_id IN (
				'Read',
				'GPI'
				)
			AND c1.concept_name = ' '
			AND v.latest_update IS NOT NULL --only for current vocabularies
		GROUP BY c1.concept_id
		) i
	WHERE i.concept_id = c.concept_id;

	--32. Check if current vocabulary exists in vocabulary_conversion table
	INSERT INTO vocabulary_conversion (
		vocabulary_id_v4,
		vocabulary_id_v5
		)
	SELECT -1,
		v.vocabulary_id
	FROM vocabulary v
	WHERE v.latest_update IS NOT NULL
	ON CONFLICT DO NOTHING;

	--33. Update latest_update on vocabulary_conversion
	UPDATE vocabulary_conversion vc
	SET latest_update = v.latest_update
	FROM vocabulary v
	WHERE v.latest_update IS NOT NULL
		AND v.vocabulary_id = vc.vocabulary_id_v5;

	--34. Clean up
	UPDATE vocabulary
	SET latest_update = NULL,
		dev_schema_name = NULL
	WHERE latest_update IS NOT NULL;

	DROP INDEX idx_crs_ids_generic_temp;

	--35. Final analysing for base tables
	ANALYZE concept;
	ANALYZE concept_relationship;
	ANALYZE concept_synonym;

	--36. Update concept_id fields in the "basic" manual tables for storing in audit
	PERFORM admin_pack.UpdateManualConceptID();

	--QA (should return NULL)
	--SELECT * FROM QA_TESTS.GET_CHECKS();
END;
$BODY$
LANGUAGE 'plpgsql'
SET client_min_messages = error;
