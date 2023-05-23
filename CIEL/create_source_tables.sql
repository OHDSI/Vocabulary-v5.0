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
* Authors: Christian Reich, Timur Vakhitov, Michael Kallfelz
* Date: 2019-2023
**************************************************************************/

/* 2023/01 - changes in export format of the CIEL database  */

DROP TABLE IF EXISTS SOURCES.CIEL_CONCEPT;
CREATE TABLE SOURCES.CIEL_CONCEPT
(
   CONCEPT_ID      INT4,
   RETIRED         INT4,
   SHORT_NAME      VARCHAR (255),
   DESCRIPTION     VARCHAR (4000),
   FORM_TEXT       VARCHAR (4000),
   DATATYPE_ID     INT4,
   CLASS_ID        INT4,
   IS_SET          INT4,
   CREATOR         INT4,
   DATE_CREATED    DATE,
   VERSION         VARCHAR (50),
   CHANGED_BY      INT4,
   DATE_CHANGED    DATE,
   RETIRED_BY      INT4,
   DATE_RETIRED    DATE,
   RETIRE_REASON   VARCHAR (255),
   UUID            VARCHAR (38)
);

DROP TABLE IF EXISTS SOURCES.CIEL_CONCEPT_CLASS;
CREATE TABLE SOURCES.CIEL_CONCEPT_CLASS
(
   CONCEPT_CLASS_ID   INT4,
   CIEL_NAME          VARCHAR (255),
   DESCRIPTION        VARCHAR (255),
   CREATOR            INT4,
   DATE_CREATED       DATE,
   RETIRED            INT4,
   RETIRED_BY         INT4,
   DATE_RETIRED       DATE,
   RETIRE_REASON      VARCHAR (255),
   UUID               VARCHAR (38)
);

DROP TABLE IF EXISTS SOURCES.CIEL_CONCEPT_NAME;
CREATE TABLE SOURCES.CIEL_CONCEPT_NAME
(
   CONCEPT_ID          INT4,
   CIEL_NAME           VARCHAR (255),
   LOCALE              VARCHAR (50),
   CREATOR             INT4,
   DATE_CREATED        DATE,
   CONCEPT_NAME_ID     INT4,
   VOIDED              INT4,
   VOIDED_BY           INT4,
   DATE_VOIDED         DATE,
   VOID_REASON         VARCHAR (255),
   UUID                VARCHAR (38),
   CONCEPT_NAME_TYPE   VARCHAR (50),
   LOCALE_PREFERRED    INT4
);

DROP TABLE IF EXISTS SOURCES.CIEL_CONCEPT_REFERENCE_MAP;
CREATE TABLE SOURCES.CIEL_CONCEPT_REFERENCE_MAP
(
   CONCEPT_MAP_ID              INT4,
   CREATOR                     INT4,
   DATE_CREATED                DATE,
   CONCEPT_ID                  INT4,
   UUID                        VARCHAR (38),
   CONCEPT_REFERENCE_TERM_ID   INT4,
   CONCEPT_MAP_TYPE_ID         INT4,
   CHANGED_BY                  INT4,
   DATE_CHANGED                DATE
);

DROP TABLE IF EXISTS SOURCES.CIEL_CONCEPT_REFERENCE_TERM;
CREATE TABLE SOURCES.CIEL_CONCEPT_REFERENCE_TERM
(
   CONCEPT_REFERENCE_TERM_ID   INT4,
   CONCEPT_SOURCE_ID           INT4,
   CIEL_NAME                   VARCHAR (255),
   CIEL_CODE                   VARCHAR (255),
   VERSION                     VARCHAR (255),
   DESCRIPTION                 VARCHAR (255),
   CREATOR                     INT4,
   DATE_CREATED                DATE,
   DATE_CHANGED                DATE,
   CHANGED_BY                  INT4,
   RETIRED                     INT4,
   RETIRED_BY                  INT4,
   DATE_RETIRED                DATE,
   RETIRE_REASON               VARCHAR (255),
   UUID                        VARCHAR (38)
);

DROP TABLE IF EXISTS SOURCES.CIEL_CONCEPT_REFERENCE_SOURCE;
CREATE TABLE SOURCES.CIEL_CONCEPT_REFERENCE_SOURCE
(
   CONCEPT_SOURCE_ID   INT4,
   CIEL_NAME           VARCHAR (50),
   DESCRIPTION         VARCHAR (4000),
   HL7_CODE            VARCHAR (50),
   CREATOR             INT4,
   DATE_CREATED        DATE,
   RETIRED             INT4,
   RETIRED_BY          INT4,
   DATE_RETIRED        DATE,
   RETIRE_REASON       VARCHAR (255),
   UUID                VARCHAR (38),
   UNIQUE_ID           VARCHAR (250)
);