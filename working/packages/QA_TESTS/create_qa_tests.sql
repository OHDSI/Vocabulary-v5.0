1. create package imitation
CREATE SCHEMA IF NOT EXISTS qa_tests AUTHORIZATION devv5;
ALTER DEFAULT PRIVILEGES IN SCHEMA qa_tests GRANT SELECT ON TABLES TO PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA qa_tests GRANT EXECUTE ON FUNCTIONS TO PUBLIC;
GRANT USAGE ON SCHEMA qa_tests TO PUBLIC;

2. in DEVV5:
CREATE TABLE DEVV5.DEV_SUMMARY
(
   table_name         VARCHAR (100),
   vocabulary_id_1    VARCHAR (100),
   vocabulary_id_2    VARCHAR (100),
   concept_class_id   VARCHAR (100),
   relationship_id    VARCHAR (100),
   invalid_reason     VARCHAR (10),
   cnt                int4,
   cnt_delta          int4
);

3. procedures:
CREATE OR REPLACE FUNCTION qa_tests.create_dev_table () RETURNS void 
SET client_min_messages = error
AS $BODY$
BEGIN
	/*
	CREATE TABLE DEVV5.DEV_SUMMARY
	(
	   table_name         VARCHAR (100),
	   vocabulary_id_1    VARCHAR (100),
	   vocabulary_id_2    VARCHAR (100),
	   domain_id          VARCHAR (100),
	   concept_class_id   VARCHAR (100),
	   relationship_id    VARCHAR (100),
	   invalid_reason     VARCHAR (10),
	   cnt                int4,
	   cnt_delta          int4
	);
	*/
	IF NOT PG_TRY_ADVISORY_XACT_LOCK(HASHTEXT(CURRENT_SCHEMA)) THEN RAISE EXCEPTION 'This function is already in use in another session'; END IF;
	CREATE TABLE IF NOT EXISTS DEV_SUMMARY (LIKE DEVV5.DEV_SUMMARY);
END ; 
$BODY$ LANGUAGE 'plpgsql' SECURITY INVOKER;


CREATE OR REPLACE FUNCTION qa_tests.purge_cache () RETURNS void AS $BODY$
BEGIN
	PERFORM qa_tests.create_dev_table();
	TRUNCATE TABLE DEV_SUMMARY;
END ; 
$BODY$ LANGUAGE 'plpgsql' SECURITY INVOKER;


CREATE OR REPLACE FUNCTION qa_tests.get_summary (
  table_name varchar, pCompareWith VARCHAR DEFAULT 'PRODV5'
)
RETURNS TABLE (
  vocabulary_id_1 varchar,
  vocabulary_id_2 varchar,
  domain_id varchar,
  concept_class_id varchar,
  relationship_id varchar,
  invalid_reason varchar,
  concept_delta integer
) AS
$BODY$
DECLARE
	z int2;
	iTable_name CONSTANT VARCHAR (100) := SUBSTR (LOWER (table_name), 0, 100);
