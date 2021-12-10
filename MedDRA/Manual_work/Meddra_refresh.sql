---vocabularies QA and run

-- step 1 -- done 08.12.21
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>true, include_deprecated_rels=>true, include_synonyms=>true);
-- step 2 -- load stage -- done 08.12.21
-- step 3 - return null -- done 08.12.21
select * from devv5.qa_ddl();
-- step 4 - return null -- done 08.12.21
SELECT * FROM qa_tests.check_stage_tables ();

-- step 5 -- done 08.12.21
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;
-- step 6 - return null -- done 08.12.21
select * from QA_TESTS.GET_CHECKS();
-- step 7 -- https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql - done 08.12.21
--01. Concept changes

    --01.1. Concepts changed their Domain
select new.concept_code,
       new.concept_name as concept_name,
       new.concept_class_id as concept_class_id,
       new.standard_concept as standard_concept,
       new.vocabulary_id as vocabulary_id,
       old.domain_id as old_domain_id,
       new.domain_id as new_domain_id
from concept new
join devv5.concept old
    using (concept_id)
where old.domain_id != new.domain_id
;

    --01.2. Domain of newly added concepts
SELECT c1.concept_code,
       c1.concept_name,
       c1.concept_class_id,
       c1.standard_concept,
       c1.domain_id as new_domain
FROM concept c1
LEFT JOIN devv5.concept c2
    ON c1.concept_id = c2.concept_id
WHERE c2.vocabulary_id IS NULL
;

    --01.3. Concepts changed their names
SELECT c.concept_code,
       c.vocabulary_id,
       c2.concept_name as old_name,
       c.concept_name as new_name,
       devv5.similarity (c2.concept_name, c.concept_name)
FROM concept c
JOIN devv5.concept c2
    ON c.concept_id = c2.concept_id
        AND c.concept_name != c2.concept_name
WHERE c.vocabulary_id IN ('MedDRA')
ORDER BY devv5.similarity (c2.concept_name, c.concept_name)
;

--02. Mapping of concepts
        --02.1. looking at new concepts and their mapping -- 'Maps to' absent
select a.concept_code as concept_code_source,
       a.concept_name as concept_name_source,
       a.vocabulary_id as vocabulary_id_source,
       a.concept_class_id as concept_class_id_source,
       a.domain_id as domain_id_source,
       b.concept_name as concept_name_target,
       b.vocabulary_id as vocabulary_id_target
 from concept a
left join concept_relationship r on a.concept_id= r.concept_id_1 and r.invalid_reason is null and r.relationship_Id ='Maps to'
left join concept  b on b.concept_id = r.concept_id_2
left join devv5.concept  c on c.concept_id = a.concept_id
where a.vocabulary_id IN ('MedDRA')
and c.concept_id is null and b.concept_id is null
;

--02.2. looking at new concepts and their mapping -- 'Maps to' present
select a.concept_code as concept_code_source,
       a.concept_name as concept_name_source,
       a.vocabulary_id as vocabulary_id_source,
       a.concept_class_id as concept_class_id_source,
       a.domain_id as domain_id_source,
       CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>'
           ELSE b.concept_name END as concept_name_target,
       CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>'
           ELSE b.vocabulary_id END as vocabulary_id_target
from concept a
join concept_relationship r
    on a.concept_id=r.concept_id_1
           and r.invalid_reason is null
           and r.relationship_Id ='Maps to'
join concept b
    on b.concept_id = r.concept_id_2
left join devv5.concept  c
    on c.concept_id = a.concept_id
where a.vocabulary_id IN ('MedDRA')
    and c.concept_id is null
   -- and a.concept_id != b.concept_id --use it to exclude mapping to itself
;

--02.3. looking at new concepts and their ancestry -- 'Is a' absent
select a.concept_code, a.concept_name, a.concept_class_id, a.domain_id, b.concept_name, b.concept_class_id, b.vocabulary_id
from concept a
left join concept_relationship r on a.concept_id= r.concept_id_1 and r.invalid_reason is null and r.relationship_Id ='Is a'
left join concept b on b.concept_id = r.concept_id_2
left join devv5.concept  c on c.concept_id = a.concept_id
where a.vocabulary_id IN ('MedDRA')
and c.concept_id is null and b.concept_id is null
;

