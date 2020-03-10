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
* Authors: Medical Team
* Date: 2020
**************************************************************************/
--00 source_table preparation
--current version of breast source
-- cap_prepared_breast_2020_source CREATION is used to preserve data of source_code by concatenation of names from the lowest term(value) to it's ancestor
-- 2020 version
-- DROP TABLE dev_vkorsik.cap_prepared_breast_2020_source
CREATE TABLE dev_vkorsik.cap_prepared_breast_2020_source WITH OIDS AS
    (
        with tab_val as
            (
            SELECT distinct value_code                                           as source_code
                          , val_concept_class                                    as source_class
                         ,coalesce(value_description, value_alt) as  alt_source_description
                            , trim(concat(coalesce(value_description, value_alt), '|',
                                   string_agg(coalesce(variable_description, variable_alt), '|'
                                              order by level_of_separation ASC))) as source_description -- full hierarchical explanation of source_code
                          , left(filename, -4)                                   as source_filename
            FROM dev_cap.ecc_202002
            WHERE filename ~* 'breast'
             AND value_code IS NOT NULL -- used to exclude 5 rows which are aggregation of all source_concepts in one for each brest protocol
            GROUP BY value_code
                   , coalesce(value_description, value_alt)
                   , left(filename, -4)
                   , val_concept_class

        )
           -- tab_var is created 'cause of some codes (with S,DI,Q classes) are not stated as values, they are 1)headers or 2)not conjugated with other source_codes as parent-child
           , tab_var as
               (
            SELECT distinct variable_code                                as source_code
                          , var_concept_class                            as source_class
                          ,coalesce(variable_description, variable_alt) as  alt_source_description
                          , trim(coalesce(variable_description, variable_alt)) as source_description
                          , left(filename, -4)                           as source_filename
            FROM dev_cap.ecc_202002
            WHERE filename ~* 'breast'
              AND variable_code NOT IN (select distinct source_code FROM tab_val)
            GROUP BY variable_code
                   , coalesce(variable_description, variable_alt)
                   , left(filename, -4)
                   , var_concept_class
        )
           ,
             tab_filename AS
                 (
                     SELECT distinct left(filename, -4)    as source_code
                          , 'CAP Protocol'                                    as source_class
                          , CASE WHEN filename='Breast.DCIS.Res.211_3.002.001.REL_sdcFDF.xml' then 'DCIS OF THE BREAST: Resection'
                                 WHEN filename='Breast.DCIS.Bx.360_1.001.001.REL_sdcFDF.xml' then 'DCIS OF THE BREAST: Biopsy'
                                 WHEN filename='Breast.Bmk.169_1.006.001.REL_sdcFDF.xml' then 'Breast Biomarker Reporting Template'
                                 WHEN filename='Breast.Invasive.Bx.362_1.001.001.REL_sdcFDF.xml' then 'INVASIVE CARCINOMA OF THE BREAST: Biopsy'
                                 WHEN filename='Breast.Invasive.Res.189_4.002.001.REL_sdcFDF.xml' then 'INVASIVE CARCINOMA OF THE BREAST: Resection'
                                        END as source_description
                                   ,CASE WHEN filename='Breast.DCIS.Res.211_3.002.001.REL_sdcFDF.xml' then 'DCIS OF THE BREAST: Resection'
                                 WHEN filename='Breast.DCIS.Bx.360_1.001.001.REL_sdcFDF.xml' then 'DCIS OF THE BREAST: Biopsy'
                                 WHEN filename='Breast.Bmk.169_1.006.001.REL_sdcFDF.xml' then 'Breast Biomarker Reporting Template'
                                 WHEN filename='Breast.Invasive.Bx.362_1.001.001.REL_sdcFDF.xml' then 'INVASIVE CARCINOMA OF THE BREAST: Biopsy'
                                 WHEN filename='Breast.Invasive.Res.189_4.002.001.REL_sdcFDF.xml' then 'INVASIVE CARCINOMA OF THE BREAST: Resection'
                                        END as alt_source_description
                          , left(filename, -4)                                   as source_filename
            FROM dev_cap.ecc_202002
            WHERE filename ~* 'breast'

                 )

           ,
             tab_resulting AS
               (
            SELECT source_code
                 , source_class
                 , source_description
                 ,alt_source_description
                 , source_filename
            FROM tab_var

            UNION ALL

            SELECT source_code
                 , source_class
                 , source_description
                 ,alt_source_description
                 , source_filename
            FROM tab_val

            UNION ALL

         SELECT source_code
                 , source_class
                 , source_description
                 ,alt_source_description
                 , source_filename
            FROM tab_filename

        )
                                        SELECT distinct source_code, source_class, source_description, alt_source_description, source_filename
                                        FROM tab_resulting
                                        ORDER BY source_description, source_code, source_filename, source_class
    )
;

