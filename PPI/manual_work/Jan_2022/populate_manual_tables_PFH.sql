--Insert into concept_manual and concept_relationship_manual

--====================================
-- concept_manual
--====================================
-- Use current_date for valid_start_date, always show date format after valid_end_date e.g. 'yyyymmmdd'
-- In case if you need to insert more, than one concept use select from mapped_table 
-- It's convenient to use case for Answer| Question | Topic|Module concept_class_id

TRUNCATE concept_manual ;
--to add all concepts
INSERT INTO concept_manual
SELECT DISTINCT
question_name AS concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Question' AS concept_class_id,
'S' as source_standard_concept,
coalesce(c.concept_code, question_code) as concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason 
from ppi_pfh_c a 
left join concept c on lower(a.question_code) = lower(c.concept_code)
where c.vocabulary_id = 'PPI'; --577

--to add rest of concepts
INSERT INTO concept_manual 
SELECT DISTINCT
question_name AS concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
CASE WHEN question_code = 'personalfamilyhistory' THEN 'Module' ELSE 'Question' END AS concept_class_id,
'S' as source_standard_concept,
question_code as concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason 
from ppi_pfh_c a 
where lower(question_code) not in (select lower(concept_code) from concept_manual) ; --128

--to add new answer names
INSERT INTO concept_manual
SELECT DISTINCT
source_name AS concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Answer' AS concept_class_id,
null AS source_standard_concept,
source_code AS concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
from ppi_pfh_all_answ
where source_code !~* '^PMI'; --2460 --PMI??

--to add new PPI concepts
INSERT INTO concept_manual
SELECT DISTINCT
concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Answer' AS concept_class_id,
'S' as source_standard_concept,
concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
from  ppi_pfh_all_answ 
where concept_code ~* 'PPI' ; --7

--====================================
-- concept_relationship_manual
--====================================
--comments:

-- Reverse relationships are built by generic 
-- Please look at 'PPI conventions'  when work on relationships
-- Use "PPI parent code of" between Module-Topic, Topic-Question, Question-Answer (check PPI conventions)
-- We build hierarchial relationship 'Is a' only for old-logic concepts, for new-logic we use only "Has PPI parent code","Has answer (PPI)", "Maps to" and reverse relationships


-- Has answer (PPI) | Has PPI parent code
-- Maps to -- for mapping to itself
TRUNCATE concept_relationship_manual ;
--to add mapping to crm
INSERT INTO concept_relationship_manual
SELECT DISTINCT
source_code AS concept_code_1,
coalesce(d.concept_code, a.concept_code) AS concept_code_2,
'PPI' AS vocabulary_id_1,
coalesce(vocabulary_id,'PPI') AS vocabulary_id_2,
relationship_id,
CURRENT_DATE AS valid_start_date, 
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM ppi_pfh_all_answ a
left join concept d on lower(a.concept_code) = lower(d.concept_code)
and d.vocabulary_id in (null, 'LOINC', 'SNOMED', 'PPI', 'OMOP Extension') 
where source_code !~* 'PMI'; --4920

--to add hierarchy for 5 new concepts
INSERT INTO concept_relationship_manual
SELECT DISTINCT
concept_code AS concept_code_1,
CASE WHEN concept_code = 'PPI1' THEN '90708001'
     WHEN concept_code = 'PPI2' THEN '90708001'
     WHEN concept_code = 'PPI3' THEN '14350001000004108'
     WHEN concept_code = 'PPI4' THEN '27550009'
     WHEN concept_code = 'PPI5' THEN '118934005' 
     WHEN concept_code = 'PPI6' THEN '372087000'
     WHEN concept_code = 'PPI7' THEN '78048006' END
     AS concept_code_2,
'PPI' AS vocabulary_id_1,
'SNOMED' AS vocabulary_id_2,
'Is a' AS relationship_id,
CURRENT_DATE AS valid_start_date, 
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
from  ppi_pfh_all_answ 
where concept_code ~* 'PPI'
and concept_code !~* 'PPI8' ;  --7

