/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
**************************************************************************/
-- input tables creation
DROP TABLE IF EXISTS DRUG_CONCEPT_STAGE;
CREATE TABLE DRUG_CONCEPT_STAGE
(
    CONCEPT_NAME               VARCHAR (255),
    VOCABULARY_ID              VARCHAR (20),
    CONCEPT_CLASS_ID           VARCHAR (25),
    SOURCE_CONCEPT_CLASS_ID    VARCHAR (25),
    STANDARD_CONCEPT           VARCHAR (1),
    CONCEPT_CODE               VARCHAR (50),
    POSSIBLE_EXCIPIENT         VARCHAR (1),
    DOMAIN_ID                  VARCHAR (25),
    VALID_START_DATE           DATE,
    VALID_END_DATE             DATE,
    INVALID_REASON             VARCHAR (1)
);

DROP TABLE IF EXISTS DS_STAGE;
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

DROP TABLE IF EXISTS INTERNAL_RELATIONSHIP_STAGE;
CREATE TABLE INTERNAL_RELATIONSHIP_STAGE
(
    CONCEPT_CODE_1    VARCHAR (50),
    CONCEPT_CODE_2    VARCHAR (50)
);

DROP TABLE IF EXISTS RELATIONSHIP_TO_CONCEPT;
CREATE TABLE RELATIONSHIP_TO_CONCEPT
(
    CONCEPT_CODE_1       VARCHAR (255),
    VOCABULARY_ID_1      VARCHAR (20),
    CONCEPT_ID_2         INTEGER,
    PRECEDENCE           INTEGER,
    CONVERSION_FACTOR    FLOAT
);

DROP TABLE IF EXISTS PC_STAGE;
CREATE TABLE PC_STAGE
(
    PACK_CONCEPT_CODE    VARCHAR (255),
    DRUG_CONCEPT_CODE    VARCHAR (255),
    AMOUNT               FLOAT,
    BOX_SIZE             INT4
);

--SEQUENCE FOR OMOP-GENERATED CODES STARTING WITH THE LAST CODE USED IN PREVIOUS VOCABULARY
DROP SEQUENCE IF EXISTS conc_stage_seq;
CREATE SEQUENCE conc_stage_seq MINVALUE 97124 MAXVALUE 1000000 START WITH 97124 INCREMENT BY 1 CACHE 20;

DROP TABLE IF EXISTS SOURCE_DATA;
CREATE TABLE SOURCE_DATA
(
    ID                         INT4,
    THERAPY_NAME_CODE          VARCHAR (255),
    THERAPY_NAME               VARCHAR (255),
    PRODUCT_NO                 VARCHAR (255),
    PRODUCT_LAUNCH_DATE        VARCHAR (255),
    PRODUCT_FORM               VARCHAR (255),
    PRODUCT_FORM_NAME          VARCHAR (255),
    STRENGTH                   VARCHAR (255),
    STRENGTH_UNIT_CODE         VARCHAR (255),
    STRENGTH_UNIT              VARCHAR (255),
    VOLUME                     VARCHAR (255),
    VOLUME_UNIT_CODE           VARCHAR (255),
    VOLUME_UNIT                VARCHAR (255),
    PACKSIZE                   VARCHAR (255),
    PACK_PRICE                 VARCHAR (255),
    FORM_LAUNCH_DATE           VARCHAR (255),
    OUT_OF_TRADE_DATE          VARCHAR (255),
    MANUFACTURER               VARCHAR (255),
    MANUFACTURER_NAME          VARCHAR (255),
    MANUFACTURER_SHORT_NAME    VARCHAR (255),
    ATC4_CODE                  VARCHAR (255),
    ATC4_TEXT                  VARCHAR (255),
    ATC3_CODE                  VARCHAR (255),
    ATC3_TEXT                  VARCHAR (255),
    ATC2_CODE                  VARCHAR (255),
    ATC2_TEXT                  VARCHAR (255),
    ATC1_CODE                  VARCHAR (255),
    ATC1_TEXT                  VARCHAR (255),
    WHO_ATC5_CODE              VARCHAR (255),
    WHO_ATC5_TEXT              VARCHAR (255),
    WHO_ATC4_CODE              VARCHAR (255),
    WHO_ATC4_TEXT              VARCHAR (255),
    WHO_ATC3_CODE              VARCHAR (255),
    WHO_ATC3_TEXT              VARCHAR (255),
    WHO_ATC2_CODE              VARCHAR (255),
    WHO_ATC2_TEXT              VARCHAR (255),
    WHO_ATC1_CODE              VARCHAR (255),
    WHO_ATC1_TEXT              VARCHAR (255),
    SUBSTANCE                  VARCHAR (255),
    NO_OF_SUBSTANCES           VARCHAR (255),
    GENERIC_ORIGINAL           VARCHAR (255),
    PZN                        VARCHAR (255),
    NFC_NO                     VARCHAR (255),
    NFC                        VARCHAR (255),
    NFC_DESCRIPTION            VARCHAR (255),
    FCC                        VARCHAR (255)
);

