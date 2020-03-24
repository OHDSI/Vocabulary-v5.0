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
* license required = Yes
*
* Authors: Medical Team
* Date: March 2020
**************************************************************************/

--load stage
--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CAP',
	pVocabularyDate			=> to_date('20200226', 'yyyymmdd'), -- here i put the date version of first version Aug 2019 20190828; Feb 2020 20200226
	pVocabularyVersion		=> 'CAP eCC release, Feb 2020', --
	pVocabularyDevSchema	=> 'DEV_CAP'
);
END $_$;


--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

-- Load into concept_stage from cap_breast_2019_concept_stage_preliminary
DROP TABLE IF EXISTS dev_cap.cap_breast_2019_concept_stage_preliminary
CREATE UNLOGGED TABLE dev_cap.cap_breast_2019_concept_stage_preliminary WITH OIDS AS
    (
        SELECT NULL                        AS concept_id,
               source_code                 AS concept_code,
               source_description          AS concept_name,
               alt_source_description AS alternative_concept_name,
     CASE
         WHEN source_class ='CAP Protocol'       or    (source_class='S'       AND source_description !~*'^Distance')  THEN 'Observation' -- todo How to treat 'CAP Protocol' in domain_id?
         WHEN source_class = 'LI' /*AND source_description !~* '^\.*other|^\.*specif.*'*/ THEN  'Meas Value' --decided to leave them as values
         ELSE 'Measurement'
         END                               AS domain_id,
               'CAP'                       AS vocabulary_id,
     CASE
         WHEN source_class = 'S'    AND source_description !~*'^Distance'                                     THEN 'CAP Header' -- or 'CAP section'
         WHEN source_class = 'LI' /*AND source_description !~* '^\.*other|^\.*specif.*'*/  THEN 'CAP Value' -- ^.*expla.* todo do we need them to be variables, decided to leave them as values
         WHEN source_class = 'CAP Protocol'                              THEN 'CAP Protocol'
         ELSE 'CAP Variable'
         END                               AS concept_class_id,
               NULL                        AS standard_concept,
               NULL                        AS invalid_reason,
               '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-12-31'                AS valid_end_date,
               source_filename,
               source_class
        FROM cap_prepared_breast_2019_source
        WHERE source_class <> 'DI' -- to exclude them from CS because of lack of sense
        ORDER BY concept_name, concept_code, concept_class_id
    )
;
DROP TABLE IF EXISTS dev_cap.cap_breast_2020_concept_stage_preliminary
CREATE UNLOGGED TABLE dev_cap.cap_breast_2020_concept_stage_preliminary WITH OIDS AS
    (
        SELECT NULL                        AS concept_id,
               source_code                 AS concept_code,
               source_description          AS concept_name,
               alt_source_description AS alternative_concept_name,
     CASE
         WHEN source_class ='CAP Protocol'       or    (source_class='S'       AND source_description !~*'^Distance')  THEN 'Observation' -- todo How to treat 'CAP Protocol' in domain_id?
         WHEN source_class = 'LI' /*AND source_description !~* '^\.*other|^\.*specif.*'*/ THEN  'Meas Value' --decided to leave them as values
         ELSE 'Measurement'
         END                               AS domain_id,
               'CAP'                       AS vocabulary_id,
     CASE
         WHEN source_class = 'S'    AND source_description !~*'^Distance'                                     THEN 'CAP Header' -- or 'CAP section'
         WHEN source_class = 'LI' /*AND source_description !~* '^\.*other|^\.*specif.*'*/  THEN 'CAP Value' -- ^.*expla.* todo do we need them to be variables, decided to leave them as values
         WHEN source_class = 'CAP Protocol'                              THEN 'CAP Protocol'
         ELSE 'CAP Variable'
         END                               AS concept_class_id,
               NULL                        AS standard_concept,
               NULL                        AS invalid_reason,
               '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-12-31'                AS valid_end_date,
               source_filename,
               source_class
        FROM cap_prepared_breast_2020_source
        WHERE source_class <> 'DI' -- to exclude them from CS because of lack of sense
        ORDER BY concept_name, concept_code, concept_class_id
    )
