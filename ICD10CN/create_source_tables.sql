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
* Authors: Medical team
* Date: 2020
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.ICD10CN_CONCEPT;
CREATE TABLE SOURCES.ICD10CN_CONCEPT (
   CONCEPT_ID           INT4,
   CONCEPT_NAME         VARCHAR (255),
   DOMAIN_ID            VARCHAR (20),
   VOCABULARY_ID        VARCHAR (20),
   CONCEPT_CLASS_ID     VARCHAR (20),
   STANDARD_CONCEPT     VARCHAR (1),
   CONCEPT_CODE         VARCHAR (50),
   VALID_START_DATE     DATE,
   VALID_END_DATE       DATE,
   INVALID_REASON       VARCHAR (1),
   ENGLISH_CONCEPT_NAME TEXT,
   CONCEPT_CODE_CLEAN   VARCHAR (50),
   VOCABULARY_DATE      DATE,
   VOCABULARY_VERSION   VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.ICD10CN_CONCEPT_RELATIONSHIP;
CREATE TABLE SOURCES.ICD10CN_CONCEPT_RELATIONSHIP (
   CONCEPT_ID_1     INT4,
   CONCEPT_ID_2     INT4,
   RELATIONSHIP_ID  VARCHAR (20),
   VALID_START_DATE DATE,
   VALID_END_DATE   DATE,
   INVALID_REASON   VARCHAR (1)
);