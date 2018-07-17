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
* distributed under the License is distributed ON an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov, Christian Reich
* Date: 2017
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.RXNATOMARCHIVE;
CREATE TABLE SOURCES.RXNATOMARCHIVE
(
   RXAUI VARCHAR(8) NOT NULL,
   AUI VARCHAR(10),
   STR VARCHAR(4000) NOT NULL,
   ARCHIVE_TIMESTAMP VARCHAR(280) NOT NULL,
   CREATED_TIMESTAMP VARCHAR(280) NOT NULL,
   UPDATED_TIMESTAMP VARCHAR(280) NOT NULL,
   CODE VARCHAR(50),
   IS_BRAND VARCHAR(1),
   LAT VARCHAR(3),
   LAST_RELEASED VARCHAR(30),
   SAUI VARCHAR(50),
   VSAB VARCHAR(40),
   RXCUI VARCHAR(8),
   SAB VARCHAR(20),
   TTY VARCHAR(20),
   MERGED_TO_RXCUI VARCHAR(8),
   VOCABULARY_DATE      DATE,
   VOCABULARY_VERSION   VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.RXNCONSO;
CREATE TABLE SOURCES.RXNCONSO
(
   RXCUI VARCHAR(8) NOT NULL,
   LAT VARCHAR (3) DEFAULT 'ENG' NOT NULL,
   TS VARCHAR (1),
   LUI VARCHAR(8),
   STT VARCHAR (3),
   SUI VARCHAR (8),
   ISPREF VARCHAR (1),
   RXAUI  VARCHAR(8) NOT NULL,
   SAUI VARCHAR (50),
   SCUI VARCHAR (50),
   SDUI VARCHAR (50),
   SAB VARCHAR (20) NOT NULL,
   TTY VARCHAR (20) NOT NULL,
   CODE VARCHAR (50) NOT NULL,
   STR VARCHAR (3000) NOT NULL,
   SRL VARCHAR (10),
   SUPPRESS VARCHAR (1),
   CVF VARCHAR(50),
   FILLER_COLUMN INT
);

DROP TABLE IF EXISTS SOURCES.RXNREL;
CREATE TABLE SOURCES.RXNREL
(
   RXCUI1    VARCHAR(8) ,
   RXAUI1    VARCHAR(8), 
   STYPE1    VARCHAR(50),
   REL       VARCHAR(4) ,
   RXCUI2    VARCHAR(8) ,
   RXAUI2    VARCHAR(8),
   STYPE2    VARCHAR(50),
   RELA      VARCHAR(100) ,
   RUI       VARCHAR(10),
   SRUI      VARCHAR(50),
   SAB       VARCHAR(20) NOT NULL,
   SL        VARCHAR(1000),
   DIR       VARCHAR(1),
   RG        VARCHAR(10),
   SUPPRESS  VARCHAR(1),
   CVF       VARCHAR(50),
   FILLER_COLUMN INT
);

DROP TABLE IF EXISTS SOURCES.RXNSAT;
CREATE TABLE SOURCES.RXNSAT
(
   RXCUI VARCHAR(8),
   LUI VARCHAR(8),
   SUI VARCHAR(8),
   RXAUI VARCHAR(9),
   STYPE VARCHAR (50),
   CODE VARCHAR (50),
   ATUI VARCHAR(11),
   SATUI VARCHAR (50),
   ATN VARCHAR (1000) NOT NULL,
   SAB VARCHAR (20) NOT NULL,
   ATV VARCHAR (4000),
   SUPPRESS VARCHAR (1),
   CVF VARCHAR (50),
   FILLER_COLUMN INT
);

CREATE INDEX x_rxnconso_str ON sources.rxnconso(str);
CREATE INDEX x_rxnconso_rxcui ON sources.rxnconso(rxcui);
CREATE INDEX x_rxnconso_tty ON sources.rxnconso(tty);
CREATE INDEX x_rxnconso_code ON sources.rxnconso(code);
CREATE INDEX x_rxnconso_rxaui ON sources.rxnconso(rxaui);
CREATE INDEX x_rxnsat_rxcui ON sources.rxnsat(rxcui);
CREATE INDEX x_rxnsat_atv ON sources.rxnsat(atv);
CREATE INDEX x_rxnsat_atn ON sources.rxnsat(atn);
CREATE INDEX x_rxnrel_rxcui1 ON sources.rxnrel(rxcui1);
CREATE INDEX x_rxnrel_rxcui2 ON sources.rxnrel(rxcui2);
CREATE INDEX x_rxnrel_rela ON sources.rxnrel(rela);
CREATE INDEX x_rxnatomarchive_rxaui ON sources.rxnatomarchive(rxaui);
CREATE INDEX x_rxnatomarchive_rxcui ON sources.rxnatomarchive(rxcui);
CREATE INDEX x_rxnatomarchive_merged_to ON sources.rxnatomarchive(merged_to_rxcui);