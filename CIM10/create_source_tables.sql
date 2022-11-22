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
* Date: 2022
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.CIM10;
CREATE TABLE SOURCES.CIM10
(
   code               TEXT,
   type_mco           TEXT,
   profil             TEXT,
   type_psy           TEXT,
   lib_court          TEXT,
   lib_complet        TEXT,
   vocabulary_date    DATE,
   vocabulary_version VARCHAR (200)
);