DROP TABLE IF EXISTS GRR_NEW_2;
CREATE TABLE GRR_NEW_2
(
    FCC                     VARCHAR (250),
    PZN                     VARCHAR (250),
    INTL_PACK_FORM_DESC     VARCHAR (250),
    INTL_PACK_STRNT_DESC    VARCHAR (250),
    INTL_PACK_SIZE_DESC     VARCHAR (250),
    PACK_DESC               VARCHAR (250),
    PACK_SUBSTN_CNT         VARCHAR (250),
    MOLECULE                VARCHAR (250),
    WGT_QTY                 VARCHAR (250),
    WGT_UOM_CD              VARCHAR (250),
    PACK_ADDL_STRNT_DESC    VARCHAR (250),
    PACK_WGT_QTY            VARCHAR (250),
    PACK_WGT_UOM_CD         VARCHAR (250),
    PACK_VOL_QTY            VARCHAR (250),
    PACK_VOL_UOM_CD         VARCHAR (250),
    PACK_SIZE_CNT           VARCHAR (250),
    ABS_STRNT_QTY           VARCHAR (250),
    ABS_STRNT_UOM_CD        VARCHAR (250),
    RLTV_STRNT_QTY          VARCHAR (250),
    HMO_DILUTION_CD         VARCHAR (250),
    FORM_DESC               VARCHAR (250),
    BRAND_NAME1             VARCHAR (250),
    BRAND_NAME              VARCHAR (250),
    PROD_LNCH_DT            VARCHAR (250),
    PACK_LNCH_DT            VARCHAR (250),
    PACK_OUT_OF_TRADE_DT    VARCHAR (250),
    PRI_ORG_LNG_NM          VARCHAR (255),
    PRI_ORG_CD              INT4
);

DROP TABLE IF EXISTS GRR_PACK;
CREATE TABLE GRR_PACK
(
    PACK_ID                VARCHAR (255),
    FCC                    VARCHAR (255),
    GRR_PACK_CD            VARCHAR (255),
    IMS_PROD_LNG_NM        VARCHAR (255),
    PRI_IFA_CD             VARCHAR (255),
    PACK_DESC              VARCHAR (255),
    FORM_DESC              VARCHAR (255),
    INTL_PACK_SIZE_DESC    VARCHAR (255)
);

DROP TABLE IF EXISTS GRR_CLASS;
CREATE TABLE GRR_CLASS
(
    NFC_123_CD         VARCHAR (5),
    CLAS_ID            VARCHAR (15),
    ATC_4_CD           VARCHAR (15),
    WHO_ATC_4_CD       VARCHAR (15),
    CTRYSP_ATC_4_CD    VARCHAR (15)
);

DROP TABLE IF EXISTS GRR_PACK_CLAS;
CREATE TABLE GRR_PACK_CLAS
(
    PACK_ID        VARCHAR (255),
    CLAS_ID        VARCHAR (255),
    CUR_REC_IND    VARCHAR (255),
    EFF_FR_DT      VARCHAR (255),
    EFF_TO_DT      VARCHAR (255)
);

DROP TABLE IF EXISTS GRR_DS;
CREATE TABLE GRR_DS
(
    FCC                  VARCHAR (259),
    BOX_SIZE             VARCHAR (250),
    MOLECULE             VARCHAR (250),
    DENOMINATOR_VALUE    FLOAT,
    DENOMINATOR_UNIT     VARCHAR (255),
    AMOUNT_VALUE         FLOAT,
    AMOUNT_UNIT          VARCHAR (255),
    INGREDIENTS_CNT      VARCHAR (250)
);

DROP TABLE IF EXISTS BN_TO_DEL;
CREATE TABLE BN_TO_DEL
(
    PZN                 VARCHAR (250),
    BN                  VARCHAR (1000),
    CONCEPT_ID          INTEGER NOT NULL,
    CONCEPT_NAME        VARCHAR (255) NOT NULL,
    DOMAIN_ID           VARCHAR (20) NOT NULL,
    VOCABULARY_ID       VARCHAR (20) NOT NULL,
    CONCEPT_CLASS_ID    VARCHAR (20) NOT NULL,
    STANDARD_CONCEPT    VARCHAR (1),
    CONCEPT_CODE        VARCHAR (50) NOT NULL,
    VALID_START_DATE    DATE NOT NULL,
    VALID_END_DATE      DATE NOT NULL,
    INVALID_REASON      VARCHAR (1)
);

CREATE TABLE INGR_PARSING
(
    INGR      VARCHAR (255),
    INGR_2    VARCHAR (255)
);

CREATE TABLE DS_SUM_2
(
    DRUG_CONCEPT_CODE          VARCHAR (255),
    INGREDIENT_CONCEPT_CODE    VARCHAR (255),
    BOX_SIZE                   INT4,
    AMOUNT_VALUE               FLOAT,
    AMOUNT_UNIT                VARCHAR (255),
    NUMERATOR_VALUE            FLOAT,
    NUMERATOR_UNIT             VARCHAR (255),
    DENOMINATOR_VALUE          FLOAT,
    DENOMINATOR_UNIT           VARCHAR (255)
);

CREATE TABLE RELATIONSHIP_TO_CONCEPT_OLD
(
    CONCEPT_NAME      VARCHAR (255),
    CONCEPT_ID        INT4,
    CONCEPT_NAME_2    VARCHAR (255),
    PRECEDENCE        INT4
);

CREATE TABLE AUT_UNIT_ALL_MAPPED
(
    CONCEPT_CODE         VARCHAR (255),
    CONCEPT_ID_2         INT4,
    CONCEPT_NAME_2       VARCHAR (255),
    CONVERSION_FACTOR    FLOAT,
    PRECEDENCE           INT4
);

CREATE TABLE AUT_FORM_1
(
    CONCEPT_CODE      VARCHAR (50),
    CONCEPT_NAME      VARCHAR (255),
    CONCEPT_NAME_2    VARCHAR (255) NOT NULL,
    CONCEPT_ID        INT4 NOT NULL,
    PRECEDENCE        INT4
);