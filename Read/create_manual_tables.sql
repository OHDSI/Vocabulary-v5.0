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
* Authors: Timur Vakhitov, Alexander Davydov
* Date: 2020
**************************************************************************/

DROP TABLE IF EXISTS concept_manual;

--References:
--https://blog.visionhealth.co.uk/hive-news/coronavirus-clinical-term-update-february-2020
--https://www.scimp.scot.nhs.uk/archives/2733
--https://www.scimp.scot.nhs.uk/archives/2701
CREATE TABLE concept_manual (
	concept_name VARCHAR (255),
	domain_id VARCHAR (20),
	vocabulary_id VARCHAR (20) NOT NULL,
	concept_class_id VARCHAR (20),
	standard_concept VARCHAR (1),
	concept_code VARCHAR (50) NOT NULL,
	valid_start_date DATE NOT NULL,
	valid_end_date DATE NOT NULL,
	invalid_reason VARCHAR (1)
);

--concept_manual cvs generating
SELECT concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_manual
ORDER BY vocabulary_id,
         valid_start_date,
         valid_end_date,
         concept_code;