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
-- create current date backup of concept_relationship_manual table
DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT TO_CHAR(CURRENT_DATE, 'YYYY_MM_DD')
        INTO update;
        EXECUTE format('create table %I as select * from concept_relationship_manual',
                       'concept_relationship_manual_backup_' || update);

    END
$body$;

--restore concept_relationship_manual table (run it only if something went wrong)
TRUNCATE TABLE dev_icd10cm.concept_relationship_manual;
INSERT INTO dev_icd10cm.concept_relationship_manual
SELECT * FROM dev_icd10cm.concept_relationship_manual_backup_2022_04_21;

DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT TO_CHAR(CURRENT_DATE, 'YYYY_MM_DD')
        INTO update;
        EXECUTE FORMAT('create table %I as select * from concept_manual',
                       'concept_manual_backup_' || update);

    END
$body$;

--restore concept_manual table (run it only if something went wrong)
/*TRUNCATE TABLE dev_icd10cm.concept_manual;
INSERT INTO dev_icd10cm.concept_manual
SELECT * FROM dev_icd10cm.concept_manual_backup_2022_06_01;*/


-- deprecate previous inaccurate mapping
UPDATE concept_relationship_manual crm
SET invalid_reason = 'D',
    valid_end_date = current_date

--SELECT * FROM concept_relationship_manual crm --use this SELECT for QA
WHERE invalid_reason IS NULL --deprecate only what's not yet deprecated in order to preserve the original deprecation date

    AND concept_code_1 IN (SELECT icd_code FROM refresh_lookup_done) --work only with the codes presented in the manual file of the current vocabulary refresh

    AND NOT EXISTS (SELECT 1 --don't deprecate mapping if the same exists in the current manual file
                    FROM refresh_lookup_done rl
                    WHERE rl.icd_code = crm.concept_code_1 --the same source_code is mapped
                        AND rl.repl_by_code = crm.concept_code_2 --to the same concept_code
                        AND rl.repl_by_vocabulary = crm.vocabulary_id_2 --of the same vocabulary
                        AND rl.repl_by_relationship = crm.relationship_id --with the same relationship
        )
;

-- activate mapping, that became valid again
UPDATE concept_relationship_manual crm
SET invalid_reason = null,
    valid_end_date = to_date('20991231','yyyymmdd'),
    valid_start_date =current_date

--SELECT * FROM concept_relationship_manual crm --use this SELECT for QA
WHERE invalid_reason = 'D' -- activate only deprecated mappings

    AND EXISTS (SELECT 1 -- activate mapping if the same exists in the current manual file
                    FROM refresh_lookup_done rl
                    WHERE rl.icd_code = crm.concept_code_1 --the same source_code is mapped
                        AND rl.repl_by_code = crm.concept_code_2 --to the same concept_code
                        AND rl.repl_by_vocabulary = crm.vocabulary_id_2 --of the same vocabulary
                        AND rl.repl_by_relationship = crm.relationship_id --with the same relationship
        )
;

-- insert new mapping
with mapping AS -- select all new codes with their mappings from manual file
    (
        SELECT DISTINCT icd_code AS concept_code_1,
               repl_by_code AS concept_code_2,
               'ICD10CM' AS vocabulary_id_1, -- set current vocabulary name as vocabulary_id_1
               repl_by_vocabulary AS vocabulary_id_2,
               repl_by_relationship AS relationship_id,
               current_date AS valid_start_date, -- set the date of the refresh as valid_start_date
               to_date('20991231','yyyymmdd') AS valid_end_date,
               NULL AS invalid_reason -- make all new mappings valid
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
