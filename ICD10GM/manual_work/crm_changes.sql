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
* Authors: Darina Ivakhnenko, Dmitry Dymshyts
* Date: 2021
**************************************************************************/
-- deprecate previous inaccurate mapping
UPDATE concept_relationship_manual SET valid_end_date = CURRENT_DATE, invalid_reason = 'D' WHERE concept_code_1 IN (SELECT icd_code FROM refresh_lookup_done) AND concept_code_2 NOT IN (SELECT repl_by_code FROM refresh_lookup_done);
-- insert new mapping
INSERT INTO concept_relationship_manual SELECT icd_code, repl_by_code, 'ICD10GM', repl_by_vocabulary, CASE WHEN repl_by_relationship = 'Is a' THEN 'Maps to' ELSE repl_by_relationship END, CURRENT_DATE, TO_DATE('20991231','YYYYMMDD'), NULL FROM refresh_lookup_done;
