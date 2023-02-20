/*
Changes of concept mapping status grouped by target domain

Usage: select * from qa_tests.get_changes_concept_mapping();
will show the difference between current schema and prodv5

or: select * from qa_tests.get_changes_concept_mapping(pCompareWith=>'devv5');
will show the difference between current schema and devv5 (you can use any schema name)
*/

CREATE OR REPLACE FUNCTION qa_tests.get_changes_concept_mapping (pCompareWith VARCHAR DEFAULT 'prodv5')
RETURNS TABLE
(
	vocabulary_id VARCHAR(20),
	old_mapped_domains TEXT,
	new_mapped_domains TEXT,
	cnt BIGINT
)
AS $BODY$
BEGIN
	RETURN QUERY
	EXECUTE FORMAT ($$
		SELECT s_all.vocabulary_id,
			s_all.old_mapped_domains,
			s_all.new_mapped_domains,
			COUNT(*) AS cnt
		FROM (
			SELECT new.vocabulary_id,
				CASE 
					WHEN old.concept_id IS NULL
						THEN 'New concept'
					ELSE COALESCE(old.domains, 'No mapping')
					END AS old_mapped_domains,
				COALESCE(new.domains, 'No mapping') AS new_mapped_domains
			FROM (
				SELECT c1.vocabulary_id,
					c1.concept_id,
					STRING_AGG(DISTINCT c2.domain_id, '/' ORDER BY c2.domain_id) AS domains
				FROM concept c1
				LEFT JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
					AND r.invalid_reason IS NULL
					AND r.relationship_id = 'Maps to'
				LEFT JOIN concept c2 ON c2.concept_id = r.concept_id_2
				GROUP BY c1.vocabulary_id,
					c1.concept_id
				) AS new
			LEFT JOIN (
				SELECT c1.concept_id,
					STRING_AGG(DISTINCT c2.domain_id, '/' ORDER BY c2.domain_id) AS domains
				FROM %1$I.concept c1
				LEFT JOIN %1$I.concept_relationship r ON r.concept_id_1 = c1.concept_id
					AND r.invalid_reason IS NULL
					AND r.relationship_id = 'Maps to'
				LEFT JOIN %1$I.concept c2 ON c2.concept_id = r.concept_id_2
				GROUP BY c1.concept_id
				) AS old ON old.concept_id = new.concept_id
			WHERE new.domains IS DISTINCT FROM old.domains
			) AS s_all
		GROUP BY s_all.vocabulary_id,
			s_all.old_mapped_domains,
			s_all.new_mapped_domains$$, LOWER(pCompareWith));
END;
$BODY$
LANGUAGE 'plpgsql' STABLE SECURITY INVOKER;