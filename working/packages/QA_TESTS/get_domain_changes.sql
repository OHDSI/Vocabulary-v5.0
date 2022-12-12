/*
Domain changes

Usage: select * from qa_tests.get_domain_changes();
will show the difference between current schema and prodv5

or: select * from qa_tests.get_domain_changes(pCompareWith=>'devv5');
will show the difference between current schema and devv5 (you can use any schema name)
*/

CREATE TYPE qa_tests.type_get_domain_changes AS (
	vocabulary_id VARCHAR(20),
	old_domain_id VARCHAR(20),
	new_domain_id VARCHAR(20),
	cnt BIGINT
	);

CREATE OR REPLACE FUNCTION qa_tests.get_domain_changes (pCompareWith VARCHAR DEFAULT 'prodv5')
RETURNS SETOF qa_tests.type_get_domain_changes
AS $BODY$
BEGIN
	RETURN QUERY
	EXECUTE FORMAT ($$
		SELECT new.vocabulary_id,
			old.domain_id AS old_domain_id,
			new.domain_id AS new_domain_id,
			count(*) AS cnt
		FROM concept new
		JOIN %I.concept old ON old.concept_id = new.concept_id
			AND new.domain_id <> old.domain_id
		GROUP BY new.vocabulary_id,
			old.domain_id,
			new.domain_id$$, LOWER(pCompareWith));
END;
$BODY$
LANGUAGE 'plpgsql' STABLE SECURITY INVOKER;