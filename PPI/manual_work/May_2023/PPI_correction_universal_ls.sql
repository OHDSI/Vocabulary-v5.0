/**************************************************************************
* Copyright 2020 Observational Health Data Sciences and Informatics (OHDSI)
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
* Authors: Timur Vakhitov
* Date: 2023
**************************************************************************/

-- FastRecreate

-- Update two concepts and set for 2 concepts diffirent concept_class_id

UPDATE dev_ppi.concept_relationship
SET valid_end_date = '2023-05-10', invalid_reason='D'
WHERE concept_id_1=40192497 AND concept_id_2=40770200;

INSERT INTO concept_manual
VALUES ('How often are you treated with less courtesy than other people when you go to a doctor''s office or other health care provider?', 'Observation', 'PPI', 'Question', 'S', 'sdoh_dms_1', '2021-11-03', '2099-12-31', null);

UPDATE dev_ppi.concept_relationship
SET valid_end_date = '2023-05-10', invalid_reason='D'
WHERE concept_id_1=40192425 AND concept_id_2=40770201;

INSERT INTO concept_manual
VALUES ('How often are you treated with less respect than other people when you go to a doctor''s office or other health care provider?', 'Observation', 'PPI', 'Question', 'S', 'sdoh_dms_2', '2021-11-03', '2099-12-31', null);

UPDATE dev_ppi.concept
SET concept_class_id='Answer'
WHERE concept_id=1585872;

UPDATE dev_ppi.concept
SET concept_class_id='Answer'
WHERE concept_id=1586164;

-- Universal Load Stage

-- Check for changes
SELECT * FROM Dev_ppi.concept
         WHERE concept_id IN (40192497, 40192425, 1585872, 1586164);

SELECT * FROM Dev_ppi.concept_relationship
         WHERE concept_id_1 IN (40192497, 40192425);