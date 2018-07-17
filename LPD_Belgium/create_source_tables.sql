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
* Date: 2017
**************************************************************************/

DROP TABLE IF EXISTS SOURCE_DATA;
CREATE TABLE SOURCE_DATA
(
    PRD_ID               VARCHAR (255),
    COUNT                VARCHAR (255),
    PRD_NAME             VARCHAR (255),
    MAST_PRD_NAME        VARCHAR (255),
    MANUFACTURER_NAME    VARCHAR (255),
    PRD_DOSAGE           VARCHAR (255),
    PRD_DOSAGE2          VARCHAR (255),
    PRD_DOSAGE3          VARCHAR (255),
    GAL_ID               VARCHAR (255),
    DRUG_FORM            VARCHAR (255),
    GAL_ID2              VARCHAR (255),
    UNIT_ID              VARCHAR (255),
    UNIT_NAME1           VARCHAR (255),
    UNIT_ID2             VARCHAR (255),
    UNIT_NAME2           VARCHAR (255),
    UNIT_ID3             VARCHAR (255),
    UNIT_NAME3           VARCHAR (255),
    MOL_NAME             VARCHAR (255)
);

DROP TABLE IF EXISTS DEVICES_MAPPED;
CREATE TABLE DEVICES_MAPPED
(
    PRD_NAME    VARCHAR (255)
);

DROP TABLE IF EXISTS BRANDS_MAPPED;
CREATE TABLE BRANDS_MAPPED
(
    PRD_NAME         VARCHAR (255),
    MAST_PRD_NAME    VARCHAR (255),
    CONCEPT_ID       INT4,
    CONCEPT_NAME     VARCHAR (255),
    VOCABULARY_ID    VARCHAR (255)
);

DROP TABLE IF EXISTS PRODUCTS_TO_INGREDS;
CREATE TABLE PRODUCTS_TO_INGREDS
(
    PRD_NAME         VARCHAR (255),
    CONCEPT_ID       INT4 NOT NULL,
    CONCEPT_NAME     VARCHAR (255) NOT NULL,
    VOCABULARY_ID    VARCHAR (20) NOT NULL
);

DROP TABLE IF EXISTS SUPPLIER_MAPPED;
CREATE TABLE SUPPLIER_MAPPED
(
    MANUFACTURER_NAME    VARCHAR (255),
    CONCEPT_ID           INT4,
    CONCEPT_NAME         VARCHAR (255)
);

DROP TABLE IF EXISTS INGRED_MAPPED;
CREATE TABLE INGRED_MAPPED
(
    MOL_NAME         VARCHAR (255),
    CONCEPT_ID       INT4,
    CONCEPT_NAME     VARCHAR (255),
    VOCABULARY_ID    VARCHAR (255),
    PRECEDENCE       INT
);

DROP TABLE IF EXISTS UNITS_MAPPED;
CREATE TABLE UNITS_MAPPED
(
    UNIT_NAME            VARCHAR (255),
    CONCEPT_ID           INT4,
    CONCEPT_NAME         VARCHAR (255),
    CONVERSION_FACTOR    FLOAT,
    PRECEDENCE           INT
);

DROP TABLE IF EXISTS FORMS_MAPPED;
CREATE TABLE FORMS_MAPPED
(
    DRUG_FORM       VARCHAR (255),
    CONCEPT_ID      INT4,
    CONCEPT_NAME    VARCHAR (255),
    PRECEDENCE      INT
);

CREATE TABLE DS_MANUAL
(
    COUNT                INT,
    PRD_ID               INT,
    PRD_NAME             VARCHAR (255),
    CONCEPT_ID           INT,
    CONCEPT_NAME         VARCHAR (255),
    AMOUNT_VALUE         FLOAT,
    AMOUNT_UNIT          VARCHAR (255),
    DENOMINATOR_VALUE    FLOAT,
    DENOMINATOR_UNIT     VARCHAR (255),
    BOX_SIZE             INT
);

CREATE TABLE LOST_ING
(
    PRD_ID        VARCHAR (255),
    PRD_NAME      VARCHAR (255),
    CONCEPT_ID    INT4
);

CREATE TABLE GRIPP
(
    PRD_ID              VARCHAR (255),
    PRD_NAME            VARCHAR (255),
    CONCEPT_ID          INT4,
    CONCEPT_NAME        VARCHAR (255),
    DOMAIN_ID           VARCHAR (20),
    VOCABULARY_ID       VARCHAR (20),
    CONCEPT_CLASS_ID    VARCHAR (20),
    STANDARD_CONCEPT    VARCHAR (1),
    CONCEPT_CODE        VARCHAR (50),
    VALID_START_DATE    DATE,
    VALID_END_DATE      DATE,
    INVALID_REASON      VARCHAR (1)
);