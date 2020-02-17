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

DROP TABLE IF EXISTS SOURCES.LEX_SCT2_CONCEPT;
CREATE TABLE SOURCES.LEX_SCT2_CONCEPT
(
   ID                 VARCHAR (100),
   EFFECTIVETIME      TIMESTAMP,
   ACTIVE             INTEGER,
   MODULEID           VARCHAR (100),
   STATUSID           VARCHAR (100),
   VOCABULARY_DATE    DATE,
   VOCABULARY_VERSION VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.LEX_SCT2_DESC;
CREATE TABLE SOURCES.LEX_SCT2_DESC
(
   ID                   VARCHAR (100),
   EFFECTIVETIME        TIMESTAMP,
   ACTIVE               INTEGER,
   MODULEID             VARCHAR (100),
   CONCEPTID            VARCHAR (100),
   LANGUAGECODE         VARCHAR (2),
   TYPEID               VARCHAR (100),
   TERM                 VARCHAR (256),
   CASESIGNIFICANCEID   VARCHAR (100)
);

DROP TABLE IF EXISTS SOURCES.LEX_SCT2_RELA;
CREATE TABLE SOURCES.LEX_SCT2_RELA
(
   ID                     VARCHAR (100),
   EFFECTIVETIME          TIMESTAMP,
   ACTIVE                 INTEGER,
   MODULEID               VARCHAR (100),
   SOURCEID               VARCHAR (100),
   DESTINATIONID          VARCHAR (100),
   RELATIONSHIPGROUP      INTEGER,
   TYPEID                 VARCHAR (100),
   CHARACTERISTICTYPEID   VARCHAR (100),
   MODIFIERID             VARCHAR (100)
);

DROP TABLE IF EXISTS SOURCES.LEX_DER2_CREFSET_ASSREF;
CREATE TABLE SOURCES.LEX_DER2_CREFSET_ASSREF
(
    ID                         VARCHAR (100),
    EFFECTIVETIME              TIMESTAMP,
    ACTIVE                     INTEGER,
    MODULEID                   VARCHAR (100),
    REFSETID                   VARCHAR (100),
    REFERENCEDCOMPONENTID      VARCHAR (100),
    TARGETCOMPONENT            VARCHAR (100)
);

CREATE INDEX idx_lex_concept_id ON SOURCES.LEX_SCT2_CONCEPT (ID);
CREATE INDEX idx_lex_desc_id ON SOURCES.LEX_SCT2_DESC (CONCEPTID);
CREATE INDEX idx_lex_rela_id ON SOURCES.LEX_SCT2_RELA (ID);