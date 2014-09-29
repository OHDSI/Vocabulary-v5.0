SPOOL 17_create_schema_&1..log;

CREATE USER &1
 IDENTIFIED by &2
 DEFAULT TABLESPACE USERS
 TEMPORARY TABLESPACE TEMP
 PROFILE DEFAULT
 ACCOUNT UNLOCK;
 -- 1 Role for READ_YYYYMMDD
 GRANT CONNECT TO &1;
 ALTER USER &1. DEFAULT ROLE ALL;
 -- 5 System Privileges for READ_YYYYMMDD
 GRANT CREATE PROCEDURE TO &1.;
 GRANT CREATE SEQUENCE TO &1.;
 GRANT CREATE ANY INDEX TO &1.;
 GRANT CREATE DATABASE LINK TO &1.;
 GRANT CREATE TABLE TO &1.;
 -- 1 Tablespace Quotas for READ_YYYYMMDD
 ALTER USER &1. QUOTA UNLIMITED ON USERS;
 
 -- 6 prototype Privileges for READ_YYYYMMDD
 GRANT SELECT, INSERT, UPDATE, DELETE ON prototype.CONCEPT TO &1.;            
 GRANT SELECT, INSERT, UPDATE, DELETE ON prototype.CONCEPT_RELATIONSHIP TO &1.;
 GRANT SELECT, INSERT, UPDATE, DELETE ON prototype.CONCEPT_ANCESTOR TO &1.;
  GRANT SELECT, INSERT, UPDATE, DELETE ON prototype.CONCEPT_SYNONIM TO &1.;
 GRANT SELECT, INSERT, UPDATE, DELETE ON prototype.RELATIONSHIP TO &1.;
 GRANT SELECT, INSERT, UPDATE, DELETE ON prototype.VOCABULARY TO &1.;
 GRANT SELECT ON prototype.SEQ_CONCEPT  TO &1.;

--DROP TABLE .CONCEPT_STAGE;
CREATE TABLE &1..CONCEPT_STAGE(
CONCEPT_ID      INTEGER NOT NULL,
CONCEPT_NAME      VARCHAR2(256)   NOT NULL,
DOMAIN_CODE VARCHAR2(20 BYTE) NOT NULL,
CLASS_CODE VARCHAR2(20 BYTE) NOT NULL, 
VOCABULARY_CODE VARCHAR2(20 BYTE) NOT NULL, 
STANDARD_CONCEPT VARCHAR2(1 BYTE), 
CONCEPT_CODE VARCHAR2(40 BYTE) NOT NULL, 
VALID_START_DATE DATE DEFAULT TO_DATE('01-Jan-1970', 'DD-MM-RRRR') NOT NULL,
VALID_END_DATE DATE DEFAULT TO_DATE('31-Dec-2099', 'DD-MM-RRRR') NOT NULL),
INVALID_REASON VARCHAR2(1 BYTE)
;

--DROP TABLE .CONCEPT_ANCESTOR_STAGE;
CREATE TABLE &1..CONCEPT_ANCESTOR_STAGE(
ANCESTOR_CONCEPT_ID INTEGER NOT NULL,
DESCENDANT_CONCEPT_ID INTEGER NOT NULL, 
MIN_LEVELS_OF_SEPARATION INTEGER NOT NULL, 
MAX_LEVELS_OF_SEPARATION INTEGER);

--DROP TABLE .CONCEPT_RELATIONSHIP_STAGE;
CREATE TABLE &1..CONCEPT_RELATIONSHIP_STAGE(
CONCEPT_ID_1     INTEGER     NOT NULL,
CONCEPT_ID_2        INTEGER     NOT NULL,
RELATIONSHIP_CODE        VARCHAR2(20)     NOT NULL,
 VALID_START_DATE DATE NOT NULL, 
 VALID_END_DATE DATE NOT NULL, 
	INVALID_REASON CHAR(1 BYTE));

--DROP TABLE .CONCEPT_SYNONYM_STAGE;
CREATE TABLE &1..CONCEPT_SYNONYM_STAGE(
SYNONIM_CONCEPT_ID  INTEGER   NOT NULL,
SYNONIM_NAME      VARCHAR2(1000)     NOT NULL,
LANGUAGE_CONCEPT_ID    INTEGER  NOT NULL);



---

CREATE INDEX &1..XAC ON &1..CONCEPT_TREE_STAGE
(DESCENDANT_CONCEPT_ID, ANCESTOR_CONCEPT_ID)
;

create index xsource on concept (
vocabulary_code asc, concept_code asc
);
create index xconcept on concept (
concept_id asc
);
create index xrelationpair on concept_relationship (
concept_id_1 asc,
concept_id_2 asc
);
create index xrelationship on concept_relationship (
relationship_code asc
);
create index xall3 on concept_relationship (
concept_id_1, concept_id_2, relationship_code
);   

---------------------
-- drop table &1..rcsctmap_uk;
CREATE  table &1..rcsctmap_uk
-- input definition acording to RctSctMap_uk_documentation_20140401000001.pdf, page 7
(
  MapId  varchar(38), -- Unique Identifier 
  ReadCode  varchar(5), -- Read Code 
  TermCode  varchar(2), -- Term Code or Term Id 
  ConceptId  varchar(18), -- SNOMED ConceptID 
  EffectiveDate  date, -- YYYYMMDD e.g. 20061218 
  MapStatus  varchar(1) -- 0 = Inactive 1 = Active. 
);

-- drop table &1..rcsctmap2_uk;
CREATE  table &1..rcsctmap2_uk
-- input definition acording to RctSctMap_uk_documentation_20140401000001.pdf, page 7
(
  MapId varchar(38), -- Unique Identifier 
  ReadCode varchar(5), -- Read Code 
  TermCode varchar(2), -- Term Code or Term Id 
  ConceptId varchar(18), -- SNOMED ConceptID 
  DescriptionId varchar(18), -- SNOMED DescriptionID 
  IS_ASSURED varchar(1), -- 0 = Not assured, 1 = Assured 
  EffectiveDate date, -- YYYYMMDD e.g. 20061218 
  MapStatus varchar(2) -- 0 = Inactive 1 = Active. 
);

drop table &1..keyv2;
create table &1..keyv2
-- all Read V2 codes with description
(
  termclass varchar(10),
  classnumber varchar(2),
  description_short varchar(30),
  description varchar(60),
  description_long varchar(200),
  termcode varchar(2),
  lang varchar(2),
  readcode varchar(5),
  digit varchar(1)
);
  
exit;


/* End 