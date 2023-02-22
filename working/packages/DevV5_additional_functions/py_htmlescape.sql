CREATE OR REPLACE FUNCTION devv5.py_htmlescape (
  txt_string text
)
RETURNS text AS
$body$
	import html
	return html.escape(txt_string, quote=False)
$body$
LANGUAGE 'plpython3u'
IMMUTABLE STRICT PARALLEL SAFE;