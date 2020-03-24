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
* license required
* Authors: Medical Team
* Date: March 2020
**************************************************************************/

--load stage
--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CAP',
	pVocabularyDate			=> to_date('20200226', 'yyyymmdd'), -- here i put the date  of appropriate  version Aug'19  - 20190828; Feb'20  - 20200226
	pVocabularyVersion		=> 'CAP eCC release, Feb 2020', --Aug 2019 -- Feb 2020
	pVocabularyDevSchema	=> 'DEV_CAP'
);
END $_$;


--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--Load into concept stage
INSERT INTO dev_cap.CONCEPT_STAGE (
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason
                           )
                           SELECT
                                  alternative_concept_name,
                                  domain_id,
                                  vocabulary_id,
                                  concept_class_id,
                                  standard_concept,
                                  concept_code,
                                  valid_start_date::date,
                                  valid_end_date::date,
                                  invalid_reason
FROM dev_cap.cap_breast_2020_concept_stage_preliminary -- here put  name of the prepared for insertion source_table
;

--  Load into CONCEPT_SYNONYM_STAGE
INSERT INTO dev_cap.CONCEPT_synonym_stage ( synonym_name,
                                           synonym_concept_code,
                                           synonym_vocabulary_id,
                                           language_concept_id)
SELECT
                               concept_name,
                               concept_code,
                               vocabulary_id,
                               4180186 as language_concept_id  -- for english language
FROM dev_cap.cap_breast_2020_concept_stage_preliminary -- here put  name of the prepared for insertion source_table
;


-- 02 concept_relationship_stage
-- Load into concept_relationship_stage
INSERT INTO dev_cap.concept_relationship_stage
(concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason)

        SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'CAP value of'                                                   AS relationship_id,
                '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-12-31'                AS valid_end_date,
               null as                                                invalid_reason
        FROM dev_cap.ecc_202002 e -- put name the initial source_table with levels_of_separation (originated from xml file)
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs -- here put  name of the prepared for insertion source_table
                      ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2 -- here put  name of the prepared for insertion source_table
                      ON e.variable_code = cs2.concept_code
        WHERE e.filename ~* 'breast'
          AND e.level_of_separation = 1
          AND cs.concept_class_id = 'CAP Value'
          AND cs2.concept_class_id = 'CAP Variable'
    ;

 -- STEP 1'Has CAP parent item' INSERT
INSERT INTO dev_cap.concept_relationship_stage
(concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason)
SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Has CAP parent item'                                                   AS relationship_id,
                '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-12-31'                AS valid_end_date,
               null as                                                invalid_reason
        FROM dev_cap.ecc_202002 e -- put name the initial source_table with levels_of_separation (originated from xml file)
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs -- here put  name of the prepared for insertion source_table
                      ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2 -- here put  name of the prepared for insertion source_table
                      ON e.variable_code = cs2.concept_code
        WHERE e.filename ~* 'breast'
          AND e.level_of_separation = 1
          AND cs.concept_class_id = 'CAP Variable'
          AND cs2.concept_class_id = 'CAP Variable'
AND cs.concept_code  NOT in (select concept_code_1 FROM concept_relationship_stage)
AND cs2.concept_code  NOT in (select concept_code_2 FROM concept_relationship_stage);
;
-- STEP 2'Has CAP parent item' INSERT
INSERT INTO dev_cap.concept_relationship_stage
(concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason)
SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Has CAP parent item'                                                   AS relationship_id,
                '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-12-31'                AS valid_end_date,
               null as                                                invalid_reason
        FROM dev_cap.ecc_202002 e -- put name the initial source_table with levels_of_separation (originated from xml file)
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs -- here put  name of the prepared for insertion source_table
                      ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2 -- here put  name of the prepared for insertion source_table
                      ON e.variable_code = cs2.concept_code
        WHERE e.filename ~* 'breast'
          AND e.level_of_separation = 1
          AND cs.concept_class_id = 'CAP Variable'
          AND cs2.concept_class_id = 'CAP Header'
AND NOT EXISTS (select 1
                FROM concept_relationship_stage cr1
    WHERE cr1.concept_code_1=cs.concept_code
    AND cr1.concept_code_2=cs2.concept_code)
;

--STEP 3'Has CAP parent item' INSERT
INSERT INTO dev_cap.concept_relationship_stage
(concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason)
SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Has CAP parent item'                                                   AS relationship_id,
                '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-12-31'                AS valid_end_date,
               null as                                                invalid_reason
        FROM dev_cap.ecc_202002 e -- put name the initial source_table with levels_of_separation (originated from xml file)
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs -- here put  name of the prepared for insertion source_table
                 ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2 -- here put  name of the prepared for insertion source_table
                 ON e.variable_code = cs2.concept_code
        WHERE e.filename ~* 'breast'
        AND e.level_of_separation = 1
        AND cs.concept_class_id = 'CAP Variable'
        AND cs2.concept_class_id = 'CAP Value'
