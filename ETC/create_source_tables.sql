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

CREATE TABLE RETCTBL0_ETC_ID
(
  ETC_ID                      VARCHAR2(8 BYTE)  NOT NULL,
  ETC_NAME                    VARCHAR2(70 BYTE),
  ETC_ULTIMATE_CHILD_IND      VARCHAR2(1 BYTE),
  ETC_DRUG_CONCEPT_LINK_IND   VARCHAR2(1 BYTE),
  ETC_PARENT_ETC_ID           VARCHAR2(8 BYTE),
  ETC_FORMULARY_LEVEL_IND     VARCHAR2(1 BYTE),
  ETC_PRESENTATION_SEQNO      VARCHAR2(5 BYTE),
  ETC_ULTIMATE_PARENT_ETC_ID  VARCHAR2(8 BYTE),
  ETC_HIERARCHY_LEVEL         VARCHAR2(2 BYTE),
  ETC_SORT_NUMBER             VARCHAR2(5 BYTE),
  ETC_RETIRED_IND             VARCHAR2(1 BYTE),
  ETC_RETIRED_DATE            VARCHAR2(8 BYTE)
);

CREATE TABLE RETCGCH0_ETC_GCNSEQNO_HIST
(
  GCN_SEQNO             VARCHAR2(6 BYTE)        NOT NULL,
  ETC_ID                VARCHAR2(8 BYTE)        NOT NULL,
  ETC_REVISION_SEQNO    VARCHAR2(5 BYTE)        NOT NULL,
  ETC_COMMON_USE_IND    VARCHAR2(1 BYTE),
  ETC_DEFAULT_USE_IND   VARCHAR2(1 BYTE),
  ETC_CHANGE_TYPE_CODE  VARCHAR2(1 BYTE),
  ETC_EFFECTIVE_DATE    DATE
);

CREATE TABLE RETCHCH0_ETC_HICSEQN_HIST
(
  HIC_SEQN              VARCHAR2(6 BYTE)        NOT NULL,
  ETC_ID                VARCHAR2(8 BYTE)        NOT NULL,
  ETC_REVISION_SEQNO    VARCHAR2(5 BYTE)        NOT NULL,
  ETC_CHANGE_TYPE_CODE  VARCHAR2(1 BYTE),
  ETC_EFFECTIVE_DATE    DATE
);