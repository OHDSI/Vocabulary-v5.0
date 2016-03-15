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

CREATE TABLE CVX
(
   cvx_code            VARCHAR2 (100),
   short_description   VARCHAR2 (4000),
   full_vaccine_name   VARCHAR2 (4000),
   vaccine_status      VARCHAR2 (100),
   nonvaccine          VARCHAR2 (100),
   last_updated_date   DATE
);

CREATE TABLE CVX_DATES
(
   cvx_code                 VARCHAR2 (100),
   concept_date             DATE
);