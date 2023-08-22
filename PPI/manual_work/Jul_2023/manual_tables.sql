-- concept_manual backup
DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT TO_CHAR(CURRENT_DATE, 'YYYY_MM_DD')
        INTO update;
        EXECUTE format('create table %I as select * from concept_manual',
                       'concept_manual_backup_' || update);
    END
$body$;

SELECT * FROM dev_ppi.concept_manual_backup_2023_07_25;

-- concept_relationship_manual backup
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

SELECT * FROM dev_ppi.concept_relationship_manual_backup_2023_07_25;

TRUNCATE concept_manual;
TRUNCATE concept_relationship_manual;

-- deprecate previous Mental Health and Well-Being Module concepts --229
INSERT INTO dev_ppi.concept_manual (
SELECT concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       null as standard_concept,
       concept_code,
       valid_start_date,
       current_date as valid_end_date,
       'D' as invalid_reason
FROM concept where concept_code = 'mhwb'

UNION

SELECT c2.concept_name,
       c2.domain_id,
       c2.vocabulary_id,
       c2.concept_class_id,
       null as standard_concept,
       c2.concept_code,
       c2.valid_start_date,
       current_date as valid_end_date,
       'D' as invalid_reason
FROM dev_ppi.concept c
LEFT JOIN concept_relationship cr on c.concept_id = cr.concept_id_1
LEFT JOIN concept c2 on cr.concept_id_2 = c2.concept_id
where
     c.concept_code = 'mhwb'
and cr.relationship_id = 'PPI parent code of'

UNION

SELECT
   c3.concept_name,
   c3.domain_id,
   c3.vocabulary_id,
   c3.concept_class_id,
   null as standard_concept,
   c3.concept_code,
   c3.valid_start_date,
   current_date as valid_end_date,
   'D' as invalid_reason
FROM dev_ppi.concept c
LEFT JOIN concept_relationship cr on c.concept_id = cr.concept_id_1
LEFT JOIN concept_relationship cr2 on cr.concept_id_2 = cr2.concept_id_1
LEFT JOIN concept c3 on cr2.concept_id_2 = c3.concept_id
where
c.concept_code = 'mhwb'
and cr.relationship_id = 'PPI parent code of'
and cr2.relationship_id = 'PPI parent code of'

UNION

SELECT
   c4.concept_name,
   c4.domain_id,
   c4.vocabulary_id,
   c4.concept_class_id,
   null as standard_concept,
   c4.concept_code,
   c4.valid_start_date,
   current_date as valid_end_date,
   'D' as invalid_reason
FROM dev_ppi.concept c
LEFT JOIN concept_relationship cr on c.concept_id = cr.concept_id_1
LEFT JOIN concept_relationship cr2 on cr.concept_id_2 = cr2.concept_id_1
LEFT JOIN concept_relationship cr3 on cr2.concept_id_2 = cr3.concept_id_1
LEFT JOIN concept c4 on cr3.concept_id_2 = c4.concept_id
where
c.concept_code = 'mhwb'
and cr.relationship_id = 'PPI parent code of'
and cr2.relationship_id = 'PPI parent code of'
and cr3.relationship_id in ('Has answer (PPI)', 'Has question source'));

-- deprecate previous Mental Health and Well-Being Module relationships
INSERT INTO dev_ppi.concept_relationship_manual (
SELECT c.concept_code,
       c1.concept_code,
       c.vocabulary_id,
       c1.vocabulary_id,
       cr.relationship_id,
       cr.valid_start_date,
       current_date as valid_end_date,
       'D' as invalid_reason
FROM concept c
LEFT JOIN concept_relationship cr on c.concept_id = cr.concept_id_1
LEFT JOIN concept c1 on cr.concept_id_2 = c1.concept_id
WHERE c.concept_code in (SELECT concept_code FROM concept_manual)
AND cr.relationship_id not in ('Question source of', 'Mapped from', 'Answer of (PPI)', 'PPI parent code of'));

--insert new concepts into concept_manual
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
--where lower(question_code) not in (select lower(concept_code) from concept_manual) ;

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
--where lower(question_code) not in (select lower(concept_code) from concept_manual) ;

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

--insert questions-answers relationships into concept_relationship_manual
--bhp
/*--to add hierarchy 'PPI parent code of' from Questions to Answers
INSERT INTO concept_relationship_manual
SELECT DISTINCT
question_code as concept_code_1,
answer_code as concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM bhp_pr
;*/

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

/*--to add hierarchy 'PPI parent code of' from Module to Questions
INSERT INTO concept_relationship_manual
SELECT DISTINCT
'bhp' AS concept_code_1,
question_code AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM bhp_pr
;*/

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

/*--add hierarchy 'Answer of (PPI)' from Answers to Questions
INSERT INTO concept_relationship_manual
SELECT DISTINCT
answer_code AS concept_code_1,
question_code AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Answer of (PPI)' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM bhp_pr
;*/

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

--insert questions-answers relationships into concept_relationship_manual
--ehh
/*--to add hierarchy 'PPI parent code of' from Questions to Answers
INSERT INTO concept_relationship_manual
SELECT DISTINCT
question_code as concept_code_1,
answer_code as concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM ehh_pr
;*/

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

/*--to add hierarchy 'PPI parent code of' from Module to Questions
INSERT INTO concept_relationship_manual
SELECT DISTINCT
'bhp' AS concept_code_1,
question_code AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM ehh_pr
;*/

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

/*--add hierarchy 'Answer of (PPI)' from Answers to Questions
INSERT INTO concept_relationship_manual
SELECT DISTINCT
answer_code AS concept_code_1,
question_code AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Answer of (PPI)' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM ehh_pr
;*/

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

SELECT * FROM dev_ppi.concept_manual; -- 1002 --237 D
SELECT * FROM concept_relationship_manual; -- 2437 1057 D









