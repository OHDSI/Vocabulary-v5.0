--Insert into concept_manual and concept_relationship_manual

--====================================
-- concept_manual
--====================================
-- Use current_date for valid_start_date, always show date format after valid_end_date e.g. 'yyyymmmdd'
-- In case if you need to insert more, than one concept use select from mapped_table 
-- It's convenient to use case for Answer| Question | Topic|Module concept_class_id

--TRUNCATE concept_manual ;
--to add all sources to cm
INSERT INTO concept_manual
SELECT DISTINCT
TRIM(source_name) AS concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
CASE WHEN mark = 'a' THEN 'Answer'
     WHEN mark = 'q' THEN 'Question' 
     WHEN mark = 'm' THEN 'Module' END AS concept_class_id,
CASE WHEN standard_concept = 'S' THEN NULL
     WHEN standard_concept IS NULL THEN 'S' END as source_standard_concept,
source_code AS concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
--'wms' as flag -- Winter Medical Survey
FROM ppi_wms_1121_mapped
where lower(source_code) not in (select lower(concept_code) from concept
where vocabulary_id = 'PPI' );
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
--TRUNCATE concept_relationship_manual ;

--add answers mapping to crm
INSERT INTO concept_relationship_manual
SELECT DISTINCT
source_code AS concept_code_1,
concept_code AS concept_code_2,
'PPI' AS vocabulary_id_1,
vocabulary_id AS vocabulary_id_2,
case when concept_id !=0 then 'Maps to' 
     when concept_id =0 then null end AS relationship_id,
CURRENT_DATE AS valid_start_date, 
valid_end_date,
invalid_reason
FROM ppi_wms_1121_mapped
where mark = 'a'
and concept_id !=0  ; --2

--add hierarchy 'Answer of (PPI)' from Answers to Questions
INSERT INTO concept_relationship_manual
SELECT DISTINCT
lower(answer_code) AS concept_code_1, --should be in lower
question_code AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Answer of (PPI)' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM wms 
where answer_code is not null ; --550

--add hierarchy 'PPI parent code of' from Questions to Answers
INSERT INTO concept_relationship_manual
SELECT DISTINCT
question_code AS concept_code_1,
lower(answer_code) AS concept_code_2, --should be in lower case
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM wms
where answer_code is not null ; --550

--add hierarchy 'PPI parent code of' from Module to Questions
INSERT INTO concept_relationship_manual
SELECT DISTINCT
'cope_vaccine3' AS concept_code_1,
trim(source_code) AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM ppi_wms_1121_mapped a 
where mark = 'q' ; --141

--cdc_covid_xx_b_dose10 PARENT OF cdc_covid_xx_b_dose10_other
INSERT INTO concept_relationship_manual
SELECT DISTINCT
sc1 AS concept_code_1,
trim(sc2) AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select a.source_code as sc1, a.source_name as sn1, b.source_code as sc2, b.source_name as sn2, a.mark from ppi_wms_1121_mapped a
join (select source_code, source_name, regexp_replace(source_code, '_other', '') as sc from ppi_wms_1121_mapped  where source_code ~* 'cdc_covid_xx_b_' 
and source_code ~* 'other' ) b on a.source_code = b.sc
where a.source_code ~* 'cdc_covid_xx_b_' 
and a.source_code !~* 'other') as t1
where mark = 'q' ; --17

--cdc_covid_xx_dose9 PARENT OF cdc_covid_xx_a_date9
INSERT INTO concept_relationship_manual
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, regexp_replace(split_part(branching_logic, ']', 1), '\[', '') as brl from ppi_wms_1121
where variable_field_name ~* 'cdc_covid_xx_a_date' ) as t1 ;--17

--cdc_covid_xx_dose10 PARENT OF cdc_covid_xx_b_dose10
INSERT INTO concept_relationship_manual
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, regexp_replace(split_part(branching_logic, ']', 1), '\[', '') as brl from ppi_wms_1121
where variable_field_name ~* 'cdc_covid_xx_b' and  variable_field_name !~* 'other') as t1 ; --17

