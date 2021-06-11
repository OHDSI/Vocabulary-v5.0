DROP TABLE IF EXISTS DEV_CIEL.CIEL_CONCEPT;
CREATE TABLE DEV_CIEL.CIEL_CONCEPT
(
   CONCEPT_ID      INT4,
   RETIRED         INT4,
   SHORT_NAME      VARCHAR (255),
   DESCRIPTION     VARCHAR (4000),
   FORM_TEXT       VARCHAR (4000),
   DATATYPE_ID     INT4,
   CLASS_ID        INT4,
   IS_SET          INT4,
   CREATOR         INT4,
   DATE_CREATED    DATE,
   VERSION         VARCHAR (50),
   CHANGED_BY      INT4,
   DATE_CHANGED    DATE,
   RETIRED_BY      INT4,
   DATE_RETIRED    DATE,
   RETIRE_REASON   VARCHAR (255),
   UUID            VARCHAR (38),
);

DROP TABLE IF EXISTS DEV_CIEL.CIEL_CONCEPT_CLASS;
CREATE TABLE DEV_CIEL.CIEL_CONCEPT_CLASS
(
   CONCEPT_CLASS_ID   INT4,
   CIEL_NAME          VARCHAR (255),
   DESCRIPTION        VARCHAR (255),
   CREATOR            INT4,
   DATE_CREATED       DATE,
   RETIRED            INT4,
   RETIRED_BY         INT4,
   DATE_RETIRED       DATE,
   RETIRE_REASON      VARCHAR (255),
   UUID               VARCHAR (38),
   DATE_CHANGED       DATE,
   CHANGED_BY         INT4
   -- FILLER_COLUMN      INT, -- not needed anymore with new source format
   VOCABULARY_DATE    DATE, -- will be populated on source upload
   VOCABULARY_VERSION VARCHAR (200) -- will be populated on source upload
);


DROP TABLE IF EXISTS DEV_CIEL.CIEL_CONCEPT_NAME;
CREATE TABLE DEV_CIEL.CIEL_CONCEPT_NAME
(
   CONCEPT_ID          INT4,
   CIEL_NAME           VARCHAR (255),
   LOCALE              VARCHAR (50),
   CREATOR             INT4,
   DATE_CREATED        DATE,
   CONCEPT_NAME_ID     INT4,
   VOIDED              INT4,
   VOIDED_BY           INT4,
   DATE_VOIDED         DATE,
   VOID_REASON         VARCHAR (255),
   UUID                VARCHAR (38),
   CONCEPT_NAME_TYPE   VARCHAR (50),
   LOCALE_PREFERRED    INT4,
   DATE_CHANGED       DATE,
   CHANGED_BY         INT4
   -- FILLER_COLUMN       INT
);

DROP TABLE IF EXISTS DEV_CIEL.CIEL_CONCEPT_REFERENCE_MAP;
CREATE TABLE DEV_CIEL.CIEL_CONCEPT_REFERENCE_MAP
(
   CONCEPT_MAP_ID              INT4,
   CREATOR                     INT4,
   DATE_CREATED                DATE,
   CONCEPT_ID                  INT4,
   UUID                        VARCHAR (38),
   CONCEPT_REFERENCE_TERM_ID   INT4,
   CONCEPT_MAP_TYPE_ID         INT4,
   CHANGED_BY                  INT4,
   DATE_CHANGED                DATE
   -- FILLER_COLUMN               INT
);

DROP TABLE IF EXISTS DEV_CIEL.CIEL_CONCEPT_REFERENCE_TERM;
CREATE TABLE DEV_CIEL.CIEL_CONCEPT_REFERENCE_TERM
(
   CONCEPT_REFERENCE_TERM_ID   INT4,
   CONCEPT_SOURCE_ID           INT4,
   CIEL_NAME                   VARCHAR (255),
   CIEL_CODE                   VARCHAR (255),
   VERSION                     VARCHAR (255),
   DESCRIPTION                 VARCHAR (255),
   CREATOR                     INT4,
   DATE_CREATED                DATE,
   DATE_CHANGED                DATE,
   CHANGED_BY                  INT4,
   RETIRED                     INT4,
   RETIRED_BY                  INT4,
   DATE_RETIRED                DATE,
   RETIRE_REASON               VARCHAR (255),
   UUID                        VARCHAR (38)
   -- FILLER_COLUMN               INT
);

DROP TABLE IF EXISTS DEV_CIEL.CIEL_CONCEPT_REFERENCE_SOURCE;
CREATE TABLE DEV_CIEL.CIEL_CONCEPT_REFERENCE_SOURCE
(
   CONCEPT_SOURCE_ID   INT4,
   CIEL_NAME           VARCHAR (50),
   DESCRIPTION         VARCHAR (4000),
   HL7_CODE            VARCHAR (50),
   CREATOR             INT4,
   DATE_CREATED        DATE,
   RETIRED             INT4,
   RETIRED_BY          INT4,
   DATE_RETIRED        DATE,
   RETIRE_REASON       VARCHAR (255),
   UUID                VARCHAR (38),
   UNIQUE_ID           VARCHAR (250),
   DATE_CHANGED        DATE,
   CHANGED_BY          INT4  
   -- FILLER_COLUMN       INT
);