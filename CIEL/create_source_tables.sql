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


DROP TABLE IF EXISTS SOURCES.CONCEPT_CIEL;
CREATE TABLE SOURCES.CONCEPT_CIEL
(
   concept_id      INT4 NOT NULL PRIMARY KEY,
   retired         INT4,
   short_name      VARCHAR (255),
   description     VARCHAR (4000),
   form_text       VARCHAR (4000),
   datatype_id     INT4,
   class_id        INT4,
   is_set          INT4,
   creator         INT4,
   date_created    DATE,
   version         VARCHAR (50),
   changed_by      INT4,
   date_changed    DATE,
   retired_by      INT4,
   date_retired    DATE,
   retire_reason   VARCHAR (255),
   uuid            VARCHAR (38),
   filler_column INT
);

DROP TABLE IF EXISTS SOURCES.CONCEPT_CLASS_CIEL;
CREATE TABLE SOURCES.CONCEPT_CLASS_CIEL
(
   concept_class_id   INT4 NOT NULL PRIMARY KEY,
   "name"             VARCHAR (255),
   description        VARCHAR (255),
   creator            INT4,
   date_created       DATE,
   retired            INT4,
   retired_by         INT4,
   date_retired       DATE,
   retire_reason      VARCHAR (255),
   uuid               VARCHAR (38),
   filler_column      INT,
   vocabulary_date    DATE,
   vocabulary_version VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.CONCEPT_NAME;
CREATE TABLE SOURCES.CONCEPT_NAME
(
   concept_id          INT4,
   "name"              VARCHAR (255),
   locale              VARCHAR (50),
   creator             INT4,
   date_created        DATE,
   concept_name_id     INT4 NOT NULL PRIMARY KEY,
   voided              INT4,
   voided_by           INT4,
   date_voided         DATE,
   void_reason         VARCHAR (255),
   uuid                VARCHAR (38),
   concept_name_type   VARCHAR (50),
   locale_preferred    INT4,
   filler_column INT
);

DROP TABLE IF EXISTS SOURCES.CONCEPT_REFERENCE_MAP;
CREATE TABLE SOURCES.CONCEPT_REFERENCE_MAP
(
   concept_map_id              INT4 NOT NULL PRIMARY KEY,
   creator                     INT4,
   date_created                DATE,
   concept_id                  INT4,
   uuid                        VARCHAR (38),
   concept_reference_term_id   INT4,
   concept_map_type_id         INT4,
   changed_by                  INT4,
   date_changed                DATE,
   filler_column INT
);

DROP TABLE IF EXISTS SOURCES.CONCEPT_REFERENCE_TERM;
CREATE TABLE SOURCES.CONCEPT_REFERENCE_TERM
(
   concept_reference_term_id   INT4 NOT NULL PRIMARY KEY,
   concept_source_id           INT4,
   "name"                      VARCHAR (255),
   "code"                      VARCHAR (255),
   version                     VARCHAR (255),
   description                 VARCHAR (255),
   creator                     INT4,
   date_created                DATE,
   date_changed                DATE,
   changed_by                  INT4,
   retired                     INT4,
   retired_by                  INT4,
   date_retired                DATE,
   retire_reason               VARCHAR (255),
   uuid                        VARCHAR (38),
   filler_column INT
);

DROP TABLE IF EXISTS SOURCES.CONCEPT_REFERENCE_SOURCE;
CREATE TABLE SOURCES.CONCEPT_REFERENCE_SOURCE
(
   concept_source_id   INT4 NOT NULL PRIMARY KEY,
   "name"              VARCHAR (50),
   description         VARCHAR (4000),
   hl7_code            VARCHAR (50),
   creator             INT4,
   date_created        DATE,
   retired             INT4,
   retired_by          INT4,
   date_retired        DATE,
   retire_reason       VARCHAR (255),
   uuid                VARCHAR (38),
   filler_column INT
);