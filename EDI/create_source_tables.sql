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
* Authors: Dmitry Dymshyts, Timur Vakhitov, Seng Chan You, Yiju Park
* Date: 2024
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.EDI_DATA;
CREATE TABLE SOURCES.EDI_DATA
(
   CONCEPT_CODE           VARCHAR (1000),
   CONCEPT_NAME           TEXT,
   CONCEPT_SYNONYM        TEXT,
   DOMAIN_ID              VARCHAR (1000),
   VOCABULARY_ID          VARCHAR (1000),
   CONCEPT_CLASS_ID       VARCHAR (1000),
   VALID_START_DATE       DATE,
   VALID_END_DATE         DATE,
   INVALID_REASON         VARCHAR (10),
   ANCESTOR_CONCEPT_CODE  VARCHAR (1000),
   PREVIOUS_CONCEPT_CODE  VARCHAR (1000),
   MATERIAL               TEXT,
   COMPANY_NAME          VARCHAR (255),
   DOSAGE                 TEXT,
   DOSAGE_UNIT            TEXT,
   SANJUNG_NAME           TEXT,
   VOCABULARY_DATE        DATE,
   VOCABULARY_VERSION     VARCHAR (200)
);