SELECT source_code, source_class, source_description, source_filename
FROM dev_vkorsik.cap_prepared_breast_2020_source
;
-- previous version of breast source
--2019
-- DROP TABLE dev_vkorsik.cap_prepared_breast_2019_source
CREATE TABLE dev_vkorsik.cap_prepared_breast_2019_source WITH OIDS AS
    (
        with tab_val as
            (
            SELECT distinct value_code                                           as source_code
                          , val_concept_class                                    as source_class
                           ,coalesce(value_description, value_alt) as  alt_source_description
                          , trim(concat(coalesce(value_description, value_alt), '|',
                                   string_agg(coalesce(variable_description, variable_alt), '|'
                                              order by level_of_separation ASC))) as source_description -- full hierarchical explanation of source_code
                          , left(filename, -4)                                   as source_filename
            FROM ddymshyts.ecc_201909_v3
            WHERE filename ~* 'breast'
             AND value_code IS NOT NULL -- used to exclude 5 rows which are aggregation of all source_concepts in one for each brest protocol
            GROUP BY value_code
                   , coalesce(value_description, value_alt)
                   , left(filename, -4)
                   , val_concept_class

        )
           -- tab_var is created 'cause of some codes (with S,DI,Q classes) are not stated as values, they are 1)headers or 2)not conjugated with other source_codes as parent-child
           , tab_var as
               (
            SELECT distinct variable_code                                as source_code
                          , var_concept_class                            as source_class
                           ,coalesce(variable_description, variable_alt) as  alt_source_description
                          , trim(coalesce(variable_description, variable_alt)) as source_description
                          , left(filename, -4)                           as source_filename
            FROM ddymshyts.ecc_201909_v3
            WHERE filename ~* 'breast'
              AND variable_code NOT IN (select distinct source_code FROM tab_val)
            GROUP BY variable_code
                   , coalesce(variable_description, variable_alt)
                   , left(filename, -4)
                   , var_concept_class
        )
           ,
             tab_filename AS
                 (
                     SELECT distinct left(filename, -4)    as source_code
                          , 'CAP Protocol'                                    as source_class
                          , CASE WHEN filename~*'Breast.DCIS.Res' then 'DCIS OF THE BREAST: Resection'
                                 WHEN filename~*'Breast.DCIS.Bx' then 'DCIS OF THE BREAST: Biopsy'
                                 WHEN filename~*'Breast.Bmk' then 'Breast Biomarker Reporting Template'
                                 WHEN filename~*'Breast.Invasive.Bx' then 'INVASIVE CARCINOMA OF THE BREAST: Biopsy'
                                 WHEN filename~*'Breast.Invasive.Res.' then 'INVASIVE CARCINOMA OF THE BREAST: Resection'
                                        END as source_description,
                                     CASE WHEN filename~*'Breast.DCIS.Res' then 'DCIS OF THE BREAST: Resection'
                                 WHEN filename~*'Breast.DCIS.Bx' then 'DCIS OF THE BREAST: Biopsy'
                                 WHEN filename~*'Breast.Bmk' then 'Breast Biomarker Reporting Template'
                                 WHEN filename~*'Breast.Invasive.Bx' then 'INVASIVE CARCINOMA OF THE BREAST: Biopsy'
                                 WHEN filename~*'Breast.Invasive.Res.' then 'INVASIVE CARCINOMA OF THE BREAST: Resection'
                                        END as alt_source_description
                          , left(filename, -4)                                   as source_filename
            FROM ddymshyts.ecc_201909_v3
            WHERE filename ~* 'breast'

                 )

           ,
             tab_resulting AS
               (
            SELECT source_code
                 , source_class
                 , source_description
                 ,alt_source_description
                 , source_filename
            FROM tab_var

            UNION ALL

            SELECT source_code
                 , source_class
                 , source_description
                 ,alt_source_description
                 , source_filename
            FROM tab_val

            UNION ALL

         SELECT source_code
                 , source_class
                 , source_description
              ,alt_source_description
                 , source_filename
            FROM tab_filename

        )
                                        SELECT distinct source_code, source_class, source_description, source_filename,alt_source_description
                                        FROM tab_resulting
                                        ORDER BY source_description, source_code, source_filename, source_class
    )
;
-- TO check which codes are not included in 2020 version
SELECT *
FROM cap_prepared_breast_2019_source
WHERE source_code IN (
SELECT distinct source_code
FROM dev_vkorsik.cap_prepared_breast_2019_source e
EXCEPT
SELECT distinct source_code
FROM dev_vkorsik.cap_prepared_breast_2020_source e
    )

-- To check which codes are newly ingested in 2020ver
SELECT *
FROM cap_prepared_breast_2020_source
WHERE source_code IN (
    SELECT distinct source_code
    FROM dev_vkorsik.cap_prepared_breast_2020_source e
        EXCEPT
    SELECT distinct source_code
    FROM dev_vkorsik.cap_prepared_breast_2019_source
    )
;
-- to explain how the codes are used across versions
-- Do the same codes with crucially different names exist? - NO
SELECT *
FROM dev_vkorsik.cap_prepared_breast_2019_source e
join  dev_vkorsik.cap_prepared_breast_2020_source ee
on e.source_code=ee.source_code
WHERE regexp_replace(e.alt_source_description,'\s|\(\w*\s\w*\)|#','','g') != regexp_replace(ee.alt_source_description,'\s|\(\w*\s\w*\)|#','','g') -- same hierarchically-conjugated names without spaces and not sensetive for words in ()
AND concat(split_part(e.source_filename,'.',1),'|',split_part(e.source_filename,'.',2),'|',split_part(e.source_filename,'.',3)) = concat(split_part(ee.source_filename,'.',1),'|',split_part(ee.source_filename,'.',2),'|',split_part(ee.source_filename,'.',3))
;
-- Do the same names with crucially different code exist? - YES
-- ver2019 26435  vs ver2020 49025
-- ver2019 45028    vs ver2020 50983
-- ver2019 46090   vs ver2020 41794
-- ver2019 59268   vs ver2020 42996
-- ver2019 5429   vs ver2020 42676
-- ver2019 16250   vs ver2020 51180
-- ver2019 44192   vs ver2020 42501
-- ver2019 41313   vs ver2020  42544
-- THIS one retrieves duplicated codes in one source_file 31339, 31340, 31343, 31344, 31359,31360
SELECT *
FROM dev_vkorsik.cap_prepared_breast_2019_source e
join  dev_vkorsik.cap_prepared_breast_2020_source ee
on regexp_replace(e.source_description,'\s|\(\w*\s\w*\)|#','','g')
        =
   regexp_replace(ee.source_description,'\s|\(\w*\s\w*\)|#','','g') -- same hierarchically-conjugated names without spaces and not sensetive for words in ()
