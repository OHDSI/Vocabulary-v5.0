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