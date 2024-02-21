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
* Authors: Irina Zherko, Darina Ivakhnenko, Dmitry Dymshyts
* Date: 2021
**************************************************************************/
TRUNCATE TABLE concept_relationship_manual;
INSERT INTO concept_relationship_manual (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT DISTINCT
source_code as concept_code_1,
target_concept_code as concept_code_2,
'KCD7' as vocabulary_id_1,
target_vocabulary_id as vocabulary_id_2,
relationship_id as relationship_id,
current_date as valid_start_date,
to_date('20991231','yyyymmdd') as valid_end_date,
null as invalid_reason
FROM dev_icd10.icd_cde_proc
WHERE source_vocabulary_id = 'KCD7'
AND target_concept_id is not null;