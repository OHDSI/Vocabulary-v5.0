DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_amt_prepare (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work"
    unzip -oqj "$2" "SnomedCT_Release_AU1000036_*/RF2Release/Full/Terminology/sct2_Concept_Full_AU1000036_*.txt" -d . && \
    unzip -oqj "$2" "SnomedCT_Release_AU1000036_*/RF2Release/Full/Terminology/sct2_Description_Full-en-AU_AU1000036_*.txt" -d . && \
    unzip -oqj "$2" "SnomedCT_Release_AU1000036_*/RF2Release/Full/Terminology/sct2_Relationship_Full_AU1000036_*.txt" -d . && \
    unzip -oqj "$2" "SnomedCT_Release_AU1000036_*/RF2Release/Full/Refset/Content/der2_ccsRefset_StrengthFull_AU1000036_*.txt" -d . && \
    unzip -oqj "$2" "SnomedCT_Release_AU1000036_*/RF2Release/Full/Refset/Language/der2_cRefset_LanguageFull-en-AU_AU1000036_*.txt" -d .
    
    #move result to original folder
    cd "$1"
    rm -f *.*
    mv work/sct2_Concept_Full_*.txt "sct2_Concept_Full_AU.txt" && \
    mv work/sct2_Description_Full-en-AU_*.txt "sct2_Description_Full-en-AU_AU.txt" && \
    mv work/sct2_Relationship_Full_*.txt "sct2_Relationship_Full_AU.txt" && \
    mv work/der2_ccsRefset_StrengthFull_*.txt "der2_ccsRefset_StrengthFull_AU.txt" && \
    mv work/der2_cRefset_LanguageFull-en-AU_AU1000036_*.txt "der2_cRefset_LanguageFull-en-AU_AU.txt"
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
  
  REVOKE EXECUTE ON FUNCTION vocabulary_download.get_amt_prepare FROM PUBLIC, role_read_only;
END $_$;