--DMD part
DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_dmd_prepare_dmd (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work" && \
    unzip -oqj "$2" "f_ampp2_*.xml" -d . && \
    unzip -oqj "$2" "f_amp2_*.xml" -d . && \
    unzip -oqj "$2" "f_vmpp2_*.xml" -d . && \
    unzip -oqj "$2" "f_vmp2_*.xml" -d . && \
    unzip -oqj "$2" "f_lookup2_*.xml" -d . && \
    unzip -oqj "$2" "f_vtm2_*.xml" -d . && \
    unzip -oqj "$2" "f_ingredient2_*.xml" -d .
        
    #move result to original folder
    cd "$1"
    rm -f *.xml
    mv work/f_ampp2_*.xml "f_ampp2.xml" && \
    mv work/f_amp2_*.xml "f_amp2.xml" && \
    mv work/f_vmpp2_*.xml "f_vmpp2.xml" && \
    mv work/f_vmp2_*.xml "f_vmp2.xml" && \
    mv work/f_lookup2_*.xml "f_lookup2.xml" && \
    mv work/f_vtm2_*.xml "f_vtm2.xml" && \
    mv work/f_ingredient2_*.xml "f_ingredient2.xml"
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;

--DMD bonus part
DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_dmd_prepare_dmdbonus (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work" && \
    unzip -oqj "$2" "*.zip" -d . && \
    unzip -oqj "week*BNF.zip" "f_bnf1_*.xml" -d . && \
    rm -f week*BNF.zip
        
    #move result to original folder
    cd "$1"
    rm -f dmdbonus.xml
    mv work/f_bnf1_*.xml "dmdbonus.xml"
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;