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
* Date: 2022
**************************************************************************/

--DROP TABLE IF EXISTS refresh_lookup_done;
--TRUNCATE TABLE refresh_lookup_done;
CREATE TABLE refresh_lookup_done (
id serial primary key,
read_code VARCHAR,
read_name VARCHAR,
cr_invalid_reason varchar,
repl_by_relationship VARCHAR,
to_value varchar,
repl_by_id INT,
repl_by_code VARCHAR,
repl_by_name VARCHAR,
repl_by_domain VARCHAR,
repl_by_vocabulary VARCHAR);

SELECT *
FROM refresh_lookup_done;


-- deprecate previous inaccurate mapping
UPDATE concept_relationship_manual crm
SET invalid_reason = 'D',
    valid_end_date = current_date

--SELECT * FROM concept_relationship_manual crm --use this SELECT for QA
WHERE invalid_reason IS NULL --deprecate only what's not yet deprecated in order to preserve the original deprecation date

    AND (concept_code_1, concept_code_2) IN (SELECT read_code, repl_by_code FROM refresh_lookup_done) --work only with the codes presented in the manual file of the current vocabulary refresh, have the same target as before
    AND NOT EXISTS(SELECT 1 --don't deprecate mapping if the same exists in the current manual file
                   FROM refresh_lookup_done rl
                   WHERE rl.read_code = crm.concept_code_1           --the same source_code is mapped
                     AND rl.repl_by_code = crm.concept_code_2        --to the same concept_code
                     AND rl.repl_by_vocabulary = crm.vocabulary_id_2 --of the same vocabulary
                     AND rl.repl_by_relationship = crm.relationship_id --with the same relationship
                     AND rl.cr_invalid_reason = crm.invalid_reason -- the same validity of links
        )
;

-- activate mapping, that became valid again
UPDATE concept_relationship_manual crm
SET invalid_reason = null,
    valid_end_date = to_date('20991231','yyyymmdd'),
    valid_start_date = current_date

--SELECT * FROM concept_relationship_manual crm --use this SELECT for QA
WHERE invalid_reason = 'D' -- activate only deprecated mappings

    AND EXISTS (SELECT 1 -- activate mapping if the same exists in the current manual file
                    FROM refresh_lookup_done rl
                    WHERE rl.read_code = crm.concept_code_1 --the same source_code is mapped
                        AND rl.repl_by_code = crm.concept_code_2 --to the same concept_code
                        AND rl.repl_by_vocabulary = crm.vocabulary_id_2 --of the same vocabulary
                        AND rl.repl_by_relationship = crm.relationship_id --with the same relationship
                        AND (cr_invalid_reason IS NULL OR cr_invalid_reason = '') --the same validity of links
        )
;

-- insert new mapping
with mapping AS -- select all new codes with their mappings from manual file
    (
        SELECT DISTINCT read_code AS concept_code_1,
               repl_by_code AS concept_code_2,
               'Read' AS vocabulary_id_1, -- set current vocabulary name as vocabulary_id_1
               repl_by_vocabulary AS vocabulary_id_2,
               repl_by_relationship AS relationship_id,
               CASE WHEN cr_invalid_reason IN ('U', 'D') --for case when we want to deprecate mapping that doesn't exist in crm: taking valid start date from devv5.concept
                   THEN (SELECT valid_start_date
                         FROM devv5.concept_relationship
                         WHERE concept_id_1 IN (SELECT concept_id
                                                FROM devv5.concept
                                                WHERE concept_code = read_code AND vocabulary_id = 'Read')
                         AND concept_id_2 IN (SELECT concept_id
                                              FROM devv5.concept
                                              WHERE concept_code = repl_by_code AND vocabulary_id = repl_by_vocabulary)
                         AND relationship_id = repl_by_relationship and invalid_reason IS NULL)
                   ELSE current_date END AS valid_start_date, -- set the date of the refresh as valid_start_date
               CASE WHEN (cr_invalid_reason NOT IN ('U', 'D') OR cr_invalid_reason IS NULL)
                   THEN to_date('20991231','yyyymmdd')
                   ELSE current_date END AS valid_end_date,
               CASE WHEN (cr_invalid_reason NOT IN ('U', 'D') OR cr_invalid_reason IS NULL)
                   THEN NULL
                ELSE cr_invalid_reason END AS invalid_reason
        FROM refresh_lookup_done
        WHERE repl_by_id != 0 -- select only codes with mapping to standard concepts
    )
-- insert new mappings into concept_relationship_manual table
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
        -- don't insert codes with mapping if the same exists in the current manual file
        WHERE (concept_code_1, --the same source_code is mapped
               concept_code_2, --to the same concept_code
               vocabulary_id_1,
               vocabulary_id_2, --of the same vocabulary
               relationship_id, --with the same relationship
               invalid_reason)
        NOT IN (SELECT concept_code_1,
                       concept_code_2,
                       vocabulary_id_1,
                       vocabulary_id_2,
                       relationship_id,
                       invalid_reason FROM concept_relationship_manual
            )
    )
;