--to addadditional hierarchy for 2 new concepts
INSERT INTO concept_relationship_manual 
SELECT DISTINCT
concept_code AS concept_code_1,
CASE WHEN concept_code = 'PPI2' THEN '105502003'
     WHEN concept_code = 'PPI7' THEN '58184002' END
     AS concept_code_2,
'PPI' AS vocabulary_id_1,
'SNOMED' AS vocabulary_id_2,
'Is a' AS relationship_id,
CURRENT_DATE AS valid_start_date, 
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
from  ppi_pfh_all_answ 
where concept_code ~* 'PPI2|PPI7' ;--2

--add hierarchy 'Answer of (PPI)' from Answers to Questions
INSERT INTO concept_relationship_manual
SELECT DISTINCT
coalesce(c.concept_code,answer_code) AS concept_code_1,
coalesce(c1.concept_code,question_code) AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Answer of (PPI)' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM ppi_pfh_c a 
left join concept c on lower(a.answer_code) = lower(c.concept_code) and c.vocabulary_id = 'PPI'
left join concept c1 on lower(a.question_code) = lower(c1.concept_code) and c1.vocabulary_id = 'PPI' 
where answer_code is not null 
and answer_code !~* '^PMI' ; --2460

--to add hierarchy 'PPI parent code of' from Questions to Answers
INSERT INTO concept_relationship_manual
SELECT DISTINCT
coalesce(c1.concept_code,question_code) AS concept_code_1,
coalesce(c.concept_code,answer_code) AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM ppi_pfh_c a
left join concept c on lower(a.answer_code) = lower(c.concept_code) and c.vocabulary_id = 'PPI'
left join concept c1 on lower(a.question_code) = lower(c1.concept_code) and c1.vocabulary_id = 'PPI'
where answer_code is not null 
and answer_code !~* '^PMI'; --2460

--to add hierarchy 'PPI parent code of' from Module to Questions
INSERT INTO concept_relationship_manual
SELECT DISTINCT
'personalfamilyhistory' AS concept_code_1,
coalesce(c.concept_code, trim(question_code)) AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM ppi_pfh_c a
left join concept c on lower(a.question_code) = lower(c.concept_code) and c.vocabulary_id = 'PPI' ; --705

--to add hierarchy from Answers to branched Questions
INSERT INTO concept_relationship_manual
with t2 as (
with t1 as (
SELECT *,
trim(split_part(split_part(branching_logic, '(', 1), '[', 2)) AS concept_code_1,
trim(variable_field_name) AS concept_code_2 FROM ppi_pfh_wt
where branching_logic != '')
select coalesce(c.short_code, t1.concept_code_1) AS concept_code_1,
       coalesce(d.short_code, t1.concept_code_2) AS concept_code_2  --better to trim
FROM t1
left join ppi_long_short_code c on lower(t1.concept_code_1) = lower(c.source_code)
left join ppi_long_short_code d on lower(t1.concept_code_2) = lower(d.source_code))
select coalesce(e.concept_code, t2.concept_code_1) AS concept_code_1,
       coalesce(e1.concept_code, concept_code_2) AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
from t2
left join concept e on lower(t2.concept_code_1) = lower(e.concept_code) and e.vocabulary_id = 'PPI'
left join concept e1 on lower(t2.concept_code_2) = lower(e1.concept_code) and e1.vocabulary_id = 'PPI' ; --691

--lookup to check yourself 
select distinct a.concept_code as concept_code_1,a.concept_name as concept_name_1,a.domain_id as domain_id_1,a.concept_class_id as concept_class_id_1,a.standard_concept as standard_concept_1, 
relationship_id, b.concept_code as concept_code_2,b.concept_name as concept_name_2,b.domain_id as domain_id_2,b.concept_class_id as concept_class_id_2,b.standard_concept as standard_concept_2, 'pfh' as flag from concept_manual a
join concept_relationship_manual r on a.concept_code = r.concept_Code_1 and a.vocabulary_id = r.vocabulary_id_1 and r.invalid_reason is null
join (select concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason from concept 
union all select * from concept_manual) b on b.concept_code = r.concept_Code_2 and b.vocabulary_id = r.vocabulary_id_2 )
