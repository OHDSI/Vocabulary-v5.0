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
* Authors: Timur Vakhitov
* Date: 2021
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.ONCOTREE_TREE;
CREATE TABLE SOURCES.ONCOTREE_TREE
(
   ANCESTOR_CODE      TEXT,
   ANCESTOR_NAME      TEXT,
   DESCENDANT_CODE    TEXT,
   DESCENDANT_NAME    TEXT,
   VOCABULARY_DATE    DATE,
   VOCABULARY_VERSION VARCHAR (200)
);