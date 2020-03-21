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
SELECT devv5.FastRecreateSchema ();
-- Some inserts to make code below viable


--load stage
-- Insert of vocabulary into concept table, and vocabulary table
INSERT INTO   dev_cap.concept (concept_id,
                               concept_name,
                               domain_id,
                               vocabulary_id,
                               concept_class_id,
                               standard_concept,
                               concept_code,
                               valid_start_date,
                               valid_end_date,
                               invalid_reason)
VALUES  (
         (SELECT concept_id+1
FROM concept
ORDER BY concept_id desc
limit 1),
         'College of American Pathologists',
         'Metadata',
         'Vocabulary',
         'Vocabulary',
         NULL,
         'OMOP generated',
         to_date('19700101', 'yyyymmdd'),
         to_date('20991231', 'yyyymmdd'),
         NULL
         )
;
INSERT INTO   dev_cap.vocabulary (vocabulary_id,
                                vocabulary_name,
                                vocabulary_reference,
                                vocabulary_version,
                                  vocabulary_concept_id
                                )
VALUES (
        'CAP',
        'College of American Pathologists',
        'link_to_source',
        'CAP eCC release, Aug 2019',
        (SELECT concept_id
FROM concept
WHERE concept_name='College of American Pathologists')
)
;


-- Insert of concept classes into concept table, and concept_class table
INSERT INTO dev_cap.concept (concept_id,
                             concept_name,
                             domain_id,
                             vocabulary_id,
                             concept_class_id,
                             standard_concept,
                             concept_code,
                             valid_start_date,
                             valid_end_date,
                             invalid_reason)

                                VALUES (
                                        (SELECT concept_id + 1
                                         FROM concept
                                         ORDER BY concept_id desc
                                         limit 1),
                                        'CAP Value',
                                        'Metadata',
                                        'Concept Class',
                                        'Concept Class',
                                        NULL,
                                        'OMOP generated',
                                        to_date('19700101', 'yyyymmdd'),
                                        to_date('20991231', 'yyyymmdd'),
                                        NULL),
                                       (
                                        (SELECT concept_id + 2
                                         FROM concept
                                         ORDER BY concept_id desc
                                         limit 1),
                                        'CAP Variable',
                                        'Metadata',
                                        'Concept Class',
                                        'Concept Class',
                                        NULL,
                                        'OMOP generated',
                                        to_date('19700101', 'yyyymmdd'),
                                        to_date('20991231', 'yyyymmdd'),
                                        NULL),
                                       (
                                        (SELECT concept_id + 3
                                         FROM concept
                                         ORDER BY concept_id desc
                                         limit 1),
                                        'CAP Protocol',
                                        'Metadata',
                                        'Concept Class',
                                        'Concept Class',
                                        NULL,
                                        'OMOP generated',
                                        to_date('19700101', 'yyyymmdd'),
                                        to_date('20991231', 'yyyymmdd'),
                                        NULL),
                                       (
                                        (SELECT concept_id + 4
                                         FROM concept
                                         ORDER BY concept_id desc
                                         limit 1),
                                        'CAP Header',
                                        'Metadata',
                                        'Concept Class',
                                        'Concept Class',
                                        NULL,
                                        'OMOP generated',
                                        to_date('19700101', 'yyyymmdd'),
                                        to_date('20991231', 'yyyymmdd'),
                                        NULL)
                             ;

INSERT INTO   dev_cap.concept_class (concept_class_id,
                                     concept_class_name,
                                     concept_class_concept_id)

VALUES ('CAP Value',
        'CAP Value',
        (SELECT concept_id
        FROM concept
           WHERE concept_name= 'CAP Value'
        limit 1 )
       ),
       ('CAP Variable',
        'CAP Variable',
        (SELECT concept_id
        FROM concept
           WHERE concept_name= 'CAP Variable'
        limit 1 )
        )
        ,
       ('CAP Protocol',
        'CAP Protocol',
          (SELECT concept_id
        FROM concept
           WHERE concept_name= 'CAP Protocol'
        limit 1 )
         )
         ,
       ('CAP Header',
        'CAP Header',
           (SELECT concept_id
        FROM concept
           WHERE concept_name= 'CAP Header'
        limit 1 )
        )
       ;
SELECT * FROM relationship;

