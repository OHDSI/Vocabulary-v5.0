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
* Date: 2016
**************************************************************************/

CREATE TABLE LOINC
(
  LOINC_NUM                  VARCHAR2(10 BYTE),
  COMPONENT                  VARCHAR2(255 BYTE),
  PROPERTY                   VARCHAR2(30 BYTE),
  TIME_ASPCT                 VARCHAR2(15 BYTE),
  SYSTEM                     VARCHAR2(100 BYTE),
  SCALE_TYP                  VARCHAR2(30 BYTE),
  METHOD_TYP                 VARCHAR2(50 BYTE),
  CLASS                      VARCHAR2(50 BYTE),
  VERSIONLASTCHANGED         VARCHAR2(10 BYTE),
  CHNG_TYPE                  VARCHAR2(3 BYTE),
  DEFINITIONDESCRIPTION      CLOB,
  STATUS                     VARCHAR2(11 BYTE),
  CONSUMER_NAME              VARCHAR2(255 BYTE),
  CLASSTYPE                  VARCHAR2(20 BYTE),
  FORMULA                    CLOB,
  SPECIES                    VARCHAR2(20 BYTE),
  EXMPL_ANSWERS              CLOB,
  SURVEY_QUEST_TEXT          CLOB,
  SURVEY_QUEST_SRC           VARCHAR2(50 BYTE),
  UNITSREQUIRED              VARCHAR2(1 BYTE),
  SUBMITTED_UNITS            VARCHAR2(30 BYTE),
  RELATEDNAMES2              CLOB,
  SHORTNAME                  VARCHAR2(40 BYTE),
  ORDER_OBS                  VARCHAR2(15 BYTE),
  CDISC_COMMON_TESTS         VARCHAR2(1 BYTE),
  HL7_FIELD_SUBFIELD_ID      VARCHAR2(50 BYTE),
  EXTERNAL_COPYRIGHT_NOTICE  CLOB,
  EXAMPLE_UNITS              VARCHAR2(255 BYTE),
  LONG_COMMON_NAME           VARCHAR2(255 BYTE),
  UNITSANDRANGE              CLOB,
  DOCUMENT_SECTION           VARCHAR2(255 BYTE),
  EXAMPLE_UCUM_UNITS         VARCHAR2(255 BYTE),
  EXAMPLE_SI_UCUM_UNITS      VARCHAR2(255 BYTE),
  STATUS_REASON              VARCHAR2(9 BYTE),
  STATUS_TEXT                CLOB,
  CHANGE_REASON_PUBLIC       CLOB,
  COMMON_TEST_RANK           VARCHAR2(20 BYTE),
  COMMON_ORDER_RANK          VARCHAR2(20 BYTE),
  COMMON_SI_TEST_RANK        VARCHAR2(20 BYTE),
  HL7_ATTACHMENT_STRUCTURE   VARCHAR2(15 BYTE),
  EXTERNAL_COPYRIGHT_LINK    VARCHAR2(255 BYTE),
  PANELTYPE                  VARCHAR2(50 BYTE),
  ASKATORDERENTRY            VARCHAR2(255 BYTE),
  ASSOCIATEDOBSERVATIONS     VARCHAR2(255 BYTE)
);

CREATE TABLE MAP_TO
(
  LOINC      VARCHAR2(10),
  MAP_TO     VARCHAR2(10),
  "COMMENT"  CLOB
);

CREATE TABLE SOURCE_ORGANIZATION
(
  ID            NUMBER,
  COPYRIGHT_ID  VARCHAR2(255),
  NAME          VARCHAR2(255),
  COPYRIGHT     CLOB,
  TERMS_OF_USE  CLOB,
  URL           VARCHAR2(255)
);

CREATE TABLE LOINC_ANSWERS
(
  LOINC                   VARCHAR2(10 BYTE),
  LOINCNAME               VARCHAR2(255 BYTE),
  ANSWERLISTOID           VARCHAR2(255 BYTE),
  EXTERNALLYDEFINEDYN     VARCHAR2(1 BYTE),
  EXTERNALLYDEFINEDANSCS  VARCHAR2(255 BYTE),
  LINKTOEXTERNALLIST      VARCHAR2(255 BYTE),
  ANSWERSTRINGID          VARCHAR2(255 BYTE),
  ANSWERCODE              VARCHAR2(255 BYTE),
  SEQUENCENO              VARCHAR2(255 BYTE),
  DISPLAYTEXT             VARCHAR2(255 BYTE)
);

CREATE TABLE LOINC_FORMS
(
   ParentLoinc   VARCHAR2 (10 BYTE),
   Loinc         VARCHAR2 (10 BYTE)
);

CREATE TABLE LOINC_CLASS
(
  CONCEPT_ID        INTEGER,
  CONCEPT_NAME      VARCHAR2(256 BYTE),
  DOMAIN_ID         VARCHAR2(200 BYTE),
  VOCABULARY_ID     VARCHAR2(20 BYTE),
  CONCEPT_CLASS_ID  VARCHAR2(20 BYTE),
  STANDARD_CONCEPT  VARCHAR2(1 BYTE),
  CONCEPT_CODE      VARCHAR2(40 BYTE),
  VALID_START_DATE  DATE,
  VALID_END_DATE    DATE,
  INVALID_REASON    VARCHAR2(1 BYTE)
);

CREATE TABLE CPT_MRSMAP
(
  MAPSETCUI  CHAR(8 BYTE),
  MAPSETSAB  VARCHAR2(40 BYTE),
  MAPID      VARCHAR2(50 BYTE),
  MAPSID     VARCHAR2(50 BYTE),
  FROMEXPR   VARCHAR2(4000 BYTE),
  FROMTYPE   VARCHAR2(50 BYTE),
  REL        VARCHAR2(4 BYTE),
  RELA       VARCHAR2(100 BYTE),
  TOEXPR     VARCHAR2(4000 BYTE),
  TOTYPE     VARCHAR2(50 BYTE),
  CVF        INTEGER
);

CREATE TABLE scccRefset_MapCorrOrFull_INT
(
   ID                      VARCHAR (256) NOT NULL,
   EFFECTIVETIME           VARCHAR (256) NOT NULL,
   ACTIVE                  NUMBER NOT NULL,
   MODULEID                NUMBER,
   REFSETID                NUMBER,
   REFERENCEDCOMPONENTID   NUMBER NOT NULL,
   MAPTARGET               VARCHAR (256) NOT NULL
);

CREATE TABLE LOINC_HIERARCHY
(
  PATH_TO_ROOT      VARCHAR2(256 CHAR),
  SEQUENCE          VARCHAR2(256 CHAR),
  IMMEDIATE_PARENT  VARCHAR2(256 CHAR),
  CODE              VARCHAR2(256 CHAR),
  CODE_TEXT         VARCHAR2(256 CHAR)
);