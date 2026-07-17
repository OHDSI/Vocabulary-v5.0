CREATE OR REPLACE FUNCTION google_pack.py_gtranslate (
	bulk_text TEXT[],
	dest_lang TEXT DEFAULT 'en',
	src_lang TEXT DEFAULT 'auto'
)
RETURNS
TABLE (
	original_text TEXT,
	translated_text TEXT
)
AS
$BODY$
  #do not call directly, use google_pack.GTranslate() instead
  from googletrans import Translator
  
  translator = Translator()
  translations = translator.translate(bulk_text, dest=dest_lang, src=src_lang)
  
  return [(translation.origin,translation.text) for translation in translations]
$BODY$
LANGUAGE 'plpython3u' STRICT;

REVOKE EXECUTE ON FUNCTION google_pack.py_gtranslate FROM PUBLIC;