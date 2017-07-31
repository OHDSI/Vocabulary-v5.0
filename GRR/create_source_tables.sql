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
CREATE TABLE DRUG_CONCEPT_STAGE
(
   CONCEPT_NAME       	 	 VARCHAR2(255 Byte),
   VOCABULARY_ID      		 VARCHAR2(20 Byte),
   CONCEPT_CLASS_ID   		 VARCHAR2(25 Byte),
   SOURCE_CONCEPT_CLASS_ID       VARCHAR2(25 Byte),
   STANDARD_CONCEPT   		 VARCHAR2(1 Byte),
   CONCEPT_CODE       		 VARCHAR2(50 Byte),
   POSSIBLE_EXCIPIENT 		 VARCHAR2(1 Byte),
   DOMAIN_ID           		 VARCHAR2(25 Byte),
   VALID_START_DATE   		 DATE,
   VALID_END_DATE     		 DATE,
   INVALID_REASON     		 VARCHAR2(1 Byte)
);

CREATE TABLE DS_STAGE
(
   DRUG_CONCEPT_CODE        VARCHAR2(255 Byte),
   INGREDIENT_CONCEPT_CODE  VARCHAR2(255 Byte),
   BOX_SIZE                 INTEGER,
   AMOUNT_VALUE             FLOAT(126),
   AMOUNT_UNIT              VARCHAR2(255 Byte),
   NUMERATOR_VALUE          FLOAT(126),
   NUMERATOR_UNIT           VARCHAR2(255 Byte),
   DENOMINATOR_VALUE        FLOAT(126),
   DENOMINATOR_UNIT         VARCHAR2(255 Byte)
);

CREATE TABLE INTERNAL_RELATIONSHIP_STAGE
(
   CONCEPT_CODE_1     VARCHAR2(50 Byte),
   CONCEPT_CODE_2     VARCHAR2(50 Byte)
);

CREATE TABLE RELATIONSHIP_TO_CONCEPT
(
   CONCEPT_CODE_1     VARCHAR2(255 Byte),
   VOCABULARY_ID_1    VARCHAR2(20 Byte),
   CONCEPT_ID_2       INTEGER,
   PRECEDENCE         INTEGER,
   CONVERSION_FACTOR  FLOAT(126)
);

CREATE TABLE PC_STAGE
(
   PACK_CONCEPT_CODE  VARCHAR2(255 Byte),
   DRUG_CONCEPT_CODE  VARCHAR2(255 Byte),
   AMOUNT             NUMBER,
   BOX_SIZE           NUMBER
);

CREATE TABLE CONCEPT_SYNONYM_STAGE
(
   SYNONYM_CONCEPT_ID     NUMBER,
   SYNONYM_NAME           VARCHAR2(255 Byte)   NOT NULL,
   SYNONYM_CONCEPT_CODE   VARCHAR2(255 Byte)     NOT NULL,
   SYNONYM_VOCABULARY_ID  VARCHAR2(255 Byte)     NOT NULL,
   LANGUAGE_CONCEPT_ID    NUMBER
)
TABLESPACE USERS;

--SEQUENCE FOR OMOP-GENERATED CODES STARTING WITH THE LAST CODE USED IN PREVIOUS VOCABULARY
CREATE sequence conc_stage_seq 
  MINVALUE 97124
  MAXVALUE 1000000
  START WITH 97124
  INCREMENT BY 1
  CACHE 20;
  ;

CREATE TABLE SOURCE_DATA
(
   ID                       NUMBER,
   THERAPY_NAME_CODE        VARCHAR2(255 Byte),
   THERAPY_NAME             VARCHAR2(255 Byte),
   PRODUCT_NO               VARCHAR2(255 Byte),
   PRODUCT_LAUNCH_DATE      VARCHAR2(255 Byte),
   PRODUCT_FORM             VARCHAR2(255 Byte),
   PRODUCT_FORM_NAME        VARCHAR2(255 Byte),
   STRENGTH                 VARCHAR2(255 Byte),
   STRENGTH_UNIT_CODE       VARCHAR2(255 Byte),
   STRENGTH_UNIT            VARCHAR2(255 Byte),
   VOLUME                   VARCHAR2(255 Byte),
   VOLUME_UNIT_CODE         VARCHAR2(255 Byte),
   VOLUME_UNIT              VARCHAR2(255 Byte),
   PACKSIZE                 VARCHAR2(255 Byte),
   PACK_PRICE               VARCHAR2(255 Byte),
   FORM_LAUNCH_DATE         VARCHAR2(255 Byte),
   OUT_OF_TRADE_DATE        VARCHAR2(255 Byte),
   MANUFACTURER             VARCHAR2(255 Byte),
   MANUFACTURER_NAME        VARCHAR2(255 Byte),
   MANUFACTURER_SHORT_NAME  VARCHAR2(255 Byte),
   ATC4_CODE                VARCHAR2(255 Byte),
   ATC4_TEXT                VARCHAR2(255 Byte),
   ATC3_CODE                VARCHAR2(255 Byte),
   ATC3_TEXT                VARCHAR2(255 Byte),
   ATC2_CODE                VARCHAR2(255 Byte),
   ATC2_TEXT                VARCHAR2(255 Byte),
   ATC1_CODE                VARCHAR2(255 Byte),
   ATC1_TEXT                VARCHAR2(255 Byte),
   WHO_ATC5_CODE            VARCHAR2(255 Byte),
   WHO_ATC5_TEXT            VARCHAR2(255 Byte),
   WHO_ATC4_CODE            VARCHAR2(255 Byte),
   WHO_ATC4_TEXT            VARCHAR2(255 Byte),
   WHO_ATC3_CODE            VARCHAR2(255 Byte),
   WHO_ATC3_TEXT            VARCHAR2(255 Byte),
   WHO_ATC2_CODE            VARCHAR2(255 Byte),
   WHO_ATC2_TEXT            VARCHAR2(255 Byte),
   WHO_ATC1_CODE            VARCHAR2(255 Byte),
   WHO_ATC1_TEXT            VARCHAR2(255 Byte),
   SUBSTANCE                VARCHAR2(255 Byte),
   NO_OF_SUBSTANCES         VARCHAR2(255 Byte),
   GENERIC_ORIGINAL         VARCHAR2(255 Byte),
   PZN                      VARCHAR2(255 Byte),
   NFC_NO                   VARCHAR2(255 Byte),
   NFC                      VARCHAR2(255 Byte),
   NFC_DESCRIPTION          VARCHAR2(255 Byte),
   FCC                      VARCHAR2(255 Byte)
);