CREATE OR REPLACE FUNCTION cde_groups.CheckGroupID (pInputTableName TEXT, pGroupID INT4[])
RETURNS TEXT AS
$BODY$
/*
	Internal function, checks that all groups exist and returns the longest group name according to the following rules:
	1. if there is one ICD10 code, take its name
	2. if there are several ICD10 codes, take the longest of these codes
	3. if there are no ICD10 codes, just take the longest name
*/
DECLARE
	iMissingGroups TEXT;
	iGroupName TEXT;
BEGIN
	EXECUTE FORMAT ($$
		SELECT t.group_name,
			STRING_AGG(g.group_id::TEXT, ', ') FILTER(WHERE t.group_id IS NULL) OVER ()
		FROM UNNEST($1) g(group_id)
		LEFT JOIN %1$I t USING (group_id)
		ORDER BY CASE WHEN t.source_vocabulary_id='ICD10' THEN 0 ELSE 1 END,
			LENGTH(t.group_name) DESC,
			t.group_name --in case different groups have the same length
		LIMIT 1
	$$, pInputTableName)
	USING pGroupID
	INTO iGroupName, iMissingGroups;

	IF iMissingGroups IS NOT NULL THEN
		RAISE EXCEPTION 'Some groups were not found: %', iMissingGroups;
	END IF;

	RETURN iGroupName;
END;
$BODY$
LANGUAGE 'plpgsql' STRICT STABLE;