CREATE OR REPLACE FUNCTION cde_groups.GSheetMergeGroups (pInputTableName TEXT, pSpreadsheetID TEXT, pWorksheetName TEXT)
RETURNS VOID AS
$BODY$
/*
	Case 2.1: Merge groups case 1
	In a group_code field a new source_code:vocabulary_id pair is placed as an indicator of a group that should be added to the existing one

	Example:
	SELECT cde_groups.GSheetMergeGroups('cde_manual_group' /*table name*/, '1a3os1cjgI...' /*spreadsheet id*/, 'Test_set_concepts' /*list name*/);
*/
BEGIN
	CALL cde_groups.CreateTempGSheetTable(pSpreadsheetID, pWorksheetName);

	--QA
	PERFORM FROM cde_spread_sheet WHERE COALESCE(group_id, -1) < 0 LIMIT 1;
	IF FOUND THEN
		RAISE EXCEPTION 'The group_id cannot be NULL or negative';
	END IF;

	PERFORM FROM cde_spread_sheet WHERE group_code = ARRAY ['{}'] LIMIT 1;
	IF FOUND THEN
		RAISE EXCEPTION 'The group_code cannot be empty';
	END IF;

	EXECUTE FORMAT ($$
		SELECT cde_groups.MergeGroupsByConcept (%1$L, s0.group_id, s0.group_code)
		FROM (
			SELECT DISTINCT t.group_id /*changed group*/, s.group_code
			FROM %1$I t
			JOIN cde_spread_sheet s USING (group_id)
			WHERE t.source_code || ':' || t.source_vocabulary_id <> ALL(s.group_code)
		) s0;
	$$, pInputTableName);
END;
$BODY$
LANGUAGE 'plpgsql' STRICT;