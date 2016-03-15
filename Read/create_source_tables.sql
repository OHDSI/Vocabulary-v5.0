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

CREATE TABLE KEYV2
(
  TERMCLASS          VARCHAR2(10 BYTE),
  CLASSNUMBER        VARCHAR2(2 BYTE),
  DESCRIPTION_SHORT  VARCHAR2(30 BYTE),
  DESCRIPTION        VARCHAR2(60 BYTE),
  DESCRIPTION_LONG   VARCHAR2(200 BYTE),
  TERMCODE           VARCHAR2(2 BYTE),
  LANG               VARCHAR2(2 BYTE),
  READCODE           VARCHAR2(5 BYTE),
  DIGIT              VARCHAR2(1 BYTE)
);

CREATE TABLE RCSCTMAP2_UK
(
  MAPID          VARCHAR2(38 BYTE),
  READCODE       VARCHAR2(5 BYTE),
  TERMCODE       VARCHAR2(2 BYTE),
  CONCEPTID      VARCHAR2(18 BYTE),
  DESCRIPTIONID  VARCHAR2(18 BYTE),
  IS_ASSURED     VARCHAR2(1 BYTE),
  EFFECTIVEDATE  DATE,
  MAPSTATUS      VARCHAR2(2 BYTE)
);