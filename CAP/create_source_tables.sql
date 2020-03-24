--source_table preparation
--current version of breast source

-- Tables created by scripts  below do not contain levels_of_sepatation;
-- The data about levels of separation comes from primarily uploaded source tables;
DROP TABLE IF EXISTS dev_cap.cap_prepared_breast_2020_source;
CREATE UNLOGGED TABLE dev_cap.cap_prepared_breast_2020_source WITH OIDS AS
    (-- primary step - full hierarchical names represented from bottom item (stated in source as value) to the top item with step_size=1 (for level_of_separation)
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

--2019 -- now we integrate this version as fundamental to emulate the vocab update process;
DROP TABLE IF EXISTS dev_cap.cap_prepared_breast_2019_source;
CREATE UNLOGGED TABLE dev_cap.cap_prepared_breast_2019_source WITH OIDS AS
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

-- Load into concept_stage from cap_breast_2019_concept_stage_preliminary
DROP TABLE IF EXISTS dev_cap.cap_breast_2019_concept_stage_preliminary;
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
        WHERE source_class <> 'DI' -- to exclude them from concept_stage because of lack of sense
        ORDER BY concept_name, concept_code, concept_class_id
    )
;
DROP TABLE IF EXISTS dev_cap.cap_breast_2020_concept_stage_preliminary;
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
        WHERE source_class <> 'DI' -- to exclude them from concept_stage because of lack of sense
        ORDER BY concept_name, concept_code, concept_class_id
    )
;
