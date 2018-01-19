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
**************************************************************************/
-- input tables creation
CREATE TABLE DRUG_CONCEPT_STAGE
(
   CONCEPT_NAME       	 	 VARCHAR2(255 Byte),
   VOCABULARY_ID      		 VARCHAR2(20 Byte),
   CONCEPT_CLASS_ID   		 VARCHAR2(25 Byte),
   SOURCE_CONCEPT_CLASS_ID       VARCHAR2(25 Byte),
   STANDARD_CONCEPT   		 VARCHAR2(1 Byte),
   CONCEPT_CODE       		 VARCHAR2(50 Byte),
   POSSIBLE_EXCIPIENT 		 VARCHAR2(1 Byte),
   DOMAIN_ID           		 VARCHAR2(25 Byte),
   VALID_START_DATE   		 DATE,
   VALID_END_DATE     		 DATE,
   INVALID_REASON     		 VARCHAR2(1 Byte)
);

CREATE TABLE DS_STAGE
(
   DRUG_CONCEPT_CODE        VARCHAR2(255 Byte),
   INGREDIENT_CONCEPT_CODE  VARCHAR2(255 Byte),
   BOX_SIZE                 INTEGER,
   AMOUNT_VALUE             FLOAT(126),
   AMOUNT_UNIT              VARCHAR2(255 Byte),
   NUMERATOR_VALUE          FLOAT(126),
   NUMERATOR_UNIT           VARCHAR2(255 Byte),
   DENOMINATOR_VALUE        FLOAT(126),
   DENOMINATOR_UNIT         VARCHAR2(255 Byte)
);

CREATE TABLE INTERNAL_RELATIONSHIP_STAGE
(
   CONCEPT_CODE_1     VARCHAR2(50 Byte),
   CONCEPT_CODE_2     VARCHAR2(50 Byte)
);

CREATE TABLE RELATIONSHIP_TO_CONCEPT
(
   CONCEPT_CODE_1     VARCHAR2(255 Byte),
   VOCABULARY_ID_1    VARCHAR2(20 Byte),
   CONCEPT_ID_2       INTEGER,
   PRECEDENCE         INTEGER,
   CONVERSION_FACTOR  FLOAT(126)
);

CREATE TABLE PC_STAGE
(
   PACK_CONCEPT_CODE  VARCHAR2(255 Byte),
   DRUG_CONCEPT_CODE  VARCHAR2(255 Byte),
   AMOUNT             NUMBER,
   BOX_SIZE           NUMBER
);

CREATE TABLE CONCEPT_SYNONYM_STAGE
(
   SYNONYM_CONCEPT_ID     NUMBER,
   SYNONYM_NAME           VARCHAR2(255 Byte)   NOT NULL,
   SYNONYM_CONCEPT_CODE   VARCHAR2(255 Byte)     NOT NULL,
   SYNONYM_VOCABULARY_ID  VARCHAR2(255 Byte)     NOT NULL,
   LANGUAGE_CONCEPT_ID    NUMBER
)
TABLESPACE USERS;

create sequence conc_stage_seq 
MINVALUE 100
  MAXVALUE 1000000
  START WITH 100
  INCREMENT BY 1
  CACHE 20;  

-- Create sequence for new OMOP-created standard concepts
declare
 ex number;
begin
select max(iex)+1 into ex from (  
    
    select cast(replace(concept_code, 'OMOP') as integer) as iex from concept where concept_code like 'OMOP%'  and concept_code not like '% %'
);
  begin
    execute immediate 'create sequence new_vocab increment by 1 start with ' || ex || ' nocycle cache 20 noorder';
    exception
      when others then null;
  end;
end;
/