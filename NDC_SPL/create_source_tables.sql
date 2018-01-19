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

CREATE TABLE PRODUCT
(
  PRODUCTID                  VARCHAR2(50 BYTE),
  PRODUCTNDC                 VARCHAR2(10 BYTE),
  PRODUCTTYPENAME            VARCHAR2(27 BYTE),
  PROPRIETARYNAME            VARCHAR2(226 BYTE),
  PROPRIETARYNAMESUFFIX      VARCHAR2(126 BYTE),
  NONPROPRIETARYNAME         VARCHAR2(4000 BYTE),
  DOSAGEFORMNAME             VARCHAR2(48 BYTE),
  ROUTENAME                  VARCHAR2(1000 BYTE),
  STARTMARKETINGDATE         DATE,
  ENDMARKETINGDATE           DATE,
  MARKETINGCATEGORYNAME      VARCHAR2(240 BYTE),
  APPLICATIONNUMBER          VARCHAR2(100 BYTE),
  LABELERNAME                VARCHAR2(100 BYTE),
  SUBSTANCENAME              VARCHAR2(4000 BYTE),
  ACTIVE_NUMERATOR_STRENGTH  VARCHAR2(4000 BYTE),
  ACTIVE_INGRED_UNIT         VARCHAR2(4000 BYTE),
  PHARM_CLASSES              VARCHAR2(4000 BYTE),
  DEASCHEDULE                VARCHAR2(5 BYTE)
);

CREATE TABLE SPL2RXNORM_MAPPINGS
(
   SETID         VARCHAR2 (50 BYTE),
   SPL_VERSION   VARCHAR2 (10 BYTE),
   RXCUI         VARCHAR2 (8 BYTE),
   RXTTY         VARCHAR2 (10 BYTE)
);

CREATE TABLE SPL_EXT_RAW
(
  XML_NAME  VARCHAR2(100 BYTE),
  XMLFIELD  XMLTYPE
);

CREATE TABLE NDC_EXT_RAW
(
  CONCEPT_CODE  VARCHAR2(100 BYTE),
  XMLFIELD  XMLTYPE
);

CREATE TABLE SPL_EXT
(
  XML_NAME          VARCHAR2(100 BYTE),
  CONCEPT_NAME      VARCHAR2(4000 BYTE),
  CONCEPT_CODE      VARCHAR2(4000 BYTE),
  VALID_START_DATE  DATE,
  DISPLAYNAME       VARCHAR2(4000 BYTE),
  REPLACED_SPL      VARCHAR2(4000 BYTE),
  LOW_VALUE         VARCHAR2(4000 BYTE),
  HIGH_VALUE        VARCHAR2(4000 BYTE)
);

CREATE TABLE SPL2NDC_MAPPINGS
(
  CONCEPT_CODE  VARCHAR2(4000 BYTE),
  NDC_CODE      VARCHAR2(4000 BYTE)
);

CREATE INDEX SPLEXT_idx
   ON SPL_EXT (concept_code)
   NOLOGGING;

CREATE INDEX SPL2NDC_idx
   ON SPL2NDC_MAPPINGS (concept_code)
   NOLOGGING;
   
CREATE INDEX idx_f_product
   ON product (SUBSTR (productid, INSTR (productid, '_') + 1))
   NOLOGGING;

CREATE INDEX idx_f1_product
ON product( 
    CASE
    WHEN INSTR (productndc, '-') = 5
    THEN '0' || SUBSTR (productndc,1,INSTR (productndc, '-') - 1)
    ELSE SUBSTR (productndc, 1, INSTR (productndc, '-') - 1)
    END||
    CASE
    WHEN LENGTH ( SUBSTR (productndc, INSTR (productndc, '-'))) = 4
    THEN '0' || SUBSTR (productndc,INSTR (productndc, '-') + 1)
    ELSE
      SUBSTR (productndc,INSTR (productndc, '-') + 1)
    END)
NOLOGGING;   