CREATE OR REPLACE FUNCTION cde_groups.DetachConceptFromGroup (pInputTableName TEXT, pConcept TEXT[])
RETURNS VOID AS
$BODY$
/*
	Case 1a Detach one or several concept from the groups
	Input – source_code:source_vocabulary_id (array)
	Result – every group member, indicated through source_code:source_vocabulary_id should be separated from the group and get their own group_id, group_name, group_code, where the group contains only one concept itself

	Example:
	SELECT cde_groups.DetachConceptFromGroup('cde_manual_group' /*table name*/, ARRAY['A18.002:ICD10CN',...] /*array of concepts*/);
*/
DECLARE
	iGroupsID INT4[];
BEGIN
	SELECT cde_groups.GetDistinctGroups(group_ids) INTO iGroupsID FROM cde_groups.CheckConcept (pInputTableName, pConcept);

	EXECUTE FORMAT ($$
		--synchronize the sequence
		SELECT SETVAL('seq_cde_manual_group', MAX(group_id)) FROM %1$I;

		UPDATE %1$I
		SET group_id = DEFAULT,
			group_name = source_code_description
		WHERE source_code || ':' || source_vocabulary_id = ANY ($1);

		--now need to re-update the names of the groups from which these concepts were taken
		UPDATE %1$I
		SET group_name = cde_groups.CheckGroupID (%1$L, ARRAY [group_id])
		WHERE group_id = ANY ($2)
			AND group_name <> cde_groups.CheckGroupID (%1$L, ARRAY [group_id]);

		ANALYZE %1$I;
	$$, pInputTableName)
	USING pConcept, iGroupsID;
END;
$BODY$
LANGUAGE 'plpgsql' STRICT;