BEGIN
	IF iTable_name NOT IN ('concept', 'concept_relationship', 'concept_ancestor')
	THEN
		RAISE EXCEPTION 'WRONG_TABLE_NAME';
	END IF;

	PERFORM qa_tests.create_dev_table();

	SELECT COUNT (*) INTO z FROM DEV_SUMMARY;
	--fill the table if it empty (caching)
	IF z = 0 THEN
		--summary for 'concept'
		EXECUTE '
		INSERT INTO DEV_SUMMARY
		SELECT 
			''concept'' AS table_name,
			c.vocabulary_id,
			NULL,
			c.domain_id,
			c.concept_class_id,
			NULL AS relationship_id,
			c.invalid_reason,
			COUNT (*) AS cnt,
			NULL AS cnt_delta
		FROM '||pCompareWith||'.concept c
		GROUP BY c.vocabulary_id, c.domain_id, c.concept_class_id, c.invalid_reason';
				
		WITH to_be_upserted as (
			SELECT 
				'concept'::varchar AS table_name,
				c.vocabulary_id AS vocabulary_id_1,
				NULL,
				c.domain_id,
				c.concept_class_id,
				NULL AS relationship_id,
				c.invalid_reason,
				COUNT (*) AS cnt,
				NULL::int4 AS cnt_delta
			FROM concept c
			GROUP BY c.vocabulary_id, c.domain_id, c.concept_class_id, c.invalid_reason
		),
		to_be_updated as (
			UPDATE DEV_SUMMARY dv 
			SET cnt_delta = up.cnt - dv.cnt
			FROM to_be_upserted up
			WHERE dv.cnt_delta IS NULL
			AND dv.table_name = up.table_name
			AND dv.vocabulary_id_1 = up.vocabulary_id_1
			AND dv.concept_class_id = up.concept_class_id
			AND dv.domain_id = up.domain_id
			AND COALESCE (dv.invalid_reason, 'X') = COALESCE (up.invalid_reason, 'X')
			RETURNING dv.*
		)
		INSERT INTO DEV_SUMMARY
			SELECT tpu.table_name, tpu.vocabulary_id_1, NULL, tpu.domain_id, tpu.concept_class_id, NULL, tpu.invalid_reason, NULL::int4, tpu.cnt
			FROM to_be_upserted tpu WHERE (tpu.table_name, tpu.vocabulary_id_1, tpu.domain_id, tpu.concept_class_id, COALESCE (tpu.invalid_reason, 'X'))
			NOT IN (SELECT up.table_name, up.vocabulary_id_1, up.domain_id, up.concept_class_id, COALESCE (up.invalid_reason, 'X') from to_be_updated up);
		
		--summary for concept_relationship
		EXECUTE '
		INSERT INTO DEV_SUMMARY
		SELECT 
			''concept_relationship'' AS table_name,
			c1.vocabulary_id,
			c2.vocabulary_id,
			NULL as domain_id,
			NULL AS concept_class_id,
			r.relationship_id,
			r.invalid_reason,
			COUNT (*) AS cnt,
			NULL AS cnt_delta
		FROM '||pCompareWith||'.concept c1, '||pCompareWith||'.concept c2, '||pCompareWith||'.concept_relationship r
		WHERE c1.concept_id = r.concept_id_1 AND c2.concept_id = r.concept_id_2
		GROUP BY c1.vocabulary_id, c2.vocabulary_id, r.relationship_id, r.invalid_reason';

		WITH to_be_upserted as (
			SELECT 
				'concept_relationship'::varchar AS table_name,
				c1.vocabulary_id AS vocabulary_id_1,
				c2.vocabulary_id AS vocabulary_id_2,
				NULL::varchar as domain_id,
				NULL::varchar AS concept_class_id,
				r.relationship_id,
				r.invalid_reason,
				COUNT (*) AS cnt,
				NULL::int4 AS cnt_delta
			FROM concept c1, concept c2, concept_relationship r
			WHERE c1.concept_id = r.concept_id_1 AND c2.concept_id = r.concept_id_2
			GROUP BY c1.vocabulary_id, c2.vocabulary_id, r.relationship_id, r.invalid_reason
		),
		to_be_updated as (
			UPDATE DEV_SUMMARY dv 
			SET cnt_delta = up.cnt - dv.cnt
			FROM to_be_upserted up
			WHERE dv.cnt_delta IS NULL
			AND dv.table_name = up.table_name
			AND dv.vocabulary_id_1 = up.vocabulary_id_1
			AND dv.vocabulary_id_2 = up.vocabulary_id_2
			AND dv.relationship_id = up.relationship_id
			AND COALESCE (dv.invalid_reason, 'X') = COALESCE (up.invalid_reason, 'X')
			RETURNING dv.*
		)
		INSERT INTO DEV_SUMMARY
			SELECT tpu.table_name, tpu.vocabulary_id_1, tpu.vocabulary_id_2, NULL, NULL, tpu.relationship_id, tpu.invalid_reason, NULL::int4, tpu.cnt
			FROM to_be_upserted tpu WHERE (tpu.table_name, tpu.vocabulary_id_1, tpu.vocabulary_id_2, tpu.relationship_id, COALESCE (tpu.invalid_reason, 'X')) 
			NOT IN (SELECT up.table_name, up.vocabulary_id_1, up.vocabulary_id_2, up.relationship_id, COALESCE (up.invalid_reason, 'X') from to_be_updated up);

		--summary for concept_ancestor
		EXECUTE '
		INSERT INTO DEV_SUMMARY
		SELECT 
			''concept_ancestor'' AS table_name,
			c.vocabulary_id,
			NULL,
			NULL AS concept_class_id,
			NULL as domain_id,
			NULL AS relationship_id,
			NULL AS invalid_reason,
			COUNT (*) AS cnt,
			NULL AS cnt_delta
		FROM '||pCompareWith||'.concept c, '||pCompareWith||'.concept_ancestor ca
		WHERE c.concept_id = ca.ancestor_concept_id
		GROUP BY c.vocabulary_id';

		WITH to_be_upserted as (
			SELECT 
				'concept_ancestor'::varchar AS table_name,
				c.vocabulary_id AS vocabulary_id_1,
				NULL::varchar,
				NULL::varchar,
				NULL::varchar AS concept_class_id,
				NULL::varchar AS relationship_id,
				NULL::varchar AS invalid_reason,
				COUNT (*) AS cnt,
				NULL::int4 AS cnt_delta
			FROM concept c, concept_ancestor ca
			WHERE c.concept_id = ca.ancestor_concept_id
			GROUP BY c.vocabulary_id
		),
		to_be_updated as (
			UPDATE DEV_SUMMARY dv 
			SET cnt_delta = up.cnt - dv.cnt
			FROM to_be_upserted up
			WHERE dv.cnt_delta IS NULL
			AND dv.table_name = up.table_name
			AND dv.vocabulary_id_1 = up.vocabulary_id_1
			RETURNING dv.*
		)
		INSERT INTO DEV_SUMMARY
			SELECT tpu.table_name, tpu.vocabulary_id_1, NULL, NULL, NULL, NULL, NULL, NULL::int4, tpu.cnt
			FROM to_be_upserted tpu WHERE (tpu.table_name, tpu.vocabulary_id_1) 
			NOT IN (SELECT up.table_name, up.vocabulary_id_1 from to_be_updated up);
	END IF;

	IF iTable_name = 'concept'
	THEN
	RETURN QUERY
		SELECT 
			ds.vocabulary_id_1,
			NULL::varchar,
			ds.domain_id,
			ds.concept_class_id,
			NULL::varchar,
			ds.invalid_reason,
			COALESCE (ds.cnt_delta, -cnt) AS cnt_delta
		FROM DEV_SUMMARY ds
		WHERE COALESCE (ds.cnt_delta, -cnt) <> 0 AND ds.table_name = iTable_name;

	ELSIF iTable_name = 'concept_relationship'
	THEN
	RETURN QUERY
		SELECT 
			ds.vocabulary_id_1,
			ds.vocabulary_id_2,
			NULL::varchar,
			NULL::varchar,
			ds.relationship_id,
			ds.invalid_reason,
			COALESCE (ds.cnt_delta, -cnt) AS cnt_delta
		FROM DEV_SUMMARY ds
		WHERE COALESCE (ds.cnt_delta, -cnt) <> 0 AND ds.table_name = iTable_name;

	ELSIF iTable_name = 'concept_ancestor'
	THEN
	RETURN QUERY
		SELECT 
		ds.vocabulary_id_1,
		NULL::varchar,
		NULL::varchar,
		NULL::varchar,
		NULL::varchar,
		NULL::varchar,
		COALESCE (ds.cnt_delta, -cnt) AS cnt_delta
		FROM DEV_SUMMARY ds
		WHERE COALESCE (ds.cnt_delta, -cnt) <> 0 AND ds.table_name = iTable_name;
	END IF;
