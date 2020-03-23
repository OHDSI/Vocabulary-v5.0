--source_table preparation
--current version of breast source
-- cap_prepared_breast_2020_source CREATION is used to preserve data of source_code by concatenation of names from the lowest term(value) to it's ancestor
-- 2020 version
-- The scripts below do not contain levels_of_sepatation;
DROP TABLE IF EXISTS dev_cap.cap_prepared_breast_2020_source;
CREATE UNLOGGED TABLE dev_cap.cap_prepared_breast_2020_source WITH OIDS AS
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



--checks
-- TODO '16079 CLINICAL and all it's children are not incorporated in 2020, the same is for some Histological entities (eg Squamous cell carcinoma)
-- TO check which codes are not included in 2020 version
SELECT *
FROM cap_prepared_breast_2019_source
WHERE source_code IN (
SELECT distinct source_code
FROM dev_cap.cap_prepared_breast_2019_source e
EXCEPT
SELECT distinct source_code
FROM dev_cap.cap_prepared_breast_2020_source e
    )
;
-- To check which codes are newly ingested in 2020ver
SELECT *
FROM cap_prepared_breast_2020_source
WHERE source_code IN (
    SELECT distinct source_code
    FROM dev_cap.cap_prepared_breast_2020_source e
        EXCEPT
    SELECT distinct source_code
    FROM dev_cap.cap_prepared_breast_2019_source
    )
;
-- to explain how the codes are used across versions
-- Do the same codes with crucially different names exist? - NO
SELECT *
FROM dev_cap.cap_prepared_breast_2019_source e
join  dev_cap.cap_prepared_breast_2020_source ee
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
FROM dev_cap.cap_prepared_breast_2019_source e
join  dev_cap.cap_prepared_breast_2020_source ee
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


SELECT distinct *
FROM cap_breast_2020_concept_stage_preliminary
 WHERE source_class='S'
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
          FROM dev_cap.cap_breast_2020_concept_stage_preliminary
      )
;

--5 rows 're retrieved because of manual creation of them
SELECT distinct concept_code as code
FROM  dev_cap.cap_breast_2020_concept_stage_preliminary

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
