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

CREATE SCT2_CONCEPT_FULL_AU
(
   ID             VARCHAR2(18 Byte),
   EFFECTIVETIME  VARCHAR2(8 Byte),
   ACTIVE         VARCHAR2(1 Byte),
   MODULEID       VARCHAR2(18 Byte),
   STATUSID       VARCHAR2(256 Byte)
)
TABLESPACE USERS;


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

create table rf2_ss_refset (
id varchar (255),
effectivetime varchar (255),
active varchar (255),
moduleid varchar (255), 
refsetid varchar (255), 
referencedcomponentid varchar (255));


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
);

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

