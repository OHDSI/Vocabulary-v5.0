
--Review COVID-19 mappings
SELECT DISTINCT
    concept_id,
    concept_name,
    domain_id,
    vocabulary_id,
    concept_class_id,
    standard_concept,
    concept_code
FROM dev_meddra.concept AS c
WHERE lower (concept_name)  ~* 'sars(?!(tedt|aparilla))|^cov(?!(er|onia|aWound|idien))|cov$|^ncov|ncov$|corona(?!(l|ry|ries))|severe acute|covid(?!ien)'
  AND lower(concept_name) !~* '( |^)LASSARS' AND vocabulary_id='MedDRA' AND NOT EXISTS (SELECT 1 FROM dev_meddra.meddra_mapped AS m WHERE m.source_code =  CAST(c.concept_code AS varchar))

----Review COVID-19 mappings with hierarchy
WITH tab as (
    SELECT ROW_NUMBER() OVER (
        order by source_code,source_code_description,to_value nulls first,CASE
                                                                              WHEN data_source = 'MedDRAtoSNOMED'
                                                                                  then 'M-S'
                                                                              WHEN data_source = 'SMOMEDtoMedDRA'
                                                                                  then 'S-M'
                                                                              WHEN data_source = 'MedDRAtoSNOMED|SMOMEDtoMedDRA'
                                                                                  then 'M-S|S-M'
                                                                              else customer end,target_concept_id ) as new_id,
           id::int as old_id,
           source_code,
           source_code_description,
           CASE
               WHEN data_source = 'MedDRAtoSNOMED' then 'M-S'
               WHEN data_source = 'SMOMEDtoMedDRA' then 'S-M'
               WHEN data_source = 'MedDRAtoSNOMED|SMOMEDtoMedDRA' then 'M-S|S-M'
               else customer end                                                                                    as customer,
           jj_counts,
           gemini_counts,
           counts,
           to_value,
           comments,
           target_concept_id,
           target_concept_code,
           target_concept_name,
           target_concept_class_id,
           CASE
               WHEN m.target_standard_concept = 'S' then 'Standard'
               else m.target_standard_concept
               end                                                                                                  as target_standard_concept,

           CASE
               WHEN m.target_invalid_reason is null then 'Valid'
               else m.target_invalid_reason
               end                                                                                                  as target_invalid_reason,
           target_domain_id,
           target_vocabulary_id,
           CASE
               WHEN (m.source_code, coalesce(m.to_value, 'X')) IN ((SELECT DISTINCT source_code, coalesce(to_value, 'X')
                                                                    FROM dev_meddra.MedDRA_environment_mapping_combined
                                                                    where (lower(source_code), coalesce(to_value, 'X')) IN
                                                                          (SELECT DISTINCT lower(source_code), coalesce(to_value, 'X')
                                                                           FROM dev_meddra.MedDRA_environment_mapping_combined
                                                                           group by 1, 2
                                                                           having count(distinct coalesce(data_source, customer)) > 1)
                                                                      AND (lower(source_code), target_concept_id) not IN
                                                                          (SELECT DISTINCT lower(source_code), target_concept_id
                                                                           FROM dev_meddra.MedDRA_environment_mapping_combined
                                                                           group by 1, 2
                                                                           having count(*) > 1))) then 1
               else null
               end                                                                                                  as dedup_flag,

           CASE
               WHEN lower(m.source_code_description) IN (SELECT lower(source_code_description)
                                                         FROM MedDRA_environment_mapping_combined
                                                         group by 1
                                                         having count(distinct source_code) > 1) then 1
               else null
               end                                                                                                  as alternative_hierarchy
    FROM dev_meddra.meddra_environment_mapping_combined m
)
,
     tabb as ( -- short ancestry buildung

SELECT
       new_id,
       old_id,
       string_agg( distinct concat(  ccc.concept_name , 'SOC: '||cc.concept_name,'='),'>') as short_ancestry,
      q. source_code,
      c.concept_name as    source_code_description,
       customer,
       s.jj_counts,
     s.  gemini_counts,
     s.  counts,
       to_value,
       comments,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_concept_class_id,
       target_standard_concept,
       target_invalid_reason,
       target_domain_id,
       target_vocabulary_id,
       dedup_flag,
       alternative_hierarchy
FROM tab q
    JOIN MedDRA_environment_source s
on q.source_code=s.source_code
    JOIN devv5.concept c
on s.source_code=c.concept_code
and c.vocabulary_id='MedDRA'
--and lower (c.concept_name)  ~* 'sars(?!(tedt|aparilla))|^cov(?!(er|onia|aWound|idien))|cov$|^ncov|ncov$|corona(?!(l|ry|ries))|severe acute|covid(?!ien)'
--and lower(c.concept_name) !~* '( |^)LASSARS' and NOT EXISTS (SELECT 1 FROM dev_meddra.meddra_mapped AS mmm WHERE mmm.source_code =  CAST(c.concept_code AS varchar))
LEFT JOIN devv5.concept_ancestor ca
on ca.descendant_concept_id=c.concept_id
LEFT JOIN devv5.concept cc
on ca.ancestor_concept_id=cc.concept_id
and cc.concept_class_id in ('SOC')
LEFT JOIN devv5.concept ccc
on ca.ancestor_concept_id=ccc.concept_id
and min_levels_of_separation in (1)
group by   new_id,
       old_id,
    q.source_code,
      c.concept_name,
       customer,
   s.    jj_counts,
     s.  gemini_counts,
    s.   counts,
       to_value,
       comments,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_concept_class_id,
       target_standard_concept,
       target_invalid_reason,
       target_domain_id,
       target_vocabulary_id,
       dedup_flag,
       alternative_hierarchy)
