DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_ggr_prepare (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work"
    unzip -oqj "$2" "Gal.csv" -d . && \
    unzip -oqj "$2" "Ir.csv" -d . && \
    unzip -oqj "$2" "MP.csv" -d . && \
    unzip -oqj "$2" "MPP.csv" -d . && \
    unzip -oqj "$2" "Sam.csv" -d . && \
    unzip -oqj "$2" "Stof.csv" -d .
    
    #move result to original folder
    cd "$1"
    rm -f *.*
    mv work/*.csv .
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;