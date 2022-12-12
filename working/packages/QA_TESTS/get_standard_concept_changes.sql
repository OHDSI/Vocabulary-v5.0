/*
Standard concept changes

Usage: select * from qa_tests.get_standard_concept_changes();
will show the difference between current schema and prodv5

or: select * from qa_tests.get_standard_concept_changes(pCompareWith=>'devv5');
will show the difference between current schema and devv5 (you can use any schema name)
*/

CREATE TYPE qa_tests.type_get_standard_concept_changes AS (
	vocabulary_id VARCHAR(20),
	old_standard_concept TEXT,
	new_standard_concept TEXT,
	cnt BIGINT
	);

CREATE OR REPLACE FUNCTION qa_tests.get_standard_concept_changes (pCompareWith VARCHAR DEFAULT 'prodv5')
RETURNS SETOF qa_tests.type_get_standard_concept_changes
AS $BODY$
BEGIN
	RETURN QUERY
	EXECUTE FORMAT ($$
		SELECT vocabulary_id,
			CASE 
				WHEN i.old_standard_concept = 'S'
					THEN 'Standard'
				WHEN i.old_standard_concept = 'C'
					AND i.old_relationship_id = 'Maps to'
					THEN 'Classification with mapping'
				WHEN i.old_standard_concept = 'C'
					AND i.old_relationship_id IS NULL
					THEN 'Classification without mapping'
				WHEN i.old_standard_concept IS NULL
					AND i.old_relationship_id = 'Maps to'
					THEN 'Non-standard with mapping'
				ELSE 'Non-standard without mapping'
				END AS old_standard_concept,
			CASE 
				WHEN i.new_standard_concept = 'S'
					THEN 'Standard'
				WHEN i.new_standard_concept = 'C'
					AND i.new_relationship_id = 'Maps to'
					THEN 'Classification with mapping'
				WHEN i.new_standard_concept = 'C'
					AND i.new_relationship_id IS NULL
					THEN 'Classification without mapping'
				WHEN i.new_standard_concept IS NULL
					AND i.new_relationship_id = 'Maps to'
					THEN 'Non-standard with mapping'
				ELSE 'Non-standard without mapping'
				END AS new_standard_concept,
			i.cnt
		FROM (
			SELECT new.vocabulary_id,
				old.standard_concept AS old_standard_concept,
				r_old.relationship_id AS old_relationship_id,
				new.standard_concept AS new_standard_concept,
				r.relationship_id AS new_relationship_id,
				COUNT(DISTINCT new.concept_id) AS cnt --there can be more than one Maps to, so DISTINCT
			FROM concept new
			JOIN %1$I.concept old ON old.concept_id = new.concept_id
				AND COALESCE(old.standard_concept, 'X') <> COALESCE(new.standard_concept, 'X')
			LEFT JOIN %1$I.concept_relationship r_old ON r_old.concept_id_1 = new.concept_id
				AND r_old.relationship_id = 'Maps to'
				AND r_old.invalid_reason IS NULL
				AND r_old.concept_id_1 <> r_old.concept_id_2
			LEFT JOIN concept_relationship r ON r.concept_id_1 = new.concept_id
				AND r.relationship_id = 'Maps to'
				AND r.invalid_reason IS NULL
				AND r.concept_id_1 <> r.concept_id_2
			GROUP BY new.vocabulary_id,
				new.standard_concept,
				old.standard_concept,
				r_old.relationship_id,
				r.relationship_id
			) AS i$$, LOWER(pCompareWith));
END;
$BODY$
LANGUAGE 'plpgsql' STABLE SECURITY INVOKER;