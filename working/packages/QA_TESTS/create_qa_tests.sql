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
	   concept_class_id   VARCHAR (100),
	   relationship_id    VARCHAR (100),
	   invalid_reason     VARCHAR (10),
	   cnt                int4,
	   cnt_delta          int4
	);
	*/
	CREATE TABLE IF NOT EXISTS DEV_SUMMARY AS SELECT * FROM DEVV5.DEV_SUMMARY WHERE 1 = 0;
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
			c.concept_class_id,
			NULL AS relationship_id,
			c.invalid_reason,
			COUNT (*) AS cnt,
			NULL AS cnt_delta
		FROM '||pCompareWith||'.concept c
		GROUP BY c.vocabulary_id, c.concept_class_id, c.invalid_reason';	
				
		WITH to_be_upserted as (
			SELECT 
				'concept'::varchar AS table_name,
				c.vocabulary_id AS vocabulary_id_1,
				NULL,
				c.concept_class_id,
				NULL AS relationship_id,
				c.invalid_reason,
				COUNT (*) AS cnt,
				NULL::int4 AS cnt_delta
			FROM concept c
			GROUP BY c.vocabulary_id, c.concept_class_id, c.invalid_reason
		),
		to_be_updated as (
			UPDATE DEV_SUMMARY dv 
			SET cnt_delta = up.cnt - dv.cnt
			FROM to_be_upserted up
			WHERE dv.cnt_delta IS NULL
			AND dv.table_name = up.table_name
			AND dv.vocabulary_id_1 = up.vocabulary_id_1
			AND dv.concept_class_id = up.concept_class_id
			AND COALESCE (dv.invalid_reason, 'X') = COALESCE (up.invalid_reason, 'X')
			RETURNING dv.*
		)
		INSERT INTO DEV_SUMMARY
			SELECT tpu.table_name, tpu.vocabulary_id_1, NULL, tpu.concept_class_id, NULL, tpu.invalid_reason, NULL::int4, tpu.cnt FROM to_be_upserted tpu WHERE (tpu.table_name, tpu.vocabulary_id_1, tpu.concept_class_id, COALESCE (tpu.invalid_reason, 'X')) 
			NOT IN (SELECT up.table_name, up.vocabulary_id_1, up.concept_class_id, COALESCE (up.invalid_reason, 'X') from to_be_updated up);
					
		--summary for concept_relationship
		EXECUTE '
        INSERT INTO DEV_SUMMARY
		SELECT 
			''concept_relationship'' AS table_name,
			c1.vocabulary_id,
			c2.vocabulary_id,
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
			SELECT tpu.table_name, tpu.vocabulary_id_1, tpu.vocabulary_id_2, NULL, tpu.relationship_id, tpu.invalid_reason, NULL::int4, tpu.cnt FROM to_be_upserted tpu WHERE (tpu.table_name, tpu.vocabulary_id_1, tpu.vocabulary_id_2, tpu.relationship_id, COALESCE (tpu.invalid_reason, 'X')) 
			NOT IN (SELECT up.table_name, up.vocabulary_id_1, up.vocabulary_id_2, up.relationship_id, COALESCE (up.invalid_reason, 'X') from to_be_updated up);

		--summary for concept_ancestor
        EXECUTE '
		INSERT INTO DEV_SUMMARY
		SELECT 
			''concept_ancestor'' AS table_name,
			c.vocabulary_id,
			NULL,
			NULL AS concept_class_id,
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
				NULL::varchar AS concept_class_id,
				NULL::varchar AS relationship_id,
				NULL::varchar AS invalid_reason,
				COUNT (*) AS cnt,
				NULL::int4 AS cnt_delta
			FROM concept c, concept_ancestor ca
			WHERE c.concept_id = CA.ANCESTOR_CONCEPT_ID
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
			SELECT tpu.table_name, tpu.vocabulary_id_1, NULL, NULL, NULL, NULL, NULL::int4, tpu.cnt FROM to_be_upserted tpu WHERE (tpu.table_name, tpu.vocabulary_id_1) 
			NOT IN (SELECT up.table_name, up.vocabulary_id_1 from to_be_updated up);
	END IF;

	IF iTable_name = 'concept'
	THEN
	RETURN QUERY
		SELECT 
			ds.vocabulary_id_1,
			NULL::varchar,
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
			ds.relationship_id,
			NULL::varchar,
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
		COALESCE (ds.cnt_delta, -cnt) AS cnt_delta
		FROM DEV_SUMMARY ds
		WHERE COALESCE (ds.cnt_delta, -cnt) <> 0 AND ds.table_name = iTable_name;
	END IF;
