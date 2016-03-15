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

CREATE TABLE RXXXREF
(
   external_source           VARCHAR2 (10),
   external_source_code      VARCHAR2 (30),
   concept_type_id           NUMBER,
   concept_value             VARCHAR2 (20),
   transaction_cd            VARCHAR2 (1),
   match_type                VARCHAR2 (2),
   umls_concept_identifier   VARCHAR2 (12),
   rxnorm_code               VARCHAR2 (10),
   reserve                   VARCHAR2 (22)
);

CREATE TABLE GPI_NAME
(
  GPI_CODE     VARCHAR2(100 BYTE),
  DRUG_STRING  VARCHAR2(100 BYTE)
);