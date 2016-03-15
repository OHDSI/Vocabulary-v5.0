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

CREATE TABLE RFMLDRH0_DXID_HIST
(
   FMLPRVDXID   VARCHAR2 (8) NOT NULL,
   FMLREPDXID   VARCHAR2 (8) NOT NULL,
   FMLDXREPDT   DATE
);

CREATE TABLE RFMLDX0_DXID
(
   DXID                       VARCHAR2 (8) NOT NULL,
   DXID_DESC56                VARCHAR2 (56),
   DXID_DESC100               VARCHAR2 (100),
   DXID_STATUS                VARCHAR2 (1) NOT NULL,
   FDBDX                      VARCHAR2 (9) NOT NULL,
   DXID_DISEASE_DURATION_CD   VARCHAR2 (1) NOT NULL
);

CREATE TABLE RFMLSYN0_DXID_SYN
(
   DXID_SYNID         VARCHAR2 (8) NOT NULL,
   DXID               VARCHAR2 (8) NOT NULL,
   DXID_SYN_NMTYP     VARCHAR2 (2) NOT NULL,
   DXID_SYN_DESC56    VARCHAR2 (56),
   DXID_SYN_DESC100   VARCHAR2 (100),
   DXID_SYN_STATUS    VARCHAR2 (1) NOT NULL
);

CREATE TABLE RINDMGC0_INDCTS_GCNSEQNO_LINK
(
   GCN_SEQNO   VARCHAR2 (6) NOT NULL,
   INDCTS      VARCHAR2 (5) NOT NULL
);

CREATE TABLE RINDMMA2_INDCTS_MSTR
(
   INDCTS       VARCHAR2 (5) NOT NULL,
   INDCTS_SN    VARCHAR2 (2) NOT NULL,
   INDCTS_LBL   VARCHAR2 (1) NOT NULL,
   FDBDX        VARCHAR2 (9) NOT NULL,
   DXID         VARCHAR2 (8),
   PROXY_IND    VARCHAR2 (1),
   PRED_CODE    VARCHAR2 (1) NOT NULL
);

CREATE TABLE RDDCMGC0_CONTRA_GCNSEQNO_LINK
(
   GCN_SEQNO   VARCHAR2 (6) NOT NULL,
   DDXCN       VARCHAR2 (5) NOT NULL
);

CREATE TABLE RDDCMMA1_CONTRA_MSTR
(
   DDXCN       VARCHAR2 (5) NOT NULL,
   DDXCN_SN    VARCHAR2 (2) NOT NULL,
   FDBDX       VARCHAR2 (9),
   DDXCN_SL    VARCHAR2 (1),
   DDXCN_REF   VARCHAR2 (26),
   DXID        VARCHAR2 (8)
);

CREATE TABLE RFMLISR1_ICD_SEARCH
(
   SEARCH_ICD_CD   VARCHAR2 (10) NOT NULL,
   ICD_CD_TYPE     VARCHAR2 (2) NOT NULL,
   RELATED_DXID    VARCHAR2 (8) NOT NULL,
   FML_CLIN_CODE   VARCHAR2 (2) NOT NULL,
   FML_NAV_CODE    VARCHAR2 (2) NOT NULL
);