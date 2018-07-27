DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_meddra_prepare (iPath text, iFilename text, iPassword text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work"
    code='unzip -oqj -P '\'"$3"\'' '"$2"' '"MedAscii/hlgt_hlt.asc"' -d . && '
    code="$code"'unzip -oqj -P '\'"$3"\'' '"$2"' '"MedAscii/hlt.asc"' -d . && '
    code="$code"'unzip -oqj -P '\'"$3"\'' '"$2"' '"MedAscii/hlt_pt.asc"' -d . && '
    code="$code"'unzip -oqj -P '\'"$3"\'' '"$2"' '"MedAscii/hlgt.asc"' -d . && '
    code="$code"'unzip -oqj -P '\'"$3"\'' '"$2"' '"MedAscii/llt.asc"' -d . && '
    code="$code"'unzip -oqj -P '\'"$3"\'' '"$2"' '"MedAscii/mdhier.asc"' -d . && '
    code="$code"'unzip -oqj -P '\'"$3"\'' '"$2"' '"MedAscii/pt.asc"' -d . && '
    code="$code"'unzip -oqj -P '\'"$3"\'' '"$2"' '"MedAscii/soc.asc"' -d . && '
    code="$code"'unzip -oqj -P '\'"$3"\'' '"$2"' '"MedAscii/soc_hlgt.asc"' -d .'
    eval "$code"
    #move result to original folder
    cd "$1"
    rm -f *.*
    mv work/*.asc .
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;