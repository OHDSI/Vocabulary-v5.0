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

-- deprecate previous inaccurate mapping
UPDATE concept_relationship_manual crm
SET invalid_reason = 'D',
    valid_end_date = current_date
--SELECT * FROM concept_relationship_manual
WHERE concept_code_1 in
    (SELECT icd_code FROM refresh_lookup_done)
AND (concept_code_2, relationship_id, vocabulary_id_2) in
(SELECT concept_code_2, relationship_id, vocabulary_id_2 FROM concept_relationship_manual crm
WHERE NOT exists (SELECT repl_by_code, repl_by_relationship, repl_by_vocabulary FROM refresh_lookup_done rl
                  WHERE rl.repl_by_code = crm.concept_code_2
                  AND rl.repl_by_vocabulary = crm.vocabulary_id_2
                  AND rl.repl_by_relationship = crm.relationship_id)
AND invalid_reason IS NULL)
    ;

-- insert new mapping
with mapping AS
    (
        SELECT DISTINCT icd_code AS concept_code_1,
               repl_by_code AS concept_code_2,
               'ICD10CM' AS vocabulary_id_1,
               repl_by_vocabulary AS vocabulary_id_2,
               repl_by_relationship AS relationship_id,
               current_date AS valid_start_date,
               to_date('20991231','yyyymmdd') AS valid_end_date,
               NULL AS invalid_reason
        FROM refresh_lookup_done
        WHERE repl_by_id != 0
    )
INSERT INTO concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
(
        SELECT concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id,
            valid_start_date,
            valid_end_date,
            invalid_reason
     FROM mapping m
        WHERE (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id)
        NOT IN (SELECT concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id FROM concept_relationship_manual)
    )
;

