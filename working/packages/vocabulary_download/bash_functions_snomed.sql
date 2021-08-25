/*
	20190204 added flag -C to unzip (only SNOMED part) = case insensitive
	20200225 added extraction of der2_Refset_SimpleFull_INT.txt
	20200519 added extraction of der2_cRefset_LanguageFull.txt
	20200511 added extraction of der2_ssRefset_ModuleDependencyFull*.txt
	20201117 added extraction of der2_iisssccRefset_ExtendedMapFull*.txt
	20210202 dm+d removed
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
    unzip -oqjC "$2" "SnomedCT_InternationalRF2_PRODUCTION_*/Full/Refset/Content/der2_cRefset_AssociationFull_INT_*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_InternationalRF2_PRODUCTION_*/Full/Refset/Map/der2_sRefset_SimpleMapFull_INT_*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_InternationalRF2_PRODUCTION_*/Full/Refset/Language/der2_cRefset_LanguageFull*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_InternationalRF2_PRODUCTION_*/Full/Refset/Metadata/der2_ssRefset_ModuleDependencyFull*.txt" -d .
        
    #move result to original folder
    cd "$1"
    rm -f "sct2_Concept_Full_INT.txt" "sct2_Description_Full-en_INT.txt" "sct2_Relationship_Full_INT.txt" "der2_cRefset_AssociationFull_INT.txt" "der2_sRefset_SimpleMapFull_INT.txt" "der2_sRefset_LanguageFull_INT.txt" "der2_ssRefset_ModuleDependencyFull_INT.txt"
    mv work/sct2_Concept_Full_INT_*.txt "sct2_Concept_Full_INT.txt" && \
    mv work/sct2_Description_Full-en_INT_*.txt "sct2_Description_Full-en_INT.txt" && \
    mv work/sct2_Relationship_Full_INT_*.txt "sct2_Relationship_Full_INT.txt" && \
    mv work/der2_cRefset_AssociationFull_INT_*.txt "der2_cRefset_AssociationFull_INT.txt" && \
    mv work/der2_sRefset_SimpleMapFull_INT_*.txt "der2_sRefset_SimpleMapFull_INT.txt" && \
    mv work/der2_cRefset_LanguageFull*.txt "der2_sRefset_LanguageFull_INT.txt" && \
    mv work/der2_ssRefset_ModuleDependencyFull*.txt "der2_ssRefset_ModuleDependencyFull_INT.txt"
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
    unzip -oqjC "$2" "SnomedCT_UKClinicalRF2_PRODUCTION_*/Full/Terminology/sct2_Concept_Full*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_UKClinicalRF2_PRODUCTION_*/Full/Terminology/sct2_Description_Full*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_UKClinicalRF2_PRODUCTION_*/Full/Terminology/sct2_Relationship_Full*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_UKClinicalRF2_PRODUCTION_*/Full/Refset/Content/der2_cRefset_AssociationFull_GB*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_UKClinicalRF2_PRODUCTION_*/Full/Refset/Language/der2_cRefset_LanguageFull*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_UKClinicalRF2_PRODUCTION_*/Full/Refset/Metadata/der2_ssRefset_ModuleDependencyFull*.txt" -d .
        
    #move result to original folder
    cd "$1"
    rm -f "sct2_Concept_Full-UK.txt" "sct2_Description_Full-UK.txt" "sct2_Relationship_Full-UK.txt" "der2_cRefset_AssociationFull_UK.txt" "der2_sRefset_LanguageFull_UK.txt" "der2_ssRefset_ModuleDependencyFull_UK.txt"
    mv work/sct2_Concept_Full*.txt "sct2_Concept_Full-UK.txt" && \
    mv work/sct2_Description_Full*.txt "sct2_Description_Full-UK.txt" && \
    mv work/sct2_Relationship_Full*.txt "sct2_Relationship_Full-UK.txt" && \
    mv work/der2_cRefset_AssociationFull*.txt "der2_cRefset_AssociationFull_UK.txt" && \
    mv work/der2_cRefset_LanguageFull*.txt "der2_sRefset_LanguageFull_UK.txt" && \
    mv work/der2_ssRefset_ModuleDependencyFull*.txt "der2_ssRefset_ModuleDependencyFull_UK.txt"
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
    unzip -oqjC "$2" "SnomedCT_USEditionRF2_PRODUCTION_*/Full/Refset/Content/der2_cRefset_AssociationFull_US*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_USEditionRF2_PRODUCTION_*/Full/Refset/Language/der2_cRefset_LanguageFull*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_USEditionRF2_PRODUCTION_*/Full/Refset/Metadata/der2_ssRefset_ModuleDependencyFull*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_USEditionRF2_PRODUCTION_*/Full/Refset/Map/der2_iisssccRefset_ExtendedMapFull*.txt" -d .
        
    #move result to original folder
    cd "$1"
    rm -f "sct2_Concept_Full_US.txt" "sct2_Description_Full-en_US.txt" "sct2_Relationship_Full_US.txt" "der2_cRefset_AssociationFull_US.txt" "der2_sRefset_LanguageFull_US.txt" "der2_ssRefset_ModuleDependencyFull_US.txt" "der2_iisssccRefset_ExtendedMapFull_US.txt"
    mv work/sct2_Concept_Full_US*.txt "sct2_Concept_Full_US.txt" && \
    mv work/sct2_Description_Full-en_US*.txt "sct2_Description_Full-en_US.txt" && \
    mv work/sct2_Relationship_Full_US*.txt "sct2_Relationship_Full_US.txt" && \
    mv work/der2_cRefset_AssociationFull_US*.txt "der2_cRefset_AssociationFull_US.txt" && \
    mv work/der2_cRefset_LanguageFull*.txt "der2_sRefset_LanguageFull_US.txt" && \
    mv work/der2_ssRefset_ModuleDependencyFull*.txt "der2_ssRefset_ModuleDependencyFull_US.txt" && \
    mv work/der2_iisssccRefset_ExtendedMapFull*.txt "der2_iisssccRefset_ExtendedMapFull_US.txt"
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
    unzip -oqjC "$2" "SnomedCT_UKDrugRF2_Production_*/Full/Refset/Content/der2_cRefset_AssociationFull_GB*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_UKDrugRF2_Production_*/Full/Refset/Language/der2_cRefset_LanguageFull*.txt" -d . && \
    unzip -oqjC "$2" "SnomedCT_UKDrugRF2_Production_*/Full/Refset/Metadata/der2_ssRefset_ModuleDependencyFull*.txt" -d .
        
    #move result to original folder
    cd "$1"
    rm -f "sct2_Concept_Full_GB_DE.txt" "sct2_Description_Full-en-GB_DE.txt" "sct2_Relationship_Full_GB_DE.txt" "der2_cRefset_AssociationFull_GB_DE.txt" "der2_sRefset_LanguageFull_GB_DE.txt" "der2_ssRefset_ModuleDependencyFull_GB_DE.txt"
    mv work/sct2_Concept_Full_GB*.txt "sct2_Concept_Full_GB_DE.txt" && \
    mv work/sct2_Description_Full-en_GB*.txt "sct2_Description_Full-en-GB_DE.txt" && \
    mv work/sct2_Relationship_Full_GB*.txt "sct2_Relationship_Full_GB_DE.txt" && \
    mv work/der2_cRefset_AssociationFull_GB*.txt "der2_cRefset_AssociationFull_GB_DE.txt" && \
    mv work/der2_cRefset_LanguageFull*.txt "der2_sRefset_LanguageFull_GB_DE.txt" && \
    mv work/der2_ssRefset_ModuleDependencyFull*.txt "der2_ssRefset_ModuleDependencyFull_GB_DE.txt"
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;