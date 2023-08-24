TRUNCATE concept_manual;
TRUNCATE concept_relationship_manual;
TRUNCATE concept_synonym_manual;

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
question_name AS concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Question' AS concept_class_id,
'S' as source_standard_concept,
question_code as concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
from bhp_pr;

--insert answers bhp
INSERT INTO concept_manual
SELECT DISTINCT
answer_name AS concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Answer' AS concept_class_id,
null AS source_standard_concept,
answer_code AS concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
from bhp_pr;

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
question_name AS concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Question' AS concept_class_id,
'S' as source_standard_concept,
question_code as concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
from ehh_pr ;

--insert answers ehh
INSERT INTO concept_manual
SELECT DISTINCT
answer_name AS concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Answer' AS concept_class_id,
null AS source_standard_concept,
answer_code AS concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
from ehh_pr;

-- 3. insert new relationships
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
FROM bhp_pr;

--to add hierarchy 'Has PPI parent code' from Questions to Module
INSERT INTO concept_relationship_manual
SELECT DISTINCT
question_code AS concept_code_1,
'bhp' AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Has PPI parent code' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM bhp_pr
;

--add hierarchy 'Has answer (PPI)' from  Questions to Answers
INSERT INTO concept_relationship_manual
SELECT DISTINCT
question_code AS concept_code_1,
answer_code AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Has answer (PPI)' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM bhp_pr
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
FROM ehh_pr;

--to add hierarchy 'Has PPI parent code' from Questions to Module
INSERT INTO concept_relationship_manual
SELECT DISTINCT
question_code AS concept_code_1,
'bhp' AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Has PPI parent code' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM ehh_pr
;

--add hierarchy 'Has answer (PPI)' from  Questions to Answers
INSERT INTO concept_relationship_manual
SELECT DISTINCT
question_code AS concept_code_1,
answer_code AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Has answer (PPI)' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM ehh_pr
;

-- 4. insert concept synonyms from manual file

SELECT * FROM dev_ppi.concept_manual; -- 1002 --237 D
SELECT * FROM concept_relationship_manual; -- 2437 1057 D
SELECT * FROM concept_synonym_manual;

