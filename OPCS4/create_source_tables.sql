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

CREATE TABLE OPCS
(
   CUI    VARCHAR2 (50),
   TERM   VARCHAR2 (150)
);

CREATE TABLE OPCSSCTMAP
(
   SCUI     VARCHAR2 (5),
   STUI     VARCHAR2 (1),
   TCUI     VARCHAR2 (18),
   TTUI     VARCHAR2 (1),
   MAPTYP   VARCHAR2 (1)
);