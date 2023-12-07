CREATE OR REPLACE FUNCTION cde_groups.MergeGroupsByConcept (pInputTableName TEXT, pGroupID INT4, pConcept TEXT[])
RETURNS VOID AS
$BODY$
/*
	Case 2 Merge groups
	Input – group_id, source_code:source_vocabulary_id (array)
	Result – The group with the indicated group_id is merged with groups, which members are indicated through source_code:source_vocabulary_id pair

	Example:
	SELECT cde_groups.MergeGroupsByConcept('cde_manual_group' /*table name*/, 2 /*group id*/, ARRAY['A18.002:ICD10CN','B90.200:ICD10CN',...] /*array of concepts*/);
*/
BEGIN
	PERFORM cde_groups.MergeGroupsByGroupID (
		pInputTableName,
		VARIADIC (
			SELECT pGroupID || group_ids FROM cde_groups.CheckConcept (pInputTableName, pConcept) WHERE ARRAY_LENGTH(cde_groups.GetDistinctGroups (pGroupID || group_ids), 1)>1
		)
	);
END;
$BODY$
LANGUAGE 'plpgsql' STRICT;