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

DROP TABLE IF EXISTS SOURCES.RETCTBL0_ETC_ID;
CREATE TABLE SOURCES.RETCTBL0_ETC_ID
(
  ETC_ID                      VARCHAR(8)  NOT NULL,
  ETC_NAME                    VARCHAR(70),
  ETC_ULTIMATE_CHILD_IND      VARCHAR(1),
  ETC_DRUG_CONCEPT_LINK_IND   VARCHAR(1),
  ETC_PARENT_ETC_ID           VARCHAR(8),
  ETC_FORMULARY_LEVEL_IND     VARCHAR(1),
  ETC_PRESENTATION_SEQNO      VARCHAR(5),
  ETC_ULTIMATE_PARENT_ETC_ID  VARCHAR(8),
  ETC_HIERARCHY_LEVEL         VARCHAR(2),
  ETC_SORT_NUMBER             VARCHAR(5),
  ETC_RETIRED_IND             VARCHAR(1),
  ETC_RETIRED_DATE            VARCHAR(8)
);

DROP TABLE IF EXISTS SOURCES.RETCGCH0_ETC_GCNSEQNO_HIST;
CREATE TABLE SOURCES.RETCGCH0_ETC_GCNSEQNO_HIST
(
  GCN_SEQNO             VARCHAR(6)        NOT NULL,
  ETC_ID                VARCHAR(8)        NOT NULL,
  ETC_REVISION_SEQNO    VARCHAR(5)        NOT NULL,
  ETC_COMMON_USE_IND    VARCHAR(1),
  ETC_DEFAULT_USE_IND   VARCHAR(1),
  ETC_CHANGE_TYPE_CODE  VARCHAR(1),
  ETC_EFFECTIVE_DATE    DATE
);

DROP TABLE IF EXISTS SOURCES.RETCHCH0_ETC_HICSEQN_HIST;
CREATE TABLE SOURCES.RETCHCH0_ETC_HICSEQN_HIST
(
  HIC_SEQN              VARCHAR(6)        NOT NULL,
  ETC_ID                VARCHAR(8)        NOT NULL,
  ETC_REVISION_SEQNO    VARCHAR(5)        NOT NULL,
  ETC_CHANGE_TYPE_CODE  VARCHAR(1),
  ETC_EFFECTIVE_DATE    DATE
);