--cdc_covid_xx_dose9 PARENT OF cdc_covid_xx_dose10
INSERT INTO concept_relationship_manual
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, regexp_replace(split_part(branching_logic, ']', 1), '\[', '') as brl from ppi_wms_1121
where variable_field_name ~* 'cdc_covid_xx_dose') as t1
where t1.brl != 'cdc_covid_xx_b_firstdose' ; --14

--cdc_covid_xx_dose10 PARENT OF cdc_covid_xx_symptom_dose10
INSERT INTO concept_relationship_manual
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, regexp_replace(split_part(branching_logic, ']', 1), '\[', '') as brl from ppi_wms_1121
where variable_field_name ~* 'cdc_covid_xx_symptom_dose') as t1 ; --15

--cdc_covid_xx_dose10 PARENT OF cdc_covid_xx_type_dose10
INSERT INTO concept_relationship_manual
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, regexp_replace(split_part(branching_logic, ']', 1), '\[', '') as brl from ppi_wms_1121
where variable_field_name ~* 'cdc_covid_xx_type' and variable_field_name !~* 'other') as t1 ; --15

--cdc_covid_xx_symptom_dose10 PARENT OF cdc_covid_xx_symptom_cope_350_dose10
INSERT INTO concept_relationship_manual
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, 
regexp_replace(regexp_replace(split_part(branching_logic, ']', 1), '\[', ''), '\(cope_a_350\)', '') as brl from ppi_wms_1121
where variable_field_name ~* 'cdc_covid_xx_symptom_cope_350_dose') as t1 ; --15

--cdc_covid_xx_type_dose10 PARENT OF cdc_covid_xx_type_dose10_other
INSERT INTO concept_relationship_manual
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, 
regexp_replace(split_part(branching_logic, ']', 1), '\[', '') as brl from ppi_wms_1121
where variable_field_name ~* 'cdc_covid_xx_type_dose' and variable_field_name ~* 'other') as t1 ; --15

--dmfs_29 PARENT OF dmfs_29_additionaldose_other
INSERT INTO concept_relationship_manual 
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, 
regexp_replace(regexp_replace(split_part(branching_logic, ']', 1), '\[', ''), '\(COPE_A_204\)', '') as brl from ppi_wms_1121
where variable_field_name ~* 'dmfs_29') as t1
where brl ~* 'dmfs_29' ; --3

--cdc_covid_xx_firstdose PARENT OF cdc_covid_xx_symptom
INSERT INTO concept_relationship_manual 
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, regexp_replace(split_part(branching_logic, ']', 1), '\[', '') as brl from ppi_wms_1121
where variable_field_name ~* 'cdc_covid_xx_symptom$') as t1 ; --1

--cdc_covid_xx_seconddose PARENT OF cdc_covid_xx_symptom_seconddose
--cdc_covid_xx_symptom_seconddose PARENT OF cdc_covid_xx_symptom_seconddose_cope_350
INSERT INTO concept_relationship_manual 
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, 
regexp_replace(regexp_replace(split_part(branching_logic, ']', 1), '\[', ''), '\(cope_a_350\)', '') as brl from ppi_wms_1121
where variable_field_name ~* 'cdc_covid_xx_symptom_seconddose') as t1 ; --2

--cdc_covid_xx_symptom(cope_a_350) PARENT OF cdc_covid_xx_symptom_cope_350
INSERT INTO concept_relationship_manual 
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, 
regexp_replace(regexp_replace(split_part(branching_logic, ']', 1), '\[', ''), '\(cope_a_350\)', '') as brl from ppi_wms_1121
where variable_field_name ~* 'cdc_covid_xx_symptom_cope_350$') as t1 ; --1

