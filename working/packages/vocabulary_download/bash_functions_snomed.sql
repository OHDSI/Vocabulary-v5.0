/*
	20190204 added flag -C to unzip (only SNOMED part) = case insensitive
*/

--INT part
DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_snomed_prepare_int (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work" && \
    unzip -oqjC "$2" "SnomedCT_InternationalRF2_PRODUCTION_*/Full/Terminology/sct2_Concept_Full_INT_*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_InternationalRF2_PRODUCTION_*/Full/Terminology/sct2_Description_Full-en_INT_*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_InternationalRF2_PRODUCTION_*/Full/Terminology/sct2_Relationship_Full_INT_*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_InternationalRF2_PRODUCTION_*/Full/Refset/Content/der2_cRefset_AssociationFull_INT_*.txt" -d .
        
    #move result to original folder
    cd "$1"
    rm -f "sct2_Concept_Full_INT.txt" "sct2_Description_Full-en_INT.txt" "sct2_Relationship_Full_INT.txt" "der2_cRefset_AssociationFull_INT.txt"
    mv work/sct2_Concept_Full_INT_*.txt "sct2_Concept_Full_INT.txt" && \
    mv work/sct2_Description_Full-en_INT_*.txt "sct2_Description_Full-en_INT.txt" && \
    mv work/sct2_Relationship_Full_INT_*.txt "sct2_Relationship_Full_INT.txt" && \
    mv work/der2_cRefset_AssociationFull_INT_*.txt "der2_cRefset_AssociationFull_INT.txt"
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;

--UK part
DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_snomed_prepare_uk (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work" && \
    unzip -oqjC "$2" "SnomedCT_UKClinicalRF2_Production_*/Full/Terminology/sct2_Concept_Full_*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_UKClinicalRF2_Production_*/Full/Terminology/sct2_Description_Full-en-GB_*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_UKClinicalRF2_Production_*/Full/Terminology/sct2_Relationship_Full_*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_UKClinicalRF2_Production_*/Full/Refset/Content/der2_cRefset_AssociationFull_GB*.txt" -d .
        
    #move result to original folder
    cd "$1"
    rm -f "sct2_Concept_Full-UK.txt" "sct2_Description_Full-UK.txt" "sct2_Relationship_Full-UK.txt" "der2_cRefset_AssociationFull_UK.txt"
    mv work/sct2_Concept_Full_GB*.txt "sct2_Concept_Full-UK.txt" && \
    mv work/sct2_Description_Full-en-GB_*.txt "sct2_Description_Full-UK.txt" && \
    mv work/sct2_Relationship_Full_GB*.txt "sct2_Relationship_Full-UK.txt" && \
    mv work/der2_cRefset_AssociationFull_GB*.txt "der2_cRefset_AssociationFull_UK.txt"
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;

--US part
DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_snomed_prepare_us (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work" && \
    unzip -oqjC "$2" "SnomedCT_USEditionRF2_PRODUCTION_*/Full/Terminology/sct2_Concept_Full_*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_USEditionRF2_PRODUCTION_*/Full/Terminology/sct2_Description_Full-en_US*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_USEditionRF2_PRODUCTION_*/Full/Terminology/sct2_Relationship_Full_*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_USEditionRF2_PRODUCTION_*/Full/Refset/Content/der2_cRefset_AssociationFull_US*.txt" -d .
        
    #move result to original folder
    cd "$1"
    rm -f "sct2_Concept_Full_US.txt" "sct2_Description_Full-en_US.txt" "sct2_Relationship_Full_US.txt" "der2_cRefset_AssociationFull_US.txt"
    mv work/sct2_Concept_Full_US*.txt "sct2_Concept_Full_US.txt" && \
    mv work/sct2_Description_Full-en_US*.txt "sct2_Description_Full-en_US.txt" && \
    mv work/sct2_Relationship_Full_US*.txt "sct2_Relationship_Full_US.txt" && \
    mv work/der2_cRefset_AssociationFull_US*.txt "der2_cRefset_AssociationFull_US.txt"
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;

--UK DE part
DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_snomed_prepare_uk_de (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work" && \
    unzip -oqjC "$2" "SnomedCT_UKDrugRF2_Production_*/Full/Terminology/sct2_Concept_Full_GB*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_UKDrugRF2_Production_*/Full/Terminology/sct2_Description_Full-en_GB*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_UKDrugRF2_Production_*/Full/Terminology/sct2_Relationship_Full_GB*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_UKDrugRF2_Production_*/Full/Refset/Content/der2_cRefset_AssociationFull_GB*.txt" -d .
        
    #move result to original folder
    cd "$1"
    rm -f "sct2_Concept_Full_GB_DE.txt" "sct2_Description_Full-en-GB_DE.txt" "sct2_Relationship_Full_GB_DE.txt" "der2_cRefset_AssociationFull_GB_DE.txt"
    mv work/sct2_Concept_Full_GB*.txt "sct2_Concept_Full_GB_DE.txt" && \
    mv work/sct2_Description_Full-en_GB*.txt "sct2_Description_Full-en-GB_DE.txt" && \
    mv work/sct2_Relationship_Full_GB*.txt "sct2_Relationship_Full_GB_DE.txt" && \
    mv work/der2_cRefset_AssociationFull_GB*.txt "der2_cRefset_AssociationFull_GB_DE.txt"
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;

--DMD part
DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_snomed_prepare_dmd (iPath text, iFilename text)
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
    CREATE OR REPLACE FUNCTION vocabulary_download.get_snomed_prepare_dmdbonus (iPath text, iFilename text)
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