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
* Date: 2017
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.SCT2_CONCEPT_FULL_MERGED;
CREATE TABLE SOURCES.SCT2_CONCEPT_FULL_MERGED
(
   ID                 BIGINT,
   EFFECTIVETIME      VARCHAR (8),
   ACTIVE             INTEGER,
   MODULEID           BIGINT,
   STATUSID           BIGINT,
   VOCABULARY_DATE    DATE,
   VOCABULARY_VERSION VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.SCT2_DESC_FULL_MERGED;
CREATE TABLE SOURCES.SCT2_DESC_FULL_MERGED
(
   ID                   BIGINT,
   EFFECTIVETIME        VARCHAR (8),
   ACTIVE               INTEGER,
   MODULEID             BIGINT,
   CONCEPTID            BIGINT,
   LANGUAGECODE         VARCHAR (2),
   TYPEID               BIGINT,
   TERM                 VARCHAR (256),
   CASESIGNIFICANCEID   BIGINT
);

DROP TABLE IF EXISTS SOURCES.SCT2_RELA_FULL_MERGED;
CREATE TABLE SOURCES.SCT2_RELA_FULL_MERGED
(
   ID                     BIGINT,
   EFFECTIVETIME          VARCHAR (8),
   ACTIVE                 INTEGER,
   MODULEID               BIGINT,
   SOURCEID               BIGINT,
   DESTINATIONID          BIGINT,
   RELATIONSHIPGROUP      INTEGER,
   TYPEID                 BIGINT,
   CHARACTERISTICTYPEID   BIGINT,
   MODIFIERID             BIGINT
);

DROP TABLE IF EXISTS SOURCES.DER2_CREFSET_ASSREFFULL_MERGED;
CREATE TABLE SOURCES.DER2_CREFSET_ASSREFFULL_MERGED
(
    ID                         VARCHAR(256),
    EFFECTIVETIME              VARCHAR(8),
    ACTIVE                     INTEGER, 
    MODULEID                   BIGINT,
    REFSETID                   BIGINT,
    REFERENCEDCOMPONENTID      BIGINT,
    TARGETCOMPONENT            BIGINT
);

CREATE INDEX idx_concept_merged_id ON SOURCES.SCT2_CONCEPT_FULL_MERGED (ID);
CREATE INDEX idx_desc_merged_id ON SOURCES.SCT2_DESC_FULL_MERGED (CONCEPTID);
CREATE INDEX idx_rela_merged_id ON SOURCES.SCT2_RELA_FULL_MERGED (ID);

--Create XML tables for DM+D
DROP TABLE IF EXISTS SOURCES.F_LOOKUP2,SOURCES.F_INGREDIENT2,SOURCES.F_VTM2,SOURCES.F_VMP2,SOURCES.F_AMP2,SOURCES.F_VMPP2,SOURCES.F_AMPP2,SOURCES.DMDBONUS;
CREATE TABLE SOURCES.F_LOOKUP2 (xmlfield XML);
CREATE TABLE SOURCES.F_INGREDIENT2 (xmlfield XML);
CREATE TABLE SOURCES.F_VTM2 (xmlfield XML);
CREATE TABLE SOURCES.F_VMP2 (xmlfield XML);
CREATE TABLE SOURCES.F_VMPP2 (xmlfield XML);
CREATE TABLE SOURCES.F_AMP2 (xmlfield XML);
CREATE TABLE SOURCES.F_AMPP2 (xmlfield XML);
CREATE TABLE SOURCES.DMDBONUS (xmlfield XML);