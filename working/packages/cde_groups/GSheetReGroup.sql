CREATE OR REPLACE FUNCTION cde_groups.GSheetReGroup (pInputTableName TEXT, pSpreadsheetID TEXT, pWorksheetName TEXT)
RETURNS VOID AS
$BODY$
/*
	Split the group case, regroup concepts

	1. Split the group case
	In case when it is necessary to split the group, group_ids are deleted for every source_code, that should be detached from the group. Group_code, group_name remain unchanged

	2. Regroup concepts within one group case 1
	When it is necessary to detach concepts from the group and unite them into another group, group_id is changed to negative numbers for concepts that should be detached and for another group, group_id is deleted for concepts, that should be only detached

	3. Regroup concepts within one group case 2
	When it is necessary to detach concepts from the group and unite them into several groups or we are working with several groups simultaneously, new group_ids are assigned using negative numbers, group_id is deleted for concepts, that should be only detached

	4. Detach concepts and add them into the group not represented in the spreadsheet
	When a concept or concepts should be detached from the group and added to another, that not represented in the spreadsheet, for such concept(s) group_id is deleted and in a group_code field a new source_code:vocabulary_id pair is placed as an indicator of a target group

	Example:
	SELECT cde_groups.GSheetReGroup('cde_manual_group' /*table name*/, '1a3os1cjgI...' /*spreadsheet id*/, 'Test_set_concepts' /*list name*/);
*/
DECLARE
	iRet INT8;
BEGIN
	CALL cde_groups.CreateTempGSheetTable(pSpreadsheetID, pWorksheetName);

	--QA
	PERFORM FROM cde_spread_sheet WHERE COALESCE(group_id, -1) < 0 LIMIT 1;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'The group_id for detached concepts must be NULL or negative';
	END IF;
	PERFORM FROM cde_spread_sheet WHERE source_code IS NULL LIMIT 1;
	IF FOUND THEN
		RAISE EXCEPTION 'The source_code cannot be NULL';
	END IF;
	PERFORM FROM cde_spread_sheet WHERE source_vocabulary_id IS NULL LIMIT 1;
	IF FOUND THEN
		RAISE EXCEPTION 'The source_vocabulary_id cannot be NULL';
	END IF;
	PERFORM FROM cde_spread_sheet WHERE group_id IS NULL AND source_code || ':' || source_vocabulary_id <> ALL (group_code) AND ARRAY_LENGTH (group_code, 1) > 1 LIMIT 1;
	IF FOUND THEN
		RAISE EXCEPTION 'For detached concepts, the target group must include only one concept';
	END IF;
	
	EXECUTE FORMAT ($$
		--set a personal group_id for all concepts with empty/negative group_id
		SELECT cde_groups.DetachConceptFromGroup(%1$L, ARRAY_AGG(t.source_code || ':' || t.source_vocabulary_id))
		FROM %1$I t
		JOIN cde_spread_sheet s USING (source_code, source_vocabulary_id)
		WHERE COALESCE(s.group_id, -1) < 0;

		--merge concepts with the same group_id
		SELECT cde_groups.MergeSeparateConcepts(%1$L, ARRAY_AGG(t.source_code || ':' || t.source_vocabulary_id))
		FROM %1$I t
		JOIN cde_spread_sheet s USING (source_code, source_vocabulary_id)
		WHERE s.group_id < 0
		GROUP BY s.group_id;

		--add concepts to another group that indicated in group_code field by specified concept
		SELECT cde_groups.MergeGroupsByGroupID (%1$L, s0.target_group_id, s0.new_group_id)
		FROM (
			SELECT l.target_group_id, t.group_id new_group_id /*new group_id from detached concept*/
			FROM %1$I t
			JOIN cde_spread_sheet s USING (source_code, source_vocabulary_id)
			CROSS JOIN LATERAL (SELECT UNNEST(g.group_ids) target_group_id FROM cde_groups.CheckConcept(%1$L, s.group_code) g WHERE ARRAY_LENGTH (g.group_ids, 1) = 1) l --get the target group_id
			WHERE s.group_id IS NULL
				AND l.target_group_id <> t.group_id
		) s0;
	$$, pInputTableName);
END;
$BODY$
LANGUAGE 'plpgsql' STRICT;