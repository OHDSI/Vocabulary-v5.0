DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_snomedvet_prepare (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work" && \
    unzip -oqjC "$2" "SnomedCT_Release_VTS*/Full/Terminology/sct2_Concept_Full_VTS_*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_Release_VTS*/Full/Terminology/sct2_Description_Full_en_VTS_*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_Release_VTS*/Full/Terminology/sct2_Relationship_Full_VTS_*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_Release_VTS*/Full/Refset/Content/der2_cRefset_AssociationReferenceFull_VTS_*.txt" -d .
        
    #move result to original folder
    cd "$1"
    rm -f "sct2_Concept_Full_VTS.txt" "sct2_Description_Full_VTS.txt" "sct2_Relationship_Full_VTS.txt" "der2_cRefset_AssociationFull_VTS.txt"
    mv work/sct2_Concept_Full_VTS_*.txt "sct2_Concept_Full_VTS.txt" && \
    mv work/sct2_Description_Full_en_VTS_*.txt "sct2_Description_Full_VTS.txt" && \
    mv work/sct2_Relationship_Full_VTS_*.txt "sct2_Relationship_Full_VTS.txt" && \
    mv work/der2_cRefset_AssociationReferenceFull_VTS_*.txt "der2_cRefset_AssociationFull_VTS.txt"
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;