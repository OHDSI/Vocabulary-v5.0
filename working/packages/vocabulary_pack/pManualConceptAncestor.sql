CREATE OR REPLACE FUNCTION vocabulary_pack.pManualConceptAncestor (pVocabularies TEXT)
RETURNS VOID AS
$BODY$
	/*
	Manual concept ancestor
	AVOF-1702
	Usage:
	1. run this script like
	DO $_$
	BEGIN
		PERFORM vocabulary_pack.pManualConceptAncestor(pVocabularies => 'CVX,SNOMED,RxNorm');
	END $_$;

	pVocabularies - comma separated vocabulary_id
	*/
DECLARE
	iVocabularies TEXT[] = (SELECT ARRAY_AGG(TRIM(voc)) FROM UNNEST(STRING_TO_ARRAY (pVocabularies,',')) voc);
	crlf TEXT:= '<br>';
	iSmallCA_emails TEXT:=(SELECT var_value FROM devv5.config$ WHERE var_name='concept_ancestor_email');
	cRet TEXT;
	cRet2 TEXT;
	cCAGroups INT:=50;
	cRecord RECORD;
	cStartTime TIMESTAMP:=CLOCK_TIMESTAMP();
	cWorkTime NUMERIC;
	cMissingVocabs TEXT;
BEGIN
	IF CURRENT_SCHEMA = 'devv5'
		THEN RAISE EXCEPTION 'You cannot use this script in the ''devv5''!';
	END IF;

	SELECT STRING_AGG(vi.vocabulary_id, ', ')
	INTO cMissingVocabs
	FROM UNNEST(iVocabularies) vi(vocabulary_id)
	LEFT JOIN vocabulary v USING (vocabulary_id)
	WHERE v.vocabulary_id IS NULL;

	IF cMissingVocabs IS NOT NULL THEN
		RAISE EXCEPTION 'Some vocabularies were not found: %', cMissingVocabs;
	END IF;

	--materialize main query
	CREATE TEMP TABLE temporary_ca_base$ ON COMMIT DROP AS
	SELECT r.concept_id_1 AS ancestor_concept_id,
		r.concept_id_2 AS descendant_concept_id,
		CASE 
			WHEN s.is_hierarchical = 1
				AND c1.standard_concept IS NOT NULL
				THEN 1
			ELSE 0
			END AS levels_of_separation
	FROM concept_relationship r
	JOIN relationship s ON s.relationship_id = r.relationship_id
		AND s.defines_ancestry = 1
	JOIN concept c1 ON c1.concept_id = r.concept_id_1
		AND c1.invalid_reason IS NULL
		AND (
			c1.vocabulary_id = ANY (iVocabularies)
			OR iVocabularies IS NULL
			)
	JOIN concept c2 ON c2.concept_id = r.concept_id_2
		AND c2.invalid_reason IS NULL
		AND (
			c2.vocabulary_id = ANY (iVocabularies)
			OR iVocabularies IS NULL
			)
	WHERE r.invalid_reason IS NULL;

	CREATE INDEX idx_temp_ca_base$ ON temporary_ca_base$ (ancestor_concept_id,descendant_concept_id,levels_of_separation) WITH (FILLFACTOR=100);
	ANALYZE temporary_ca_base$;

	--create a 'groups' table. we want to split a whole bunch of data into N separate chunks, this will give a good perfomance boost due to less temporary tablespace usage
	CREATE TEMP TABLE temporary_ca_groups$ ON COMMIT DROP AS
	SELECT s1.n,
		COALESCE(LAG(s1.ancestor_concept_id) OVER (
				ORDER BY s1.n
				), - 1) ancestor_concept_id_min,
		ancestor_concept_id ancestor_concept_id_max
	FROM (
		SELECT n,
			MAX(ancestor_concept_id) ancestor_concept_id
		FROM (
			SELECT NTILE(cCAGroups) OVER (
					ORDER BY ancestor_concept_id
					) n,
				ancestor_concept_id
			FROM temporary_ca_base$
			) AS s0
		GROUP BY n
		) AS s1;

	CREATE TEMP TABLE temporary_ca$ (LIKE concept_ancestor) ON COMMIT DROP;
	FOR cRecord IN (SELECT * FROM temporary_ca_groups$ ORDER BY n) LOOP
		INSERT INTO temporary_ca$
		WITH RECURSIVE hierarchy_concepts(ancestor_concept_id, descendant_concept_id, root_ancestor_concept_id, levels_of_separation, full_path) AS (
				SELECT ca.ancestor_concept_id,
					ca.descendant_concept_id,
					ca.ancestor_concept_id AS root_ancestor_concept_id,
					ca.levels_of_separation,
					ARRAY [descendant_concept_id] AS full_path
				FROM temporary_ca_base$ ca
				JOIN concept c ON c.concept_id = ca.ancestor_concept_id
					AND c.standard_concept IS NOT NULL --remove non-standard records in ancestor_concept_id
				WHERE ca.ancestor_concept_id > cRecord.ancestor_concept_id_min
					AND ca.ancestor_concept_id <= cRecord.ancestor_concept_id_max
				
				UNION ALL
				
				SELECT c.ancestor_concept_id,
					c.descendant_concept_id,
					root_ancestor_concept_id,
					hc.levels_of_separation + c.levels_of_separation AS levels_of_separation,
					hc.full_path || c.descendant_concept_id AS full_path
				FROM temporary_ca_base$ c
				JOIN hierarchy_concepts hc ON hc.descendant_concept_id = c.ancestor_concept_id
				WHERE c.descendant_concept_id <> ALL (full_path)
				)
		SELECT hc.root_ancestor_concept_id AS ancestor_concept_id,
			hc.descendant_concept_id,
			MIN(hc.levels_of_separation) AS min_levels_of_separation,
			MAX(hc.levels_of_separation) AS max_levels_of_separation
		FROM hierarchy_concepts hc
		GROUP BY hc.root_ancestor_concept_id,
			hc.descendant_concept_id;
	END LOOP;

	--remove non-standard records in descendant_concept_id
	DELETE
	FROM temporary_ca$ ca USING concept c
	WHERE c.standard_concept IS NULL
		AND c.concept_id = ca.descendant_concept_id;

	--Add connections to self for those vocabs having at least one concept in the concept_relationship table
	INSERT INTO temporary_ca$
	SELECT c.concept_id AS ancestor_concept_id,
		c.concept_id AS descendant_concept_id,
		0 AS min_levels_of_separation,
		0 AS max_levels_of_separation
	FROM concept c
	WHERE c.vocabulary_id IN (
			SELECT c_int.vocabulary_id
			FROM concept_relationship cr,
				concept c_int
			WHERE c_int.concept_id = cr.concept_id_1
				AND cr.invalid_reason IS NULL
			)
		AND c.invalid_reason IS NULL
		AND c.standard_concept IS NOT NULL;

	CREATE INDEX idx_tmp_ca$ ON temporary_ca$ (ancestor_concept_id, descendant_concept_id, min_levels_of_separation, max_levels_of_separation) WITH (FILLFACTOR=100);
	ANALYZE temporary_ca$;

	--Remove old records
	DELETE
	FROM concept_ancestor ca
	WHERE NOT EXISTS (
			SELECT 1
			FROM temporary_ca$ ca_int
			WHERE ca_int.ancestor_concept_id = ca.ancestor_concept_id
				AND ca_int.descendant_concept_id = ca.descendant_concept_id
			);

	--Add new records and update existing
	INSERT INTO concept_ancestor AS ca
	SELECT *
	FROM temporary_ca$
	ON CONFLICT ON CONSTRAINT xpkconcept_ancestor
	DO UPDATE
	SET min_levels_of_separation = excluded.min_levels_of_separation,
		max_levels_of_separation = excluded.max_levels_of_separation
	WHERE ca.* IS DISTINCT FROM excluded.*;

	ANALYZE concept_ancestor;

	cWorkTime:=ROUND((EXTRACT(EPOCH FROM CLOCK_TIMESTAMP()-cStartTime)/60)::NUMERIC,1);
	PERFORM devv5.SendMailHTML (iSmallCA_emails, 'Manual concept ancestor in '||UPPER(CURRENT_SCHEMA)||' [ok]', 'Manual concept ancestor in '||UPPER(CURRENT_SCHEMA)||' completed'||crlf||'Execution time: '||cWorkTime||' min');

	EXCEPTION WHEN OTHERS THEN
		GET STACKED DIAGNOSTICS cRet = PG_EXCEPTION_CONTEXT, cRet2 = PG_EXCEPTION_DETAIL;
		cRet:='ERROR: '||SQLERRM||crlf||'DETAIL: '||cRet2||crlf||'CONTEXT: '||REGEXP_REPLACE(cRet, '\r|\n|\r\n', crlf, 'g');
		cRet := SUBSTR ('Manual concept ancestor completed with errors:'||crlf||'<b>'||cRet||'</b>', 1, 10000);
		PERFORM devv5.SendMailHTML (iSmallCA_emails, 'Manual concept ancestor in '||UPPER(CURRENT_SCHEMA)||' [error]', cRet);
END;
$BODY$
LANGUAGE 'plpgsql'
SET client_min_messages = error;