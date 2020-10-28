DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_ccam_prepare (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work"
    unzip -oqj "$2_PART1.zip" "R_ACTE.txt" -d . && \
    unzip -oqj "$2_PART1.zip" "R_ACTE.dbf" -d . && \
    unzip -oqj "$2_PART3.zip" "R_MENU.dbf" -d . && \
    unzip -oqj "$2_PART3.zip" "R_ACTE_IVITE.dbf" -d . && \
    unzip -oqj "$2_PART3.zip" "R_REGROUPEMENT.dbf" -d .
    
    #move result to original folder
    cd "$1"
    rm -f *.*
    mv work/*.dbf work/*.txt .
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;