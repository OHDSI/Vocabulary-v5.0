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
* Authors: Timur Vakhitov
* Date: 2024
**************************************************************************/

DROP TABLE IF EXISTS sources.meta_mrconso;
CREATE TABLE sources.meta_mrconso
(
  CUI           TEXT,
  LAT           TEXT,
  TS            TEXT,
  LUI           TEXT,
  STT           TEXT,
  SUI           TEXT,
  ISPREF        TEXT,
  AUI           TEXT,
  SAUI          TEXT,
  SCUI          TEXT,
  SDUI          TEXT,
  SAB           TEXT,
  TTY           TEXT,
  CODE          TEXT,
  STR           TEXT,
  SRL           INT,
  SUPPRESS      TEXT,
  CVF           INT,
  FILLER_COLUMN INT
);

DROP TABLE IF EXISTS sources.meta_mrhier;
CREATE TABLE sources.meta_mrhier
(
  CUI           TEXT,
  AUI           TEXT,
  CXN           INT,
  PAUI          TEXT,
  SAB           TEXT,
  RELA          TEXT,
  PTR           TEXT,
  HCD           TEXT,
  CVF           INT,
  FILLER_COLUMN INT
);

DROP TABLE IF EXISTS sources.meta_mrmap;
CREATE TABLE sources.meta_mrmap
(
  MAPSETCUI     TEXT,
  MAPSETSAB     TEXT,
  MAPSUBSETID   TEXT,
  MAPRANK       INT,
  MAPID         TEXT,
  MAPSID        TEXT,
  FROMID        TEXT,
  FROMSID       TEXT,
  FROMEXPR      TEXT,
  FROMTYPE      TEXT,
  FROMRULE      TEXT,
  FROMRES       TEXT,
  REL           TEXT,
  RELA          TEXT,
  TOID          TEXT,
  TOSID         TEXT,
  TOEXPR        TEXT,
  TOTYPE        TEXT,
  TORULE        TEXT,
  TORES         TEXT,
  MAPRULE       TEXT,
  MAPRES        TEXT,
  MAPTYPE       TEXT,
  MAPATN        TEXT,
  MAPATV        TEXT,
  CVF           INT,
  FILLER_COLUMN INT
);

DROP TABLE IF EXISTS sources.meta_mrsmap;
CREATE TABLE sources.meta_mrsmap
(
  MAPSETCUI     TEXT,
  MAPSETSAB     TEXT,
  MAPID         TEXT,
  MAPSID        TEXT,
  FROMEXPR      TEXT,
  FROMTYPE      TEXT,
  REL           TEXT,
  RELA          TEXT,
  TOEXPR        TEXT,
  TOTYPE        TEXT,
  CVF           INT,
  FILLER_COLUMN INT
);

DROP TABLE IF EXISTS sources.meta_mrsat;
CREATE TABLE sources.meta_mrsat
(
  CUI           TEXT,
  LUI           TEXT,
  SUI           TEXT,
  METAUI        TEXT,
  STYPE         TEXT,
  CODE          TEXT,
  ATUI          TEXT,
  SATUI         TEXT,
  ATN           TEXT,
  SAB           TEXT,
  ATV           TEXT,
  SUPPRESS      TEXT,
  CVF           TEXT,
  FILLER_COLUMN INT
);

DROP TABLE IF EXISTS sources.meta_mrrel;
CREATE TABLE sources.meta_mrrel
(
  CUI1          TEXT,
  AUI1          TEXT,
  STYPE1        TEXT,
  REL           TEXT,
  CUI2          TEXT,
  AUI2          TEXT,
  STYPE2        TEXT,
  RELA          TEXT,
  RUI           TEXT,
  SRUI          TEXT,
  SAB           TEXT,
  SL            TEXT,
  RG            TEXT,
  DIR           TEXT,
  SUPPRESS      TEXT,
  CVF           INT,
  FILLER_COLUMN INT
);

DROP TABLE IF EXISTS sources.meta_mrsty;
CREATE TABLE sources.meta_mrsty
(
  CUI           TEXT,
  TUI           TEXT,
  STN           TEXT,
  STY           TEXT,
  ATUI          TEXT,
  CVF           TEXT,
  FILLER_COLUMN INT
);

DROP TABLE IF EXISTS sources.meta_mrdef;
CREATE TABLE sources.meta_mrdef
(
  CUI           TEXT,
  AUI           TEXT,
  ATUI          TEXT,
  SATUI         TEXT,
  SAB           TEXT,
  DEF           TEXT,
  SUPPRESS      TEXT,
  CVF           INT,
  FILLER_COLUMN INT
);

DROP TABLE IF EXISTS sources.meta_mrsab;
CREATE TABLE sources.meta_mrsab
(
  VCUI               TEXT,
  RCUI               TEXT,
  VSAB               TEXT,
  RSAB               TEXT,
  SON                TEXT,
  SF                 TEXT,
  SVER               TEXT,
  VSTART             TEXT,
  VEND               TEXT,
  IMETA              TEXT,
  RMETA              TEXT,
  SLC                TEXT,
  SCC                TEXT,
  SRL                INT4,
  TFR                INT4,
  CFR                INT4,
  CXTY               TEXT,
  TTYL               TEXT,
  ATNL               TEXT,
  LAT                TEXT,
  CENC               TEXT,
  CURVER             TEXT,
  SABIN              TEXT,
  SSN                TEXT,
  SCIT               TEXT,
  VOCABULARY_DATE    DATE,
  VOCABULARY_VERSION TEXT
);

DROP TABLE IF EXISTS sources.meta_ncimeme;
CREATE TABLE sources.meta_ncimeme
(
  conceptcode    TEXT,
  conceptname    TEXT,
  editaction     TEXT,
  editdate       TEXT,
  referencecode  TEXT,
  referencename  TEXT
);

CREATE INDEX idx_meta_mrsat_cui ON sources.meta_mrsat (cui);
CREATE INDEX idx_meta_mrconso_code ON sources.meta_mrconso (code);
CREATE INDEX idx_meta_mrconso_cui ON sources.meta_mrconso (cui);
CREATE INDEX idx_meta_mrconso_aui ON sources.meta_mrconso (aui);
CREATE INDEX idx_meta_mrconso_sab_tty ON sources.meta_mrconso (
	sab,
	tty
	);
CREATE INDEX idx_meta_mrconso_scui ON sources.meta_mrconso (scui);
CREATE INDEX idx_meta_mrsty_cui ON sources.meta_mrsty (cui);
CREATE INDEX idx_meta_mrdef_sab_cui ON sources.meta_mrdef (
	sab,
	cui
	);
CREATE INDEX idx_meta_ncimeme_conceptcode ON sources.meta_ncimeme (conceptcode);