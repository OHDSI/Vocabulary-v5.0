DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_umls_prepare (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work" && \
    unzip -oqj "$2" "*/META/MRCONSO.RRF" -d . && \
    unzip -oqj "$2" "*/META/MRHIER.RRF" -d . && \
    unzip -oqj "$2" "*/META/MRMAP.RRF" -d . && \
    unzip -oqj "$2" "*/META/MRSMAP.RRF" -d . && \
    unzip -oqj "$2" "*/META/MRSAT.RRF" -d . && \
    unzip -oqj "$2" "*/META/MRREL.RRF" -d . && \
    unzip -oqj "$2" "*/META/MRSTY.RRF" -d .

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
END $_$;