--02.4. looking at new concepts and their ancestry -- 'Is a' present
select a.concept_code, a.concept_name, a.concept_class_id, a.domain_id, b.concept_name, b.concept_class_id, b.vocabulary_id
from concept a
join concept_relationship r on a.concept_id= r.concept_id_1 and r.invalid_reason is null and r.relationship_Id ='Is a'
join concept  b on b.concept_id = r.concept_id_2
left join devv5.concept  c on c.concept_id = a.concept_id
where a.vocabulary_id IN ('MedDRA')
and c.concept_id is null
;

--02.5. concepts changed their mapping ('Maps to'), this includes 2 scenarios: mapping changed; mapping present in one version, absent in another;
--to detect the absent mappings cases, sort by the respective code_agg to get the NULL values first.
with new_map as (
select a.concept_id,
       a.vocabulary_id,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from concept a
left join concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Maps to', 'Maps to value') and r.invalid_reason is null
left join concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN ('MedDRA')
    --and a.invalid_reason is null --to exclude invalid concepts
group by a.concept_id, a.vocabulary_id, a.concept_code, a.concept_name
)
,
old_map as (
select a.concept_id,
       a.vocabulary_id,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from devv5. concept a
left join devv5.concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Maps to', 'Maps to value') and r.invalid_reason is null
left join devv5.concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN ('MedDRA')
    --and a.invalid_reason is null --to exclude invalid concepts
group by a.concept_id, a.vocabulary_id, a.concept_code, a.concept_name
)
select b.vocabulary_id as new_vocabulary_id,
       a.concept_code as source_code,
       a.concept_name as source_name,
       a.relationship_agg as old_relat_agg,
       a.code_agg as old_code_agg,
       a.name_agg as old_name_agg,
       b.relationship_agg as new_relat_agg,
       b.code_agg as new_code_agg,
       b.name_agg as new_name_agg
from old_map  a
join new_map b
on a.concept_id = b.concept_id and ((coalesce (a.code_agg, '') != coalesce (b.code_agg, '')) or (coalesce (a.relationship_agg, '') != coalesce (b.relationship_agg, '')))
order by a.concept_code
;

--02.6. Concepts changed their ancestry ('Is a'), this includes 2 scenarios: Ancestor(s) changed; ancestor(s) present in one version, absent in another;
--to detect the absent ancestry cases, sort by the respective code_agg to get the NULL values first.
with new_map as (
select a.concept_id,
       a.vocabulary_id,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from concept a
left join concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Is a') and r.invalid_reason is null
left join concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN ('MedDRA') and a.invalid_reason is null
group by a.concept_id, a.vocabulary_id, a.concept_code, a.concept_name
)
,
old_map as (
select a.concept_id,
       a.vocabulary_id,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from devv5. concept a
left join devv5.concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Is a') and r.invalid_reason is null
left join devv5.concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN ('MedDRA') and a.invalid_reason is null
group by a.concept_id, a.vocabulary_id, a.concept_code, a.concept_name
)
select b.vocabulary_id as new_vocabulary_id,
       a.concept_code as source_code,
       a.concept_name as source_name,
       a.relationship_agg as old_relat_agg,
       a.code_agg as old_code_agg,
       a.name_agg as old_name_agg,
       b.relationship_agg as new_relat_agg,
       b.code_agg as new_code_agg,
       b.name_agg as new_name_agg
from old_map  a
join new_map b
on a.concept_id = b.concept_id and ((coalesce (a.code_agg, '') != coalesce (b.code_agg, '')) or (coalesce (a.relationship_agg, '') != coalesce (b.relationship_agg, '')))
order by a.concept_code
;

--02.7. Concepts with 1-to-many mapping -- multiple 'Maps to' present
select a.vocabulary_id,
       a.concept_code as concept_code_source,
       a.concept_name as concept_name_source,
       a.domain_id as domain_id_source,
       b.concept_code as concept_code_target,
       CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>'
           ELSE b.concept_name END as concept_name_target,
       CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>'
           ELSE b.vocabulary_id END as vocabulary_id_target
from concept a
join concept_relationship r
    on a.concept_id=r.concept_id_1
           and r.invalid_reason is null
           and r.relationship_Id ='Maps to'
join concept b
    on b.concept_id = r.concept_id_2
where a.vocabulary_id IN ('MedDRA')
    --and a.concept_id != b.concept_id --use it to exclude mapping to itself
    and a.concept_id IN (
                            select a.concept_id
                            from concept a
                            join concept_relationship r
                                on a.concept_id=r.concept_id_1
                                       and r.invalid_reason is null
                                       and r.relationship_Id ='Maps to'
                            join concept b
                                on b.concept_id = r.concept_id_2
                            where a.vocabulary_id IN ('MedDRA')
                                --and a.concept_id != b.concept_id --use it to exclude mapping to itself
                            group by a.concept_id
                            having count(*) > 1
    )
