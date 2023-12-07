CREATE OR REPLACE FUNCTION cde_groups.SplitGroup (pInputTableName TEXT, pGroupID INT4)
RETURNS VOID AS
$BODY$
/*
	Case 1 Split the group into separate concepts
	Input – group id
	Result – every group member should get their own group_id, group_name, group_code, where the group contains only one concept itself

	Example:
	SELECT cde_groups.SplitGroup('cde_manual_group' /*table name*/, 2 /*group id*/);
*/
BEGIN
	PERFORM cde_groups.CheckGroupID (pInputTableName, ARRAY[pGroupID]);

	EXECUTE FORMAT ($$
		--synchronize the sequence
		SELECT SETVAL('seq_cde_manual_group', MAX(group_id)) FROM %1$I;

		UPDATE %1$I
		SET group_id = DEFAULT
		WHERE group_id = %2$s;

		ANALYZE %1$I;
	$$, pInputTableName, pGroupID);
END;
$BODY$
LANGUAGE 'plpgsql' STRICT;