;



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
FROM dev_cap.cap_breast_2020_concept_stage_preliminary -- august 2019 version
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
FROM dev_cap.cap_breast_2020_concept_stage_preliminary
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
        FROM dev_cap.ecc_202002 e
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs
                      ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2
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
        FROM dev_cap.ecc_202002 e
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs
                      ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2
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
        FROM dev_cap.ecc_202002 e
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs
                      ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2
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
        FROM dev_cap.ecc_202002 e
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs
                 ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2
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
        FROM dev_cap.ecc_202002 e
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs
                 ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2
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
        FROM dev_cap.ecc_202002 e
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs
                      ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2
                      ON e.variable_code = cs2.concept_code
        WHERE e.filename ~* 'breast'
          AND e.level_of_separation = 1
         AND cs.concept_class_id in ( 'CAP Variable', 'CAP Header')
        AND NOT EXISTS (select 1
                FROM concept_relationship_stage cr1
    WHERE cr1.concept_code_1=cs.concept_code
    AND cr1.concept_code_2=cs2.concept_code);
;

-- 'Has protocol'
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
               'Has protocol'                                                   AS relationship_id,
               to_date('19700101'  ,  'yyyymmdd'   )       AS valid_start_date, -- AT LEAST FOR NOW
               to_date('20991231'  ,  'yyyymmdd'   )                 AS valid_end_date,
               null as                                                invalid_reason
FROM  dev_cap.cap_breast_2020_concept_stage_preliminary cs
LEFT JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2
ON cs2.concept_code~*'DCIS.*Res'
WHERE cs.source_filename~*'DCIS.*Res'

UNION ALL

SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Has protocol'                                                   AS relationship_id,
               to_date('19700101'  ,  'yyyymmdd'   )             AS valid_start_date, -- AT LEAST FOR NOW
               to_date('20991231'    ,  'yyyymmdd'   )                 AS valid_end_date,
               null as                                                invalid_reason
FROM  dev_cap.cap_breast_2020_concept_stage_preliminary cs
LEFT JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2
ON cs2.concept_code~* 'DCIS.*Bx'
WHERE cs.source_filename  ~*'DCIS.*Bx'

UNION ALL

SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Has protocol'                                                   AS relationship_id,
               to_date('19700101'  ,  'yyyymmdd'   )               AS valid_start_date, -- AT LEAST FOR NOW
               to_date('20991231'    ,  'yyyymmdd'   )                 AS valid_end_date,
               null as                                                invalid_reason
FROM  dev_cap.cap_breast_2020_concept_stage_preliminary cs
LEFT JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2
ON cs2.concept_code~*'Breast.*Invasive.*Bx'
WHERE cs.source_filename ~*'Breast.*Invasive.*Bx'

UNION ALL

SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Has protocol'                                                   AS relationship_id,
             to_date('19700101'  ,  'yyyymmdd'   )             AS valid_start_date, -- AT LEAST FOR NOW
             to_date('20991231'    ,  'yyyymmdd'   )                 AS valid_end_date,
               null as                                                invalid_reason
FROM  dev_cap.cap_breast_2020_concept_stage_preliminary cs
LEFT JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2
ON cs2.concept_code~*'Breast.*Invasive.*Res'
WHERE cs.source_filename ~*'Breast.*Invasive.*Res'

UNION ALL

SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Has protocol'                                                   AS relationship_id,
             to_date('19700101'  ,  'yyyymmdd'   )        AS valid_start_date, -- AT LEAST FOR NOW
             to_date('20991231'    ,  'yyyymmdd'   )                   AS valid_end_date,
               null as                                                invalid_reason
FROM  dev_cap.cap_breast_2020_concept_stage_preliminary cs
LEFT JOIN dev_cap.cap_breast_2020_concept_stage_preliminary cs2
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


SELECT * FROM dev_cap.concept
WHERE vocabulary_id='CAP'
AND concept_code  NOT in (SELECT source_code FROM cap_prepared_breast_2019_source);

SELECT * FROM cap_prepared_breast_2019_source
WHERE source_code NOT IN (SELECT concept_code FROM dev_cap.concept)

SELECT * FROM  qa_tests.get_summary ('concept')
WHERE vocabulary_id_1='CAP';

SELECT * FROM qa_tests.get_summary ('concept_relationship')
WHERE vocabulary_id_1='CAP'
OR  vocabulary_id_2='CAP';

select qa_tests.get_checks ();

select qa_tests.get_summary ('concept_relationship');

select qa_tests.get_summary ('concept');

SELECT * FROM concept c
JOIN concept_synonym cs ON c.concept_id=cs.concept_id
WHERE c.vocabulary_id='CAP'


SELECT * FROM cap_prepared_breast_2020_source
WHERE source_class <>'DI'
WHERE source_code NOT IN (SELECT source_code FROM  cap_prepared_breast_2019_source)
