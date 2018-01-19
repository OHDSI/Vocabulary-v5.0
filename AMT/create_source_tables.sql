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
);

CREATE SCT2_CONCEPT_FULL_AU
(
   ID             VARCHAR2(18 Byte),
   EFFECTIVETIME  VARCHAR2(8 Byte),
   ACTIVE         VARCHAR2(1 Byte),
   MODULEID       VARCHAR2(18 Byte),
   STATUSID       VARCHAR2(256 Byte)
)
TABLESPACE USERS;


CREATE TABLE RF2_FULL_RELATIONSHIPS
(
   ID                    VARCHAR2(255 Byte),
   EFFECTIVETIME         VARCHAR2(255 Byte),
   ACTIVE                VARCHAR2(255 Byte),
   MODULEID              VARCHAR2(255 Byte),
   SOURCEID              VARCHAR2(255 Byte),
   DESTINATIONID         VARCHAR2(255 Byte),
   RELATIONSHIPGROUP     VARCHAR2(255 Byte),
   TYPEID                VARCHAR2(255 Byte),
   CHARACTERISTICTYPEID  VARCHAR2(255 Byte),
   MODIFIERID            VARCHAR2(255 Byte)
);


CREATE TABLE RF2_SS_REFSET
(
   ID                     VARCHAR2(255 Byte),
   EFFECTIVETIME          VARCHAR2(255 Byte),
   ACTIVE                 VARCHAR2(255 Byte),
   MODULEID               VARCHAR2(255 Byte),
   REFSETID               VARCHAR2(255 Byte),
   REFERENCEDCOMPONENTID  VARCHAR2(255 Byte)
);


CREATE RF2_SS_STRENGTH_REFSET
(
   ID                     VARCHAR2(255 Byte),
   EFFECTIVETIME          VARCHAR2(255 Byte),
   ACTIVE                 VARCHAR2(255 Byte),
   MODULEID               VARCHAR2(255 Byte),
   REFSETID               VARCHAR2(255 Byte),
   REFERENCEDCOMPONENTID  VARCHAR2(255 Byte),
   UNITID                 VARCHAR2(255 Byte),
   OPERATORID             VARCHAR2(255 Byte),
   VALUE                  VARCHAR2(255 Byte)
);


CREATE RF2_SS_UNIT_OF_USE_SIZE_REFSET
(
   ID                     VARCHAR2(255 Byte),
   EFFECTIVETIME          VARCHAR2(255 Byte),
   ACTIVE                 VARCHAR2(255 Byte),
   MODULEID               VARCHAR2(255 Byte),
   REFSETID               VARCHAR2(255 Byte),
   REFERENCEDCOMPONENTID  VARCHAR2(255 Byte),
   UNITID                 VARCHAR2(255 Byte),
   OPERATORID             VARCHAR2(255 Byte),
   VALUE                  VARCHAR2(255 Byte)
);

CREATE TABLE RF2_SS_UNIT_OF_USE_QR
(
   ID                     VARCHAR2(255 Byte),
   EFFECTIVETIME          VARCHAR2(255 Byte),
   ACTIVE                 VARCHAR2(255 Byte),
   MODULEID               VARCHAR2(255 Byte),
   REFSETID               VARCHAR2(255 Byte),
   REFERENCEDCOMPONENTID  VARCHAR2(255 Byte),
   UNITID                 VARCHAR2(255 Byte),
   OPERATORID             VARCHAR2(255 Byte),
   VALUE                  VARCHAR2(255 Byte)
);

CREATE TABLE RF2_SS_SUBPACK_QUANTITY_REFSET
(
   ID                     VARCHAR2(255 Byte),
   EFFECTIVETIME          VARCHAR2(255 Byte),
   ACTIVE                 VARCHAR2(255 Byte),
   MODULEID               VARCHAR2(255 Byte),
   REFSETID               VARCHAR2(255 Byte),
   REFERENCEDCOMPONENTID  VARCHAR2(255 Byte),
   UNITID                 VARCHAR2(255 Byte),
   OPERATORID             VARCHAR2(255 Byte),
   VALUE                  VARCHAR2(255 Byte)
);


