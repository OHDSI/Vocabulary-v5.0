CREATE OR REPLACE FUNCTION cde_groups.GetDistinctConcepts (pConcept TEXT[])
RETURNS TEXT[] AS
$BODY$
/*
	Internal function, returns an array of unique concepts
*/
	SELECT ARRAY_AGG(DISTINCT c.concept) FROM UNNEST(pConcept) c(concept);
$BODY$
LANGUAGE 'sql' STRICT IMMUTABLE;