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
   CONCEPT_NAME              VARCHAR(255),
   VOCABULARY_ID             VARCHAR(20),
   CONCEPT_CLASS_ID          VARCHAR(25),
   SOURCE_CONCEPT_CLASS_ID   VARCHAR(25),
   STANDARD_CONCEPT          VARCHAR(1),
   CONCEPT_CODE              VARCHAR(50),
   POSSIBLE_EXCIPIENT        VARCHAR(1),
   DOMAIN_ID                 VARCHAR(25),
   VALID_START_DATE          DATE,
   VALID_END_DATE            DATE,
   INVALID_REASON            VARCHAR(1)
);

DROP TABLE IF EXISTS DS_STAGE;
CREATE TABLE DS_STAGE
(
   DRUG_CONCEPT_CODE        VARCHAR(255),
   INGREDIENT_CONCEPT_CODE  VARCHAR(255),
   AMOUNT_VALUE             FLOAT,
   AMOUNT_UNIT              VARCHAR(255),
   NUMERATOR_VALUE          FLOAT,
   NUMERATOR_UNIT           VARCHAR(255),
   DENOMINATOR_VALUE        FLOAT,
   DENOMINATOR_UNIT         VARCHAR(255),
   BOX_SIZE                 INT4
);

DROP TABLE IF EXISTS INTERNAL_RELATIONSHIP_STAGE;
CREATE TABLE INTERNAL_RELATIONSHIP_STAGE
(
   CONCEPT_CODE_1     VARCHAR(50),
   CONCEPT_CODE_2     VARCHAR(50)
);

DROP TABLE IF EXISTS RELATIONSHIP_TO_CONCEPT;
CREATE TABLE RELATIONSHIP_TO_CONCEPT
(
   CONCEPT_CODE_1     VARCHAR(255),
   VOCABULARY_ID_1    VARCHAR(20),
   CONCEPT_ID_2       INTEGER,
   PRECEDENCE         INTEGER,
   CONVERSION_FACTOR  FLOAT
);

DROP TABLE IF EXISTS PC_STAGE;
CREATE TABLE PC_STAGE
(
   PACK_CONCEPT_CODE  VARCHAR(255),
   DRUG_CONCEPT_CODE  VARCHAR(255),
   AMOUNT             FLOAT,
   BOX_SIZE           INT4
);

CREATE TABLE GEMSCRIPT_REFERENCE
(
    PRODCODE         VARCHAR (50),
    GEMSCRIPTCODE    VARCHAR (50),
    PRODUCTNAME      VARCHAR (500),
    DRUGSUBSTANCE    VARCHAR (1500),
    STRENGTH         VARCHAR (300),
    FORMULATION      VARCHAR (300),
    ROUTE            VARCHAR (300),
    BNF              VARCHAR (300),
    BNF_WITH_DOTS    VARCHAR (300),
    BNFCHAPTER       VARCHAR (500)
);

CREATE TABLE THIN_GEMSC_DMD_0717
(
    DMD_CODE              VARCHAR (255),
    GENERIC               VARCHAR (255),
    GEMSCRIPT_DRUGCODE    VARCHAR (100),
    ENCRYPTED_DRUGCODE    VARCHAR (100),
    BRAND                 VARCHAR (255)
);

CREATE TABLE PACKS_IN
(
    thin_name         VARCHAR (255),
    gemscript_code    VARCHAR (255),
    gemscript_name    VARCHAR (255),
    pack_component    VARCHAR (250),
    amount            FLOAT
);

CREATE TABLE FULL_MANUAL
(
    DOSAGE                     VARCHAR (50),
    VOLUME                     VARCHAR (50),
    THIN_NAME                  VARCHAR (550),
    GEMSCRIPT_NAME             VARCHAR (550),
    INGREDIENT_ID              INT4,
    THIN_CODE                  VARCHAR (50),
    GEMSCRIPT_CODE             VARCHAR (50),
    INGREDIENT_CONCEPT_CODE    VARCHAR (250),
    DOMAIN_ID                  VARCHAR (50)
);