WHERE e.source_code != ee.source_code -- different codes
AND concat(split_part(e.source_filename,'.',1),'|',
           split_part(e.source_filename,'.',2),'|',
           split_part(e.source_filename,'.',3))
                                                    =
    concat(split_part(ee.source_filename,'.',1),'|',
           split_part(ee.source_filename,'.',2),'|',
           split_part(ee.source_filename,'.',3)) -- to restrict to the same filename
ORDER BY e.source_description
;
SELECT * FROM  dev_cap.ecc_202002 d

WHERE EXISTS(
              SELECT value_code, variable_code
              FROM dev_cap.ecc_202002 dd
              WHERE level_of_separation = 1
               AND filename ~*'breast'
               and dd.value_code=d.value_code
               and dd.variable_code=d.variable_code
                  EXCEPT
              SELECT value_code, variable_code
              FROM ddymshyts.ecc_201909_v3
              WHERE level_of_separation = 1
    AND filename ~*'breast'
          )
 AND filename ~*'breast'
;

-- 01 concept_stage
-- dev_vkorsik.cap_breast_2020_concept_stage_preliminary this table is preliminary generated concept_stage the diff
-- between it and dev_vkorsik.cap_prepared_breast_2020_source is in the absence of filename  field in 1st

-- DROP TABLE dev_vkorsik.cap_breast_2020_concept_stage_preliminary
CREATE TABLE dev_vkorsik.cap_breast_2020_concept_stage_preliminary WITH OIDS AS
    (
        SELECT NULL                        AS concept_id,
               source_code                 AS concept_code,
               source_description          AS concept_name,
               alt_source_description AS alternative_concept_name,
     CASE
         WHEN source_class in ('DI', 'CAP Protocol')       or    (source_class='S'       AND source_description !~*'^Distance')  THEN 'Observation' -- todo How to treat 'CAP Protocol' in domain_id?
         WHEN source_class = 'LI' /*AND source_description !~* '^\.*other|^\.*specif.*'*/ THEN  'Meas Value' --decided to leave them as values
         ELSE 'Measurement'
         END                               AS domain_id,
               'CAP'                       AS vocabulary_id,
     CASE
         WHEN source_class = 'S'    AND source_description !~*'^Distance'                                     THEN 'CAP Header' -- or 'CAP section'
         WHEN source_class = 'LI' /*AND source_description !~* '^\.*other|^\.*specif.*'*/  THEN 'CAP Value' -- ^.*expla.* todo do we need them to be variables, decided to leave them as values
         WHEN source_class = 'CAP Protocol'                              THEN 'CAP Protocol'
         WHEN source_class = 'DI' THEN 'CAP Comment'
         ELSE 'CAP Variable'
         END                               AS concept_class_id,
               NULL                        AS standard_concept,
               NULL                        AS invalid_reason,
               '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-01-01'                AS valid_end_date,
               source_filename,
               source_class
        FROM cap_prepared_breast_2020_source
        WHERE source_class != 'DI' -- to exclude them from CS because of lack of sense
        ORDER BY concept_name, concept_code, concept_class_id
    )
;

SELECT *
FROM cap_breast_2020_concept_stage_preliminary
;

-- check that no source_codes lost after modification
--73 rows with CAP-comments marked as 'DI' class
SELECT *
FROM dev_cap.ecc_202002 e
      WHERE e.filename ~* 'breast'
AND e.variable_code IN (
          SELECT distinct code
          FROM (SELECT distinct variable_code as code
                FROM dev_cap.ecc_202002 e
                WHERE e.filename ~* 'breast'
                UNION ALL
                SELECT distinct value_code as code
                FROM dev_cap.ecc_202002 e
                WHERE e.filename ~* 'breast'
                  AND value_code IS NOT NULL
               ) as a
              except

          SELECT distinct concept_code as code
          FROM dev_vkorsik.cap_breast_2020_concept_stage_preliminary
      )
;

--5 rows 're retrieved because of manual creation of them
SELECT distinct concept_code as code
FROM  dev_vkorsik.cap_breast_2020_concept_stage_preliminary

except

SELECT distinct code
FROM (SELECT distinct variable_code as code
      FROM dev_cap.ecc_202002 e
      WHERE e.filename ~* 'breast'
      UNION ALL
      SELECT distinct value_code as code
      FROM dev_cap.ecc_202002 e
      WHERE e.filename ~* 'breast'
      AND value_code IS NOT NULL
     ) as a
;


