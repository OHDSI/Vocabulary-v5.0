CREATE OR REPLACE FUNCTION vocabulary_pack.run_upload (
  ppath varchar
)
RETURNS void AS
$body$
#!/bin/bash
"$1upload_vocab_new.sh"$body$
LANGUAGE 'plsh'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;