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
* Authors: Timur Vakhitov
* Date: 2021
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.HEMONC_CS;
CREATE TABLE SOURCES.HEMONC_CS
(
   CONCEPT_ID         INT4,
   CONCEPT_NAME       TEXT,
   DOMAIN_ID          TEXT,
   VOCABULARY_ID      TEXT,
   CONCEPT_CLASS_ID   TEXT,
   STANDARD_CONCEPT   TEXT,
   CONCEPT_CODE       TEXT,
   VALID_START_DATE   DATE,
   VALID_END_DATE     DATE,
   INVALID_REASON     TEXT,
   VOCABULARY_DATE    DATE,
   VOCABULARY_VERSION VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.HEMONC_CRS;
CREATE TABLE SOURCES.HEMONC_CRS
(
   CONCEPT_ID_1     INT4,
   CONCEPT_ID_2     INT4,
   CONCEPT_CODE_1   TEXT,
   CONCEPT_CODE_2   TEXT,
   VOCABULARY_ID_1  TEXT,
   VOCABULARY_ID_2  TEXT,
   RELATIONSHIP_ID  TEXT,
   VALID_START_DATE DATE,
   VALID_END_DATE   DATE,
   INVALID_REASON   TEXT
);

DROP TABLE IF EXISTS SOURCES.HEMONC_CSS;
CREATE TABLE SOURCES.HEMONC_CSS
(
   SYNONYM_CONCEPT_ID    INT4,
   SYNONYM_NAME          TEXT,
   SYNONYM_CONCEPT_CODE  TEXT,
   SYNONYM_VOCABULARY_ID TEXT,
   LANGUAGE_CONCEPT_ID   INT4,
   VALID_START_DATE      DATE,
   VALID_END_DATE        DATE,
   INVALID_REASON        TEXT
);