END;
$BODY$ LANGUAGE 'plpgsql' SECURITY INVOKER;

CREATE type qa_tests.type_get_checks AS (
	check_id int4,
	check_name VARCHAR(1000),
	concept_id_1 int4,
	concept_id_2 int4,
	relationship_id VARCHAR(20),
	valid_start_date DATE,
	valid_end_date DATE,
	invalid_reason VARCHAR(1)
	);

CREATE OR REPLACE FUNCTION qa_tests.get_checks (checkid IN INT DEFAULT NULL) RETURNS 
SETOF qa_tests.type_get_checks
SET  max_parallel_workers_per_gather=4
SET work_mem='4GB'
AS $BODY$
	--relationships cycle
	SELECT 1 check_id,
		'relationships cycle' AS check_name,
		r.*
	FROM concept_relationship r,
		concept_relationship r_int
	WHERE r.invalid_reason IS NULL
		AND r_int.concept_id_1 = r.concept_id_2
		AND r_int.concept_id_2 = r.concept_id_1
		AND r.concept_id_1 <> r.concept_id_2
		AND r_int.relationship_id = r.relationship_id
		AND r_int.invalid_reason IS NULL
		AND COALESCE(checkid, 1) = 1

	UNION ALL

	--opposing relationships between same pair of concepts
	SELECT 2 check_id,
		'opposing relationships between same pair of concepts' AS check_name,
		r.*
	FROM concept_relationship r,
		concept_relationship r_int,
		relationship rel
	WHERE r.invalid_reason IS NULL
		AND r.relationship_id = rel.relationship_id
		AND r_int.concept_id_1 = r.concept_id_1
		AND r_int.concept_id_2 = r.concept_id_2
		AND r.concept_id_1 <> r.concept_id_2
		AND r_int.relationship_id = rel.reverse_relationship_id
		AND r_int.invalid_reason IS NULL
		AND COALESCE(checkid, 2) = 2

	UNION ALL

	--relationships without reverse
	SELECT 3 check_id,
		'relationships without reverse' AS check_name,
		r.*
	FROM concept_relationship r,
		relationship rel
	WHERE r.relationship_id = rel.relationship_id
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship r_int
			WHERE r_int.relationship_id = rel.reverse_relationship_id
				AND r_int.concept_id_1 = r.concept_id_2
				AND r_int.concept_id_2 = r.concept_id_1
			)
		AND COALESCE(checkid, 3) = 3

	UNION ALL

	/*--replacement relationships between different vocabularies (exclude RxNorm to RxNorm Ext OR RxNorm Ext to RxNorm OR SNOMED<->SNOMED Veterinary replacement relationships)
		--deprecated 20190227
		SELECT 4 check_id,
			r.*
		FROM concept_relationship r,
			concept c1,
			concept c2
		WHERE r.invalid_reason IS NULL
			AND r.concept_id_1 <> r.concept_id_2
			AND c1.concept_id = r.concept_id_1
			AND c2.concept_id = r.concept_id_2
			AND c1.vocabulary_id <> c2.vocabulary_id
			AND NOT (
				c1.vocabulary_id IN (
					'RxNorm',
					'RxNorm Extension'
					)
				AND c2.vocabulary_id IN (
					'RxNorm',
					'RxNorm Extension'
					)
				)
			AND NOT (
				c1.vocabulary_id IN (
					'SNOMED',
					'SNOMED Veterinary'
					)
				AND c2.vocabulary_id IN (
					'SNOMED',
					'SNOMED Veterinary'
					)
				)			
			AND r.relationship_id IN (
				'Concept replaced by',
				'Concept same_as to',
				'Concept alt_to to',
				'Concept poss_eq to',
				'Concept was_a to'
				)
			AND COALESCE(checkid, 4) = 4

		UNION ALL*/
	--wrong relationships: 'Maps to' to 'D' or 'U'; replacement relationships to 'D'
	SELECT 5 check_id, $$wrong relationships: 'Maps to' TO 'D' OR 'U'; replacement relationships TO 'D'$$ AS check_name,
		r.*
	FROM concept c2,
		concept_relationship r
	WHERE c2.concept_id = r.concept_id_2
		AND (
			(
				c2.invalid_reason IN (
					'D',
					'U'
					)
				AND r.relationship_id = 'Maps to'
				)
			OR (
				c2.invalid_reason = 'D'
				AND r.relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept poss_eq to',
					'Concept was_a to'
					)
				)
			)
		AND r.invalid_reason IS NULL
		AND COALESCE(checkid, 5) = 5

	UNION ALL

	--direct and reverse mappings are not same
	SELECT 6 check_id,
		'direct and reverse mappings are not same' AS check_name,
		r.*
	FROM concept_relationship r,
		relationship rel,
		concept_relationship r_int
	WHERE r.relationship_id = rel.relationship_id
		AND r_int.relationship_id = rel.reverse_relationship_id
		AND r_int.concept_id_1 = r.concept_id_2
		AND r_int.concept_id_2 = r.concept_id_1
		AND (
			r.valid_end_date <> r_int.valid_end_date
			OR COALESCE(r.invalid_reason, 'X') <> COALESCE(r_int.invalid_reason, 'X')
			)
		AND COALESCE(checkid, 6) = 6

	UNION ALL

	--wrong valid_start_date, valid_end_date or invalid_reason for the concept
	SELECT 7 check_id,
		'wrong valid_start_date, valid_end_date or invalid_reason for the concept' AS check_name,
		c.concept_id,
		NULL,
		c.vocabulary_id,
		c.valid_start_date,
		c.valid_end_date,
		c.invalid_reason
	FROM concept c
	JOIN vocabulary_conversion vc ON vc.vocabulary_id_v5 = c.vocabulary_id
	WHERE (
			c.valid_end_date < c.valid_start_date
			OR (
				c.valid_end_date = TO_DATE('20991231', 'YYYYMMDD')
				AND c.invalid_reason IS NOT NULL
				)
			OR (
				c.valid_end_date <> TO_DATE('20991231', 'YYYYMMDD')
				AND c.invalid_reason IS NULL
				AND c.vocabulary_id NOT IN (SELECT TRIM(v) FROM UNNEST(STRING_TO_ARRAY((SELECT var_value FROM devv5.config$ WHERE var_name='special_vocabularies'),',')) v)
				)
			OR c.valid_start_date > COALESCE(vc.latest_update, CURRENT_DATE) + INTERVAL '15 year' --some concepts might be from near future (e.g. GGR, HCPCS) [AVOF-1015]/increased 20180928 for some NDC concepts
			OR c.valid_start_date < TO_DATE('19000101', 'yyyymmdd') -- some concepts have a real date < 1970
			)
		AND COALESCE(checkid, 7) = 7

	UNION ALL

	--wrong valid_start_date, valid_end_date or invalid_reason for the concept_relationship
	SELECT 8 check_id,
		'wrong valid_start_date, valid_end_date or invalid_reason for the concept_relationship' AS check_name,
		s0.concept_id_1,
		s0.concept_id_2,
		s0.relationship_id,
		s0.valid_start_date,
		s0.valid_end_date,
		s0.invalid_reason
	FROM (
		SELECT r.*,
			CASE 
				WHEN (
						r.valid_end_date = TO_DATE('20991231', 'YYYYMMDD')
						AND r.invalid_reason IS NOT NULL
						)
					OR (
						r.valid_end_date <> TO_DATE('20991231', 'YYYYMMDD')
						AND r.invalid_reason IS NULL
						)
					OR (
						r.valid_start_date > CURRENT_DATE
						AND r.valid_start_date IS DISTINCT FROM GREATEST(vc1.latest_update, vc2.latest_update)
						)
					OR r.valid_start_date < TO_DATE('19700101', 'yyyymmdd')
					THEN 1
				ELSE 0
				END check_flag
		FROM concept_relationship r
		JOIN concept c1 ON c1.concept_id = r.concept_id_1
		JOIN concept c2 ON c2.concept_id = r.concept_id_2
		LEFT JOIN vocabulary_conversion vc1 ON vc1.vocabulary_id_v5 = c1.vocabulary_id
		LEFT JOIN vocabulary_conversion vc2 ON vc2.vocabulary_id_v5 = c2.vocabulary_id
		) AS s0
	WHERE check_flag = 1
		AND COALESCE(checkid, 8) = 8

	UNION ALL

	--RxE to Rx name duplications
	--tempopary disabled
	/*
	SELECT 9 check_id,
		'RxE to Rx name duplications' AS check_name,
		c2.concept_id,
		c1.concept_id,
		'Concept replaced by' AS relationship_id,
		NULL AS valid_start_date,
		NULL AS valid_end_date,
		NULL AS invalid_reason
	FROM concept c1
	JOIN concept c2 ON upper(c2.concept_name) = upper(c1.concept_name)
		AND c2.concept_class_id = c1.concept_class_id
		AND c2.vocabulary_id = 'RxNorm Extension'
		AND c2.invalid_reason IS NULL
	WHERE c1.vocabulary_id = 'RxNorm'
		AND c1.standard_concept = 'S'
		AND COALESCE(checkid, 9) = 9

	UNION ALL*/

	--Rxnorm/Rxnorm Extension name duplications
	--tempopary disabled (never used)
	/*SELECT 9 check_id,
			c_int.concept_id_1,
			c_int.concept_id_2,
			'Concept replaced by' AS relationship_id,
			NULL AS valid_start_date,
			NULL AS valid_end_date,
			NULL AS invalid_reason
		FROM (
			SELECT FIRST_VALUE(c.concept_id) OVER (
					PARTITION BY d.concept_name ORDER BY c.vocabulary_id DESC,
						c.concept_name,
						c.concept_id
					) AS concept_id_1,
				c.concept_id AS concept_id_2,
				c.vocabulary_id
			FROM concept c
			JOIN (
				SELECT LOWER(concept_name) AS concept_name,
					concept_class_id
				FROM concept c_int
				WHERE c_int.vocabulary_id LIKE 'RxNorm%'
					AND c_int.concept_name NOT LIKE '%...%'
					AND c_int.invalid_reason IS NULL
				GROUP BY LOWER(c_int.concept_name),
					c_int.concept_class_id
				HAVING COUNT(*) > 1
				
				EXCEPT
				
				SELECT LOWER(c_int.concept_name),
					c_int.concept_class_id
				FROM concept c_int
				WHERE c_int.vocabulary_id = 'RxNorm'
					AND c_int.concept_name NOT LIKE '%...%'
					AND c_int.invalid_reason IS NULL
				GROUP BY LOWER(c_int.concept_name),
					c_int.concept_class_id
				HAVING COUNT(*) > 1
				) d ON LOWER(c.concept_name) = d.concept_name
				AND c.vocabulary_id LIKE 'RxNorm%'
				AND c.invalid_reason IS NULL
			) c_int
		JOIN concept c1 ON c1.concept_id = c_int.concept_id_1
		JOIN concept c2 ON c2.concept_id = c_int.concept_id_2
		WHERE c_int.concept_id_1 <> c_int.concept_id_2
			AND NOT (
				c1.vocabulary_id = 'RxNorm'
				AND c2.vocabulary_id = 'RxNorm'
				)
			--AVOF-1434 (20190125)
			AND NOT EXISTS (
				SELECT 1
				FROM drug_strength ds1,
					drug_strength ds2
				WHERE ds1.drug_concept_id = c1.concept_id
					AND ds2.drug_concept_id = c2.concept_id
					AND ds1.ingredient_concept_id = ds2.ingredient_concept_id
					AND ds1.amount_value = ds2.numerator_value
					AND ds1.amount_unit_concept_id = ds2.numerator_unit_concept_id
					AND ds1.amount_unit_concept_id IN (
						9325,
						9324
						)
				)
			AND COALESCE(checkid, 9) = 9

		UNION ALL*/
	--one concept has multiple replaces
	SELECT 10 check_id,
		'one concept has multiple replaces' AS check_name,
		r.*
	FROM concept_relationship r
	WHERE (
			r.concept_id_1,
			r.relationship_id
			) IN (
			SELECT r_int.concept_id_1,
				r_int.relationship_id
			FROM concept_relationship r_int
			WHERE r_int.relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept poss_eq to',
					'Concept was_a to'
					)
				AND r_int.invalid_reason IS NULL
			GROUP BY r_int.concept_id_1,
				r_int.relationship_id
			HAVING COUNT(*) > 1
			)
		AND COALESCE(checkid, 10) = 10

	UNION ALL

	--wrong concept_name [AVOF-1438]
	SELECT 11 check_id,
		'wrong concept_name ("OMOP generated", but should be OMOPxxx)' AS check_name,
		c.concept_id,
		NULL,
		c.vocabulary_id,
		c.valid_start_date,
		c.valid_end_date,
		c.invalid_reason
	FROM concept c
	WHERE c.domain_id <> 'Metadata'
		AND c.concept_code = 'OMOP generated'
		AND COALESCE(checkid, 11) = 11

	UNION ALL

	--duplicate 'OMOP generated' concepts [AVOF-2000]
	SELECT 12 check_id,
		'duplicate ''OMOP generated'' concepts' AS check_name,
		s0.concept_id,
		NULL,
		s0.vocabulary_id,
		s0.valid_start_date,
		s0.valid_end_date,
		NULL
	FROM (
		SELECT c.concept_id,
			c.vocabulary_id,
			c.valid_start_date,
			c.valid_end_date,
			COUNT(*) OVER (
				PARTITION BY c.concept_name,
				c.concept_code,
				c.vocabulary_id
				) AS cnt
		FROM concept c
		WHERE c.invalid_reason IS NULL
			AND c.concept_code = 'OMOP generated'
		) AS s0
	WHERE s0.cnt > 1
		AND COALESCE(checkid, 12) = 12

	UNION ALL

	--duplicate concept_name in 'OMOP Extension' vocabulary
	SELECT 13 check_id,
		'duplicate concept_name in ''OMOP Extension'' vocabulary: ' || s0.concept_name AS check_name,
		s0.concept_id,
		NULL,
		s0.vocabulary_id,
		s0.valid_start_date,
		s0.valid_end_date,
		s0.invalid_reason
	FROM (
		SELECT c.concept_id,
			c.concept_name,
			c.vocabulary_id,
			c.valid_start_date,
			c.valid_end_date,
			c.invalid_reason,
			COUNT(c.concept_code) OVER (PARTITION BY LOWER(c.concept_name)) AS cnt
		FROM concept c
		WHERE c.vocabulary_id = 'OMOP Extension'
			AND c.invalid_reason IS NULL
		) s0
	WHERE s0.cnt > 1
		AND COALESCE(checkid, 13) = 13;

