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

DROP TABLE IF EXISTS SOURCES.HLGT_PREF_TERM;
CREATE TABLE SOURCES.HLGT_PREF_TERM
(
   hlgt_code          INT4,
   hlgt_name          VARCHAR (100),
   hlgt_whoart_code   VARCHAR (100),
   hlgt_harts_code    INT4,
   hlgt_costart_sym   VARCHAR (100),
   hlgt_icd9_code     VARCHAR (100),
   hlgt_icd9cm_code   VARCHAR (100),
   hlgt_icd10_code    VARCHAR (100),
   hlgt_jart_code     VARCHAR (100),
   filler_column      INT
);

DROP TABLE IF EXISTS SOURCES.HLGT_HLT_COMP;
CREATE TABLE SOURCES.HLGT_HLT_COMP
(
   hlgt_code     INT4,
   hlt_code      INT4,
   filler_column INT
);

DROP TABLE IF EXISTS SOURCES.HLT_PREF_TERM;
CREATE TABLE SOURCES.HLT_PREF_TERM
(
   hlt_code          INT4,
   hlt_name          VARCHAR (100),
   hlt_whoart_code   VARCHAR (100),
   hlt_harts_code    INT4,
   hlt_costart_sym   VARCHAR (100),
   hlt_icd9_code     VARCHAR (100),
   hlt_icd9cm_code   VARCHAR (100),
   hlt_icd10_code    VARCHAR (100),
   hlt_jart_code     VARCHAR (100),
   filler_column     INT
);

DROP TABLE IF EXISTS SOURCES.HLT_PREF_COMP;
CREATE TABLE SOURCES.HLT_PREF_COMP
(
   hlt_code           INT4,
   pt_code            INT4,
   filler_column      INT,
   vocabulary_date    DATE,
   vocabulary_version VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.LOW_LEVEL_TERM;
CREATE TABLE SOURCES.LOW_LEVEL_TERM
(
   llt_code          INT4,
   llt_name          VARCHAR (100),
   pt_code           INT4,
   llt_whoart_code   VARCHAR (100),
   llt_harts_code    INT4,
   llt_costart_sym   VARCHAR (100),
   llt_icd9_code     VARCHAR (100),
   llt_icd9cm_code   VARCHAR (100),
   llt_icd10_code    VARCHAR (100),
   llt_currency      VARCHAR (100),
   llt_jart_code     VARCHAR (100),
   filler_column     INT
);

DROP TABLE IF EXISTS SOURCES.MD_HIERARCHY;
CREATE TABLE SOURCES.MD_HIERARCHY
(
   pt_code          INT4,
   hlt_code         INT4,
   hlgt_code        INT4,
   soc_code         INT4,
   pt_name          VARCHAR (100),
   hlt_name         VARCHAR (100),
   hlgt_name        VARCHAR (100),
   soc_name         VARCHAR (100),
   soc_abbrev       VARCHAR (100),
   null_field       VARCHAR (100),
   pt_soc_code      INT4,
   primary_soc_fg   VARCHAR (100),
   filler_column    INT
);

DROP TABLE IF EXISTS SOURCES.PREF_TERM;
CREATE TABLE SOURCES.PREF_TERM
(
   pt_code          INT4,
   pt_name          VARCHAR (100),
   null_field       VARCHAR (100),
   pt_soc_code      INT4,
   pt_whoart_code   VARCHAR (100),
   pt_harts_code    INT4,
   pt_costart_sym   VARCHAR (100),
   pt_icd9_code     VARCHAR (100),
   pt_icd9cm_code   VARCHAR (100),
   pt_icd10_code    VARCHAR (100),
   pt_jart_code     VARCHAR (100),
   filler_column    INT
);

DROP TABLE IF EXISTS SOURCES.SOC_TERM;
CREATE TABLE SOURCES.SOC_TERM
(
   soc_code          INT4,
   soc_name          VARCHAR (100),
   soc_abbrev        VARCHAR (100),
   soc_whoart_code   VARCHAR (100),
   soc_harts_code    INT4,
   soc_costart_sym   VARCHAR (100),
   soc_icd9_code     VARCHAR (100),
   soc_icd9cm_code   VARCHAR (100),
   soc_icd10_code    VARCHAR (100),
   soc_jart_code     VARCHAR (100),
   filler_column     INT
);

DROP TABLE IF EXISTS SOURCES.SOC_HLGT_COMP;
CREATE TABLE SOURCES.SOC_HLGT_COMP
(
   soc_code      INT4,
   hlgt_code     INT4,
   filler_column INT
);