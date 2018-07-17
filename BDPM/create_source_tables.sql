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
DROP TABLE IF EXISTS SOURCES.BDPM_DRUG;
CREATE TABLE SOURCES.BDPM_DRUG
(
    DRUG_CODE            VARCHAR (255),
    DRUG_DESCR           VARCHAR (300),
    FORM                 VARCHAR (255),
    ROUTE                VARCHAR (255),
    STATUS               VARCHAR (255),
    CERTIFIER            VARCHAR (255),
    MARKET_STATUS        VARCHAR (255),
    APPROVAL_DATE        DATE,
    INACTIVE_FLAG        VARCHAR (25),
    EU_NUMBER            VARCHAR (255),
    MANUFACTURER         VARCHAR (255),
    SURVEILLANCE_FLAG    VARCHAR (5),
    VOCABULARY_DATE      DATE,
    VOCABULARY_VERSION   VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.BDPM_INGREDIENT;
CREATE TABLE SOURCES.BDPM_INGREDIENT
(
    DRUG_CODE      VARCHAR (255),
    DRUG_FORM      VARCHAR (255),
    FORM_CODE      VARCHAR (255),
    INGREDIENT     VARCHAR (255),
    DOSAGE         VARCHAR (255),
    VOLUME         VARCHAR (255),
    INGR_NATURE    VARCHAR (5),
    COMP_NUMBER    INT,
    FILLER_COLUMN  VARCHAR(1)
);

DROP TABLE IF EXISTS SOURCES.BDPM_PACKAGING;
CREATE TABLE SOURCES.BDPM_PACKAGING
(
    DRUG_CODE             VARCHAR (255),
    DIN_7                 INT,
    PACKAGING             VARCHAR (355),
    STATUS                VARCHAR (255),
    MARKET_STATUS         VARCHAR (255),
    MARKETED_DATE         VARCHAR (255),
    DIN_13                BIGINT,
    COMMUNITY_APPROVAL    VARCHAR (255),
    REPAYMENT_RATE        VARCHAR (255),
    DRUG_COST             VARCHAR (255),
    FILLER_COLUMN         VARCHAR (255),
    FILLER_COLUMN2        VARCHAR (255),
    FILLER_COLUMN3        VARCHAR (4000)
);

DROP TABLE IF EXISTS SOURCES.BDPM_GENER;
CREATE TABLE SOURCES.BDPM_GENER
(
    GENERIC_GROUP     INT,
    GENERIC_DESC      VARCHAR (1000),
    DRUG_CODE         VARCHAR (255),
    GENERIC_TYPE      INT,
    SERIAL_NUMBER     INT,
    FILLER_COLUMN     VARCHAR (255)
);