END;
$BODY$ LANGUAGE 'plpgsql' SECURITY INVOKER;

CREATE type qa_tests.type_get_checks AS (
	check_id int4,
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
SET work_mem='5GB'
AS $BODY$
	--relationships cycle
	SELECT 1 check_id,
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
		r.*
	FROM concept_relationship r,
		relationship rel
	WHERE r.relationship_id = rel.relationship_id
		AND r.concept_id_1 <> r.concept_id_2
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship r_int
			WHERE r_int.relationship_id = rel.reverse_relationship_id
				AND r_int.concept_id_1 = r.concept_id_2
				AND r_int.concept_id_2 = r.concept_id_1
			)
		AND COALESCE(checkid, 3) = 3

	UNION ALL

	--replacement relationships between different vocabularies (exclude RxNorm to RxNorm Ext OR RxNorm Ext to RxNorm replacement relationships)
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
		AND r.relationship_id IN (
			'Concept replaced by',
			'Concept same_as to',
			'Concept alt_to to',
			'Concept poss_eq to',
			'Concept was_a to'
			)
		AND COALESCE(checkid, 4) = 4

	UNION ALL

	--wrong relationships: 'Maps to' to 'D' or 'U'; replacement relationships to 'D'
	SELECT 5 check_id,
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

	-- wrong valid_start_date, valid_end_date or invalid_reason for the concept
	SELECT 7 check_id,
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
				AND c.vocabulary_id NOT IN (
					'CPT4',
					'HCPCS',
					'ICD9Proc'
					)
				)
			OR c.valid_start_date > COALESCE(vc.latest_update, CURRENT_DATE) + INTERVAL '15 year' --some concepts might be from near future (e.g. GGR, HCPCS) [AVOF-1015]/increased 20180928 for some NDC concepts
			OR c.valid_start_date < TO_DATE ('19000101', 'yyyymmdd') -- some concepts have a real date < 1970
			)
		AND COALESCE(checkid, 7) = 7

	UNION ALL

	-- wrong valid_start_date, valid_end_date or invalid_reason for the concept_relationship
	SELECT 8 check_id,
		r.*
	FROM concept_relationship r
	WHERE (
			(
				r.valid_end_date = TO_DATE('20991231', 'YYYYMMDD')
				AND r.invalid_reason IS NOT NULL
				)
			OR (
				r.valid_end_date <> TO_DATE('20991231', 'YYYYMMDD')
				AND r.invalid_reason IS NULL
				)
			OR r.valid_start_date > CURRENT_DATE
			)
		AND COALESCE(checkid, 8) = 8

	UNION ALL

	-- Rxnorm/Rxnorm Extension name duplications
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
				PARTITION BY LOWER(c.concept_name) ORDER BY c.vocabulary_id DESC,
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
			) d ON LOWER(c.concept_name) = LOWER(d.concept_name)
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
		AND COALESCE(checkid, 9) = 9

	UNION ALL*/

	--one concept has multiple replaces
	SELECT 10 check_id,
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
		AND COALESCE(checkid, 10) = 10;


$BODY$
language 'sql'
STABLE PARALLEL RESTRICTED SECURITY INVOKER;

