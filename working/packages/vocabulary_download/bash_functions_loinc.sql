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
    unzip -oqj "$2.zip" "LoincTable/Loinc.csv" -d . && \
    unzip -oqj "$2.zip" "LoincTable/MapTo.csv" -d . && \
    unzip -oqj "$2.zip" "LoincTable/SourceOrganization.csv" -d . && \
    unzip -oqj "$2.zip" "AccessoryFiles/ComponentHierarchyBySystem/ComponentHierarchyBySystem.csv" -d . && \
    unzip -oqj "$2.zip" "AccessoryFiles/PanelsAndForms/PanelsAndForms.csv" -d . && \
    unzip -oqj "$2.zip" "AccessoryFiles/PanelsAndForms/AnswerList.csv" -d . && \
    unzip -oqj "$2.zip" "AccessoryFiles/PanelsAndForms/LoincAnswerListLink.csv" -d . && \
    unzip -oqj "$2.zip" "AccessoryFiles/DocumentOntology/DocumentOntology.csv" -d . && \
    unzip -oqj "$2.zip" "AccessoryFiles/GroupFile/Group.csv" -d . && \
    unzip -oqj "$2.zip" "AccessoryFiles/GroupFile/GroupLoincTerms.csv" -d . && \
    unzip -oqj "$2.zip" "AccessoryFiles/GroupFile/ParentGroupAttributes.csv" -d . && \
    unzip -oqj "$2.zip" "AccessoryFiles/PartFile/Part.csv" -d . && \
    unzip -oqj "$2.zip" "AccessoryFiles/PartFile/LoincPartLink_Supplementary.csv" -d . && \
    unzip -oqj "$2.zip" "AccessoryFiles/PartFile/LoincPartLink_Primary.csv" -d . && \
    unzip -oqj "$2.zip" "AccessoryFiles/LoincRsnaRadiologyPlaybook/LoincRsnaRadiologyPlaybook.csv" -d . && \
    unzip -oqj "$2.zip" "AccessoryFiles/ConsumerName/ConsumerName.csv" -d . && \
    unzip -oqj "$2_cpt.zip" "MRSMAP.RRF" -d .
    
    #move result to original folder
    cd "$1"
    rm -f *.*
    mv work/Loinc.csv "loinc.csv" && \
    mv work/MapTo.csv "mapto.csv" && \
    mv work/SourceOrganization.csv "sourceorganization.csv" && \
    mv work/ComponentHierarchyBySystem.csv "componenthierarchybysystem.csv" && \
    mv work/PanelsAndForms.csv "panelsandforms.csv" && \
    mv work/AnswerList.csv "answerlist.csv" && \
    mv work/LoincAnswerListLink.csv "loincanswerlistlink.csv" && \
    mv work/loinc_class.csv "loinc_class.csv" && \
    mv work/DocumentOntology.csv "documentontology.csv" && \
    mv work/Group.csv "group.csv" && \
    mv work/GroupLoincTerms.csv "grouploincterms.csv" && \
    mv work/ParentGroupAttributes.csv "parentgroupattributes.csv" && \
    mv work/Part.csv "part.csv" && \
    mv work/LoincPartLink_Supplementary.csv "loincpartlink_supplementary.csv" && \
    mv work/LoincPartLink_Primary.csv "loincpartlink_primary.csv" && \
    mv work/LoincRsnaRadiologyPlaybook.csv "loincrsnaradiologyplaybook.csv" && \
    mv work/ConsumerName.csv "ConsumerName.csv" && \
    mv work/MRSMAP.RRF "cpt_mrsmap.rrf"
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
  
  REVOKE EXECUTE ON FUNCTION vocabulary_download.get_loinc_prepare FROM PUBLIC, role_read_only;
END $_$;