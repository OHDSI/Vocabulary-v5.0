--At least these tables to be updated during refresh:
--1) FRANCE (OBLIGATORY)
--2) Data_NFC_Reference
--3) Data_NFC_Dictionary

CREATE TABLE FRANCE
(
    PRODUCT_DESC    VARCHAR (450), --DESCR_PROD
    FORM_DESC       VARCHAR (250),--DESCR_FORME
    DOSAGE          VARCHAR (100), --VL_WG_UNIT (as it needed to be stored somewhere)
    DOSAGE_ADD      VARCHAR (100), --ADDOS
    VOLUME          VARCHAR (100), --VL_WG_MEAS (based on load_stage (e.g. regexp_replace(volume, '\d*(\.)?(\d)*', '', 'g') = 'ML'))  -> then UPDATE WITH CONCATENATION OF VL_WG_UNIT || ' ' || VL_WG_MEAS ( based on substring(volume, '(\d+(\.\d+)*)')::FLOAT,)
    PACKSIZE        VARCHAR (100), --PCK_SIZE
    CLAATC          VARCHAR (100), --CODE_ATC
    PFC             VARCHAR (100), --CODE_PFC
    MOLECULE        VARCHAR (1024), --MOLECULE
    CD_NFC_3        VARCHAR (250), -- CD_NFC_3
    ENGLISH         VARCHAR (250), -- retrieve from Update table
    LB_NFC_3        VARCHAR (250), -- retrieve from Update table
    DESCR_PCK       VARCHAR (250), -- DESCR_PCK
    STRG_UNIT       VARCHAR (100), --STRG_UNIT
    STRG_MEAS       VARCHAR (100) --STRG_MEAS
);

-- Based on substring(volume, '(\d+(\.\d+)*)')::FLOAT,)
UPDATE FRANCE
SET VOLUME = CONCAT(DOSAGE,' ',VOLUME )
;

--After population of VOLUME rebuild the DOSAGE according to https://docs.google.com/document/d/1Fp4Ru2ONqlb9x4ch_IRifXrV810BGznfpKbc_a96P2M/edit
--Needed in case when we decide to rerun the Script
UPDATE FRANCE
SET DOSAGE = CONCAT(STRG_UNIT,' ',STRG_MEAS )
;

CREATE TABLE Data_NFC_Reference
(

    CD_NFC_3 VARCHAR (255),
        LB_NFC_3 VARCHAR (255),
        CD_NFC_2	 VARCHAR (255),
        LB_NFC_2	VARCHAR (255),
        CD_NFC_1	VARCHAR (255),
        LB_NFC_1	VARCHAR (255),
        TOPICAL VARCHAR (255)
);


UPDATE FRANCE f
SET LB_NFC_3 = r.LB_NFC_3
FROM Data_NFC_Reference r
where r.CD_NFC_3=f.CD_NFC_3;

CREATE TABLE Data_NFC_Dictionary
(

     CD_NFC_1 VARCHAR (255),
     LB_NFC_1 VARCHAR (255),
     English	 VARCHAR (255)
);

UPDATE FRANCE f
SET english = r.English
FROM Data_NFC_Dictionary r
where r.CD_NFC_1= left(f.CD_NFC_3,1);


CREATE TABLE DRUG_CONCEPT_STAGE
(
    CONCEPT_NAME               VARCHAR (255),
    VOCABULARY_ID              VARCHAR (20),
    CONCEPT_CLASS_ID           VARCHAR (25),
    STANDARD_CONCEPT           VARCHAR (1),
    CONCEPT_CODE               VARCHAR (50),
    POSSIBLE_EXCIPIENT         VARCHAR (1),
    DOMAIN_ID                  VARCHAR (25),
    VALID_START_DATE           DATE,
    VALID_END_DATE             DATE,
    INVALID_REASON             VARCHAR (1),
    SOURCE_CONCEPT_CLASS_ID    VARCHAR (50)
);

CREATE TABLE INTERNAL_RELATIONSHIP_STAGE
(
    CONCEPT_CODE_1    VARCHAR (50),
    CONCEPT_CODE_2    VARCHAR (50)
);

CREATE TABLE DS_STAGE
(
    DRUG_CONCEPT_CODE          VARCHAR (255),
    INGREDIENT_CONCEPT_CODE    VARCHAR (255),
    BOX_SIZE                   INTEGER,
    AMOUNT_VALUE               FLOAT,
    AMOUNT_UNIT                VARCHAR (255),
    NUMERATOR_VALUE            FLOAT,
    NUMERATOR_UNIT             VARCHAR (255),
    DENOMINATOR_VALUE          FLOAT,
    DENOMINATOR_UNIT           VARCHAR (255)
);

CREATE TABLE RELATIONSHIP_TO_CONCEPT
(
    CONCEPT_CODE_1       VARCHAR (255),
    VOCABULARY_ID_1      VARCHAR (20),
    CONCEPT_ID_2         INTEGER,
    PRECEDENCE           INTEGER,
    CONVERSION_FACTOR    FLOAT
);

CREATE TABLE PC_STAGE
(
    PACK_CONCEPT_CODE    VARCHAR (255),
    DRUG_CONCEPT_CODE    VARCHAR (255),
    AMOUNT               FLOAT,
    BOX_SIZE             INT4
);

CREATE TABLE FRANCE_NAMES_TRANSLATION
(
    DOSE_FORM         VARCHAR (255),
    DOSE_FORM_NAME    VARCHAR (255)
);

CREATE TABLE DS_STAGE_MANUAL
(
    PRODUCT_DESC         VARCHAR (255),
    FORM_DESC            VARCHAR (255),
    DOSAGE               VARCHAR (255),
    DOSAGE_ADD           VARCHAR (255),
    VOLUME               VARCHAR (255),
    PACKSIZE             INTEGER,
    CLAATC               VARCHAR (255),
    PFC                  VARCHAR (100),
    MOLECULE             VARCHAR (255),
    CD_NFC_3             VARCHAR (255),
    ENGLISH              VARCHAR (255),
    LB_NFC_3             VARCHAR (255),
    DESCR_PCK            VARCHAR (255),
    STRG_UNIT            VARCHAR (255),
    STRG_MEAS            VARCHAR (255),
    AMOUNT_VALUE         FLOAT,
    AMOUNT_UNIT          VARCHAR (255),
    NUMERATOR_VALUE      FLOAT,
    NUMERATOR_UNIT       VARCHAR (255),
    DENOMINATOR_VALUE    FLOAT,
    DENOMINATOR_UNIT     VARCHAR (255)
);

CREATE TABLE INGREDIENT_ALL_COMPLETED
(
    CONCEPT_NAME    VARCHAR (250),
    CONCEPT_ID_2    INTEGER
);

CREATE TABLE BRAND_NAMES_MANUAL
(
    CONCEPT_NAME    VARCHAR (250),
    CONCEPT_ID_2    INTEGER
);

CREATE TABLE NEW_FORM_NAME_MAPPING
(
    DOSE_FORM_NAME  VARCHAR(250),
    CONCEPT_ID_2    INTEGER,
    PRECEDENCE      INTEGER,
    CONCEPT_NAME    VARCHAR(250)
);

CREATE TABLE COMPLETE_NAME
(
    CONCEPT_CODE    VARCHAR (50),
    CONCEPT_NAME    VARCHAR (255)
);