--cdc_covid_xx_b_firstdose PARENT OF cdc_covid_xx_seconddose
INSERT INTO concept_relationship_manual 
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, regexp_replace(split_part(branching_logic, ']', 1), '\[', '') as brl from ppi_wms_1121
where variable_field_name ~* 'cdc_covid_xx_seconddose') as t1 ; --1
--
--cdc_covid_xx_dose3 PARENT OF dmfs_xx_1_additionaldose
INSERT INTO concept_relationship_manual 
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, regexp_replace(split_part(branching_logic, ']', 1), '\[', '') as brl from ppi_wms_1121
where variable_field_name ~* 'dmfs_xx_1_additionaldose') as t1 ; --1

--cdc_covid_xx_firstdose PARENT OF dmfs_xx_1
INSERT INTO concept_relationship_manual
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, regexp_replace(split_part(branching_logic, ']', 1), '\[', '') as brl from ppi_wms_1121
where variable_field_name ~* 'dmfs_xx_1$') as t1 ; --1

--dmfs_xx_1_additionaldose PARENT OF  dmfs_29_additionaldose
INSERT INTO concept_relationship_manual
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, regexp_replace(split_part(branching_logic, ']', 1), '\[', '') as brl from ppi_wms_1121
where variable_field_name ~* 'dmfs_29_additionaldose$') as t1 ;--1

--dmfs_xx_1_seconddose PARENT OF dmfs_29_seconddose
INSERT INTO concept_relationship_manual 
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, regexp_replace(split_part(branching_logic, ']', 1), '\[', '') as brl from ppi_wms_1121
where variable_field_name ~* 'dmfs_29_seconddose$') as t1 ; --1

--dmfs_xx_1 PARENT OF dmfs_29
INSERT INTO concept_relationship_manual ;
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, regexp_replace(split_part(branching_logic, ']', 1), '\[', '') as brl from ppi_wms_1121
where variable_field_name ~* 'dmfs_29$') as t1 ; --1

--cdc_covid_xx_b_firstdose PARENT OF cdc_covid_xx_dose3
--cdc_covid_xx_b_seconddose PARENT OF cdc_covid_xx_dose3
INSERT INTO concept_relationship_manual 
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, 
regexp_replace(regexp_replace(split_part(regexp_split_to_table(branching_logic, ' or '), ']', 1), '\[', ''), '\(', '') as brl from ppi_wms_1121
where variable_field_name ~* 'cdc_covid_xx_dose3') as t1 ;

--cdc_covid_xx_b_firstdose PARENT OF dmfs_xx_1_seconddose
--cdc_covid_xx_seconddose PARENT OF dmfs_xx_1_seconddose
INSERT INTO concept_relationship_manual 
SELECT DISTINCT
brl AS concept_code_1,
sc AS concept_code_2, --better to trim
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'PPI parent code of' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM (select variable_field_name as sc, field_label as sn, branching_logic, 
regexp_replace(regexp_replace(split_part(regexp_split_to_table(branching_logic, ' or '), ']', 1), '\[', ''), '\(', '') as brl from ppi_wms_1121
where variable_field_name ~* 'dmfs_xx_1_seconddose') as t1 ; --2

--lookup to check yourself 
select distinct a.concept_code as concept_code_1,a.concept_name as concept_name_1,a.domain_id as domain_id_1,a.concept_class_id as concept_class_id_1,a.standard_concept as standard_concept_1, 
relationship_id, b.concept_code as concept_code_2,b.concept_name as concept_name_2,b.domain_id as domain_id_2,b.concept_class_id as concept_class_id_2,b.standard_concept as standard_concept_2, 'wms' as flag from concept_manual a
join concept_relationship_manual r on a.concept_code = r.concept_Code_1 and a.vocabulary_id = r.vocabulary_id_1 and r.invalid_reason is null
join (select concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason from concept 
union all select * from concept_manual) b on b.concept_code = r.concept_Code_2 and b.vocabulary_id = r.vocabulary_id_2 )
