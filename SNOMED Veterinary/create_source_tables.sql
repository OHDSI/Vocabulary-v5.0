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
* Date: 2019
**************************************************************************/
DROP TABLE IF EXISTS sources_VET_SCT2_CONCEPT_FULL;
CREATE TABLE sources_VET_SCT2_CONCEPT_FULL
(
   ID                 VARCHAR (100),
   EFFECTIVETIME      TIMESTAMP,
   ACTIVE             INTEGER,
   MODULEID           VARCHAR (100),
   STATUSID           VARCHAR (100),
   VOCABULARY_DATE    DATE,
   VOCABULARY_VERSION VARCHAR (200)
);

DROP TABLE IF EXISTS sources_VET_SCT2_DESC_FULL;
CREATE TABLE sources_VET_SCT2_DESC_FULL
(
   ID                   VARCHAR (100),
   EFFECTIVETIME        TIMESTAMP,
   ACTIVE               INTEGER,
   MODULEID             VARCHAR (100),
   CONCEPTID            VARCHAR (100),
   LANGUAGECODE         VARCHAR (2),
   TYPEID               VARCHAR (100),
   TERM                 VARCHAR (1000),
   CASESIGNIFICANCEID   VARCHAR (100)
);

DROP TABLE IF EXISTS sources_VET_SCT2_RELA_FULL;
CREATE TABLE sources_VET_SCT2_RELA_FULL
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

DROP TABLE IF EXISTS sources_VET_DER2_CREFSET_ASSREFFULL;
CREATE TABLE sources_VET_DER2_CREFSET_ASSREFFULL
(
    ID                         VARCHAR (100),
    EFFECTIVETIME              TIMESTAMP,
    ACTIVE                     INTEGER,
    MODULEID                   VARCHAR (100),
    REFSETID                   VARCHAR (100),
    REFERENCEDCOMPONENTID      VARCHAR (100),
    TARGETCOMPONENT            VARCHAR (100)
);

DROP TABLE IF EXISTS sources_VET_DER2_CREFSET_ATTRIBUTEVALUE_FULL;
CREATE TABLE sources_vet_der2_crefset_attributevalue_full (
    id varchar(256),
    effectivetime  TIMESTAMP,
    active int2,
    moduleid text,
    refsetid text,
    referencedcomponentid text,
    valueid text
);

DROP TABLE IF EXISTS sources_VET_DER2_CREFSET_LANGUAGE;
CREATE TABLE sources_vet_der2_crefset_language (
    id varchar(256),
    effectivetime  TIMESTAMP,
    active int2,
    moduleid text,
    refsetid text,
    referencedcomponentid text,
    acceptabilityid text,
    source_file_id varchar(10)
);

DROP TABLE IF EXISTS sources_VET_DER2_SSREFSET_MODULEDEPENDENCY;
CREATE TABLE sources_VET_DER2_SSREFSET_MODULEDEPENDENCY
(
    ID                         VARCHAR(256),
    EFFECTIVETIME              TIMESTAMP,
    ACTIVE                     INT2,
    MODULEID                   TEXT,
    REFSETID                   TEXT,
    REFERENCEDCOMPONENTID      TEXT,
    SOURCEEFFECTIVETIME        TIMESTAMP,
    TARGETEFFECTIVETIME        TIMESTAMP
);

CREATE INDEX idx_vet_concept_id ON sources_VET_SCT2_CONCEPT_FULL (ID);
CREATE INDEX idx_vet_desc_id ON sources_VET_SCT2_DESC_FULL (CONCEPTID);
CREATE INDEX idx_vet_rela_id ON sources_VET_SCT2_RELA_FULL (ID);
CREATE INDEX idx_lang_refid ON sources_VET_DER2_CREFSET_LANGUAGE USING btree (referencedcomponentid);