SELECT new_id,
       old_id,
 string_agg ( cc.concept_class_id||': '||cc.concept_name,'=>' order by min_levels_of_separation asc) as ancestry,
 regexp_replace(short_ancestry,'^\=>|\=$','','gi') as short_ancestry  ,
       c.concept_class_id as source_class_id,
       c.standard_concept as source_standard_concept,
       source_code,
       source_code_description,
       customer,
       jj_counts,
       gemini_counts,
       counts,
       to_value,
             CASE WHEN (source_code,coalesce(to_value,'x'),customer) in (
    SELECT source_code,coalesce(to_value,'x'),customer
    FROM tabb
    GROUP BY source_code,coalesce(to_value,'x'),customer
    HAVING count(*) > 1) then 1 else null end as OtoM,
       comments,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_concept_class_id,
       target_standard_concept,
       target_invalid_reason,
       target_domain_id,
       target_vocabulary_id,
       dedup_flag,
       alternative_hierarchy
FROM tabb a
    JOIN devv5.concept c
on a.source_code=c.concept_code
and c.vocabulary_id='MedDRA'
LEFT JOIN devv5.concept_ancestor ca
on c.concept_id=ca.descendant_concept_id
and ca.min_levels_of_separation>0
LEFT JOIN devv5.concept cc
on ca.ancestor_concept_id=cc.concept_id
and cc.vocabulary_id='MedDRA'
group by new_id,
       old_id,
       regexp_replace(short_ancestry,'^\=>|\=$','','gi'),
       source_code,
       source_code_description,
           c.concept_class_id,
           c.standard_concept,
       customer,
       CASE WHEN (source_code,coalesce(to_value,'x'),customer) in (
    SELECT source_code,coalesce(to_value,'x'),customer
    FROM tabb
    GROUP BY source_code,coalesce(to_value,'x'),customer
    HAVING count(*) > 1) then 1 else null end,
       jj_counts,
       gemini_counts,
       counts,
       to_value,
       comments,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_concept_class_id,
       target_standard_concept,
       target_invalid_reason,
       target_domain_id,
       target_vocabulary_id,
       dedup_flag,
       alternative_hierarchy
ORDER BY old_id asc nulls last, new_id asc;





