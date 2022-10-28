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

TRUNCATE TABLE dev_kcd7.concept_relationship_manual;
INSERT INTO dev_kcd7.concept_relationship_manual
SELECT *
FROM dev_kcd7.concept_relationship_manual_backup_2022_05_18
    ;
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

    AND concept_code_1 IN (SELECT icd_code FROM refresh_lookup_done) --work only with the codes presented in the manual file of the current vocabulary refresh

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
               'KCD7' AS vocabulary_id_1, -- set current vocabulary name as vocabulary_id_1
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
               relationship_id) --with the same relationship
        NOT IN (SELECT concept_code_1,
                       concept_code_2,
                       vocabulary_id_1,
                       vocabulary_id_2,
                       relationship_id FROM concept_relationship_manual)
    )
;

-- 23/08/2022 patch  used after generic to detect Values to be invalidated
INSERT INTO concept_relationship_manual(vocabulary_id_1, concept_code_1, relationship_id, valid_start_date, invalid_reason, valid_end_date, vocabulary_id_2, concept_code_2)
SELECT
distinct
       con.vocabulary_id as vocabulary_id_1,
       con.concept_code as concept_code_1,
       crm.relationship_id,
       crm.valid_start_date,
   'D' as invalid_reason,
    current_date as valid_end_date,
       con2.vocabulary_id  as vocabulary_id_2,
       con2.concept_code   as concept_code_2
FROM concept_relationship  crm
JOIN concept con
on con.concept_id=crm.concept_id_1
and con.vocabulary_id='KCD7'
and crm.invalid_reason is null
    and crm.relationship_id ilike 'Maps%'
JOIN concept con2
on crm.concept_id_2=con2.concept_id
where exists(SELECT 1
             from concept c
                      JOIN concept_relationship cr
                           on cr.concept_id_1 = c.concept_id
                                  and cr.relationship_id = 'Maps to value'
                               and cr.invalid_reason is null
    and crm.concept_id_1=c.concept_id
    and c.vocabulary_id='KCD7'
    )
and   not exists(SELECT 1
             from devv5.concept c1
                      JOIN devv5.concept_relationship cr1
                           on cr1.concept_id_1 = c1.concept_id
                                  and cr1.relationship_id = 'Maps to value'
                                  and cr1.invalid_reason is null
    and con.concept_code=c1.concept_code
    and 'ICD10'=c1.vocabulary_id
    )
and crm.relationship_id ='Maps to value'
 and (con.concept_code, --the same source_code is mapped
               con2.concept_code, --to the same concept_code
               con.vocabulary_id,
                 con2.vocabulary_id, --of the same vocabulary
               crm.relationship_id) --with the same relationship
        NOT IN (SELECT concept_code_1,
                       concept_code_2,
                       vocabulary_id_1,
                       vocabulary_id_2,
                       relationship_id FROM concept_relationship_manual)
;



