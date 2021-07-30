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
*Author: Medical team, edited by Timur
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.AMT_FULL_DESCR_DRUG_ONLY;
CREATE TABLE SOURCES.AMT_FULL_DESCR_DRUG_ONLY
(
   ID                  BIGINT,
   EFFECTIVETIME       VARCHAR(255),
   ACTIVE              INT,
   MODULEID            BIGINT,
   CONCEPTID           BIGINT,
   LANGUAGECODE        VARCHAR(2),
   TYPEID              BIGINT,
   TERM                VARCHAR(4000),
   CASESIGNIFICANCEID  BIGINT
);

DROP TABLE IF EXISTS SOURCES.AMT_SCT2_CONCEPT_FULL_AU;
CREATE TABLE SOURCES.AMT_SCT2_CONCEPT_FULL_AU
(
   ID                  BIGINT,
   EFFECTIVETIME       VARCHAR(8),
   ACTIVE              INT4,
   MODULEID            BIGINT,
   STATUSID            BIGINT,
   VOCABULARY_DATE     DATE,
   VOCABULARY_VERSION  VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.AMT_RF2_FULL_RELATIONSHIPS;
CREATE TABLE SOURCES.AMT_RF2_FULL_RELATIONSHIPS
(
   ID                    BIGINT,
   EFFECTIVETIME         VARCHAR(8),
   ACTIVE                INT,
   MODULEID              BIGINT,
   SOURCEID              BIGINT,
   DESTINATIONID         BIGINT,
   RELATIONSHIPGROUP     INT,
   TYPEID                BIGINT,
   CHARACTERISTICTYPEID  BIGINT,
   MODIFIERID            BIGINT
);

CREATE TABLE SOURCES.AMT_SCT2_RELA_FULL_AU
(
   ID                    BIGINT,
   EFFECTIVETIME         VARCHAR(8),
   ACTIVE                INT,
   MODULEID              BIGINT,
   SOURCEID              BIGINT,
   DESTINATIONID         BIGINT,
   RELATIONSHIPGROUP     INT,
   TYPEID                BIGINT,
   CHARACTERISTICTYPEID  BIGINT,
   MODIFIERID            BIGINT
);

DROP TABLE IF EXISTS SOURCES.AMT_RF2_SS_STRENGTH_REFSET;
CREATE TABLE SOURCES.AMT_RF2_SS_STRENGTH_REFSET
(
   ID                     VARCHAR(255),
   EFFECTIVETIME          VARCHAR(8),
   ACTIVE                 INT,
   MODULEID               BIGINT,
   REFSETID               BIGINT,
   REFERENCEDCOMPONENTID  BIGINT,
   UNITID                 BIGINT,
   OPERATORID             BIGINT,
   VALUE                  VARCHAR(255)
);

DROP TABLE IF EXISTS SOURCES.AMT_CREFSET_LANGUAGE;
CREATE TABLE SOURCES.AMT_CREFSET_LANGUAGE
(
   ID                         VARCHAR(255),
   EFFECTIVETIME              VARCHAR(8),
   ACTIVE                     INT2,
   MODULEID                   BIGINT,
   REFSETID                   BIGINT,
   REFERENCEDCOMPONENTID      BIGINT,
   ACCEPTABILITYID            BIGINT
);

CREATE INDEX idx_amt_lang_refid ON SOURCES.AMT_CREFSET_LANGUAGE (REFERENCEDCOMPONENTID);
CREATE INDEX idx_amt_concept_id ON SOURCES.AMT_SCT2_CONCEPT_FULL_AU (ID);
CREATE INDEX idx_amt_descr_id ON SOURCES.AMT_FULL_DESCR_DRUG_ONLY (CONCEPTID);
CREATE INDEX idx_amt_rela_id ON SOURCES.AMT_RF2_FULL_RELATIONSHIPS (ID);
CREATE INDEX idx_amt_rela2_id ON SOURCES.AMT_SCT2_RELA_FULL_AU (ID);