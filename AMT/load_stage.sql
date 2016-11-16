create table GOV_ING_TO_SNOMED 
(id	varchar (255),
effectiveTime	varchar (255),
active	varchar (255),
moduleId	varchar (255),
refsetId	varchar (255),
referencedComponentId	varchar (255),
mapType	varchar (255),
targetSnomedCtSubstance varchar (255))
;

WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Refset/Map/der2_csRefset_SubstanceToSnomedCtauMappingFull_AU1000036_20160930.txt"
         -type=text
         -table=GOV_ING_TO_SNOMED
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,REFSETID,REFERENCEDCOMPONENTID,MAPTYPE,TARGETSNOMEDCTSUBSTANCE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000;

CREATE TABLE FULL_DESCR_DRUG_ONLY
(
   ID                  VARCHAR2(255 Byte),
   EFFECTIVETIME       VARCHAR2(255 Byte),
   ACTIVE              VARCHAR2(255 Byte),
   MODULEID            VARCHAR2(255 Byte),
   CONCEPTID           VARCHAR2(255 Byte),
   LANGUAGECODE        VARCHAR2(255 Byte),
   TYPEID              VARCHAR2(255 Byte),
   TERM                VARCHAR2(1555 Byte),
   CASESIGNIFICANCEID  VARCHAR2(255 Byte)
)
TABLESPACE USERS;

WbImport -file="C:/Users/aostropolets/Desktop/Australia/sct2_Description_Full-en-AU_AU1000168_20160930.txt"
         -type=text
         -table=FULL_DESCR_DRUG_ONLY
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,CONCEPTID,LANGUAGECODE,TYPEID,TERM,CASESIGNIFICANCEID
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=10000;


create table rf2_full_concepts (
id varchar (255), 
effectivetime varchar (255), 
active varchar (255),
moduleid varchar (255),
definitionstatusid  varchar (255));


WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Terminology/sct2_Concept_Full_AU1000036_20160930.txt"
         -type=text
         -table=RF2_FULL_CONCEPTS
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,DEFINITIONSTATUSID
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=1000;

create table rf2_full_descriptions (
id varchar (255), 
effectivetime varchar (255), 
active varchar (255),
moduleid varchar (255),
conceptId varchar (255),
languageCode varchar (255),
typeId varchar (255),
term varchar (1555),
caseSignificanceId varchar (255));

WbImport -file="C:\Users\aostropolets\Desktop\Australia\DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930\SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Terminology/sct2_Description_Full-en-AU_AU1000036_20160930.txt"
         -type=text
         -table=RF2_FULL_DESCRIPTIONS
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,CONCEPTID,LANGUAGECODE,TYPEID,TERM,CASESIGNIFICANCEID
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100000;

create table rf2_full_relationships (
id varchar (255),
effectivetime varchar (255),
active varchar (255),
moduleid varchar (255), 
sourceid varchar (255),
destinationid varchar (255),
relationshipgroup varchar (255),
typeid varchar (255),
characteristictypeid varchar (255),
modifierid varchar (255)
);
WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Terminology/sct2_Relationship_Full_AU1000036_20160930.txt"
         -type=text
         -table=RF2_FULL_RELATIONSHIPS
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,SOURCEID,DESTINATIONID,RELATIONSHIPGROUP,TYPEID,CHARACTERISTICTYPEID,MODIFIERID
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=10000;



create table rf2_full_language_refset
(id varchar (255),
effectivetime varchar (255),
active varchar (255),
moduleid varchar (255), 
 refsetid varchar (255), 
 referencedcomponentid varchar (255), 
 valueid varchar (255));
 WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Refset/Language/der2_cRefset_LanguageFull-en-AU_AU1000036_20160930.txt"
         -type=text
         -table=RF2_FULL_LANGUAGE_REFSET
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,REFSETID,REFERENCEDCOMPONENTID,$wb_skip$
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=10000;


create table rf2_ss_refset (
id varchar (255),
effectivetime varchar (255),
active varchar (255),
moduleid varchar (255), 
refsetid varchar (255), 
referencedcomponentid varchar (255));

WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Refset/Content/der2_Refset_ContaineredTradeProductPackFull_AU1000036_20160930.txt"
         -type=text
         -table=RF2_SS_REFSET
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,REFSETID,REFERENCEDCOMPONENTID
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100000;
         
WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Refset/Content/der2_Refset_MedicinalProductUnitOfUseFull_AU1000036_20160930.txt"
         -type=text
         -table=RF2_SS_REFSET
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,REFSETID,REFERENCEDCOMPONENTID
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100000;

WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Refset/Content/der2_Refset_TradeProductUnitOfUseFull_AU1000036_20160930.txt"
         -type=text
         -table=RF2_SS_REFSET
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,REFSETID,REFERENCEDCOMPONENTID
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100000;
         
WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Refset/Content/der2_Refset_TradeProductPackFull_AU1000036_20160930.txt"
         -type=text
         -table=RF2_SS_REFSET
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,REFSETID,REFERENCEDCOMPONENTID
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100000;
         
WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Refset/Content/der2_Refset_TradeProductFull_AU1000036_20160930.txt"
         -type=text
         -table=RF2_SS_REFSET
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,REFSETID,REFERENCEDCOMPONENTID
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100000;
         
WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Refset/Content/der2_Refset_MedicinalProductPackFull_AU1000036_20160930.txt"
         -type=text
         -table=RF2_SS_REFSET
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,REFSETID,REFERENCEDCOMPONENTID
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100000;
         
WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Refset/Content/der2_Refset_MedicinalProductFull_AU1000036_20160930.txt"
         -type=text
         -table=RF2_SS_REFSET
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,REFSETID,REFERENCEDCOMPONENTID
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100000;


create table rf2_ss_strength_refset (
id varchar (255),
effectivetime varchar (255),
active varchar (255),
moduleid varchar (255), 
refsetid varchar (255), 
referencedcomponentid varchar (255), 
unitid varchar (255), 
operatorid varchar (255), 
value varchar (255)
);
WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Refset/Content/der2_ccsRefset_StrengthFull_AU1000036_20160930.txt"
         -type=text
         -table=RF2_SS_STRENGTH_REFSET
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,REFSETID,REFERENCEDCOMPONENTID,UNITID,OPERATORID,VALUE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100000;

create table rf2_ss_unit_of_use_size_refset (
id varchar (255),
effectivetime varchar (255),
active varchar (255),
moduleid varchar (255), 
refsetid varchar (255), 
referencedcomponentid varchar (255), 
unitid varchar (255), 
operatorid varchar (255), 
value varchar (255)
);WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Refset/Content/der2_ccsRefset_UnitOfUseSizeFull_AU1000036_20160930.txt"
         -type=text
         -table=RF2_SS_UNIT_OF_USE_SIZE_REFSET
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,REFSETID,REFERENCEDCOMPONENTID,UNITID,OPERATORID,VALUE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100000;

create table rf2_ss_unit_of_use_qr (
id varchar (255),
effectivetime varchar (255),
active varchar (255),
moduleid varchar (255), 
refsetid varchar (255), 
referencedcomponentid varchar (255), 
unitid varchar (255), 
operatorid varchar (255), 
value varchar (255)
);
WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Refset/Content/der2_ccsRefset_UnitOfUseQuantityFull_AU1000036_20160930.txt"
         -type=text
         -table=RF2_SS_UNIT_OF_USE_QR
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,REFSETID,REFERENCEDCOMPONENTID,UNITID,OPERATORID,VALUE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100000;

create table rf2_ss_subpack_quantity_refset (
id varchar (255),
effectivetime varchar (255),
active varchar (255),
moduleid varchar (255), 
refsetid varchar (255), 
referencedcomponentid varchar (255), 
unitid varchar (255), 
operatorid varchar (255), 
value varchar (255));

WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Refset/Content/der2_cciRefset_SubpackQuantityFull_AU1000036_20160930.txt"
         -type=text
         -table=RF2_SS_SUBPACK_QUANTITY_REFSET
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,REFSETID,REFERENCEDCOMPONENTID,UNITID,OPERATORID,VALUE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100000;
         
create table identifier_full (
identifierSchemeId	varchar(255),
alternateIdentifier	varchar(255),
effectiveTime	varchar(255),
active	varchar(255),
moduleId	varchar(255),
referencedComponentId varchar(255));

WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Full/Terminology/sct2_Identifier_Full_AU1000036_20160930.txt"
         -type=text
         -table=IDENTIFIER_FULL
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=IDENTIFIERSCHEMEID,ALTERNATEIDENTIFIER,EFFECTIVETIME,ACTIVE,MODULEID,REFERENCEDCOMPONENTID
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=1000;

create table AssociationReferenceSnapshot(
id varchar (255), 
effectivetime varchar (255), 
active varchar (255),
moduleid varchar (255),
refsetId  varchar (255),
referencedComponentId varchar (255),
targetComponentId varchar (255)
);
WbImport -file="C:/Users/aostropolets/Desktop/Australia/DH_2439_2016_SNOMEDCT-AU_CombinedReleaseFile_v20160930/SnomedCT_Release_AU1000036_20160930/RF2Release/Snapshot/Refset/Content/der2_cRefset_AssociationReferenceSnapshot_AU1000036_20160930.txt"
         -type=text
         -table=ASSOCIATIONREFERENCESNAPSHOT
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ID,EFFECTIVETIME,ACTIVE,MODULEID,REFSETID,REFERENCEDCOMPONENTID,TARGETCOMPONENTID
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=10000;
