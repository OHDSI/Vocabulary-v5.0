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
* Authors: Timur Vakhitov, Christian Reich
* Date: 2018
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.CDM_TABLES;
CREATE TABLE SOURCES.CDM_TABLES(
    TABLE_NAME               VARCHAR(100) NOT NULL,
    COLUMN_NAME              VARCHAR(100) NOT NULL,
    ORDINAL_POSITION         INT2 NOT NULL,
    COLUMN_DEFAULT           VARCHAR(100),
    IS_NULLABLE              VARCHAR(3) NOT NULL,
    COLUMN_TYPE              VARCHAR(100) NOT NULL,
    CHARACTER_MAXIMUM_LENGTH INT2,
    DDL_DATE                 TIMESTAMP NOT NULL,
    DDL_RELEASE_ID           TEXT NOT NULL,
    VOCABULARY_DATE          DATE NOT NULL,
    VOCABULARY_VERSION       VARCHAR (200) NOT NULL
);

DROP TABLE IF EXISTS SOURCES.CDM_RAW_TABLE;
CREATE TABLE SOURCES.CDM_RAW_TABLE
(
    DDL_TEXT             TEXT NOT NULL,
    DDL_DATE             TIMESTAMP,
    DDL_RELEASE_ID       TEXT,
    VOCABULARY_DATE      DATE,
    VOCABULARY_VERSION   VARCHAR (200)
);

CREATE INDEX IDX_CDM_DDL_RELEASE_ID ON SOURCES.CDM_TABLES(DDL_RELEASE_ID);