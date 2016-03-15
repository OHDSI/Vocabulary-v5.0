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

CREATE TABLE ANWEB_V2
(
   HCPC                VARCHAR2 (1000 CHAR),
   LONG_DESCRIPTION    VARCHAR2 (4000 CHAR),
   SHORT_DESCRIPTION   VARCHAR2 (1000 CHAR),
   PRICE_CD1           VARCHAR2 (1000 CHAR),
   PRICE_CD2           VARCHAR2 (1000 CHAR),
   PRICE_CD3           VARCHAR2 (1000 CHAR),
   PRICE_CD4           VARCHAR2 (1000 CHAR),
   MULTI_PI            VARCHAR2 (1000 CHAR),
   CIM1                VARCHAR2 (1000 CHAR),
   CIM2                VARCHAR2 (1000 CHAR),
   CIM3                VARCHAR2 (1000 CHAR),
   MCM1                VARCHAR2 (1000 CHAR),
   MCM2                VARCHAR2 (1000 CHAR),
   MCM3                VARCHAR2 (1000 CHAR),
   STATUTE             VARCHAR2 (1000 CHAR),
   LAB_CERT_CD1        VARCHAR2 (1000 CHAR),
   LAB_CERT_CD2        VARCHAR2 (1000 CHAR),
   LAB_CERT_CD3        VARCHAR2 (1000 CHAR),
   LAB_CERT_CD4        VARCHAR2 (1000 CHAR),
   LAB_CERT_CD5        VARCHAR2 (1000 CHAR),
   LAB_CERT_CD6        VARCHAR2 (1000 CHAR),
   LAB_CERT_CD7        VARCHAR2 (1000 CHAR),
   LAB_CERT_CD8        VARCHAR2 (1000 CHAR),
   XREF1               VARCHAR2 (1000 CHAR),
   XREF2               VARCHAR2 (1000 CHAR),
   XREF3               VARCHAR2 (1000 CHAR),
   XREF4               VARCHAR2 (1000 CHAR),
   XREF5               VARCHAR2 (1000 CHAR),
   COV_CODE            VARCHAR2 (1000 CHAR),
   ASC_GPCD            VARCHAR2 (1000 CHAR),
   ASC_EFF_DT          VARCHAR2 (1000 CHAR),
   BETOS               VARCHAR2 (1000 CHAR),
   TOS1                VARCHAR2 (1000 CHAR),
   TOS2                VARCHAR2 (1000 CHAR),
   TOS3                VARCHAR2 (1000 CHAR),
   TOS4                VARCHAR2 (1000 CHAR),
   TOS5                VARCHAR2 (1000 CHAR),
   ANES_UNIT           VARCHAR2 (1000 CHAR),
   ADD_DATE            DATE,
   ACT_EFF_DT          DATE,
   TERM_DT             DATE,
   ACTION_CODE         VARCHAR2 (1000 CHAR)
);