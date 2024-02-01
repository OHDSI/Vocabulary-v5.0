CREATE OR REPLACE FUNCTION vocabulary_pack.run_upload (pPath TEXT)
RETURNS VOID AS
$BODY$
#!/bin/bash
"$1/upload_vocab_new.sh"$BODY$
LANGUAGE 'plsh';

REVOKE EXECUTE ON FUNCTION vocabulary_pack.run_upload FROM PUBLIC, role_read_only;