-- Insert of relationships into concept table, and concept_class table
INSERT INTO dev_cap.concept (concept_id,
                             concept_name,
                             domain_id,
                             vocabulary_id,
                             concept_class_id,
                             standard_concept,
                             concept_code,
                             valid_start_date,
                             valid_end_date,
                             invalid_reason)

                                VALUES (
                                        (SELECT concept_id + 1
                                         FROM concept
                                         ORDER BY concept_id desc
                                         limit 1),
                                        'CAP Value of',
                                        'Metadata',
                                        'Relationship',
                                        'Relationship',
                                        NULL,
                                        'OMOP generated',
                                        to_date('19700101', 'yyyymmdd'),
                                        to_date('20991231', 'yyyymmdd'),
                                        NULL),
                                       (
                                        (SELECT concept_id + 2
                                         FROM concept
                                         ORDER BY concept_id desc
                                         limit 1),
                                        'CAP Variable for',
                                        'Metadata',
                                        'Relationship',
                                        'Relationship',
                                        NULL,
                                        'OMOP generated',
                                        to_date('19700101', 'yyyymmdd'),
                                        to_date('20991231', 'yyyymmdd'),
                                        NULL),
                                       (
                                        (SELECT concept_id + 3
                                         FROM concept
                                         ORDER BY concept_id desc
                                         limit 1),
                                        'Has CAP parent item',
                                        'Metadata',
                                        'Relationship',
                                       'Relationship',
                                        NULL,
                                        'OMOP generated',
                                        to_date('19700101', 'yyyymmdd'),
                                        to_date('20991231', 'yyyymmdd'),
                                        NULL),
                                       (
                                        (SELECT concept_id + 4
                                         FROM concept
                                         ORDER BY concept_id desc
                                         limit 1),
                                        'Parent item for',
                                        'Metadata',
                                       'Relationship',
                                        'Relationship',
                                        NULL,
                                        'OMOP generated',
                                        to_date('19700101', 'yyyymmdd'),
                                        to_date('20991231', 'yyyymmdd'),
                                        NULL)
                                        ,
                                        (
                                        (SELECT concept_id + 5
                                         FROM concept
                                         ORDER BY concept_id desc
                                         limit 1),
                                        'Part of protocol',
                                        'Metadata',
                                       'Relationship',
                                        'Relationship',
                                        NULL,
                                        'OMOP generated',
                                        to_date('19700101', 'yyyymmdd'),
                                        to_date('20991231', 'yyyymmdd'),
                                        NULL)
                                        ,

                                        (
                                        (SELECT concept_id + 6
                                         FROM concept
                                         ORDER BY concept_id desc
                                         limit 1),
                                        'Protocol of',
                                        'Metadata',
                                       'Relationship',
                                        'Relationship',
                                        NULL,
                                        'OMOP generated',
                                        to_date('19700101', 'yyyymmdd'),
                                        to_date('20991231', 'yyyymmdd'),
                                        NULL)
                             ;

INSERT INTO dev_cap.relationship (relationship_id,
                                  relationship_name,
                                  is_hierarchical,
                                  defines_ancestry,
                                  reverse_relationship_id,
                                  relationship_concept_id)
VALUES ('CAP Value of',
        'CAP Value of',
        0,
        0,
         'CAP Variable for',
        (SELECT concept_id
        FROM dev_cap.concept
            WHERE concept_name='CAP Value of')
       ),
       ('CAP Variable for',
        'CAP Variable for',
        0,
        0,
         'CAP Value of',
        (SELECT concept_id
        FROM dev_cap.concept
            WHERE concept_name='CAP Variable for')
       ),
         ('Has CAP parent item',
        'Has CAP parent item (CAP)',
        0,
        0,
         'Parent item for',
        (SELECT concept_id
        FROM dev_cap.concept
            WHERE concept_name='Has CAP parent item')
       ),
        ('Parent item for',
        'Parent item for (CAP)',
        0,
        0,
         'Has CAP parent item',
        (SELECT concept_id
        FROM dev_cap.concept
            WHERE concept_name='Parent item for')
       ),
       ('Part of protocol',
        'Part of protocol (CAP)',
        0,
        0,
         'Protocol of',
        (SELECT concept_id
        FROM dev_cap.concept
            WHERE concept_name='Part of protocol')
       ),
        ('Protocol of',
        'Protocol of(CAP)',
        0,
        0,
         'Part of protocol',
        (SELECT concept_id
        FROM dev_cap.concept
            WHERE concept_name='Protocol of')
       )