AND NOT EXISTS (select 1
                FROM concept_relationship_stage cr1
    WHERE cr1.concept_code_1=cs.concept_code
    AND cr1.concept_code_2=cs2.concept_code)
;

--STEP 4 'Has CAP parent item' INSERT
INSERT INTO dev_cap.concept_relationship_stage
(concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason)
SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Has CAP parent item'                                                   AS relationship_id,
                '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-12-31'                AS valid_end_date,
               null as                                                invalid_reason
        FROM dev_cap.ecc_202002 e -- put name the initial source_table with levels_of_separation (originated from xml file)  or dev_cap. ecc_202002 or ddymshyts. ecc_201909_v3
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs -- here put  name of the prepared for insertion source_table
                 ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2 -- here put  name of the prepared for insertion source_table
                 ON e.variable_code = cs2.concept_code
        WHERE e.filename ~* 'breast'
          AND e.level_of_separation = 1
          AND cs.concept_class_id = 'CAP Header'
          AND cs2.concept_class_id = 'CAP Value'
AND NOT EXISTS (select 1
                FROM concept_relationship_stage cr1
    WHERE cr1.concept_code_1=cs.concept_code
    AND cr1.concept_code_2=cs2.concept_code)

;

--STEP 5'Has CAP parent item' INSERT
INSERT INTO dev_cap.concept_relationship_stage
(concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason)
SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Has CAP parent item'                                                   AS relationship_id,
                '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-12-31'                AS valid_end_date,
               null as                                                invalid_reason
        FROM dev_cap.ecc_202002 e -- put name the initial source_table with levels_of_separation (originated from xml file)
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs -- here put  name of the prepared for insertion source_table
                      ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2 -- here put  name of the prepared for insertion source_table
                      ON e.variable_code = cs2.concept_code
        WHERE e.filename ~* 'breast'
          AND e.level_of_separation = 1
         AND cs.concept_class_id in ( 'CAP Variable', 'CAP Header')
        AND NOT EXISTS (select 1
                FROM concept_relationship_stage cr1
    WHERE cr1.concept_code_1=cs.concept_code
    AND cr1.concept_code_2=cs2.concept_code);
;

-- 'Has CAP protocol'
INSERT INTO dev_cap.concept_relationship_stage
(concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason)
SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Has CAP protocol'                                                   AS relationship_id,
               to_date('19700101'  ,  'yyyymmdd'   )       AS valid_start_date, -- AT LEAST FOR NOW
               to_date('20991231'  ,  'yyyymmdd'   )                 AS valid_end_date,
               null as                                                invalid_reason
FROM  dev_cap.cap_breast_2020_concept_stage_preliminary cs -- here put  name of the prepared for insertion source_table
LEFT JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2 -- here put  name of the prepared for insertion source_table
ON cs2.concept_code~*'DCIS.*Res'
WHERE cs.source_filename~*'DCIS.*Res'

UNION ALL

SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Has CAP protocol'                                                   AS relationship_id,
               to_date('19700101'  ,  'yyyymmdd'   )             AS valid_start_date, -- AT LEAST FOR NOW
               to_date('20991231'    ,  'yyyymmdd'   )                 AS valid_end_date,
               null as                                                invalid_reason
FROM  dev_cap.cap_breast_2020_concept_stage_preliminary cs -- here put  name of the prepared for insertion source_table
LEFT JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2 -- here put  name of the prepared for insertion source_table
ON cs2.concept_code~* 'DCIS.*Bx'
WHERE cs.source_filename  ~*'DCIS.*Bx'

UNION ALL

SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Has CAP protocol'                                                   AS relationship_id,
               to_date('19700101'  ,  'yyyymmdd'   )               AS valid_start_date, -- AT LEAST FOR NOW
               to_date('20991231'    ,  'yyyymmdd'   )                 AS valid_end_date,
               null as                                                invalid_reason
FROM  dev_cap.cap_breast_2020_concept_stage_preliminary cs -- here put  name of the prepared for insertion source_table
LEFT JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2 -- here put  name of the prepared for insertion source_table
ON cs2.concept_code~*'Breast.*Invasive.*Bx'
WHERE cs.source_filename ~*'Breast.*Invasive.*Bx'

UNION ALL

SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Has CAP protocol'                                                   AS relationship_id,
             to_date('19700101'  ,  'yyyymmdd'   )             AS valid_start_date, -- AT LEAST FOR NOW
             to_date('20991231'    ,  'yyyymmdd'   )                 AS valid_end_date,
               null as                                                invalid_reason
FROM  dev_cap.cap_breast_2020_concept_stage_preliminary cs -- here put  name of the prepared for insertion source_table
LEFT JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2 -- here put  name of the prepared for insertion source_table
ON cs2.concept_code~*'Breast.*Invasive.*Res'
WHERE cs.source_filename ~*'Breast.*Invasive.*Res'

UNION ALL

SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Has CAP protocol'                                                   AS relationship_id,
             to_date('19700101'  ,  'yyyymmdd'   )        AS valid_start_date, -- AT LEAST FOR NOW
             to_date('20991231'    ,  'yyyymmdd'   )                   AS valid_end_date,
               null as                                                invalid_reason
FROM  dev_cap.cap_breast_2020_concept_stage_preliminary cs -- here put  name of the prepared for insertion source_table
LEFT JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2 -- here put  name of the prepared for insertion source_table
ON cs2.concept_code~*'Breast.*Bmk'
WHERE cs.source_filename~*'Breast.*Bmk'
;
--QA for stage tables
--all the selects below should return null

select relationship_id from concept_relationship_stage
except
select relationship_id from relationship;


select concept_class_id from concept_stage
except
select concept_class_id from concept_class;


select domain_id from concept_stage
except
select domain_id from domain;


select vocabulary_id from concept_stage
except
select vocabulary_id from vocabulary;


select * from concept_stage where concept_name is null or domain_id is null or concept_class_id is null or concept_code is null or valid_start_date is null or valid_end_date is null
or valid_end_date is null or concept_name<>trim(concept_name) or concept_code<>trim(concept_code);

select concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id  from concept_relationship_stage
group by concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id  having count(*)>1;

select concept_code, vocabulary_id  from concept_stage
group by concept_code, vocabulary_id  having count(*)>1;


select * From concept_relationship_stage where valid_start_date is null or valid_end_date is null or (invalid_reason is null and valid_end_date<>to_date ('20991231', 'yyyymmdd'))
or (invalid_reason is not null and valid_end_date=to_date ('20991231', 'yyyymmdd'));

select * from concept_stage where valid_start_date is null or valid_end_date is null
or (invalid_reason is null and valid_end_date::date <> to_date ('20991231', 'yyyymmdd') and vocabulary_id not in ('CPT4', 'HCPCS', 'ICD9Proc'))
or (invalid_reason is not null and valid_end_date::date = to_date ('20991231', 'yyyymmdd'))
or valid_start_date::date < to_date ('19000101', 'yyyymmdd'); -- some concepts have a real date < 1970
;



select * from concept_stage where concept_name is null or domain_id is null or concept_class_id is null or concept_code is null or valid_start_date is null or valid_end_date is null
or valid_end_date is null or concept_name<>trim(concept_name) or concept_code<>trim(concept_code);

select concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id  from concept_relationship_stage
group by concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id  having count(*)>1;

select concept_code, vocabulary_id  from concept_stage
group by concept_code, vocabulary_id  having count(*)>1;



SELECT crm.*
FROM concept_relationship_stage crm
	 LEFT JOIN concept c1 ON c1.concept_code = crm.concept_code_1 AND c1.vocabulary_id = crm.vocabulary_id_1
	 LEFT JOIN concept_stage cs1 ON cs1.concept_code = crm.concept_code_1 AND cs1.vocabulary_id = crm.vocabulary_id_1
	 LEFT JOIN concept c2 ON c2.concept_code = crm.concept_code_2 AND c2.vocabulary_id = crm.vocabulary_id_2
	 LEFT JOIN concept_stage cs2 ON cs2.concept_code = crm.concept_code_2 AND cs2.vocabulary_id = crm.vocabulary_id_2
	 LEFT JOIN vocabulary v1 ON v1.vocabulary_id = crm.vocabulary_id_1
	 LEFT JOIN vocabulary v2 ON v2.vocabulary_id = crm.vocabulary_id_2
	 LEFT JOIN relationship rl ON rl.relationship_id = crm.relationship_id
WHERE    (c1.concept_code IS NULL AND cs1.concept_code IS NULL)
	 OR (c2.concept_code IS NULL AND cs2.concept_code IS NULL)
	 OR v1.vocabulary_id IS NULL
	 OR v2.vocabulary_id IS NULL
	 OR rl.relationship_id IS NULL
	 OR crm.valid_start_date::date > CURRENT_DATE
	 OR crm.valid_end_date::date < crm.valid_start_date::date;

-- generic update()
select dev_cap.genericupdate() -- custom version with 3.1  modification ( When CAP then 1)
;

SELECT qa_tests.purge_cache();

--checks after generic
SELECT  qa_tests.get_checks ();

SELECT *
FROM  qa_tests.get_summary ('concept');

SELECT *
FROM  qa_tests.get_summary ('concept')
WHERE vocabulary_id_1='CAP';

SELECT *
FROM qa_tests.get_summary ('concept_relationship');

SELECT *
FROM qa_tests.get_summary ('concept_relationship')
WHERE vocabulary_id_1='CAP'
OR  vocabulary_id_2='CAP'
;

SELECT qa_tests.get_domain_changes();
SELECT	qa_tests.get_newly_concepts();
SELECT qa_tests.get_standard_concept_changes();
SELECT qa_tests.get_newly_concepts_standard_concept_status();

