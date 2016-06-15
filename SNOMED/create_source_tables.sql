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

CREATE TABLE SCT2_RELA_FULL_INT
(
   ID                     INTEGER,
   EFFECTIVETIME          VARCHAR2 (8 BYTE),
   ACTIVE                 VARCHAR2 (1 BYTE),
   MODULEID               VARCHAR2 (256 BYTE),
   SOURCEID               VARCHAR2 (256 BYTE),
   DESTINATIONID          VARCHAR2 (256 BYTE),
   RELATIONSHIPGROUP      INTEGER,
   TYPEID                 INTEGER,
   CHARACTERISTICTYPEID   VARCHAR2 (256 BYTE),
   MODIFIERID             VARCHAR2 (256 BYTE)
);

CREATE TABLE SCT2_DESC_FULL_EN_INT
(
   ID                   INTEGER,
   EFFECTIVETIME        VARCHAR2 (8 BYTE),
   ACTIVE               VARCHAR2 (1 BYTE),
   MODULEID             VARCHAR2 (18 BYTE),
   CONCEPTID            VARCHAR2 (256 BYTE),
   LANGUAGECODE         VARCHAR2 (2 BYTE),
   TYPEID               VARCHAR2 (18 BYTE),
   TERM                 VARCHAR2 (256 BYTE),
   CASESIGNIFICANCEID   VARCHAR2 (256 BYTE)
);

CREATE TABLE SCT2_CONCEPT_FULL_INT
(
   ID              VARCHAR2 (18 BYTE),
   EFFECTIVETIME   VARCHAR2 (8 BYTE),
   ACTIVE          VARCHAR2 (1 BYTE),
   MODULEID        VARCHAR2 (18 BYTE),
   STATUSID        VARCHAR2 (256 BYTE)
);

CREATE TABLE der2_cRefset_AssRefFull_INT
(
    ID                         VARCHAR(256) NOT NULL,  
    EFFECTIVETIME              VARCHAR(256) NOT NULL,  
    ACTIVE                     NUMBER NOT NULL, 
    MODULEID                   NUMBER,
    REFSETID                   NUMBER, 
    REFERENCEDCOMPONENTID      NUMBER NOT NULL,
    TARGETCOMPONENT            NUMBER NOT NULL
);

CREATE INDEX X_CID
   ON SCT2_CONCEPT_FULL_INT (ID);

CREATE INDEX X_rel_id
   ON SCT2_RELA_FULL_INT (ID);

CREATE INDEX X_DESC_2CD
   ON SCT2_DESC_FULL_EN_INT (CONCEPTID, MODULEID);

CREATE INDEX X_DESC_3CD
   ON SCT2_DESC_FULL_EN_INT (CONCEPTID, MODULEID, TERM);

CREATE TABLE SCT2_RELA_FULL_UK
(
   ID                     INTEGER,
   EFFECTIVETIME          VARCHAR2 (8 BYTE),
   ACTIVE                 VARCHAR2 (1 BYTE),
   MODULEID               VARCHAR2 (256 BYTE),
   SOURCEID               VARCHAR2 (256 BYTE),
   DESTINATIONID          VARCHAR2 (256 BYTE),
   RELATIONSHIPGROUP      INTEGER,
   TYPEID                 INTEGER,
   CHARACTERISTICTYPEID   VARCHAR2 (256 BYTE),
   MODIFIERID             VARCHAR2 (256 BYTE)
);

CREATE TABLE SCT2_DESC_FULL_UK
(
   ID                   INTEGER,
   EFFECTIVETIME        VARCHAR2 (8 BYTE),
   ACTIVE               VARCHAR2 (1 BYTE),
   MODULEID             VARCHAR2 (18 BYTE),
   CONCEPTID            VARCHAR2 (256 BYTE),
   LANGUAGECODE         VARCHAR2 (2 BYTE),
   TYPEID               VARCHAR2 (18 BYTE),
   TERM                 VARCHAR2 (256 BYTE),
   CASESIGNIFICANCEID   VARCHAR2 (256 BYTE)
);

CREATE TABLE SCT2_CONCEPT_FULL_UK
(
   ID              VARCHAR2 (18 BYTE),
   EFFECTIVETIME   VARCHAR2 (8 BYTE),
   ACTIVE          VARCHAR2 (1 BYTE),
   MODULEID        VARCHAR2 (18 BYTE),
   STATUSID        VARCHAR2 (256 BYTE)
);

CREATE TABLE der2_cRefset_AssRefFull_UK
(
    ID                         VARCHAR(256) NOT NULL,  
    EFFECTIVETIME              VARCHAR(256) NOT NULL,  
    ACTIVE                     NUMBER NOT NULL, 
    MODULEID                   NUMBER,
    REFSETID                   NUMBER, 
    REFERENCEDCOMPONENTID      NUMBER NOT NULL,
    TARGETCOMPONENT            NUMBER NOT NULL
);

CREATE INDEX X_rel_id_uk
   ON SCT2_RELA_FULL_UK (ID);

CREATE INDEX X_DESC_2CD_UK
   ON SCT2_DESC_FULL_UK (CONCEPTID, MODULEID);

CREATE INDEX X_DESC_3CD_UK
   ON SCT2_DESC_FULL_UK (CONCEPTID, MODULEID, TERM);

CREATE INDEX X_CID_UK
   ON SCT2_CONCEPT_FULL_UK (ID);
   
-- Create views combining the Int and UK versions
CREATE VIEW sct2_concept_full_merged AS SELECT * FROM sct2_concept_full_int UNION SELECT * FROM  sct2_concept_full_uk;
CREATE VIEW sct2_desc_full_merged AS SELECT * FROM sct2_desc_full_en_int UNION SELECT * FROM sct2_desc_full_uk;
CREATE VIEW sct2_rela_full_merged AS SELECT * FROM sct2_rela_full_int UNION SELECT * FROM sct2_rela_full_uk;
CREATE VIEW der2_cRefset_AssRefFull_merged AS SELECT * FROM der2_cRefset_AssRefFull_INT UNION SELECT * FROM der2_cRefset_AssRefFull_UK;

--Create XML table for DM+D
CREATE TABLE f_lookup2 (xmlfield XMLTYPE);
CREATE TABLE f_ingredient2 (xmlfield XMLTYPE);
CREATE TABLE f_vtm2 (xmlfield XMLTYPE);
CREATE TABLE f_vmp2 (xmlfield XMLTYPE);
CREATE TABLE f_amp2 (xmlfield XMLTYPE);
CREATE TABLE f_vmpp2 (xmlfield XMLTYPE);
CREATE TABLE f_ampp2 (xmlfield XMLTYPE);
CREATE TABLE dmdbonus (xmlfield XMLTYPE);