;
--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CAP',
	pVocabularyDate			=> to_date('20190828', 'yyyymmdd'), -- here i put the date version of first version;
	pVocabularyVersion		=> 'CAP eCC release, Aug 2019',
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
FROM cap_breast_2019_concept_stage_preliminary -- august version
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
FROM cap_breast_2019_concept_stage_preliminary
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
               'CAP Value of'                                                   AS relationship_id,
                '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-01-01'                AS valid_end_date,
               null as                                                invalid_reason
        FROM ddymshyts.ecc_201909_v3 e
                 JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs
                      ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
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
               '2099-01-01'                AS valid_end_date,
               null as                                                invalid_reason
        FROM ddymshyts.ecc_201909_v3 e
                 JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs
                      ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
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
               '2099-01-01'                AS valid_end_date,
               null as                                                invalid_reason
        FROM ddymshyts.ecc_201909_v3 e
                 JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs
                      ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
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
               '2099-01-01'                AS valid_end_date,
               null as                                                invalid_reason
        FROM ddymshyts.ecc_201909_v3 e
                 JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs
                 ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
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
               '2099-01-01'                AS valid_end_date,
               null as                                                invalid_reason
        FROM ddymshyts.ecc_201909_v3 e
                 JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs
                 ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
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
               '2099-01-01'                AS valid_end_date,
               null as                                                invalid_reason
        FROM ddymshyts.ecc_201909_v3 e
                 JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs
                      ON e.value_code = cs.concept_code
                 JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
                      ON e.variable_code = cs2.concept_code
        WHERE e.filename ~* 'breast'
          AND e.level_of_separation = 1
         AND cs.concept_class_id in ( 'CAP Variable', 'CAP Header')
        AND NOT EXISTS (select 1
                FROM concept_relationship_stage cr1
    WHERE cr1.concept_code_1=cs.concept_code
    AND cr1.concept_code_2=cs2.concept_code);
;

-- 'Part of protocol'
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
               'Part of protocol'                                                   AS relationship_id,
               to_date('19700101'  ,  'yyyymmdd'   )       AS valid_start_date, -- AT LEAST FOR NOW
               to_date('2099-01-01'    ,  'yyyymmdd'   )                 AS valid_end_date,
               null as                                                invalid_reason
FROM  dev_cap.cap_breast_2019_concept_stage_preliminary cs
LEFT JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
ON cs2.concept_code~*'DCIS.*Res'
WHERE cs.source_filename~*'DCIS.*Res'

UNION ALL

SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Part of protocol'                                                   AS relationship_id,
               to_date('19700101'  ,  'yyyymmdd'   )             AS valid_start_date, -- AT LEAST FOR NOW
               to_date('2099-01-01'    ,  'yyyymmdd'   )                 AS valid_end_date,
               null as                                                invalid_reason
FROM  dev_cap.cap_breast_2019_concept_stage_preliminary cs
LEFT JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
ON cs2.concept_code~* 'DCIS.*Bx'
WHERE cs.source_filename  ~*'DCIS.*Bx'

UNION ALL

SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Part of protocol'                                                   AS relationship_id,
               to_date('19700101'  ,  'yyyymmdd'   )               AS valid_start_date, -- AT LEAST FOR NOW
               to_date('2099-01-01'    ,  'yyyymmdd'   )                 AS valid_end_date,
               null as                                                invalid_reason
FROM  dev_cap.cap_breast_2019_concept_stage_preliminary cs
LEFT JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
ON cs2.concept_code~*'Breast.*Invasive.*Bx'
WHERE cs.source_filename ~*'Breast.*Invasive.*Bx'

UNION ALL

SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Part of protocol'                                                   AS relationship_id,
             to_date('19700101'  ,  'yyyymmdd'   )             AS valid_start_date, -- AT LEAST FOR NOW
             to_date('2099-01-01'    ,  'yyyymmdd'   )                 AS valid_end_date,
               null as                                                invalid_reason
FROM  dev_cap.cap_breast_2019_concept_stage_preliminary cs
LEFT JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
ON cs2.concept_code~*'Breast.*Invasive.*Res'
WHERE cs.source_filename ~*'Breast.*Invasive.*Res'

UNION ALL

SELECT cs.concept_code                                                       AS concept_code_1,
               cs2.concept_code                                                    AS concept_code_2,
               'CAP'                                                            AS vocabulary_id_1,
               'CAP'                                                            AS vocabulary_id_2,
               'Part of protocol'                                                   AS relationship_id,
             to_date('19700101'  ,  'yyyymmdd'   )        AS valid_start_date, -- AT LEAST FOR NOW
             to_date('2099-01-01'    ,  'yyyymmdd'   )                   AS valid_end_date,
               null as                                                invalid_reason