$BODY$
language 'sql'
STABLE PARALLEL RESTRICTED SECURITY INVOKER;

CREATE OR REPLACE FUNCTION qa_tests.check_stage_tables ()
RETURNS TABLE (
	error_text TEXT,
	rows_count BIGINT
) AS
$BODY$
BEGIN
	RETURN QUERY
	SELECT reason, COUNT(*) FROM (
		--concept_relationship_stage
		SELECT
			CASE WHEN v1.vocabulary_id IS NOT NULL AND v2.vocabulary_id IS NOT NULL
					AND COALESCE (v1.latest_update, v2.latest_update) IS NULL THEN 'concept_relationship_stage contains a vocabulary, that is not affected by the SetLatestUpdate: '||crs.vocabulary_id_1
				WHEN crs.valid_start_date IS NULL THEN 'concept_relationship_stage.valid_start_date is null'
				WHEN crs.valid_end_date IS NULL THEN 'concept_relationship_stage.valid_end_date is null'
				WHEN ((crs.invalid_reason IS NULL AND crs.valid_end_date <> TO_DATE('20991231', 'yyyymmdd'))
					OR (crs.invalid_reason IS NOT NULL AND crs.valid_end_date = TO_DATE('20991231', 'yyyymmdd')))
					THEN 'wrong concept_relationship_stage.invalid_reason: '||COALESCE(crs.invalid_reason,'NULL')||' for '||TO_CHAR(crs.valid_end_date,'YYYYMMDD')
				WHEN crs.valid_end_date < crs.valid_start_date THEN 'concept_relationship_stage.valid_end_date < concept_relationship_stage.valid_start_date: '||TO_CHAR(crs.valid_end_date,'YYYYMMDD')||'+'||TO_CHAR(crs.valid_start_date,'YYYYMMDD')
				WHEN date_trunc('day', (crs.valid_start_date)) <> crs.valid_start_date THEN 'wrong format for concept_relationship_stage.valid_start_date (not truncated): '||TO_CHAR(crs.valid_start_date,'YYYYMMDD HH24:MI:SS')
				WHEN date_trunc('day', (crs.valid_end_date)) <> crs.valid_end_date THEN 'wrong format for concept_relationship_stage.valid_end_date (not truncated to YYYYMMDD): '||TO_CHAR(crs.valid_end_date,'YYYYMMDD HH24:MI:SS')
				WHEN COALESCE(crs.invalid_reason, 'D') <> 'D' THEN 'wrong value for concept_relationship_stage.invalid_reason: '||crs.invalid_reason
				WHEN crs.concept_code_1 = '' THEN 'concept_relationship_stage contains concept_code_1 which is empty ('''')'
				WHEN crs.concept_code_2 = '' THEN 'concept_relationship_stage contains concept_code_2 which is empty ('''')'
				WHEN c1.concept_code IS NULL AND cs1.concept_code IS NULL THEN 'concept_code_1+vocabulary_id_1 not found in the concept/concept_stage: '||crs.concept_code_1||'+'||crs.vocabulary_id_1
				WHEN c2.concept_code IS NULL AND cs2.concept_code IS NULL THEN 'concept_code_2+vocabulary_id_2 not found in the concept/concept_stage: '||crs.concept_code_2||'+'||crs.vocabulary_id_2
				WHEN v1.vocabulary_id IS NULL THEN 'vocabulary_id_1 not found in the vocabulary: '||CASE WHEN crs.vocabulary_id_1='' THEN '''''' ELSE crs.vocabulary_id_1 END
				WHEN v2.vocabulary_id IS NULL THEN 'vocabulary_id_2 not found in the vocabulary: '||CASE WHEN crs.vocabulary_id_2='' THEN '''''' ELSE crs.vocabulary_id_2 END
				WHEN rl.relationship_id IS NULL THEN 'relationship_id not found in the relationship: '||CASE WHEN crs.relationship_id='' THEN '''''' ELSE crs.relationship_id END
				WHEN crs.valid_start_date > CURRENT_DATE AND crs.valid_start_date<>v1.latest_update THEN 'concept_relationship_stage.valid_start_date is greater than the current date: '||TO_CHAR(crs.valid_start_date,'YYYYMMDD')
				WHEN crs.valid_start_date < TO_DATE ('19000101', 'yyyymmdd') THEN 'concept_relationship_stage.valid_start_date is before 1900: '||TO_CHAR(crs.valid_start_date,'YYYYMMDD')
				ELSE NULL
			END AS reason
			FROM concept_relationship_stage crs
				LEFT JOIN concept c1 ON c1.concept_code = crs.concept_code_1 AND c1.vocabulary_id = crs.vocabulary_id_1
				LEFT JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_1 AND cs1.vocabulary_id = crs.vocabulary_id_1
				LEFT JOIN concept c2 ON c2.concept_code = crs.concept_code_2 AND c2.vocabulary_id = crs.vocabulary_id_2
				LEFT JOIN concept_stage cs2 ON cs2.concept_code = crs.concept_code_2 AND cs2.vocabulary_id = crs.vocabulary_id_2
				LEFT JOIN vocabulary v1 ON v1.vocabulary_id = crs.vocabulary_id_1
				LEFT JOIN vocabulary v2 ON v2.vocabulary_id = crs.vocabulary_id_2
				LEFT JOIN relationship rl ON rl.relationship_id = crs.relationship_id
		UNION ALL
		SELECT
			'duplicates in concept_relationship_stage were found: '||crs.concept_code_1||'+'||crs.concept_code_2||'+'||crs.vocabulary_id_1||'+'||crs.vocabulary_id_2||'+'||crs.relationship_id AS reason
			FROM concept_relationship_stage crs
			GROUP BY crs.concept_code_1, crs.concept_code_2, crs.vocabulary_id_1, crs.vocabulary_id_2, crs.relationship_id HAVING COUNT (*) > 1
		UNION ALL
		--concept_stage
		SELECT
			CASE WHEN v.vocabulary_id IS NOT NULL AND v.latest_update IS NULL THEN 'concept_stage contains a vocabulary, that is not affected by the SetLatestUpdate: '||cs.vocabulary_id
				WHEN v.vocabulary_id IS NULL THEN 'concept_stage.vocabulary_id not found in the vocabulary: '||CASE WHEN cs.vocabulary_id='' THEN '''''' ELSE cs.vocabulary_id END
				WHEN cs.valid_end_date < cs.valid_start_date THEN
					--it's absolutely ok if valid_end_date < valid_start_date when valid_start_date = latest_update, because generic_update keeps the old date. check it
					CASE WHEN cs.valid_start_date<>v.latest_update THEN
						'concept_stage.valid_end_date < concept_stage.valid_start_date: '||TO_CHAR(cs.valid_end_date,'YYYYMMDD')||'+'||TO_CHAR(cs.valid_start_date,'YYYYMMDD')
					ELSE
						--but even if valid_start_date = latest_update we should check what if valid_start_date in the 'concept' bigger than valid_end_date in the 'concept_stage'?
						CASE WHEN cs.valid_end_date<c.valid_start_date THEN
							'concept_stage.valid_end_date < concept.valid_start_date: '||TO_CHAR(cs.valid_end_date,'YYYYMMDD')||'+'||TO_CHAR(c.valid_start_date,'YYYYMMDD')
						END
					END
				WHEN COALESCE(cs.invalid_reason, 'D') NOT IN ('D','U') THEN 'wrong value for concept_stage.invalid_reason: '||CASE WHEN cs.invalid_reason='' THEN '''''' ELSE cs.invalid_reason END
				WHEN date_trunc('day', (cs.valid_start_date)) <> cs.valid_start_date THEN 'wrong format for concept_stage.valid_start_date (not truncated): '||TO_CHAR(cs.valid_start_date,'YYYYMMDD HH24:MI:SS')
				WHEN date_trunc('day', (cs.valid_end_date)) <> cs.valid_end_date THEN 'wrong format for concept_stage.valid_end_date (not truncated to YYYYMMDD): '||TO_CHAR(cs.valid_end_date,'YYYYMMDD HH24:MI:SS')
				WHEN (((cs.invalid_reason IS NULL AND cs.valid_end_date <> TO_DATE('20991231', 'yyyymmdd')) AND cs.vocabulary_id NOT IN (SELECT TRIM(v) FROM UNNEST(STRING_TO_ARRAY((SELECT var_value FROM devv5.config$ WHERE var_name='special_vocabularies'),',')) v))
					OR (cs.invalid_reason IS NOT NULL AND cs.valid_end_date = TO_DATE('20991231', 'yyyymmdd'))) THEN 'wrong concept_stage.invalid_reason: '||COALESCE(cs.invalid_reason,'NULL')||' for '||TO_CHAR(cs.valid_end_date,'YYYYMMDD')
				WHEN d.domain_id IS NULL AND cs.domain_id IS NOT NULL THEN 'domain_id not found in the domain: '||CASE WHEN cs.domain_id='' THEN '''''' ELSE cs.domain_id END
				WHEN cc.concept_class_id IS NULL AND cs.concept_class_id IS NOT NULL THEN 'concept_class_id not found in the concept_class: '||CASE WHEN cs.concept_class_id='' THEN '''''' ELSE cs.concept_class_id END
				WHEN COALESCE(cs.standard_concept, 'S') NOT IN ('C','S') THEN 'wrong value for standard_concept: '||CASE WHEN cs.standard_concept='' THEN '''''' ELSE cs.standard_concept END
				WHEN cs.valid_start_date IS NULL THEN 'concept_stage.valid_start_date is null'
				WHEN cs.valid_end_date IS NULL THEN 'concept_stage.valid_end_date is null'
				WHEN cs.valid_start_date < TO_DATE ('19000101', 'yyyymmdd') THEN 'concept_stage.valid_start_date is before 1900: '||TO_CHAR(cs.valid_start_date,'YYYYMMDD')
				WHEN COALESCE(cs.concept_name, '') = '' THEN 'empty concept_stage.concept_name ('''')'
				WHEN cs.concept_code = '' THEN 'empty concept_stage.concept_code ('''')'
				WHEN cs.concept_name<>TRIM(cs.concept_name) THEN 'concept_stage.concept_name not trimmed for concept_code: '||cs.concept_code
				WHEN cs.concept_code<>TRIM(cs.concept_code) THEN 'concept_stage.concept_code not trimmed for concept_name: '||cs.concept_name
				ELSE NULL
			END AS reason
		FROM concept_stage cs
			LEFT JOIN vocabulary v ON v.vocabulary_id = cs.vocabulary_id
			LEFT JOIN domain d ON d.domain_id = cs.domain_id
			LEFT JOIN concept_class cc ON cc.concept_class_id = cs.concept_class_id
			LEFT JOIN concept c ON c.concept_code = cs.concept_code AND c.vocabulary_id=cs.vocabulary_id
		UNION ALL
		--concept_synonym_stage
		SELECT
			CASE WHEN v.vocabulary_id IS NOT NULL AND v.latest_update IS NULL THEN 'concept_synonym_stage contains a vocabulary, that is not affected by the SetLatestUpdate: '||css.synonym_vocabulary_id
				WHEN v.vocabulary_id IS NULL THEN 'concept_synonym_stage.synonym_vocabulary_id not found in the vocabulary: '||CASE WHEN css.synonym_vocabulary_id='' THEN '''''' ELSE css.synonym_vocabulary_id END
				WHEN css.synonym_name = '' THEN 'empty synonym_name ('''')'
				WHEN css.synonym_concept_code = '' THEN 'empty synonym_concept_code ('''')'
				WHEN c.concept_code IS NULL AND cs.concept_code IS NULL THEN 'synonym_concept_code+synonym_vocabulary_id not found in the concept/concept_stage: '||css.synonym_concept_code||'+'||css.synonym_vocabulary_id
				WHEN css.synonym_name<>TRIM(css.synonym_name) THEN 'synonym_name not trimmed for concept_code: '||css.synonym_concept_code
				WHEN css.synonym_concept_code<>TRIM(css.synonym_concept_code) THEN 'synonym_concept_code not trimmed for synonym_name: '||css.synonym_name
				WHEN c_lng.concept_id IS NULL THEN 'language_concept_id not found in the concept: '||css.language_concept_id
				ELSE NULL
			END AS reason
		FROM concept_synonym_stage css
			LEFT JOIN vocabulary v ON v.vocabulary_id = css.synonym_vocabulary_id
			LEFT JOIN concept c ON c.concept_code = css.synonym_concept_code AND c.vocabulary_id = css.synonym_vocabulary_id
			LEFT JOIN concept_stage cs ON cs.concept_code = css.synonym_concept_code AND cs.vocabulary_id = css.synonym_vocabulary_id
			LEFT JOIN concept c_lng ON c_lng.concept_id = css.language_concept_id
		UNION ALL
		SELECT
			'duplicates in concept_stage were found: '||cs.concept_code||'+'||cs.vocabulary_id AS reason
			FROM concept_stage cs
			GROUP BY cs.concept_code, cs.vocabulary_id HAVING COUNT (*) > 1
		UNION ALL
		--pack_content_stage
		SELECT
			'duplicates in pack_content_stage were found: '||pcs.pack_concept_code||'+'||pcs.pack_vocabulary_id||pcs.drug_concept_code||'+'||pcs.drug_vocabulary_id||'+'||pcs.amount AS reason
			FROM pack_content_stage pcs
			GROUP BY pcs.pack_concept_code, pcs.pack_vocabulary_id, pcs.drug_concept_code, pcs.drug_vocabulary_id, pcs.amount HAVING COUNT (*) > 1
		UNION ALL
		--drug_strength_stage
		SELECT
			'duplicates in drug_strength_stage were found: '||dcs.drug_concept_code||'+'||dcs.vocabulary_id_1||
				dcs.ingredient_concept_code||'+'||dcs.vocabulary_id_2||'+'||TO_CHAR(dcs.amount_value, 'FM9999999999999999999990.999999999999999999999') AS reason
			FROM drug_strength_stage dcs
			GROUP BY dcs.drug_concept_code, dcs.vocabulary_id_1, dcs.ingredient_concept_code, dcs.vocabulary_id_2, dcs.amount_value HAVING COUNT (*) > 1
	) AS s0
	WHERE reason IS NOT NULL
	GROUP BY reason;
END;
$BODY$ LANGUAGE 'plpgsql' SECURITY INVOKER;