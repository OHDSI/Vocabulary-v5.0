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
* Authors: Polina Talapova, Daryna Ivakhnenko, Dmitry Dymshyts
* Date: 2020
**************************************************************************/

DROP TABLE IF EXISTS nccd_vocabulary_vesion;
CREATE TABLE nccd_vocabulary_vesion
(
   vocabulary_date    DATE,
   vocabulary_version VARCHAR (200)
);

CREATE TABLE nccd_full_done 
(
  nccd_type          VARCHAR(50),
  nccd_code          VARCHAR(50),
  nccd_name          VARCHAR(1000),
  t_nm               VARCHAR(255),
  concept_id         INTEGER,
  concept_code       VARCHAR(50),
  concept_name       VARCHAR(255),
  vocabulary_id      VARCHAR(20),
  concept_class_id   VARCHAR(20),
  ing_code           VARCHAR(50),
  df_code            VARCHAR(50),
  dose               VARCHAR(20),
  unit               VARCHAR(20),
  add_rel_id         VARCHAR(20),
  related_code       VARCHAR(50),
  df_name            VARCHAR(255)
);
