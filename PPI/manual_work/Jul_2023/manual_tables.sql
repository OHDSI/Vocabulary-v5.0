CREATE TABLE concept_manual_backup_10_2023 as SELECT * FROM concept_manual;
SELECT * FROM concept_manual_backup_10_2023;
CREATE TABLE concept_relationship_manual_backup_10_2023 as SELECT * FROM concept_relationship_manual;
SELECT * FROM concept_relationship_manual_backup_10_2023;
CREATE TABLE concept_synonym_manual_backup_10_2023 as SELECT * FROM concept_synonym_manual;
SELECT * FROM concept_synonym_manual_backup_10_2023;

--TRUNCATE concept_manual;
--TRUNCATE concept_relationship_manual;
--TRUNCATE concept_synonym_manual;

SELECT * FROM concept_manual;
SELECT * FROM concept_relationship_manual;
SELECT * FROM concept_synonym_manual;

-- 1. insert previous Mental Health and Well-Being Module concepts and their relationships to deprecate from manual file

-- 2. insert new concepts into concept_manual
--insert module bhp
INSERT INTO concept_manual
SELECT DISTINCT
'Behavioral Health and Personality' AS concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Module' AS concept_class_id,
'S' as source_standard_concept,
'bhp' as concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
;

-- insert questions bhp
INSERT INTO concept_manual
SELECT DISTINCT
concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Question' AS concept_class_id,
'S' as source_standard_concept,
concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
from bhp_pr
WHERE flag = 'q'
and concept_code != 'bhp';

--insert answers bhp
INSERT INTO concept_manual
SELECT DISTINCT
concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Answer' AS concept_class_id,
null AS source_standard_concept,
concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
from bhp_pr
WHERE flag = 'a'
and concept_code not in ('pmi_prefernottoanswer', 'pmi_dontknow'); --concepts will be reused;

--insert module ehh
INSERT INTO concept_manual
SELECT DISTINCT
'Emotional Health History and Well-Being' AS concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Module' AS concept_class_id,
'S' as source_standard_concept,
'ehhwb' as concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
;

-- insert questions ehh
INSERT INTO concept_manual
SELECT DISTINCT
concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Question' AS concept_class_id,
'S' as source_standard_concept,
concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
FROM ehh_pr
WHERE flag = 'q'
and concept_code != 'ehhwb';

--insert answers ehh
INSERT INTO concept_manual
SELECT DISTINCT
concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Answer' AS concept_class_id,
null AS source_standard_concept,
concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
FROM ehh_pr
WHERE flag = 'a'
and concept_code not in ('pmi_prefernottoanswer', 'pmi_dontknow', 'pmi_none'); --concepts will be reused



-- 3. insert new relationships
--to add hierarchy 'Has PPI parent code' from Questions to Module
INSERT INTO concept_relationship_manual
SELECT DISTINCT
concept_code AS concept_code_1,
'bhp' AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Has PPI parent code' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM bhp_pr
WHERE flag = 'q'
AND concept_code != 'bhp'
;

--to add hierarchy 'Has PPI parent code' from Questions to Module
INSERT INTO concept_relationship_manual
SELECT DISTINCT
concept_code AS concept_code_1,
'ehhwb' AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Has PPI parent code' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM ehh_pr
WHERE flag = 'q'
AND concept_code != 'ehh'
;

--to add hierarchy 'Has PPI parent code' from Answers to Questions
INSERT INTO concept_relationship_manual
SELECT DISTINCT
answer_code as concept_code_1,
question_code as concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Has PPI parent code' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM bhp_qa;

--to add hierarchy 'Has PPI parent code' from Answers to Questions
INSERT INTO concept_relationship_manual
SELECT DISTINCT
answer_code as concept_code_1,
question_code as concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Has PPI parent code' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM ehh_qa;



-- 4. insert concept synonyms from manual file

SELECT * FROM dev_ppi.concept_manual; -- 1002 --237 D
SELECT * FROM concept_relationship_manual; -- 2437 1057 D
SELECT * FROM concept_synonym_manual;

