CREATE OR REPLACE FUNCTION cde_groups.ClearString (pString TEXT)
RETURNS TEXT AS
$BODY$
/*
	Internal function, clears the input string
*/
	SELECT NULLIF(TRIM(REGEXP_REPLACE(pString, '([^[:ascii:]]|[\t\r\n\v\f])', '', 'g')), '');
$BODY$
LANGUAGE 'sql' STRICT IMMUTABLE;