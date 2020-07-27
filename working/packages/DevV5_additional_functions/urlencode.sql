CREATE OR REPLACE FUNCTION devv5.urlencode (
  txt_string text
)
RETURNS text AS
$body$
	from urllib import quote_plus
	return quote_plus (txt_string)
$body$
LANGUAGE 'plpythonu'
IMMUTABLE
RETURNS NULL ON NULL INPUT
SECURITY DEFINER
PARALLEL SAFE
COST 10;