DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_omop_invest_drug_prepare (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work" && \
    gunzip -dq "dump-public.gsrs.gz"
    
    #move result to original folder
    cd "$1"
    rm -f *.*
    mv work/* .
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
  
  REVOKE EXECUTE ON FUNCTION vocabulary_download.get_omop_invest_drug_prepare FROM PUBLIC, role_read_only;
END $_$;