-- INSERT INTO CONCEPT_STAGE
INSERT INTO dev_vkorsik.CONCEPT_STAGE (
                                       concept_id,
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
                           SELECT concept_id::int,
                                  alternative_concept_name,
                                  domain_id,
                                  vocabulary_id,
                                  concept_class_id,
                                   standard_concept,
                                  concept_code,
                                  valid_start_date::date,
                                  valid_end_date::date,
                                  invalid_reason
FROM cap_breast_2020_concept_stage_preliminary
;
-- TRUNCATE TABLE dev_vkorsik.CONCEPT_STAGE
SELECT * FROM dev_vkorsik.CONCEPT_STAGE;

-- CONCEPT_SYNONYM_STAGE
INSERT INTO dev_vkorsik.CONCEPT_synonym_stage (synonym_concept_id, synonym_name, synonym_concept_code, synonym_vocabulary_id, language_concept_id)
SELECT                                concept_id::int,
                                  concept_name,
                               concept_code,
                                  vocabulary_id,
                                  4180186 as language_concept_id  -- for english language
FROM cap_breast_2020_concept_stage_preliminary
;

SELECT *
FROM dev_vkorsik.concept_stage cs
JOIN dev_vkorsik.concept_synonym_stage css
    ON cs.concept_code=css.synonym_concept_code
;

-- 02 concept_relationship_stage
-- SQL to retrieve all the hierarchical direct parent-child pairs generated in dev_vkorsik.cap_breast_2020_concept_stage_preliminary
SELECT distinct
       cs.concept_class_id,

       cs2.concept_class_id,
                count(*) as COUNTS
FROM dev_cap.ecc_202002 e
JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
ON e.value_code=cs.concept_code
JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs2
ON e.variable_code=cs2.concept_code
WHERE e.filename ~* 'breast'
AND e.level_of_separation =1
GROUP BY cs.concept_class_id,
       cs2.concept_class_id
Order BY COUNTS desc
;
-- not included to any hierarchy codes from source plus newly created class CAP protocols
SELECT distinct *

FROM dev_cap.ecc_202002 e
JOIN  dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
ON e.variable_code=cs.concept_code

WHERE e.filename ~* 'breast'
AND e.variable_code NOT IN (SELECT distinct
       e.value_code
FROM dev_cap.ecc_202002 e
JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
ON e.value_code=cs.concept_code
JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs2
ON e.variable_code=cs2.concept_code
WHERE e.filename ~* 'breast'
AND e.level_of_separation =1

    UNION
    SELECT distinct
       e.variable_code
FROM dev_cap.ecc_202002 e
JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
ON e.value_code=cs.concept_code
JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs2
ON e.variable_code=cs2.concept_code
WHERE e.filename ~* 'breast'
AND e.level_of_separation =1
)

;
;

-- DROP TABLE dev_vkorsik.cap_breast_2020_concept_relationship_stage_preliminary;
CREATE TABLE dev_vkorsik.cap_breast_2020_concept_relationship_stage_preliminary WITH OIDS AS
    (
        -- 'CAP Value of' for Value to Variable
    WITH tab_CAP_Value AS (
        SELECT NULL                                                             AS concept_id_1,
               value_code                                                       AS concept_code_1,
               val_concept_class                                                AS source_class_1,
               'CAP'                                                            AS vocabulary_id_1,
               cs.concept_name /* coalesce(value_description,value_alt)*/       AS concept_name_1,
               cs.concept_class_id                                              AS concept_class_1,
               'CAP Value of'                                                   AS relationship_id,
               NULL                                                             AS concept_id_2,
               variable_code                                                    AS concept_code_2,
               var_concept_class                                                AS source_class_2,
               'CAP'                                                            AS vocabulary_id_2,
               cs2.concept_name /*coalesce(variable_description,variable_alt)*/ AS concept_name_2,
               cs2.concept_class_id                                             AS concept_class_2,
                NULL                        AS invalid_reason,
                '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-01-01'                AS valid_end_date,
               cs.source_filename                                               AS filename
        FROM dev_cap.ecc_202002 e
                 JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
                      ON e.value_code = cs.concept_code
                 JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs2
                      ON e.variable_code = cs2.concept_code
        WHERE e.filename ~* 'breast'
          AND e.level_of_separation = 1
          AND cs.concept_class_id = 'CAP Value'
          AND cs2.concept_class_id = 'CAP Variable'

    ) SELECT *
        FROM tab_CAP_Value
        ORDER BY concept_code_1
        )
    ;
 -- STEP 1 'Is a' INSERT
INSERT INTO dev_vkorsik.cap_breast_2020_concept_relationship_stage_preliminary
SELECT NULL                                                             AS concept_id_1,
               cs.concept_code                                                       AS concept_code_1,
               cs.source_class                                                AS source_class_1,
               'CAP'                                                            AS vocabulary_id_1,
               cs.concept_name /* coalesce(value_description,value_alt)*/       AS concept_name_1,
               cs.concept_class_id                                              AS concept_class_1,
               'Is a'                                                   AS relationship_id,
               NULL                                                             AS concept_id_2,
                cs2.concept_code                                                 AS concept_code_2,
                cs2.source_class                                                 AS source_class_2,
               'CAP'                                                            AS vocabulary_id_2,
               cs2.concept_name /*coalesce(variable_description,variable_alt)*/ AS concept_name_2,
               cs2.concept_class_id                                             AS concept_class_2,
        NULL                        AS invalid_reason,
       '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-01-01'                AS valid_end_date,
               cs.source_filename                                               AS filename
        FROM dev_cap.ecc_202002 e
                 JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
                      ON e.value_code = cs.concept_code
                 JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs2
                      ON e.variable_code = cs2.concept_code
        WHERE e.filename ~* 'breast'
          AND e.level_of_separation = 1
          AND cs.concept_class_id = 'CAP Variable'
          AND cs2.concept_class_id = 'CAP Variable'
AND cs.concept_code  NOT in (select concept_code_1 FROM cap_breast_2020_concept_relationship_stage_preliminary)
AND cs2.concept_code  NOT in (select concept_code_2 FROM cap_breast_2020_concept_relationship_stage_preliminary);
;
-- STEP 2 'Is a' INSERT
INSERT INTO dev_vkorsik.cap_breast_2020_concept_relationship_stage_preliminary
SELECT NULL                                                             AS concept_id_1,
               cs.concept_code                                                       AS concept_code_1,
               cs.source_class                                                AS source_class_1,
               'CAP'                                                            AS vocabulary_id_1,
               cs.concept_name /* coalesce(value_description,value_alt)*/       AS concept_name_1,
               cs.concept_class_id                                              AS concept_class_1,
               'Is a'                                                   AS relationship_id,
               NULL                                                             AS concept_id_2,
                cs2.concept_code                                                 AS concept_code_2,
                cs2.source_class                                                 AS source_class_2,
               'CAP'                                                            AS vocabulary_id_2,
               cs2.concept_name /*coalesce(variable_description,variable_alt)*/ AS concept_name_2,
               cs2.concept_class_id                                             AS concept_class_2,
        NULL                        AS invalid_reason,
       '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-01-01'                AS valid_end_date,
               cs.source_filename                                               AS filename
        FROM dev_cap.ecc_202002 e
                 JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
                      ON e.value_code = cs.concept_code
                 JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs2
                      ON e.variable_code = cs2.concept_code
        WHERE e.filename ~* 'breast'
          AND e.level_of_separation = 1
          AND cs.concept_class_id = 'CAP Variable'
          AND cs2.concept_class_id = 'CAP Header'
AND NOT EXISTS (select 1
                FROM cap_breast_2020_concept_relationship_stage_preliminary cr1
    WHERE cr1.concept_code_1=cs.concept_code
    AND cr1.concept_code_2=cs2.concept_code)
;

--STEP 3 'Is a' INSERT
INSERT INTO dev_vkorsik.cap_breast_2020_concept_relationship_stage_preliminary
SELECT NULL                                                             AS concept_id_1,
               cs.concept_code                                                       AS concept_code_1,
               cs.source_class                                                AS source_class_1,
               'CAP'                                                            AS vocabulary_id_1,
               cs.concept_name /* coalesce(value_description,value_alt)*/       AS concept_name_1,
               cs.concept_class_id                                              AS concept_class_1,
               'Is a'                                                   AS relationship_id,
               NULL                                                             AS concept_id_2,
                cs2.concept_code                                                 AS concept_code_2,
                cs2.source_class                                                 AS source_class_2,
               'CAP'                                                            AS vocabulary_id_2,
               cs2.concept_name /*coalesce(variable_description,variable_alt)*/ AS concept_name_2,
               cs2.concept_class_id                                             AS concept_class_2,
        NULL                        AS invalid_reason,
       '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-01-01'                AS valid_end_date,
               cs.source_filename                                               AS filename
        FROM dev_cap.ecc_202002 e
                 JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
                      ON e.value_code = cs.concept_code
                 JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs2
                      ON e.variable_code = cs2.concept_code
        WHERE e.filename ~* 'breast'
          AND e.level_of_separation = 1
          AND cs.concept_class_id = 'CAP Variable'
          AND cs2.concept_class_id = 'CAP Value'
AND NOT EXISTS (select 1
                FROM cap_breast_2020_concept_relationship_stage_preliminary cr1
    WHERE cr1.concept_code_1=cs.concept_code
    AND cr1.concept_code_2=cs2.concept_code)
;

--STEP 4  'Is a' INSERT
INSERT INTO dev_vkorsik.cap_breast_2020_concept_relationship_stage_preliminary
SELECT NULL                                                             AS concept_id_1,
               cs.concept_code                                                       AS concept_code_1,
               cs.source_class                                                AS source_class_1,
               'CAP'                                                            AS vocabulary_id_1,
               cs.concept_name /* coalesce(value_description,value_alt)*/       AS concept_name_1,
               cs.concept_class_id                                              AS concept_class_1,
               'Is a'                                                   AS relationship_id,
               NULL                                                             AS concept_id_2,
                cs2.concept_code                                                 AS concept_code_2,
                cs2.source_class                                                 AS source_class_2,
               'CAP'                                                            AS vocabulary_id_2,
               cs2.concept_name /*coalesce(variable_description,variable_alt)*/ AS concept_name_2,
               cs2.concept_class_id                                             AS concept_class_2,
        NULL                        AS invalid_reason,
       '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-01-01'                AS valid_end_date,
               cs.source_filename                                               AS filename
        FROM dev_cap.ecc_202002 e
                 JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
                      ON e.value_code = cs.concept_code
                 JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs2
                      ON e.variable_code = cs2.concept_code
        WHERE e.filename ~* 'breast'
          AND e.level_of_separation = 1
          AND cs.concept_class_id = 'CAP Header'
          AND cs2.concept_class_id = 'CAP Value'
AND NOT EXISTS (select 1
                FROM cap_breast_2020_concept_relationship_stage_preliminary cr1
    WHERE cr1.concept_code_1=cs.concept_code
    AND cr1.concept_code_2=cs2.concept_code)

;

--STEP 5 'Is a' INSERT
INSERT INTO dev_vkorsik.cap_breast_2020_concept_relationship_stage_preliminary
SELECT NULL                                                             AS concept_id_1,
               cs.concept_code                                                       AS concept_code_1,
               cs.source_class                                                AS source_class_1,
               'CAP'                                                            AS vocabulary_id_1,
               cs.concept_name /* coalesce(value_description,value_alt)*/       AS concept_name_1,
               cs.concept_class_id                                              AS concept_class_1,
               'Is a'                                                   AS relationship_id,
               NULL                                                             AS concept_id_2,
                cs2.concept_code                                                 AS concept_code_2,
                cs2.source_class                                                 AS source_class_2,
               'CAP'                                                            AS vocabulary_id_2,
               cs2.concept_name /*coalesce(variable_description,variable_alt)*/ AS concept_name_2,
               cs2.concept_class_id                                             AS concept_class_2,
        NULL                        AS invalid_reason,
       '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-01-01'                AS valid_end_date,
               cs.source_filename                                               AS filename
        FROM dev_cap.ecc_202002 e
                 JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
                      ON e.value_code = cs.concept_code
                 JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs2
                      ON e.variable_code = cs2.concept_code
        WHERE e.filename ~* 'breast'
          AND e.level_of_separation = 1
         AND cs.concept_class_id in ( 'CAP Variable', 'CAP Header')
        AND NOT EXISTS (select 1
                FROM cap_breast_2020_concept_relationship_stage_preliminary cr1
    WHERE cr1.concept_code_1=cs.concept_code
    AND cr1.concept_code_2=cs2.concept_code);
;

-- 'Derives from'
INSERT INTO dev_vkorsik.cap_breast_2020_concept_relationship_stage_preliminary
select         NULL                                                             AS concept_id_1,
               cs.concept_code                                                       AS concept_code_1,
               cs.source_class                                                AS source_class_1,
               'CAP'                                                            AS vocabulary_id_1,
               cs.concept_name /* coalesce(value_description,value_alt)*/       AS concept_name_1,
               cs.concept_class_id                                              AS concept_class_1,
               'Derives from'                                                   AS relationship_id,
               NULL                                                             AS concept_id_2,
                cs2.concept_code                                                 AS concept_code_2,
                cs2.source_class                                                 AS source_class_2,
               'CAP'                                                            AS vocabulary_id_2,
               cs2.concept_name /*coalesce(variable_description,variable_alt)*/ AS concept_name_2,
               cs2.concept_class_id                                             AS concept_class_2,
        NULL                        AS invalid_reason,
       '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-01-01'                AS valid_end_date,
               cs.source_filename                                               AS filename
FROM  dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs2
ON cs2.concept_code='Breast.DCIS.Res.211_3.002.001.REL_sdcFDF'
WHERE cs.source_filename ='Breast.DCIS.Res.211_3.002.001.REL_sdcFDF'

UNION ALL

select NULL                                                             AS concept_id_1,
       cs.concept_code                                                       AS concept_code_1,
               cs.source_class                                                AS source_class_1,
               'CAP'                                                            AS vocabulary_id_1,
               cs.concept_name /* coalesce(value_description,value_alt)*/       AS concept_name_1,
               cs.concept_class_id                                              AS concept_class_1,
               'Derives from'                                                   AS relationship_id,
               NULL                                                             AS concept_id_2,
                cs2.concept_code                                                 AS concept_code_2,
                cs2.source_class                                                 AS source_class_2,
               'CAP'                                                            AS vocabulary_id_2,
               cs2.concept_name /*coalesce(variable_description,variable_alt)*/ AS concept_name_2,
               cs2.concept_class_id                                             AS concept_class_2,
        NULL                        AS invalid_reason,
       '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-01-01'                AS valid_end_date,
               cs.source_filename                                               AS filename
FROM  dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs2
ON cs2.concept_code='Breast.DCIS.Bx.360_1.001.001.REL_sdcFDF'
WHERE cs.source_filename ='Breast.DCIS.Bx.360_1.001.001.REL_sdcFDF'

UNION ALL

select NULL                                                             AS concept_id_1,
       cs.concept_code                                                       AS concept_code_1,
               cs.source_class                                                AS source_class_1,
               'CAP'                                                            AS vocabulary_id_1,
               cs.concept_name /* coalesce(value_description,value_alt)*/       AS concept_name_1,
               cs.concept_class_id                                              AS concept_class_1,
               'Derives from'                                                   AS relationship_id,
               NULL                                                             AS concept_id_2,
                cs2.concept_code                                                 AS concept_code_2,
                cs2.source_class                                                 AS source_class_2,
               'CAP'                                                            AS vocabulary_id_2,
               cs2.concept_name /*coalesce(variable_description,variable_alt)*/ AS concept_name_2,
               cs2.concept_class_id                                             AS concept_class_2,
        NULL                        AS invalid_reason,
       '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-01-01'                AS valid_end_date,
               cs.source_filename                                               AS filename
FROM  dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs2
ON cs2.concept_code='Breast.Invasive.Bx.362_1.001.001.REL_sdcFDF'
WHERE cs.source_filename ='Breast.Invasive.Bx.362_1.001.001.REL_sdcFDF'

UNION ALL

select NULL                                                             AS concept_id_1,
       cs.concept_code                                                       AS concept_code_1,
               cs.source_class                                                AS source_class_1,
               'CAP'                                                            AS vocabulary_id_1,
               cs.concept_name /* coalesce(value_description,value_alt)*/       AS concept_name_1,
               cs.concept_class_id                                              AS concept_class_1,
               'Derives from'                                                   AS relationship_id,
               NULL                                                             AS concept_id_2,
                cs2.concept_code                                                 AS concept_code_2,
                cs2.source_class                                                 AS source_class_2,
               'CAP'                                                            AS vocabulary_id_2,
               cs2.concept_name /*coalesce(variable_description,variable_alt)*/ AS concept_name_2,
               cs2.concept_class_id                                             AS concept_class_2,
        NULL                        AS invalid_reason,
       '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-01-01'                AS valid_end_date,
               cs.source_filename                                               AS filename
FROM  dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs2
ON cs2.concept_code='Breast.Invasive.Res.189_4.002.001.REL_sdcFDF'
WHERE cs.source_filename ='Breast.Invasive.Res.189_4.002.001.REL_sdcFDF'

UNION ALL

select NULL                                                             AS concept_id_1,
       cs.concept_code                                                       AS concept_code_1,
               cs.source_class                                                AS source_class_1,
               'CAP'                                                            AS vocabulary_id_1,
               cs.concept_name /* coalesce(value_description,value_alt)*/       AS concept_name_1,
               cs.concept_class_id                                              AS concept_class_1,
               'Derives from'                                                   AS relationship_id,
               NULL                                                             AS concept_id_2,
                cs2.concept_code                                                 AS concept_code_2,
                cs2.source_class                                                 AS source_class_2,
               'CAP'                                                            AS vocabulary_id_2,
               cs2.concept_name /*coalesce(variable_description,variable_alt)*/ AS concept_name_2,
               cs2.concept_class_id                                             AS concept_class_2,
        NULL                        AS invalid_reason,
       '1970-01-01'                AS valid_start_date, -- AT LEAST FOR NOW
               '2099-01-01'                AS valid_end_date,
               cs.source_filename                                               AS filename
FROM  dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
JOIN dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs2
ON cs2.concept_code='Breast.Bmk.169_1.006.001.REL_sdcFDF'
WHERE cs.source_filename ='Breast.Bmk.169_1.006.001.REL_sdcFDF'






SELECT distinct concept_id_1,
                concept_code_1,
                source_class_1,
                vocabulary_id_1,
                concept_name_1,
                concept_class_1,
                relationship_id,
                concept_id_2,
                concept_code_2,
                source_class_2,
                vocabulary_id_2,
                concept_name_2,
                concept_class_2,
                invalid_reason,
                valid_start_date,
                valid_end_date,
                filename
FROM dev_vkorsik.cap_breast_2020_concept_relationship_stage_preliminary
;
INSERT INTO dev_vkorsik.concept_relationship_stage (
                                                    concept_id_1,
                                                    concept_id_2,
                                                    concept_code_1,
                                                    concept_code_2,
                                                    vocabulary_id_1,
                                                    vocabulary_id_2,
                                                    relationship_id,
                                                    valid_start_date,
                                                    valid_end_date,
                                                    invalid_reason
                                                    )
                                                    SELECT concept_id_1::int,
                                                           concept_id_2::int,
                                                           concept_code_1,
                                                            concept_code_2,
                                                           vocabulary_id_1,
                                                          vocabulary_id_2,
                                                           relationship_id,
                                                           valid_start_date::date,
                                                           valid_end_date::date,
                                                           invalid_reason
FROM cap_breast_2020_concept_relationship_stage_preliminary;

SELECT concept_id_1,
       concept_id_2,
       concept_code_1,
       cs.concept_name,
        relationship_id,
       concept_code_2,
        cs2.concept_name,
       vocabulary_id_1,
       vocabulary_id_2,
       crs.valid_start_date,
       crs.valid_end_date,
       crs.invalid_reason
FROM dev_vkorsik.concept_relationship_stage crs
JOIN concept_stage cs
ON crs.concept_code_1=cs.concept_code
JOIN concept_stage cs2
ON crs.concept_code_2=cs2.concept_code
ORDER BY cs.concept_name
;
-- to check existence of more then one direct relationchip
SELECT distinct *
FROM dev_vkorsik.cap_breast_2020_concept_relationship_stage_preliminary
WHERE concept_code_1 IN (SELECT concept_code_1
    FROM cap_breast_2020_concept_relationship_stage_preliminary
WHERE  relationship_id = 'Derives from'
GROUP BY concept_code_1
    HAVING count(distinct concept_code_2)>1
    )
;


-- check af multiple relationships
SELECT distinct concept_code,concept_name,concept_class_id
FROM cap_breast_2020_concept_stage_preliminary c
WHERE NOT EXISTS (select 1
                FROM cap_breast_2020_concept_relationship_stage_preliminary cr1
    WHERE cr1.concept_code_1=c.concept_code)
ORDER BY concept_name
;
-- for only one relationship created
SELECT *
FROM cap_breast_2020_concept_relationship_stage_preliminary
WHERE concept_code_1 IN
(SELECT concept_code_1
    FROM cap_breast_2020_concept_relationship_stage_preliminary
    GROUP BY concept_code_1
    having count(relationship_id)=1)
;
-- Check for uniqueness of pair concept_code_1, concept_code_2
select concept_code_1, concept_code_2
from dev_vkorsik.cap_breast_2020_concept_relationship_stage_preliminary
group by concept_code_1, concept_code_2 having count(1) > 1
;

--QA for stage tables
--all the selects below should return null


select relationship_id from cap_breast_2020_concept_relationship_stage_preliminary
except
select relationship_id from relationship;


select concept_class_id from cap_breast_2020_concept_stage_preliminary
except
select concept_class_id from concept_class;


select domain_id from cap_breast_2020_concept_stage_preliminary
except
select domain_id from domain;


select vocabulary_id from cap_breast_2020_concept_stage_preliminary
except
select vocabulary_id from vocabulary;


select * from cap_breast_2020_concept_stage_preliminary where concept_name is null or domain_id is null or concept_class_id is null or concept_code is null or valid_start_date is null or valid_end_date is null
or valid_end_date is null or concept_name<>trim(concept_name) or concept_code<>trim(concept_code);

select concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id  from cap_breast_2020_concept_relationship_stage_preliminary
group by concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id  having count(*)>1;

select concept_code, vocabulary_id  from cap_breast_2020_concept_stage_preliminary
group by concept_code, vocabulary_id  having count(*)>1;


select * From cap_breast_2020_concept_relationship_stage_preliminary where valid_start_date is null or valid_end_date is null or (invalid_reason is null and valid_end_date::date<>to_date ('20991231', 'yyyymmdd'))
or (invalid_reason is not null and valid_end_date::date=to_date ('20991231', 'yyyymmdd'));

select * from cap_breast_2020_concept_stage_preliminary where valid_start_date is null or valid_end_date is null
or (invalid_reason is null and valid_end_date::date <> to_date ('20991231', 'yyyymmdd') and vocabulary_id not in ('CPT4', 'HCPCS', 'ICD9Proc'))
or (invalid_reason is not null and valid_end_date::date = to_date ('20991231', 'yyyymmdd'))
or valid_start_date::date < to_date ('19000101', 'yyyymmdd'); -- some concepts have a real date < 1970
;

select relationship_id from cap_breast_2020_concept_relationship_stage_preliminary
except
select relationship_id from relationship;


select concept_class_id from cap_breast_2020_concept_stage_preliminary
except
select concept_class_id from concept_class;


select domain_id from cap_breast_2020_concept_stage_preliminary
except
select domain_id from domain;


select vocabulary_id from cap_breast_2020_concept_stage_preliminary
except
select vocabulary_id from vocabulary;


select * from cap_breast_2020_concept_stage_preliminary where concept_name is null or domain_id is null or concept_class_id is null or concept_code is null or valid_start_date is null or valid_end_date is null
or valid_end_date is null or concept_name<>trim(concept_name) or concept_code<>trim(concept_code);

select concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id  from cap_breast_2020_concept_relationship_stage_preliminary
group by concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id  having count(*)>1;

select concept_code, vocabulary_id  from cap_breast_2020_concept_stage_preliminary
group by concept_code, vocabulary_id  having count(*)>1;



SELECT crm.*
FROM cap_breast_2020_concept_relationship_stage_preliminary crm
	 LEFT JOIN concept c1 ON c1.concept_code = crm.concept_code_1 AND c1.vocabulary_id = crm.vocabulary_id_1
	 LEFT JOIN cap_breast_2020_concept_stage_preliminary cs1 ON cs1.concept_code = crm.concept_code_1 AND cs1.vocabulary_id = crm.vocabulary_id_1
	 LEFT JOIN concept c2 ON c2.concept_code = crm.concept_code_2 AND c2.vocabulary_id = crm.vocabulary_id_2
	 LEFT JOIN cap_breast_2020_concept_stage_preliminary cs2 ON cs2.concept_code = crm.concept_code_2 AND cs2.vocabulary_id = crm.vocabulary_id_2
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







-- TODO reverse relationships need to be created
--dev_lexicon - for Nebraska_Lexicon mappings
select distinct cs.concept_code,cs.concept_name, cs.concept_class_id, cs.alternative_concept_name, n.*,
                CASE WHEN length(n.concept_name)>20 then 'CHECK' else '' END AS comment
FROM dev_vkorsik.cap_breast_2020_concept_stage_preliminary cs
left JOIN  dev_lexicon.concept n
ON trim(lower(regexp_replace(cs.alternative_concept_name,'[[:punct:]]|\s','','g')))
    = trim(lower(regexp_replace(n.concept_name,'\sposition|[[:punct:]]|\s','','g')))
AND n.vocabulary_id='Nebraska Lexicon'
AND n.invalid_reason IS NULL
ORDER BY cs.concept_name
;

SELECT distinct *
FROM dev_vkorsik.cap_breast_2020_concept_relationship_stage_preliminary
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
FROM dev_lexicon.concept n
WHERE n.vocabulary_id='Nebraska Lexicon'
AND n.concept_name ~*'Weak'
/* AND n.concept_name ~*'Grade'*/
AND n.invalid_reason is NULL
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
AND n.concept_id = 3067438-- from above select
/* AND n.concept_name ~*'skin'*/
AND n.invalid_reason is NULL
;



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
                    d.*


    FROM  dev_vkorsik.cap_breast_2020_concept_stage_preliminary s --source table
        /*LEFT*/  JOIN all_concepts ac
              ON trim(lower(regexp_replace(s.alternative_concept_name,'[[:punct:]]|\s','','g')))
                                           = trim(lower(regexp_replace(ac.name,'\sposition|[[:punct:]]|\s','','g')))
/*LEFT*/ join DEV_LEXICON.CONCEPT D
ON d.concept_id=ac.concept_id
;
