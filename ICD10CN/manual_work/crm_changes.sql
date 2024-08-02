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
--1. Update the concept_relationship_manual table
CREATE TABLE concept_relationship_manual_bu as (SELECT * FROM concept_relationship_manual);
INSERT INTO concept_relationship_manual (SELECT * FROM concept_relationship_manual_bu);
TRUNCATE TABLE dev_ICD10CN.concept_relationship_manual;
INSERT INTO concept_relationship_manual (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT DISTINCT
concept_code_1,
concept_code_2,
vocabulary_id_1,
vocabulary_id_2,
relationship_id,
valid_start_date,
valid_end_date,
invalid_reason
FROM devv5.base_concept_relationship_manual
where vocabulary_id_1 = 'ICD10CN';

-- deprecate previous inaccurate mapping
UPDATE concept_relationship_manual crm
SET invalid_reason = 'D',
    valid_end_date = current_date

--SELECT * FROM concept_relationship_manual crm --use this SELECT for QA
WHERE invalid_reason IS NULL --deprecate only what's not yet deprecated in order to preserve the original deprecation date

    AND concept_code_1 IN (SELECT source_code FROM dev_icd10.icd_cde_proc WHERE source_vocabulary_id = 'ICD10CN') --work only with the codes presented in the manual file of the current vocabulary refresh
    AND vocabulary_id_1 = 'ICD10CN'
    AND NOT EXISTS (SELECT 1 --don't deprecate mapping if the same exists in the current manual file
                    FROM dev_icd10.icd_cde_proc rl
                    WHERE rl.source_code = crm.concept_code_1 --the same source_code is mapped
                        AND rl.target_concept_code = crm.concept_code_2 --to the same concept_code
                        AND rl.target_vocabulary_id = crm.vocabulary_id_2 --of the same vocabulary
                        AND rl.relationship_id = crm.relationship_id --with the same relationship
                        AND rl.source_vocabulary_id = 'ICD10CN'     )
;

-- activate mapping, that became valid again
UPDATE concept_relationship_manual crm
SET invalid_reason = null,
    valid_end_date = to_date('20991231','yyyymmdd'),
    valid_start_date = current_date

--SELECT * FROM concept_relationship_manual crm --use this SELECT for QA
WHERE invalid_reason = 'D' -- activate only deprecated mappings

    AND EXISTS (SELECT 1 -- activate mapping if the same exists in the current manual file
                    FROM dev_icd10.icd_cde_proc rl
                    WHERE rl.source_code = crm.concept_code_1 --the same source_code is mapped
                        AND rl.target_concept_code = crm.concept_code_2 --to the same concept_code
                        AND rl.target_vocabulary_id = crm.vocabulary_id_2 --of the same vocabulary
                        AND rl.relationship_id = crm.relationship_id --with the same relationship
                        AND rl.source_vocabulary_id = 'ICD10CN'
        )
;

-- insert new mapping
with mapping AS -- select all new codes with their mappings from manual file
    (
        SELECT DISTINCT source_code AS concept_code_1,
               target_concept_code AS concept_code_2,
               'ICD10CN' AS vocabulary_id_1, -- set current vocabulary name as vocabulary_id_1
               target_vocabulary_id AS vocabulary_id_2,
               relationship_id AS relationship_id,
               current_date AS valid_start_date, -- set the date of the refresh as valid_start_date
               to_date('20991231','yyyymmdd') AS valid_end_date,
               NULL AS invalid_reason -- make all new mappings valid
        FROM dev_icd10.icd_cde_proc
        WHERE target_concept_id is not null -- select only codes with mapping to standard concepts
        AND source_vocabulary_id = 'ICD10CN'
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

UPDATE concept_relationship_manual SET relationship_id = 'Maps to' WHERE relationship_id = 'Maps to ';

 -- Minor manual updates
INSERT INTO concept_relationship_manual VALUES ('J68.001', '205237003', 'ICD10CN', 'SNOMED', 'Maps to', '2024-07-30', '2099-12-31', null);

INSERT INTO concept_relationship_manual VALUES ('I62.002', '291581000119109', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I71.201', '433068007', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I71.202', '433068007', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I71.203', '433068007', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I71.204', '433068007', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I71.205', '433068007', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I71.206', '433068007', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I71.401', '233985008', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I71.402', '233985008', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I77.001', '439470001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I77.002', '439470001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I77.003', '439470001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I77.004', '439470001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I77.005', '439470001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I77.006', '439470001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I77.007', '439470001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I77.008', '439470001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I77.009', '439470001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I77.010', '439470001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I77.011', '439470001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I77.012', '439470001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I77.013', '439470001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('I77.014', '439470001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('M95.402', '391986001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('M95.403', '391986001', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('M95.404', '24228002', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('X70', '225052008', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('X70.x00', '225052008', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('Y20', '219328003', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('Y20.9', '219328003', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('Y20.x00', '219328003', 'ICD10CN', 'SNOMED', 'Maps to', '2024-08-01', '2099-12-31', null);
UPDATE concept_relationship_manual SET valid_end_date = '2024-08-01', invalid_reason = 'D' WHERE concept_code_1 = 'J43.901' and concept_code_2 = '195957006';
UPDATE concept_relationship_manual SET valid_end_date = '2024-08-01', invalid_reason = 'D' WHERE concept_code_1 = 'J43.902' and concept_code_2 = '195957006';
UPDATE concept_relationship_manual SET valid_end_date = '2024-08-01', invalid_reason = 'D' WHERE concept_code_1 = 'M84800/6' and concept_code_2 = 'OMOP4998856';
UPDATE concept_relationship_manual SET valid_end_date = '2024-08-01', invalid_reason = 'D' WHERE concept_code_1 = 'M84801/6' and concept_code_2 = 'OMOP4998856';
UPDATE concept_relationship_manual SET valid_end_date = '2024-08-01', invalid_reason = 'D' WHERE concept_code_1 = 'O10.001' and concept_code_2 = '118185001';
UPDATE concept_relationship_manual SET valid_end_date = '2024-08-01', invalid_reason = 'D' WHERE concept_code_1 = 'O10.201' and concept_code_2 = '118185001';
UPDATE concept_relationship_manual SET valid_end_date = '2024-08-01', invalid_reason = 'D' WHERE concept_code_1 = 'O10.301' and concept_code_2 = '118185001';
UPDATE concept_relationship_manual SET valid_end_date = '2024-08-01', invalid_reason = 'D' WHERE concept_code_1 = 'O10.401' and concept_code_2 = '118185001';
UPDATE concept_relationship_manual SET valid_end_date = '2024-08-01', invalid_reason = 'D' WHERE concept_code_1 = 'O11.x01' and concept_code_2 = '118185001';
UPDATE concept_relationship_manual SET valid_end_date = '2024-08-01', invalid_reason = 'D' WHERE concept_code_1 = 'O13.x01' and concept_code_2 = '118185001';
UPDATE concept_relationship_manual SET valid_end_date = '2024-08-01', invalid_reason = 'D' WHERE concept_code_1 = 'O14.901' and concept_code_2 = '118185001';
UPDATE concept_relationship_manual SET valid_end_date = '2024-08-01', invalid_reason = 'D' WHERE concept_code_1 = 'R74.805' and concept_code_2 = '122444009';
UPDATE concept_relationship_manual SET valid_end_date = '2024-08-01', invalid_reason = 'D' WHERE concept_code_1 = 'Z88.101' and concept_code_2 = '609328004';
INSERT INTO concept_relationship_manual VALUES ('Z96.2', 'OMOP5165859', 'ICD10CN', 'OMOP Extension', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('Z96.2', '118891001', 'ICD10CN', 'SNOMED', 'Maps to value', '2016-01-01', '2024-08-01', 'D');

INSERT INTO concept_relationship_manual VALUES ('Z96.200', 'OMOP5165859', 'ICD10CN', 'OMOP Extension', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('Z96.200', '118891001', 'ICD10CN', 'SNOMED', 'Maps to value', '2016-01-01', '2024-08-01', 'D');

INSERT INTO concept_relationship_manual VALUES ('Z96.201', 'OMOP5165859', 'ICD10CN', 'OMOP Extension', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('Z96.201', '118891001', 'ICD10CN', 'SNOMED', 'Maps to value', '2016-01-01', '2024-08-01', 'D');

INSERT INTO concept_relationship_manual VALUES ('Z96.4', 'OMOP5165859', 'ICD10CN', 'OMOP Extension', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('Z96.4', '79537002', 'ICD10CN', 'SNOMED', 'Maps to value', '2016-01-01', '2024-08-01', 'D');

INSERT INTO concept_relationship_manual VALUES ('Z96.400', 'OMOP5165859', 'ICD10CN', 'OMOP Extension', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('Z96.400', '79537002', 'ICD10CN', 'SNOMED', 'Maps to value', '2016-01-01', '2024-08-01', 'D');

INSERT INTO concept_relationship_manual VALUES ('Z96.401', 'OMOP5165859', 'ICD10CN', 'OMOP Extension', 'Maps to', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('Z96.401', '79537002', 'ICD10CN', 'SNOMED', 'Maps to value', '2016-01-01', '2024-08-01', 'D');

INSERT INTO concept_relationship_manual VALUES ('X37.x00', '420101009', 'ICD10CN', 'SNOMED', 'Maps to value', '2024-08-01', '2099-12-31', null);
INSERT INTO concept_relationship_manual VALUES ('X37', '420101009', 'ICD10CN', 'SNOMED', 'Maps to value', '2024-08-01', '2099-12-31', null);