-- Insert mappings to CRM
with mapping AS
    (
        SELECT DISTINCT source_code AS concept_code_1,
               target_concept_code AS concept_code_2,
               'MedDRA' AS vocabulary_id_1,
               target_vocabulary_id AS vocabulary_id_2,
               CASE WHEN to_value ~* 'value' THEN 'Maps to value'
                    WHEN to_value ~* 'Is a' THEN 'Is a'
                    WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                   ELSE 'Maps to' END AS relationship_id,
               current_date AS valid_start_date,
               to_date('20991231','yyyymmdd') AS valid_end_date,
               NULL AS invalid_reason
        FROM dev_meddra.meddra_mapped
        WHERE target_concept_id != 0
    )

INSERT INTO concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
    (SELECT concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id,
            valid_start_date,
            valid_end_date,
            invalid_reason
     FROM mapping AS m
        WHERE (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id)
                  NOT IN (SELECT concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id FROM dev_meddra.concept_relationship_manual)
    );


/*
Check of current and prerelise mapping snomedtomeddra and meddratosnomed
*/

with first as (
                SELECT a.*, 'mdr_from_sources' as schema
                FROM (   SELECT --concept_id,
                                meddra_code,
                                replace(meddra_llt, '''''', '''') AS meddra_llt,
                                snomed_code,
                                replace (snomed_ct_fsn, '''''', '''') AS snomed_ct_fsn

                         FROM sources.meddra_mapsto_snomed

                         EXCEPT

                         SELECT --concept_id,
                                meddra_code,
                                replace(meddra_llt, '''''', '''') AS meddra_llt,
                                snomed_ct_code,
                                replace (snomed_ct_fsn, '''''', '''') AS snomed_ct_fsn

                         FROM dev_meddra.meddratosnomedmap
                     ) as a ),

second as (

                SELECT b.*, 'mdr_prerelise' as schema
                FROM (   SELECT --concept_id,
                               meddra_code,
                               replace(meddra_llt, '''''', '''') AS meddra_llt,
                               snomed_ct_code,
                               replace (snomed_ct_fsn, '''''', '''') AS snomed_ct_fsn

                         FROM dev_meddra.meddratosnomedmap

                         EXCEPT

                         SELECT --concept_id,
                                meddra_code,
                                replace(meddra_llt, '''''', '''') AS meddra_llt,
                                snomed_code,
                                replace (snomed_ct_fsn, '''''', '''') AS snomed_ct_fsn

                         FROM sources.meddra_mapsto_snomed
                     ) as b)
SELECT *
from first
UNION ALL
SELECT *
from second;


with first as (
                SELECT a.*, 'mdr_from_sources' as schema
                FROM (   SELECT --concept_id,
                                snomed_code,
                                replace (snomed_ct_fsn, '''''', '''') AS snomed_ct_fsn,
                                meddra_code,
                                replace(meddra_llt, '''''', '''') AS meddra_llt
                         FROM sources.meddra_mappedfrom_snomed

                         EXCEPT

                         SELECT --concept_id,
                                snomed_ct_code,
                                replace (snomed_ct_fsn, '''''', '''') AS snomed_ct_fsn,
                                meddra_code,
                                replace(meddra_llt, '''''', '''') AS meddra_llt
                         FROM dev_meddra.snomedtomeddramap
                     ) as a ),

second as (

                SELECT b.*, 'mdr_current_mapping' as schema
                FROM (   SELECT --concept_id,
                               snomed_ct_code,
                               replace (snomed_ct_fsn, '''''', '''') AS snomed_ct_fsn,
                                meddra_code,
                                replace(meddra_llt, '''''', '''') AS meddra_llt
                         FROM dev_meddra.snomedtomeddramap

                         EXCEPT

                         SELECT --concept_id,
                                snomed_code,
                                replace (snomed_ct_fsn, '''''', '''') AS snomed_ct_fsn,
                                meddra_code,
                                replace(meddra_llt, '''''', '''') AS meddra_llt
                         FROM sources.meddra_mappedfrom_snomed
                     ) as b)
SELECT *
from first
UNION ALL
SELECT *
from second;




   -- UNION ALL
   -- SELECT meddra_code, meddra_llt, snomed_ct_code, snomed_ct_fsn
   -- FROM snomedtomeddramap
   -- WHERE meddra_code NOT IN (SELECT source_code FROM meddra_environment_source)



--Source table for refresh
--Flags show different reasons for refresh
CREATE TABLE meddra_source AS (
with previous_mappings AS
    (SELECT concept_id_1, c.standard_concept, array_agg(concept_id_2 ORDER BY concept_id_2 DESC) AS old_maps_to
        FROM devv5.concept_relationship cr
        JOIN devv5.concept c
        ON cr.concept_id_1 = c.concept_id
        AND c.vocabulary_id = 'MedDRA'
        --Previous mapping, available in devv5
        AND cr.relationship_id IN ('Maps to', 'Maps to value')
        AND cr.invalid_reason IS NULL

        GROUP BY concept_id_1, standard_concept
        ),

     current_mapping AS
         (
        SELECT concept_id_1, array_agg(concept_id_2 ORDER BY concept_id_2 DESC) AS new_maps_to
        FROM dev_meddra.concept_relationship cr
        JOIN dev_meddra.concept c
        ON cr.concept_id_1 = c.concept_id
        AND c.vocabulary_id = 'MedDRA'
        --Previous mapping, available in devv5
        AND cr.relationship_id IN ('Maps to', 'Maps to value')
        AND cr.invalid_reason IS NULL

        GROUP BY concept_id_1
        )


SELECT DISTINCT
                replace (c.concept_name, 'Deprecated ', '') AS source_concept_name_clean,
                c.concept_name AS       source_concept_name,
                c.concept_code AS       source_concept_code,
                c.concept_class_id AS   source_concept_class_id,
                c.invalid_reason AS     source_invalid_reason,
                c.domain_id AS          source_domain_id,

                NULL::varchar AS relationship_id,

                CASE WHEN previous_mappings.concept_id_1 IS NOT NULL    --Mapping was available
                          AND NOT EXISTS (SELECT concept_id_1 FROM dev_meddra.concept_relationship lcr
                          JOIN dev_meddra.concept lc
                          ON lc.concept_id = lcr.concept_id_1 AND lc.vocabulary_id = 'MedDRA'
                          WHERE lcr.relationship_id IN ('Maps to', 'Maps to value') AND lcr.invalid_reason IS NULL
                                AND lcr.concept_id_1 = c.concept_id --Concept_id never changes
                              )
                          AND previous_mappings.standard_concept = 'S'
                    THEN 'Was Standard and don''t have mapping now'

                    WHEN previous_mappings.concept_id_1 IS NOT NULL    --Mapping was available
                          AND NOT EXISTS (SELECT concept_id_1 FROM dev_meddra.concept_relationship lcr
                          JOIN dev_meddra.concept lc
                          ON lc.concept_id = lcr.concept_id_1 AND lc.vocabulary_id = 'MedDRA'
                          WHERE lcr.relationship_id IN ('Maps to', 'Maps to value') AND lcr.invalid_reason IS NULL
                                AND lcr.concept_id_1 = c.concept_id --Concept_id never changes
                              )
                          AND previous_mappings.standard_concept != 'S'
                    THEN 'Was non-Standard but mapped and don''t have mapping now'

                WHEN previous_mappings.concept_id_1 IN
                    (SELECT cc.concept_id FROM dev_meddra.concept_relationship_manual crm
                    JOIN devv5.concept c
                    ON crm.concept_code_2 = c.concept_code AND crm.vocabulary_id_2 = c.vocabulary_id
                    JOIN devv5.concept cc
                    ON cc.concept_code = crm.concept_code_1 AND cc.vocabulary_id = 'MedDRA'
                    WHERE c.standard_concept IS NULL) THEN 'Mapping changed according to changes in other vocabs'

                --mapping changed
                WHEN previous_mappings.old_maps_to != current_mapping.new_maps_to THEN 'Mapping changed'

                WHEN c.concept_code NOT IN (SELECT concept_code FROM devv5.concept WHERE vocabulary_id = 'MedDRA')
                                THEN 'New and not-mapped'
                                ELSE 'Not mapped' END AS flag,
                NULL::int AS target_concept_id,
                NULL::varchar AS target_concept_code,
                NULL::varchar AS target_concept_name,
                NULL::varchar AS target_concept_class_id,
                NULL::varchar AS target_standard_concept,
                NULL::varchar AS target_invalid_reason,
                NULL::varchar AS target_domain_id,
                NULL::varchar AS target_vocabulary_id

FROM dev_meddra.concept c
LEFT JOIN previous_mappings
ON c.concept_id = previous_mappings.concept_id_1
LEFT JOIN current_mapping
ON c.concept_id = current_mapping.concept_id_1
    --new concept_relationship
LEFT JOIN dev_meddra.concept_relationship cr
ON c.concept_id = cr.concept_id_1
AND cr.relationship_id IN ('Maps to', 'Maps to value')
AND cr.invalid_reason IS NULL

--TODO: implement diff logic
/*
 WHERE c.concept_id / concept_code NOT IN (SELECT FROM _mapped table)
 */

--Conditions show options for specific concept classes refreshes
WHERE cr.concept_id_2 IS NULL
AND (c.standard_concept IS NULL OR c.invalid_reason = 'D') AND c.vocabulary_id = 'MedDRA'
AND c.concept_class_id IN ('Lab Test'
                           --,'Survey', 'Answer', 'Clinical Observation' --TODO: postponed for now
                           )

ORDER BY replace (c.concept_name, 'Deprecated ', ''), c.concept_code)
;

--One time executed code to run and take concepts from concept_relationship_manual
--TODO: There are a lot of non-deprecated relationships to non-standard (in dev_loinc) concepts.
--! Not anymore
-- Bring the list to the manual file.
-- There should be a check that force us to manually fix the manual file (even before running the 1st query to get the delta).
-- So once the concept is in the manual file, it should NOT appear in delta. Basically this is "check if target concepts are Standard and exist in the concept table"
-- Once the relationship to the specific target concept is gone, the machinery should make it D in CRM using the current_date.
SELECT DISTINCT
       replace (c.concept_name, 'Deprecated ', '') AS source_concept_name_clean,
       c.concept_name AS source_concept_name,
       c.concept_code AS source_concept_code,
       c.concept_class_id AS   source_concept_class_id,
       c.invalid_reason AS     source_invalid_reason,
       c.domain_id AS          source_domain_id,

       crm.relationship_id AS relationship_id,

       'CRM' AS flag,
       cc.concept_id AS target_concept_id,
       cc.concept_code AS target_concept_code,
       cc.concept_name AS target_concept_name,
       cc.concept_class_id AS target_concept_class_id,
       cc.standard_concept AS target_standard_concept,
       cc.invalid_reason AS target_invalid_reason,
       cc.domain_id AS target_domain_id,
       cc.vocabulary_id AS target_vocabulary_id

FROM dev_meddra.concept_relationship_manual crm
JOIN dev_meddra.concept c ON c.concept_code = crm.concept_code_1 AND c.vocabulary_id = 'MedDRA'  AND crm.invalid_reason IS NULL
JOIN dev_meddra.concept cc ON cc.concept_code = crm.concept_code_2 AND cc.vocabulary_id = crm.vocabulary_id_2

ORDER BY replace (c.concept_name, 'Deprecated ', ''),
         c.concept_code,
         crm.relationship_id,
         cc.concept_id
;


--New and COVID concepts lacking hierarchy
--Taken into CRM
SELECT * FROM (
SELECT DISTINCT
       replace (long_common_name, 'Deprecated ', '') AS source_concept_name_clean,
       long_common_name AS source_concept_name,
	   meddra AS source_concept_code,
	   'Lab Test' AS source_concept_class_id,
	   NULL as source_invalid_reason,
	'Measurement' AS source_domain_id
FROM vocabulary_pack.GetLoincPrerelease() s

UNION

SELECT DISTINCT
        replace (cs.concept_name, 'Deprecated ', '') AS source_concept_name_clean,
        cs.concept_name AS       source_concept_name,
        cs.concept_code AS       source_concept_code,
        cs.concept_class_id AS   source_concept_class_id,
        cs.invalid_reason AS     source_invalid_reason,
        cs.domain_id AS          source_domain_id

FROM dev_meddra.concept_stage cs
WHERE cs.vocabulary_id = 'MedDRA'
    AND cs.concept_name ~* 'SARS-CoV-2|COVID|SARS2|SARS-2'
    AND cs.concept_class_id IN ('Clinical Observation', 'Lab Test')
) as s


WHERE NOT EXISTS (
SELECT
FROM dev_meddra.concept_relationship_manual crm
WHERE s.source_concept_code = crm.concept_code_1
    AND crm.relationship_id = 'Is a'
    AND crm.invalid_reason IS NULL
)

ORDER BY replace (s.source_concept_name, 'Deprecated ', ''), s.source_concept_code
;


--backup CRM
--CREATE TABLE dev_loinc.concept_relationship_manual_backup_20210603 AS SELECT * FROM dev_loinc.concept_relationship_manual;
;

--restore CRM
--TRUNCATE TABLE dev_loinc.concept_relationship_manual;
--INSERT INTO dev_loinc.concept_relationship_manual
--SELECT * FROM dev_loinc.concept_relationship_manual_backup_20210603;


--Insert into CRM
-- Step 1: Create table crm_manual_mappings_changed with fields from manual file
--TRUNCATE TABLE dev_loinc.loinc_mapped;
CREATE TABLE dev_meddra.meddra_mapped
(
    id SERIAL PRIMARY KEY,
    source_code_description varchar(255),
    source_code varchar(50),
    source_concept_class_id varchar(50),
    source_invalid_reason varchar(20),
    source_domain_id varchar(50),
    to_value varchar(50),
    flag varchar(50),
    target_concept_id int,
    target_concept_code varchar(50),
    target_concept_name varchar(255),
    target_concept_class_id varchar(50),
    target_standard_concept varchar(20),
    target_invalid_reason varchar(20),
    target_domain_id varchar(50),
    target_vocabulary_id varchar(50)
);


--Step 2: Deprecate all mappings that differ from the new version
UPDATE dev_meddra.concept_relationship_manual
SET invalid_reason = 'D',
    valid_end_date = current_date
WHERE (concept_code_1, concept_code_2, relationship_id, vocabulary_id_2) IN

(SELECT concept_code_1, concept_code_2, relationship_id, vocabulary_id_2 FROM concept_relationship_manual crm_old

WHERE NOT exists(SELECT source_code, target_concept_code, 'MedDRA', target_vocabulary_id, CASE WHEN to_value ~* 'value' THEN 'Maps to value'
                    WHEN to_value ~* 'Is a' THEN 'Is a'
                    WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                   ELSE 'Maps to' END
                FROM dev_meddra.meddra_mapped crm_new
                WHERE source_code = crm_old.concept_code_1
                AND target_concept_code = crm_old.concept_code_2
                AND target_vocabulary_id = crm_old.vocabulary_id_2
                AND CASE WHEN to_value ~* 'value' THEN 'Maps to value'
                    WHEN to_value ~* 'Is a' THEN 'Is a'
                    WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                   ELSE 'Maps to' END = crm_old.relationship_id

    )
    AND invalid_reason IS NULL
    )
;

--Step 3: Insert new mappings + corrected mappings
with mapping AS
    (
        SELECT DISTINCT source_code AS concept_code_1,
               target_concept_code AS concept_code_2,
               'MedDRA' AS vocabulary_id_1,
               target_vocabulary_id AS vocabulary_id_2,
               CASE WHEN to_value ~* 'value' THEN 'Maps to value'
                    WHEN to_value ~* 'Is a' THEN 'Is a'
                    WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                   ELSE 'Maps to' END AS relationship_id,
               current_date AS valid_start_date,
               to_date('20991231','yyyymmdd') AS valid_end_date,
               NULL AS invalid_reason
        FROM dev_meddra.meddra_mapped
        WHERE target_concept_id != 0
    )


INSERT INTO concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
    (SELECT concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id,
            valid_start_date,
            valid_end_date,
            invalid_reason
     FROM mapping m
        WHERE (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id)
                  NOT IN (SELECT concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id FROM dev_meddra.concept_relationship_manual)
    )
;