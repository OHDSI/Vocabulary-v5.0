CREATE OR REPLACE FUNCTION cde_groups.MergeGroupsByGroupID (pInputTableName TEXT, VARIADIC pGroupID INT4[])
RETURNS VOID AS
$BODY$
/*
	Case 2a Merge groups
	Input – group_id1, group_id2, group_id3, etc
	Result – The group with the indicated group_id is merged with other group(s) indicated through group_id

	Example:
	SELECT cde_groups.MergeGroupsByGroupID('cde_manual_group' /*table name*/, 1, 2, 3, ... /*group ids separated by comma*/);
*/
BEGIN
	pGroupID:=cde_groups.GetDistinctGroups(pGroupID);

	IF ARRAY_LENGTH(pGroupID, 1)<2 THEN
		RAISE EXCEPTION 'Please specify more than one group';
	END IF;

	EXECUTE FORMAT ($$
		UPDATE %1$I t
		SET group_id = $1,
			group_name = $3
		WHERE group_id = ANY ($2)
			AND (
				group_id <> $1
				OR (
					group_id = $1
					AND group_name <> $3 --update 'main' group only if group names are different
					)
				);

		ANALYZE %1$I;
	$$, pInputTableName)
	USING pGroupID[1], pGroupID, (SELECT * FROM cde_groups.CheckGroupID (pInputTableName, pGroupID));
END;
$BODY$
LANGUAGE 'plpgsql' STRICT;