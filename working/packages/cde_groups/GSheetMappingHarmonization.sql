CREATE OR REPLACE FUNCTION cde_groups.GSheetMappingHarmonization (pInputTableName TEXT, pSpreadsheetID TEXT, pWorksheetName TEXT)
RETURNS VOID AS
$BODY$
/*
	Case 1: Mapping harmonization
	Group_id is used for mapping. All group members should then acquire the same target_concept_id in the CDE table with mappings on the server

	Example:
	SELECT cde_groups.GSheetMappingHarmonization('cde_manual_group' /*table name*/, '1a3os1cjgI...' /*spreadsheet id*/, 'Test_set_concepts' /*list name*/);
*/
DECLARE
	iRet INT8;
	iMissingGroups TEXT;
BEGIN
	CALL cde_groups.CreateTempGSheetTable(pSpreadsheetID, pWorksheetName);

	--QA
	PERFORM FROM cde_spread_sheet WHERE group_id IS NULL LIMIT 1;
	IF FOUND THEN
		RAISE EXCEPTION 'The group_id cannot be NULL';
	END IF;
	PERFORM FROM cde_spread_sheet GROUP BY group_id HAVING COUNT(*)>1 LIMIT 1;
	IF FOUND THEN
		RAISE EXCEPTION 'Group_ids must be unique';
	END IF;
	PERFORM FROM cde_spread_sheet WHERE target_concept_id IS NULL LIMIT 1;
	IF FOUND THEN
		RAISE EXCEPTION 'All target_concept_ids must be filled';
	END IF;

	EXECUTE FORMAT ($$
		SELECT STRING_AGG(s.group_id::TEXT, ', ') FROM cde_spread_sheet s
		LEFT JOIN %1$I t USING (group_id)
		WHERE t.group_id IS NULL
	$$, pInputTableName)
	INTO iMissingGroups;

	IF iMissingGroups IS NOT NULL THEN
		RAISE EXCEPTION 'Some groups were not found: %', iMissingGroups;
	END IF;

	EXECUTE FORMAT ($$
		UPDATE %1$I t
		SET target_concept_id = s.target_concept_id
		FROM cde_spread_sheet s
		WHERE t.group_id = s.group_id
			AND t.target_concept_id IS DISTINCT FROM s.target_concept_id
	$$, pInputTableName);
END;
$BODY$
LANGUAGE 'plpgsql' STRICT;