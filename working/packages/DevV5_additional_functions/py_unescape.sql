CREATE OR REPLACE FUNCTION devv5.py_unescape (
  txt_string text
)
RETURNS text AS
$body$
	from xml.sax.saxutils import unescape
	return unescape (txt_string)
$body$
LANGUAGE 'plpythonu'
IMMUTABLE
RETURNS NULL ON NULL INPUT
SECURITY DEFINER
PARALLEL SAFE
COST 10;