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
* Authors: Vocabulary Team
* Date: 2021
**************************************************************************/
CREATE TABLE class_drugs_scraper 
(
  id                 INT,
  class_code         VARCHAR(100),
  class_name         VARCHAR,
  ddd                VARCHAR(100),
  u                  VARCHAR(100),
  adm_r              VARCHAR(100),
  note               VARCHAR(100),
  valid_start_date   DATE,
  valid_end_date     DATE,
  cgange_type        VARCHAR(1)
);

CREATE TABLE atc_inexistent 
(
  class_code                VARCHAR,
  class_name                VARCHAR,
  ing                       VARCHAR,
  source_standard_concept   VARCHAR,
  "comment" VARCHAR
);

CREATE TABLE atc_one_to_many_excl 
(
  atc_id            INT,
  atc_code          VARCHAR,
  atc_name          VARCHAR,
  relationship_id   VARCHAR,
  flag              VARCHAR,
  concept_id        INT,
  concept_code      VARCHAR,
  concept_name      VARCHAR
);


CREATE TABLE missing 
(
  atc_id             INT,
  atc_code           VARCHAR(50),
  atc_name           VARCHAR(255),
  atc_class          VARCHAR(20),
  relationship_id    VARCHAR(20),
  concept_id         INT,
  concept_code       VARCHAR(50),
  concept_name       VARCHAR(255),
  concept_class_id   VARCHAR(20),
  domain_id          VARCHAR(20),
  vocabulary_id      VARCHAR(20),
  valid_start_date   DATE,
  valid_end_date     DATE,
  invalid_reason     VARCHAR(1)
);