CREATE OR REPLACE FUNCTION qa_tests.check_stage_tables () RETURNS void
AS $BODY$
DECLARE
z int;
BEGIN
  SELECT SUM (cnt) INTO z
	FROM (SELECT COUNT (*) cnt
			FROM concept_relationship_stage crs
				 LEFT JOIN vocabulary v1 ON v1.vocabulary_id = crs.vocabulary_id_1 AND v1.latest_update IS NOT NULL
				 LEFT JOIN vocabulary v2 ON v2.vocabulary_id = crs.vocabulary_id_2 AND v2.latest_update IS NOT NULL
		   WHERE COALESCE (v1.latest_update, v2.latest_update) IS NULL
		  UNION ALL
		  SELECT COUNT (*)
			FROM concept_stage cs LEFT JOIN vocabulary v ON v.vocabulary_id = cs.vocabulary_id AND v.latest_update IS NOT NULL
		   WHERE v.latest_update IS NULL
		  UNION ALL
		  SELECT COUNT (*)
			FROM concept_relationship_stage
		   WHERE    valid_start_date IS NULL
				 OR valid_end_date IS NULL
				 OR (invalid_reason IS NULL AND valid_end_date <> TO_DATE ('20991231', 'yyyymmdd'))
				 OR (invalid_reason IS NOT NULL AND valid_end_date = TO_DATE ('20991231', 'yyyymmdd'))
		  UNION ALL
		  SELECT COUNT (*)
			FROM concept_stage
		   WHERE    valid_start_date IS NULL
				 OR valid_end_date IS NULL
				 OR (invalid_reason IS NULL AND valid_end_date <> TO_DATE ('20991231', 'yyyymmdd') AND vocabulary_id NOT IN ('CPT4', 'HCPCS', 'ICD9Proc'))
				 OR (invalid_reason IS NOT NULL AND valid_end_date = TO_DATE ('20991231', 'yyyymmdd'))
				 OR valid_start_date < TO_DATE ('19000101', 'yyyymmdd') -- some concepts have a real date < 1970
		  UNION ALL
		  SELECT COUNT (*)
			FROM (SELECT relationship_id FROM concept_relationship_stage
				  EXCEPT
				  SELECT relationship_id FROM relationship) AS s0
		  UNION ALL
		  SELECT COUNT (*)
			FROM (SELECT concept_class_id FROM concept_stage
				  EXCEPT
				  SELECT concept_class_id FROM concept_class) AS s0
		  UNION ALL
		  SELECT COUNT (*)
			FROM (SELECT domain_id FROM concept_stage
				  EXCEPT
				  SELECT domain_id FROM domain) AS s0
		  UNION ALL
		  SELECT COUNT (*)
			FROM (SELECT vocabulary_id FROM concept_stage
				  EXCEPT
				  SELECT vocabulary_id FROM vocabulary) AS s0
		  UNION ALL
		  SELECT COUNT (*)
			FROM concept_stage
		   WHERE concept_name IS NULL OR domain_id IS NULL OR concept_class_id IS NULL OR concept_code IS NULL OR valid_start_date IS NULL OR valid_end_date IS NULL
		  UNION ALL
			SELECT COUNT (*)
			  FROM concept_relationship_stage
		  GROUP BY concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id
			HAVING COUNT (*) > 1
		  UNION ALL
			SELECT COUNT (*)
			  FROM concept_stage
		  GROUP BY concept_code, vocabulary_id
			HAVING COUNT (*) > 1
		  UNION ALL
			SELECT COUNT (*)
			  FROM pack_content_stage
		  GROUP BY pack_concept_code,
				   pack_vocabulary_id,
				   drug_concept_code,
				   drug_vocabulary_id,
				   amount
			HAVING COUNT (*) > 1
		  UNION ALL
			SELECT COUNT (*)
			  FROM drug_strength_stage
		  GROUP BY drug_concept_code,
				   vocabulary_id_1,
				   ingredient_concept_code,
				   vocabulary_id_2,
				   amount_value
			HAVING COUNT (*) > 1
		  UNION ALL
		  SELECT COUNT (*)
			FROM concept_relationship_stage crm
				 LEFT JOIN concept c1 ON c1.concept_code = crm.concept_code_1 AND c1.vocabulary_id = crm.vocabulary_id_1
				 LEFT JOIN concept_stage cs1 ON cs1.concept_code = crm.concept_code_1 AND cs1.vocabulary_id = crm.vocabulary_id_1
				 LEFT JOIN concept c2 ON c2.concept_code = crm.concept_code_2 AND c2.vocabulary_id = crm.vocabulary_id_2
				 LEFT JOIN concept_stage cs2 ON cs2.concept_code = crm.concept_code_2 AND cs2.vocabulary_id = crm.vocabulary_id_2
				 LEFT JOIN vocabulary v1 ON v1.vocabulary_id = crm.vocabulary_id_1
				 LEFT JOIN vocabulary v2 ON v2.vocabulary_id = crm.vocabulary_id_2
				 LEFT JOIN relationship rl ON rl.relationship_id = crm.relationship_id
		   WHERE    (c1.concept_code IS NULL AND cs1.concept_code IS NULL)
				 OR (c2.concept_code IS NULL AND cs2.concept_code IS NULL)
				 OR v1.vocabulary_id IS NULL
				 OR v2.vocabulary_id IS NULL
				 OR rl.relationship_id IS NULL
				 OR crm.valid_start_date > CURRENT_DATE
				 OR crm.valid_end_date < crm.valid_start_date) AS s1;

  IF z <> 0
  THEN
	  RAISE EXCEPTION '% error(s) found in stage tables. Check working\QA_stage_tables.sql', z;
  END IF;
END;
$BODY$ LANGUAGE 'plpgsql' SECURITY INVOKER;