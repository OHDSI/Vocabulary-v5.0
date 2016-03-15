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

CREATE TABLE MRCONSO
(
  CUI       CHAR(8 CHAR)                        NOT NULL,
  LAT       CHAR(3 CHAR)                        NOT NULL,
  TS        CHAR(1 CHAR)                        NOT NULL,
  LUI       VARCHAR2(10 CHAR)                   NOT NULL,
  STT       VARCHAR2(3 CHAR)                    NOT NULL,
  SUI       VARCHAR2(10 CHAR)                   NOT NULL,
  ISPREF    CHAR(1 CHAR)                        NOT NULL,
  AUI       VARCHAR2(9 CHAR)                    NOT NULL,
  SAUI      VARCHAR2(50 CHAR),
  SCUI      VARCHAR2(100 CHAR),
  SDUI      VARCHAR2(100 CHAR),
  SAB       VARCHAR2(40 CHAR)                   NOT NULL,
  TTY       VARCHAR2(40 CHAR)                   NOT NULL,
  CODE      VARCHAR2(100 CHAR)                  NOT NULL,
  STR       VARCHAR2(3000 CHAR)                 NOT NULL,
  SRL       INTEGER                             NOT NULL,
  SUPPRESS  CHAR(1 CHAR)                        NOT NULL,
  CVF       INTEGER
);

CREATE TABLE MRHIER
(
  CUI   CHAR(8 BYTE),
  AUI   VARCHAR2(9 BYTE),
  CXN   INTEGER,
  PAUI  VARCHAR2(9 BYTE),
  SAB   VARCHAR2(40 BYTE),
  RELA  VARCHAR2(100 BYTE),
  PTR   VARCHAR2(1000 BYTE),
  HCD   VARCHAR2(50 BYTE),
  CVF   INTEGER
);

CREATE TABLE MRMAP
(
  MAPSETCUI    CHAR(8 BYTE),
  MAPSETSAB    VARCHAR2(40 BYTE),
  MAPSUBSETID  VARCHAR2(10 BYTE),
  MAPRANK      INTEGER,
  MAPID        VARCHAR2(50 BYTE),
  MAPSID       VARCHAR2(50 BYTE),
  FROMID       VARCHAR2(50 BYTE),
  FROMSID      VARCHAR2(50 BYTE),
  FROMEXPR     VARCHAR2(4000 BYTE),
  FROMTYPE     VARCHAR2(50 BYTE),
  FROMRULE     VARCHAR2(4000 BYTE),
  FROMRES      VARCHAR2(4000 BYTE),
  REL          VARCHAR2(4 BYTE),
  RELA         VARCHAR2(100 BYTE),
  TOID         VARCHAR2(50 BYTE),
  TOSID        VARCHAR2(50 BYTE),
  TOEXPR       VARCHAR2(4000 BYTE),
  TOTYPE       VARCHAR2(50 BYTE),
  TORULE       VARCHAR2(4000 BYTE),
  TORES        VARCHAR2(4000 BYTE),
  MAPRULE      VARCHAR2(4000 BYTE),
  MAPRES       VARCHAR2(4000 BYTE),
  MAPTYPE      VARCHAR2(50 BYTE),
  MAPATN       VARCHAR2(20 BYTE),
  MAPATV       VARCHAR2(4000 BYTE),
  CVF          INTEGER
);

CREATE TABLE MRSMAP
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

CREATE TABLE MRSAT
(
  CUI       CHAR(8 CHAR),
  LUI       VARCHAR2(10 BYTE),
  SUI       VARCHAR2(10 BYTE),
  METAUI    VARCHAR2(50 BYTE),
  STYPE     VARCHAR2(50 BYTE),
  CODE      VARCHAR2(50 BYTE),
  ATUI      VARCHAR2(11 BYTE),
  SATUI     VARCHAR2(50 BYTE),
  ATN       VARCHAR2(100 BYTE),
  SAB       VARCHAR2(40 BYTE),
  ATV       CLOB,
  SUPPRESS  CHAR(1 BYTE),
  CVF       VARCHAR2(50 BYTE)
);

CREATE INDEX X_MRSAT_CUI ON MRSAT
(CUI) nologging;

CREATE INDEX X_MRCONSO_CODE ON MRCONSO
(CODE) nologging;

CREATE INDEX X_MRCONSO_CUI ON MRCONSO
(CUI) nologging;

CREATE INDEX X_MRCONSO_LUI ON MRCONSO
(LUI) nologging;

CREATE UNIQUE INDEX X_MRCONSO_PK ON MRCONSO
(AUI) nologging;

CREATE INDEX X_MRCONSO_SAB_TTY ON MRCONSO
(SAB, TTY) nologging;

CREATE INDEX X_MRCONSO_SCUI ON MRCONSO
(SCUI) nologging;

CREATE INDEX X_MRCONSO_SDUI ON MRCONSO
(SDUI) nologging;

CREATE INDEX X_MRCONSO_STR ON MRCONSO
(STR) nologging;

CREATE INDEX X_MRCONSO_SUI ON MRCONSO
(SUI) nologging;

ALTER TABLE MRCONSO ADD (
  CONSTRAINT X_MRCONSO_PK
  PRIMARY KEY
  (AUI)
  USING INDEX X_MRCONSO_PK);