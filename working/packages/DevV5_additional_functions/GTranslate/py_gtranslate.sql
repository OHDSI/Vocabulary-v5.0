CREATE OR REPLACE FUNCTION devv5.py_gtranslate (bulk_text text[], dest_lang text default 'en', src_lang text default 'auto')
RETURNS
TABLE (
  original_text text,
  translated_text text
)
AS
$BODY$
  #do not call directly, use devv5.GTranslate() instead
  from googletrans import Translator
  
  translator = Translator()
  translations = translator.translate(bulk_text, dest=dest_lang, src=src_lang)
  
  return [(translation.origin,translation.text) for translation in translations]
$BODY$
LANGUAGE 'plpython3u' STRICT;

REVOKE EXECUTE ON FUNCTION devv5.py_gtranslate FROM PUBLIC;