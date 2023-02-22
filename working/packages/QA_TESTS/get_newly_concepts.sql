/*
Newly added concepts grouped by vocabulary_id and domain

Usage: select * from qa_tests.get_newly_concepts();
will show the difference between current schema and prodv5

or: select * from qa_tests.get_newly_concepts(pCompareWith=>'devv5');
will show the difference between current schema and devv5 (you can use any schema name)
*/

CREATE OR REPLACE FUNCTION qa_tests.get_newly_concepts (pCompareWith VARCHAR DEFAULT 'prodv5')
RETURNS TABLE
(
	vocabulary_id VARCHAR(20),
	domain_id VARCHAR(20),
	cnt BIGINT
)
AS $BODY$
BEGIN
	RETURN QUERY
	EXECUTE FORMAT ($$
		SELECT new.vocabulary_id,
			new.domain_id,
			COUNT(*) AS cnt
		FROM concept new
		LEFT JOIN %I.concept old ON old.concept_id = new.concept_id
		WHERE old.concept_id IS NULL
			AND new.domain_id <> 'Metadata'
		GROUP BY new.vocabulary_id,
			new.domain_id$$, LOWER(pCompareWith));
END;
$BODY$
LANGUAGE 'plpgsql' STABLE SECURITY INVOKER;