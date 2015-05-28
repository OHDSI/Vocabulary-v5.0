CREATE TABLE RXNATOMARCHIVE
(
   RXAUI VARCHAR2(8) NOT NULL,
   AUI VARCHAR2(10),
   STR VARCHAR2(4000) NOT NULL,
   ARCHIVE_TIMESTAMP VARCHAR2(280) NOT NULL,
   CREATED_TIMESTAMP VARCHAR2(280) NOT NULL,
   UPDATED_TIMESTAMP VARCHAR2(280) NOT NULL,
   CODE VARCHAR2(50),
   IS_BRAND VARCHAR2(1),
   LAT VARCHAR2(3),
   LAST_RELEASED VARCHAR2(30),
   SAUI VARCHAR2(50),
   VSAB VARCHAR2(40),
   RXCUI VARCHAR2(8),
   SAB VARCHAR2(20),
   TTY VARCHAR2(20),
   MERGED_TO_RXCUI VARCHAR2(8)
)
;

CREATE TABLE RXNCONSO
(
   RXCUI VARCHAR2(8) NOT NULL,
   LAT VARCHAR2 (3) DEFAULT 'ENG' NOT NULL,
   TS VARCHAR2 (1),
   LUI VARCHAR2(8),
   STT VARCHAR2 (3),
   SUI VARCHAR2 (8),
   ISPREF VARCHAR2 (1),
   RXAUI  VARCHAR2(8) NOT NULL,
   SAUI VARCHAR2 (50),
   SCUI VARCHAR2 (50),
   SDUI VARCHAR2 (50),
   SAB VARCHAR2 (20) NOT NULL,
   TTY VARCHAR2 (20) NOT NULL,
   CODE VARCHAR2 (50) NOT NULL,
   STR VARCHAR2 (3000) NOT NULL,
   SRL VARCHAR2 (10),
   SUPPRESS VARCHAR2 (1),
   CVF VARCHAR2(50)
)
;

CREATE TABLE RXNREL
(
   RXCUI1    VARCHAR2(8) ,
   RXAUI1    VARCHAR2(8), 
   STYPE1    VARCHAR2(50),
   REL       VARCHAR2(4) ,
   RXCUI2    VARCHAR2(8) ,
   RXAUI2    VARCHAR2(8),
   STYPE2    VARCHAR2(50),
   RELA      VARCHAR2(100) ,
   RUI       VARCHAR2(10),
   SRUI      VARCHAR2(50),
   SAB       VARCHAR2(20) NOT NULL,
   SL        VARCHAR2(1000),
   DIR       VARCHAR2(1),
   RG        VARCHAR2(10),
   SUPPRESS  VARCHAR2(1),
   CVF       VARCHAR2(50)
)
;

CREATE TABLE RXNSAT
(
   RXCUI VARCHAR2(8),
   LUI VARCHAR2(8),
   SUI VARCHAR2(8),
   RXAUI VARCHAR2(8),
   STYPE VARCHAR2 (50),
   CODE VARCHAR2 (50),
   ATUI VARCHAR2(11),
   SATUI VARCHAR2 (50),
   ATN VARCHAR2 (1000) NOT NULL,
   SAB VARCHAR2 (20) NOT NULL,
   ATV VARCHAR2 (4000),
   SUPPRESS VARCHAR2 (1),
   CVF VARCHAR2 (50)
)
;

create index x_rxnconso_str on rxnconso(str) nologging;
create index x_rxnconso_rxcui on rxnconso(rxcui) nologging;
create index x_rxnconso_tty on rxnconso(tty) nologging;
create index x_rxnconso_code on rxnconso(code) nologging;
create index x_rxnsat_rxcui on rxnsat(rxcui) nologging;
create index x_rxnsat_atv on rxnsat(atv) nologging;
create index x_rxnsat_atn on rxnsat(atn) nologging;
create index x_rxnrel_rxcui1 on rxnrel(rxcui1) nologging;
create index x_rxnrel_rxcui2 on rxnrel(rxcui2) nologging;
create index x_rxnrel_rela on rxnrel(rela) nologging;
create index x_rxnatomarchive_rxaui on rxnatomarchive(rxaui) nologging;
create index x_rxnatomarchive_rxcui on rxnatomarchive(rxcui) nologging;
create index x_rxnatomarchive_merged_to on rxnatomarchive(merged_to_rxcui) nologging;


 
