DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_rxnorm_prepare (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work" && \
    unzip -oqj "$2" "rrf/RXNATOMARCHIVE.RRF" -d . && \
    unzip -oqj "$2" "rrf/RXNCONSO.RRF" -d . && \
    unzip -oqj "$2" "rrf/RXNREL.RRF" -d . && \
    unzip -oqj "$2" "rrf/RXNSAT.RRF" -d .
    
    #move result to original folder
    cd "$1"
    rm -f *.*
    mv work/*.RRF .
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
  
  REVOKE EXECUTE ON FUNCTION vocabulary_download.get_rxnorm_prepare FROM PUBLIC, role_read_only;
END $_$;