FROM  dev_cap.cap_breast_2019_concept_stage_preliminary cs
LEFT JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
ON cs2.concept_code~*'Breast.*Bmk'
WHERE cs.source_filename~*'Breast.*Bmk'
;


SELECT *
FROM concept_relationship_stage cr
JOIN concept_stage c
ON cr.concept_code_1=c.concept_code
JOIN concept_stage c2
ON cr.concept_code_2=c2.concept_code
-----------------------------------------------------------------------------------------
--- CHECKS CRS source
-- SQL to retrieve all the hierarchical direct parent-child pairs generated in dev_cap.cap_breast_2019_concept_stage_preliminary
SELECT distinct
       cs.concept_class_id,
       cs2.concept_class_id,
       count(*) as COUNTS
FROM ddymshyts.ecc_201909_v3 e
JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs
ON e.value_code=cs.concept_code
JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
ON e.variable_code=cs2.concept_code
WHERE e.filename ~* 'breast'
AND e.level_of_separation =1
GROUP BY cs.concept_class_id,
         cs2.concept_class_id
Order BY COUNTS desc
;

-- not included to any hierarchy codes from source plus newly created class CAP protocols
SELECT distinct *

FROM ddymshyts.ecc_201909_v3 e
LEFT JOIN  dev_cap.cap_breast_2019_concept_stage_preliminary cs
ON e.variable_code=cs.concept_code

WHERE e.filename ~* 'breast'
AND e.variable_code NOT IN (SELECT distinct
       e.value_code
FROM ddymshyts.ecc_201909_v3 e
JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs
ON e.value_code=cs.concept_code
JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
ON e.variable_code=cs2.concept_code
WHERE e.filename ~* 'breast'
AND e.level_of_separation =1

    UNION
    SELECT distinct
       e.variable_code
FROM ddymshyts.ecc_201909_v3 e
JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs
ON e.value_code=cs.concept_code
JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
ON e.variable_code=cs2.concept_code
WHERE e.filename ~* 'breast'
AND e.level_of_separation =1
)
;

--- CHECKS CRS resulting
-- check af multiple relationships
-- for only one relationship created
SELECT *
FROM concept_relationship_stage
WHERE concept_code_1 IN
(SELECT concept_code_1
    FROM concept_relationship_stage
    GROUP BY concept_code_1
    having count(relationship_id)=1)
;
-- Check for uniqueness of pair concept_code_1, concept_code_2
select concept_code_1, concept_code_2
from dev_cap.concept_relationship_stage
group by concept_code_1, concept_code_2 having count(1) > 1
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
select devv5.genericupdate()




--dev_lexicon - for Nebraska_Lexicon mappings
select distinct cs.concept_code,cs.concept_name, cs.concept_class_id, cs.alternative_concept_name, n.*,
                CASE WHEN length(n.concept_name)>20 then 'CHECK' else '' END AS comment
FROM dev_cap.cap_breast_2020_concept_stage_preliminary cs
left JOIN  dev_lexicon.concept n
ON trim(lower(regexp_replace(cs.alternative_concept_name,'[[:punct:]]|\s','','g')))
    = trim(lower(regexp_replace(n.concept_name,'\sposition|[[:punct:]]|\s','','g')))
AND n.vocabulary_id='Nebraska Lexicon'
AND n.invalid_reason IS NULL
ORDER BY cs.concept_name
;

SELECT distinct *
FROM dev_cap.cap_breast_2020_concept_relationship_stage_preliminary
WHERE concept_name_2='Extent of Medial Margin Involvement|Medial|Specify Margin(s)|Positive for DCIS|Margins|MARGINS (Note H)'
;

SELECT distinct n.concept_id,
               n.concept_code	,
               n.concept_name	,
               n. domain_id	,
               n. concept_class_id	,
               n. vocabulary_id	,
               n. valid_start_date	,
               n. valid_end_date	,
               n. invalid_reason	,
               n. standard_concept
FROM devv5.concept n
WHERE n.vocabulary_id='Nebraska Lexicon'
--AND  n.concept_code='445028008'
AND n.concept_name ~*'pM1'
--AND n.concept_name ~*'surgica'
--AND n.concept_name !~*'clos'
--AND n.invalid_reason is NULL
;
SELECT * FROM  dev_lexicon.concept n
WHERE n.vocabulary_id='Nebraska Lexicon'
;

