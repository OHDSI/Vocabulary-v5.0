CREATE OR REPLACE FUNCTION cde_groups.CheckConcept (pInputTableName TEXT, pConcept TEXT[])
RETURNS TABLE (
	group_ids INT4[],
	max_group_name TEXT
) AS
$BODY$
/*
	Internal function, checks that all concepts exist and returns group IDs and the longest group name according to the following rules:
	1. if there is one ICD10 code, take its name
	2. if there are several ICD10 codes, take the longest of these codes
	3. if there are no ICD10 codes, just take the longest name
*/
DECLARE
	iMissingConcepts TEXT;
	iGroupID INT4 [];
	iGroupName TEXT;
BEGIN
	EXECUTE FORMAT ($$
		SELECT t.group_name,
			ARRAY_AGG(t.group_id) OVER (),
			STRING_AGG(c.concept, ', ') FILTER(WHERE t.group_id IS NULL) OVER ()
		FROM UNNEST($1) c(concept)
		LEFT JOIN %1$I t ON t.source_code || ':' || t.source_vocabulary_id = c.concept
		ORDER BY CASE WHEN t.source_vocabulary_id='ICD10' THEN 0 ELSE 1 END,
			LENGTH(t.group_name) DESC,
			t.group_name --in case different groups have the same length
		LIMIT 1
	$$, pInputTableName)
	USING pConcept
	INTO max_group_name, group_ids, iMissingConcepts;

	IF iMissingConcepts IS NOT NULL THEN
		RAISE EXCEPTION 'Some concepts were not found: %', iMissingConcepts;
	END IF;

	RETURN NEXT;
END;
$BODY$
LANGUAGE 'plpgsql' STRICT STABLE;