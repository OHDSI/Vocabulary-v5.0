CREATE TABLE CONCEPT_CIEL
(
   concept_id      NUMBER NOT NULL PRIMARY KEY,
   retired         NUMBER,
   short_name      VARCHAR2 (255),
   description     VARCHAR2 (4000),
   form_text       VARCHAR2 (4000),
   datatype_id     NUMBER,
   class_id        NUMBER,
   is_set          NUMBER,
   creator         NUMBER,
   date_created    DATE,
   version         VARCHAR2 (50),
   changed_by      NUMBER,
   date_changed    DATE,
   retired_by      NUMBER,
   date_retired    DATE,
   retire_reason   VARCHAR2 (255),
   uuid            VARCHAR2 (38)
);

CREATE TABLE CONCEPT_CLASS_CIEL
(
   concept_class_id   NUMBER NOT NULL PRIMARY KEY,
   "name"             VARCHAR2 (255),
   description        VARCHAR2 (255),
   creator            NUMBER,
   date_created       DATE,
   retired            NUMBER,
   retired_by         NUMBER,
   date_retired       DATE,
   retire_reason      VARCHAR2 (255),
   uuid               VARCHAR2 (38)
);

CREATE TABLE CONCEPT_NAME
(
   concept_id          NUMBER,
   "name"              VARCHAR2 (255),
   locale              VARCHAR2 (50),
   creator             NUMBER,
   date_created        DATE,
   concept_name_id     NUMBER NOT NULL PRIMARY KEY,
   voided              NUMBER,
   voided_by           NUMBER,
   date_voided         DATE,
   void_reason         VARCHAR2 (255),
   uuid                VARCHAR2 (38),
   concept_name_type   VARCHAR2 (50),
   locale_preferred    NUMBER
);

CREATE TABLE CONCEPT_REFERENCE_MAP
(
   concept_map_id              NUMBER NOT NULL PRIMARY KEY,
   creator                     NUMBER,
   date_created                DATE,
   concept_id                  NUMBER,
   uuid                        VARCHAR2 (38),
   concept_reference_term_id   NUMBER,
   concept_map_type_id         NUMBER,
   changed_by                  NUMBER,
   date_changed                DATE
);

CREATE TABLE CONCEPT_REFERENCE_TERM
(
   concept_reference_term_id   NUMBER NOT NULL PRIMARY KEY,
   concept_source_id           NUMBER,
   "name"                      VARCHAR2 (255),
   "code"                      VARCHAR2 (255),
   version                     VARCHAR2 (255),
   description                 VARCHAR2 (255),
   creator                     NUMBER,
   date_created                DATE,
   date_changed                DATE,
   changed_by                  NUMBER,
   retired                     NUMBER,
   retired_by                  NUMBER,
   date_retired                DATE,
   retire_reason               VARCHAR2 (255),
   uuid                        VARCHAR2 (38)
);

CREATE TABLE CONCEPT_REFERENCE_SOURCE
(
   concept_source_id   NUMBER NOT NULL PRIMARY KEY,
   "name"              VARCHAR2 (50),
   description         VARCHAR2 (4000),
   hl7_code            VARCHAR2 (50),
   creator             NUMBER,
   date_created        DATE,
   retired             NUMBER,
   retired_by          NUMBER,
   date_retired        DATE,
   retire_reason       VARCHAR2 (255),
   uuid                VARCHAR2 (38)
);