;

--02.8. Concepts became non-Standard with no mapping replacement - return null 08.12.21
select a.concept_code,
       a.concept_name,
       a.concept_class_id,
       a.domain_id,
       a.vocabulary_id
from concept a
join devv5.concept b
        on a.concept_id = b.concept_id
where a.vocabulary_id IN ('MedDRA')
    and b.standard_concept = 'S'
    and a.standard_concept IS NULL
    and not exists (
                    SELECT 1
                    FROM concept_relationship cr
                    WHERE a.concept_id = cr.concept_id_1
                        AND cr.relationship_id = 'Maps to'
                        AND cr.invalid_reason IS NULL
    )
;

--02.9. Concepts are presented in CRM with "Maps to" link, but end up with no valid "Maps to"
SELECT *
FROM concept c
WHERE c.vocabulary_id IN ('MedDRA')
    AND EXISTS (SELECT 1
                FROM concept_relationship_manual crm
                WHERE c.concept_code = crm.concept_code_1
                    AND c.vocabulary_id = crm.vocabulary_id_1
                    AND crm.relationship_id = 'Maps to' AND crm.invalid_reason IS NULL)
AND NOT EXISTS (SELECT 1
                FROM concept_relationship cr
                WHERE c.concept_id = cr.concept_id_1
                    AND cr.relationship_id = 'Maps to'
                    AND cr.invalid_reason IS NULL)
;


--02.9. Mapping of covid concepts (please adjust inclusion/exclusion in the master branch if found something)
with covid_inclusion as (SELECT
        'sars(?!(tedt|aparilla))|^cov(?!(er|onia|aWound|idien))|cov$|^ncov|ncov$|corona(?!(l|ry|ries| radiata))|severe acute|covid(?!ien)' as covid_inclusion
    ),

     /*~* 'sars(?!(tedt|aparilla))|^cov(?!(er|onia|aWound|idien))|cov$|^ncov|ncov$|corona(?!(l|ry|ries))|severe acute|covid(?!ien)'
  AND lower(c.concept_name) !~* '( |^)LASSARS|papillaris|radiata' AND c.vocabulary_id='MedDRA'*/

covid_exclusion as (SELECT
    '( |^)LASSARS|Coronaro|coronae' as covid_exclusion
    )


select distinct c.vocabulary_id, c.concept_name, c.concept_class_id, b.concept_name, b.concept_class_id, b.vocabulary_id as target_vocabulary_id
from concept c
left join concept_relationship cr on cr.concept_id_1 = c.concept_id and relationship_id ='Maps to' and cr.invalid_reason is null
left join concept b on b.concept_id = cr.concept_id_2
where c.vocabulary_id IN ('MedDRA')

    and ((c.concept_name ~* (select covid_inclusion from covid_inclusion) and c.concept_name !~* (select covid_exclusion from covid_exclusion))
        or
        (b.concept_name ~* (select covid_inclusion from covid_inclusion) and b.concept_name !~* (select covid_exclusion from covid_exclusion)))
;

-- step 8
select * from qa_tests.purge_cache();
select * from qa_tests.get_summary (table_name=>'concept',pCompareWith=>'devv5');
select * from qa_tests.get_summary (table_name=>'concept_relationship',pCompareWith=>'devv5');
--select * from qa_tests.get_summary (table_name=>'concept_ancestor',pCompareWith=>'devv5');

-- Statistics QA checks
--13.1. Domain changes
select * from qa_tests.get_domain_changes(pCompareWith=>'devv5');
--13.2. Newly added concepts grouped by vocabulary_id and domain
select * from qa_tests.get_newly_concepts(pCompareWith=>'devv5');
--13.3. Standard concept changes
select * from qa_tests.get_standard_concept_changes(pCompareWith=>'devv5');
--13.4. Newly added concepts and their standard concept status
select * from qa_tests.get_newly_concepts_standard_concept_status(pCompareWith=>'devv5');
--13.5. Changes of concept mapping status grouped by target domain
select * from qa_tests.get_changes_concept_mapping(pCompareWith=>'devv5');



--- Final ----
--Review COVID-19 mappings
/*
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
*/

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
                FROM dev_meddra.meddra_mapped_version22_11_21 crm_new
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
        FROM dev_meddra.meddra_mapped_version22_11_21
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