SELECT distinct nn.concept_id,
               nn.concept_code	,
               nn.concept_name	,
               nn. domain_id	,
               nn. concept_class_id	,
               nn. vocabulary_id	,
               nn. valid_start_date	,
               nn. valid_end_date	,
               nn. invalid_reason	,
               nn. standard_concept,
                nn.concept_name	,
                nr.relationship_id,
                n.concept_name

FROM dev_lexicon.concept n
JOIN dev_lexicon.concept_relationship nr
ON n.concept_id=nr.concept_id_2
JOIN dev_lexicon.concept nn ON nn.concept_id=nr.concept_id_1
WHERE n.vocabulary_id='Nebraska Lexicon'
AND nn.vocabulary_id='Nebraska Lexicon'
AND n.concept_code = '84921008'-- from above select
/* AND n.concept_name ~*'skin'*/
AND n.invalid_reason is NULL
;


select * from ddymshyts.concept where vocabulary_id ='Nebraska Lexicon'
and concept_code not in (select concept_code from dev_lexicon.concept where vocabulary_id ='Nebraska Lexicon')
AND CONCEPT_id IN ('36902312',
'36902319',
'36902401',
'36902461',
'36902542',
'36902644',
'36902651',
'36902670',
'36902679',
'36902696',
'36902711',
'36902732',
'36902735',
'36902742',
'36902754',
'36902795',
'36902806',
'36903138');

SELECT distinct vocabulary_id
FROM devv5.concept
WHERE vocabulary_id ilike'n%'


-- used to upload to g-dock for manual
WITH all_concepts AS (
    SELECT DISTINCT a.name, cc.concept_id, cc.vocabulary_id,cc.standard_concept, cc.invalid_reason, a.algorithm
    FROM (
             SELECT concept_name as name,
                    concept_id as concept_id,
                    'CN' as algorithm
             FROM dev_lexicon.concept c
             WHERE c.vocabulary_id='Nebraska Lexicon'
UNION ALL
             --Mapping non-standard to standard through concept relationship
             SELECT c.concept_name as name,
                    cr.concept_id_2 as concept_id,
                    'CR' as algorithm
             FROM  dev_lexicon.concept c
             JOIN dev_lexicon.concept_relationship cr
             ON (cr.concept_id_1 = c.concept_id
                 AND cr.invalid_reason IS NULL AND cr.relationship_id in ('Maps to','Concept same_as to','Concept poss_eq to'))
             JOIN dev_lexicon.concept cc
             ON (cr.concept_id_2 = cc.concept_id
                 AND (cc.standard_concept IN ('S','') or cc.standard_concept IS NULL) AND cc.invalid_reason IS NULL)
             WHERE c.standard_concept != 'S' OR c.standard_concept IS NULL
AND cc.vocabulary_id in ('Nebraska Lexicon')
AND c.vocabulary_id in ('Nebraska Lexicon') --vocabularies selection
         ) AS a

             JOIN dev_lexicon.concept cc
                  ON a.concept_id = cc.concept_id

      WHERE (cc.standard_concept IN ('S','') or cc.standard_concept IS NULL)
      AND cc.invalid_reason IS NULL
)

    SELECT DISTINCT  S.CONCEPT_CODE,
                    S.CONCEPT_NAME,
                    S.ALTERNATIVE_CONCEPT_NAME,
                    S.DOMAIN_ID,
                    S.VOCABULARY_ID,
                    S.CONCEPT_CLASS_ID,
                    S.STANDARD_CONCEPT,
                    S.INVALID_REASON,
                    dc.*


    FROM  dev_cap.cap_breast_2020_concept_stage_preliminary s --source table
        LEFT  JOIN all_concepts ac
          ON trim(lower(regexp_replace(s.alternative_concept_name,'[[:punct:]]|\s','','g')))
                                           = trim(lower(regexp_replace(ac.name,'\sposition|[[:punct:]]|\s','','g')))
LEFT join DEV_LEXICON.CONCEPT D
ON d.concept_id=ac.concept_id

        /* JOIN  ddymshyts.concept dc
    ON trim(lower(regexp_replace(s.alternative_concept_name,'[[:punct:]]|\s','','g')))
                                           = trim(lower(regexp_replace(dc.concept_name,'\sposition|[[:punct:]]|\s','','g')))
     AND  dc.vocabulary_id ='Nebraska Lexicon'
and dc.concept_code not in (select concept_code from dev_lexicon.concept where vocabulary_id ='Nebraska Lexicon')*/ -- to map to 36902696	 Cannot be assessed

;
