/*
Newly 'Maps to' mappings to vocabularies that didn't exist before

Usage: select * from qa_tests.get_new_vocabulary_dependencies();
will show the difference between current schema and prodv5

or: select * from qa_tests.get_new_vocabulary_dependencies(pCompareWith=>'devv5');
will show the difference between current schema and devv5 (you can use any schema name)
*/

CREATE OR REPLACE FUNCTION qa_tests.get_new_vocabulary_dependencies (pCompareWith VARCHAR DEFAULT 'prodv5')
RETURNS TABLE
(
	vocabulary_id_1 VARCHAR(20),
	vocabulary_id_2 VARCHAR(20),
	cnt BIGINT
)
AS $BODY$
BEGIN
	RETURN QUERY
	EXECUTE FORMAT ($$
		SELECT c1.vocabulary_id,
			c2.vocabulary_id,
			COUNT(*) AS cnt
		FROM concept_relationship cr
		JOIN concept c1 ON c1.concept_id = cr.concept_id_1
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		WHERE cr.relationship_id = 'Maps to'
			AND cr.invalid_reason IS NULL
			AND c1.vocabulary_id <> c2.vocabulary_id
			AND NOT EXISTS (
				SELECT 1
				FROM %1$I.concept_relationship r_int
				JOIN %1$I.concept c1_int ON c1_int.concept_id = r_int.concept_id_1
				JOIN %1$I.concept c2_int ON c2_int.concept_id = r_int.concept_id_2
				WHERE r_int.relationship_id = 'Maps to'
					AND r_int.invalid_reason IS NULL
					AND c1_int.vocabulary_id = c1.vocabulary_id
					AND c2_int.vocabulary_id = c2.vocabulary_id
				)
		GROUP BY c1.vocabulary_id,
			c2.vocabulary_id$$, LOWER(pCompareWith));
END;
$BODY$
LANGUAGE 'plpgsql' STABLE;