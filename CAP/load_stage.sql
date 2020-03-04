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
-- cap_prepared_breast_2020_source CREATION is used to preserve data of source_code by concatenation of names from the lowest term(value) to it's ancestor
-- DROP TABLE dev_vkorsik.cap_prepared_breast_2020_source
CREATE TABLE dev_vkorsik.cap_prepared_breast_2020_source WITH OIDS AS
    (
        with tab_val as
            (
            SELECT distinct value_code                                           as source_code
                          , val_concept_class                                    as source_class
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
                 , source_filename
            FROM tab_var

            UNION ALL

            SELECT source_code
                 , source_class
                 , source_description
                 , source_filename
            FROM tab_val

            UNION ALL

         SELECT source_code
                 , source_class
                 , source_description
                 , source_filename
            FROM tab_filename

        )
                                        SELECT distinct source_code, source_class, source_description, source_filename
                                        FROM tab_resulting
                                        ORDER BY source_description, source_code, source_filename, source_class
    )
;
SELECT source_code, source_class, source_description, source_filename
FROM dev_vkorsik.cap_prepared_breast_2020_source
;

-- 00 dev_vkorsik.cap_prepared_breast_2020_source this table is preliminary generated concept_stage the diff
-- between it and dev_vkorsik.cap_prepared_breast_2020_source is in the ansence of filename  field in 1st

--todo  concept_name~*'Comment(s)' looks not like real variable

-- DROP TABLE dev_vkorsik.cap_breast_2020_concept_stage_preliminary
CREATE TABLE dev_vkorsik.cap_breast_2020_concept_stage_preliminary WITH OIDS AS
    (
        SELECT NULL                        AS concept_id,
               source_code                 AS concept_code,
               source_description          AS concept_name,
               CASE WHEN source_description ~* '\|' THEN split_part(source_description,'|',1) || '|' || split_part(source_description,'|',2)
                    ELSE source_description END AS alternative_concept_name,
     CASE
         WHEN source_class in ('DI', 'CAP Protocol')       or    (source_class='S'       AND source_description !~*'^Distance')  THEN 'Observation' -- todo How to treat 'CAP Protocol' in domain_id?
         WHEN source_class = 'LI' AND source_description !~* '^\.*other|^\.*specif.*' THEN  'Meas Value'
         ELSE 'Measurment'
         END                               AS domain_id,
               'CAP'                       AS vocabulary_id,
     CASE
         WHEN source_class = 'S'    AND source_description !~*'^Distance'                                     THEN 'CAP Header'
         WHEN source_class = 'LI' AND source_description !~* '^\.*other|^\.*specif.*' THEN 'CAP Value' -- ^.*expla.* todo do we need them to be variables
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
        ORDER BY concept_name, concept_code, concept_class_id
    )
;

SELECT --concept_id,
       concept_code,
       concept_name,
       alternative_concept_name,
       domain_id,
      -- vocabulary_id,
       concept_class_id,
      -- standard_concept,
      -- invalid_reason,
     --  valid_start_date,
      -- valid_end_date,
       source_filename
      -- source_class
FROM dev_vkorsik.cap_breast_2020_concept_stage_preliminary
/*WHERE concept_name ~*'^\.*specif\.*'
AND  concept_name !~*'clock'*/
ORDER BY alternative_concept_name,source_filename
--AND concept_name  !~* '^note'
;

