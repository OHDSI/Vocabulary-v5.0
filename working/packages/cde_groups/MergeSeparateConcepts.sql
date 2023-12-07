CREATE OR REPLACE FUNCTION cde_groups.MergeSeparateConcepts (pInputTableName TEXT, pConcept TEXT[])
RETURNS VOID AS
$BODY$
/*
	Case 2b Merge separate concepts in the group
	Input – source_code:source_vocabulary_id (array)
	Result – indicated concepts should be united in a group

	Example:
	SELECT cde_groups.MergeSeparateConcepts('cde_manual_group' /*table name*/, ARRAY['A18.002:ICD10CN','B90.200:ICD10CN',...] /*array of concepts*/);
*/
DECLARE
	iGroupID INT4;
BEGIN
	pConcept:=cde_groups.GetDistinctConcepts(pConcept);

	IF ARRAY_LENGTH(pConcept, 1)<2 THEN
		RAISE EXCEPTION 'Please specify more than one concept';
	END IF;

	PERFORM cde_groups.CheckConcept (pInputTableName, pConcept);

	EXECUTE FORMAT ($$
		SELECT MIN(group_id)
		FROM %1$I
		WHERE source_code || ':' || source_vocabulary_id = ANY ($1)
		HAVING COUNT(group_id) = COUNT(DISTINCT group_id) AND COUNT(group_id) = ARRAY_LENGTH($1, 1) --the input table must have all the specified concepts in individual groups
	$$, pInputTableName)
	USING pConcept
	INTO iGroupID;

	IF iGroupID IS NULL THEN
		RAISE EXCEPTION 'The input table must have all the specified concepts in individual groups';
	END IF;

	PERFORM cde_groups.MergeGroupsByConcept (pInputTableName, iGroupID, pConcept);
END;
$BODY$
LANGUAGE 'plpgsql' STRICT;