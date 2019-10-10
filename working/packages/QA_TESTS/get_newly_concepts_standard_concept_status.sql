/*
Newly added concepts and their standard concept status

Usage: select * from qa_tests.get_newly_concepts_standard_concept_status();
will show the difference between current schema and prodv5

or: select * from qa_tests.get_newly_concepts_standard_concept_status(pCompareWith=>'devv5');
will show the difference between current schema and devv5 (you can use any schema name)
*/

CREATE TYPE qa_tests.type_get_newly_concepts_sc_status AS (
	vocabulary_id VARCHAR(20),
	new_standard_concept TEXT,
	cnt BIGINT
	);

CREATE OR REPLACE FUNCTION qa_tests.get_newly_concepts_standard_concept_status (pCompareWith VARCHAR DEFAULT 'PRODV5')
RETURNS SETOF qa_tests.type_get_newly_concepts_sc_status
SET work_mem='5GB'
AS $BODY$
BEGIN
	RETURN QUERY
	EXECUTE $$
		SELECT new.vocabulary_id,
			CASE 
				WHEN new.standard_concept = 'S'
					THEN 'Standard'
				WHEN new.standard_concept = 'C'
					THEN 'Classification'
				WHEN new.standard_concept IS NULL
					AND r.relationship_id = 'Maps to'
					THEN 'Non-standard with mapping'
				ELSE 'Non-standard without mapping'
				END AS new_standard_concept,
			count(*) AS cnt
		FROM concept new
		LEFT JOIN $$||pCompareWith||$$.concept old ON old.concept_id = new.concept_id
		LEFT JOIN concept_relationship r ON r.concept_id_1 = new.concept_id
			AND relationship_id = 'Maps to'
			AND r.invalid_reason IS NULL
			AND r.concept_id_1 <> r.concept_id_2
		WHERE old.concept_id IS NULL
		GROUP BY new.vocabulary_id,
			new.standard_concept,
			r.relationship_id$$;
END;
$BODY$
LANGUAGE 'plpgsql' STABLE SECURITY INVOKER;