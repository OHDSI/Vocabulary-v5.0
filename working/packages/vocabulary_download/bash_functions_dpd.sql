DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_dpd_prepare (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work"
    unzip -oqj "$2.zip" "drug.txt" -d . && \
    unzip -oqj "$2.zip" "ingred.txt" -d . && \
    unzip -oqj "$2.zip" "form.txt" -d . && \
    unzip -oqj "$2.zip" "route.txt" -d . && \
    unzip -oqj "$2.zip" "package.txt" -d . && \
    unzip -oqj "$2.zip" "status.txt" -d . && \
    unzip -oqj "$2.zip" "comp.txt" -d . && \
    unzip -oqj "$2.zip" "ther.txt" -d . && \
    unzip -oqj "$2_ia.zip" "drug_ia.txt" -d . && \
    unzip -oqj "$2_ia.zip" "ingred_ia.txt" -d . && \
    unzip -oqj "$2_ia.zip" "form_ia.txt" -d . && \
    unzip -oqj "$2_ia.zip" "route_ia.txt" -d . && \
    unzip -oqj "$2_ia.zip" "package_ia.txt" -d . && \
    unzip -oqj "$2_ia.zip" "status_ia.txt" -d . && \
    unzip -oqj "$2_ia.zip" "comp_ia.txt" -d . && \
    unzip -oqj "$2_ia.zip" "ther_ia.txt" -d . && \
    unzip -oqj "$2_ap.zip" "drug_ap.txt" -d . && \
    unzip -oqj "$2_ap.zip" "ingred_ap.txt" -d . && \
    unzip -oqj "$2_ap.zip" "form_ap.txt" -d . && \
    unzip -oqj "$2_ap.zip" "route_ap.txt" -d . && \
    unzip -oqj "$2_ap.zip" "package_ap.txt" -d . && \
    unzip -oqj "$2_ap.zip" "status_ap.txt" -d . && \
    unzip -oqj "$2_ap.zip" "comp_ap.txt" -d . && \
    unzip -oqj "$2_ap.zip" "ther_ap.txt" -d .
    
    #move result to original folder
    cd "$1"
    rm -f *.*
    mv work/*.txt .
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
  
  REVOKE EXECUTE ON FUNCTION vocabulary_download.get_dpd_prepare FROM PUBLIC, role_read_only;
END $_$;