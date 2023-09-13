DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_hcpcs_prepare (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work" && \
    #get all matches by mask "HCPC*ANWEB*.xls*", if there is more than one file, sort by size, get the largest one, then unzip it
    f=$(unzip -qq -l "$2" | egrep -i "HCPC.*ANWEB.*\.xls.*" | sort -nr -k1 | head -1 | awk '{print $4}') && unzip -oqj "$2" "$f" -d .
    
    #move result to original folder
    cd "$1"
    rm -f *.*
    mv work/*.xls* "HCPC_CONTR_ANWEB.xlsx"
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
  
  REVOKE EXECUTE ON FUNCTION vocabulary_download.get_hcpcs_prepare FROM PUBLIC, role_read_only;
END $_$;