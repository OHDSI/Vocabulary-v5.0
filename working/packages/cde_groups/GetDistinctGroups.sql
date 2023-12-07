CREATE OR REPLACE FUNCTION cde_groups.GetDistinctGroups (pGroupID INT4[])
RETURNS INT4[] AS
$BODY$
/*
	Internal function, returns an sequence-preserving array of unique groups
*/
	SELECT ARRAY_AGG(s0.group_id ORDER BY s0.group_pos)
	FROM (
		SELECT DISTINCT ON (g.group_id) g.group_id,
			g.group_pos
		FROM UNNEST(pGroupID) WITH ORDINALITY AS g(group_id, group_pos)
		ORDER BY g.group_id,
			g.group_pos
		) s0;
$BODY$
LANGUAGE 'sql' STRICT IMMUTABLE;