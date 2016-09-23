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

CREATE TABLE ATC_Glossary
(
   concept_code   VARCHAR2 (1000),
   concept_name   VARCHAR2 (1000),
   n1             VARCHAR2 (1000),
   n2             VARCHAR2 (1000),
   n3             VARCHAR2 (1000),
   n4             VARCHAR2 (1000),
   n5             VARCHAR2 (1000)
);