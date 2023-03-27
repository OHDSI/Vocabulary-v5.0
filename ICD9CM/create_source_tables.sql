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

DROP TABLE IF EXISTS SOURCES.ICD9CM_TEMP;
CREATE UNLOGGED TABLE SOURCES.ICD9CM_TEMP
(
   CMS32_CODES_AND_DESC text
);

DROP TABLE IF EXISTS SOURCES.CMS_DESC_LONG_DX;
CREATE TABLE SOURCES.CMS_DESC_LONG_DX
(
   code   VARCHAR (8),
   name   VARCHAR (256)
);

DROP TABLE IF EXISTS SOURCES.CMS_DESC_SHORT_DX;
CREATE TABLE SOURCES.CMS_DESC_SHORT_DX
(
   code   VARCHAR (8),
   name   VARCHAR (256),
   vocabulary_date      DATE,
   vocabulary_version   VARCHAR (200)
);