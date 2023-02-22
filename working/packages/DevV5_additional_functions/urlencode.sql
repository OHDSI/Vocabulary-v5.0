CREATE OR REPLACE FUNCTION devv5.urlencode (
  txt_string text
)
RETURNS text AS
$body$
	from urllib.parse import quote_plus
	return quote_plus (txt_string)
$body$
LANGUAGE 'plpython3u'
IMMUTABLE STRICT PARALLEL SAFE;