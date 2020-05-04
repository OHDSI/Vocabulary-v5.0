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
    f=$(unzip -l "$2" | awk 'NR == 4 {print $4}') && \
    unzip -oq "$2" && \
    cd "$f/META"
    
    #move result to original folder
    mv "MRCONSO.RRF" "$1" && \
    mv "MRHIER.RRF" "$1" && \
    mv "MRMAP.RRF" "$1" && \
    mv "MRSMAP.RRF" "$1" && \
    mv "MRSAT.RRF" "$1" && \
    mv "MRREL.RRF" "$1"
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;