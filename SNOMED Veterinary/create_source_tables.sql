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

DROP TABLE IF EXISTS SOURCES.VET_SCT2_CONCEPT_FULL;
CREATE TABLE SOURCES.VET_SCT2_CONCEPT_FULL
(
   ID                 text,
   EFFECTIVETIME      TIMESTAMP,
   ACTIVE             int2,
   MODULEID           text,
   STATUSID           text,
   VOCABULARY_DATE    DATE,
   VOCABULARY_VERSION VARCHAR(200)
);

DROP TABLE IF EXISTS SOURCES.VET_SCT2_DESC_FULL;
CREATE TABLE SOURCES.VET_SCT2_DESC_FULL
(
   ID                   text,
   EFFECTIVETIME        TIMESTAMP,
   ACTIVE               int2,
   MODULEID             text,
   CONCEPTID            text,
   LANGUAGECODE         VARCHAR(2),
   TYPEID               text,
   TERM                 text,
   CASESIGNIFICANCEID   text
);

DROP TABLE IF EXISTS SOURCES.VET_SCT2_RELA_FULL;
CREATE TABLE SOURCES.VET_SCT2_RELA_FULL
(
   ID                     text,
   EFFECTIVETIME          TIMESTAMP,
   ACTIVE                 int2,
   MODULEID               text,
   SOURCEID               text,
   DESTINATIONID          text,
   RELATIONSHIPGROUP      INTEGER,
   TYPEID                 text,
   CHARACTERISTICTYPEID   text,
   MODIFIERID             text
);

DROP TABLE IF EXISTS SOURCES.VET_DER2_CREFSET_ASSREFFULL;
CREATE TABLE SOURCES.VET_DER2_CREFSET_ASSREFFULL
(
    ID                         VARCHAR (256),
    EFFECTIVETIME              TIMESTAMP,
    ACTIVE                     int2,
    MODULEID                   text,
    REFSETID                   text,
    REFERENCEDCOMPONENTID      text,
    TARGETCOMPONENT            text
);

CREATE INDEX idx_vet_concept_id ON SOURCES.VET_SCT2_CONCEPT_FULL(ID);
CREATE INDEX idx_vet_desc_id ON SOURCES.VET_SCT2_DESC_FULL(CONCEPTID);
CREATE INDEX idx_vet_rela_id ON SOURCES.VET_SCT2_RELA_FULL(ID);

DROP TABLE IF EXISTS sources.vet_der2_crefset_attributevalue_full;
CREATE TABLE sources.vet_der2_crefset_attributevalue_full (
    id varchar(256),
    effectivetime TIMESTAMP,
    active int2,
    moduleid text,
    refsetid text,
    referencedcomponentid text,
    valueid text
);

DROP TABLE IF EXISTS sources.vet_der2_crefset_language;
CREATE TABLE sources.vet_der2_crefset_language (
    id varchar(256),
    effectivetime TIMESTAMP,
    active int2,
    moduleid text,
    refsetid text,
    referencedcomponentid text,
    acceptabilityid text,
    source_file_id varchar(10)
);
CREATE INDEX idx_vet_lang_refid ON sources.VET_der2_crefset_language (referencedcomponentid);

DROP TABLE IF EXISTS vet_der2_ssrefset_moduledependency;
CREATE TABLE sources.vet_der2_ssrefset_moduledependency (
 id varchar(256),
    effectivetime TIMESTAMP,
    active int2,
    moduleid text,
    refsetid text,
    referencedcomponentid text,
  sourceEffectiveTime timestamp,
  targetEffectiveTime timestamp
  );