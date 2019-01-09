DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_loinc_prepare (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work" && \
    unzip -oqj "$2.zip" "Loinc.csv" -d . && \
    unzip -oqj "$2.zip" "MapTo.csv" -d . && \
    unzip -oqj "$2.zip" "SourceOrganization.csv" -d . && \
    f=$(unzip -l "$2_mh.zip" | grep -i .*multi.*axial.*hierarchy.csv | awk '{print $4}') && \
    unzip -oqj "$2_mh.zip" "$f" -d . && \
    f=$(unzip -l "$2_pf.zip" | grep -i .*panels.*forms.csv | awk '{print $4}') && \
    unzip -oqj "$2_pf.zip" "$f" -d . && \
    unzip -oqj "$2_ls.zip" "*SnomedCT_LOINC*.zip" -d . && \
    unzip -oqj "*SnomedCT_LOINC*.zip" "*SnomedCT_LOINC*/Full/Refset/Content/*ExpressionAssociationFull*.txt" -d . && \
    unzip -oqj "$2_cpt.zip" "MRSMAP.RRF" -d . && \
    unzip -oqj "$2_la.zip" "AnswerList.csv" -d . && \
    unzip -oqj "$2_la.zip" "LoincAnswerListLink.csv" -d . && \
    unzip -oqj "$2_do.zip" "DocumentOntology.csv" -d . && \
    unzip -oqj "$2_gf.zip" "Group.csv" -d . && \
    unzip -oqj "$2_gf.zip" "GroupLoincTerms.csv" -d . && \
    unzip -oqj "$2_gf.zip" "ParentGroupAttributes.csv" -d .
    
    #move result to original folder
    cd "$1"
    rm -f *.*
    mv work/Loinc.csv "loinc.csv" && \
    mv work/MapTo.csv "map_to.csv" && \
    mv work/SourceOrganization.csv "source_organization.csv" && \
    mv work/*ierarchy.csv "LOINC_MULTI-AXIAL_HIERARCHY.CSV" && \
    mv work/*orms.csv "LOINC_PanelsAndForms.csv" && \
    mv work/*ExpressionAssociationFull*.txt "xder2_sscccRefset_LOINCExpressionAssociationFull_INT.txt" && \
    mv work/MRSMAP.RRF "CPT_MRSMAP.RRF" && \
    mv work/AnswerList.csv "AnswerList.csv" && \
    mv work/LoincAnswerListLink.csv "LoincAnswerListLink.csv" && \
    mv work/loinc_class.csv "loinc_class.csv" && \
    mv work/DocumentOntology.csv "DocumentOntology.csv" && \
    mv work/Group.csv "Group.csv" && \
    mv work/GroupLoincTerms.csv "GroupLoincTerms.csv" && \
    mv work/ParentGroupAttributes.csv "ParentGroupAttributes.csv"
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;