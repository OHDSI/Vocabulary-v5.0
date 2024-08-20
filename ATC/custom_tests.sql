---- What new ATC - RxNorm connections appeared for every code compared to the old version

WITH
    CTE_old as(
                select c1.concept_code,
                       c1.concept_name,
                       c2.concept_id as id_old,
                       c2.concept_name as name_old
--                        string_agg(c2.concept_id::VARCHAR, ' |') as ids_old,
--                        string_agg(c2.concept_name, ' |') as names_old,
--                        count(*) as count_old
                from devv5.concept_relationship cr
                     join devv5.concept c1 on cr.concept_id_1 = c1.concept_id and c1.vocabulary_id = 'ATC'
                                                                              and length(c1.concept_code) = 7
                     join devv5.concept c2 on cr.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                              and cr.relationship_id = 'ATC - RxNorm'),
    CTE_new as(
                select c1.concept_code,
                       c1.concept_name,
                       c2.concept_id as id_new,
                       c2.concept_name as name_new
--                        string_agg(c2.concept_id::VARCHAR, ' |') as ids_new,
--                        string_agg(c2.concept_name, ' |') as names_new,
--                        count(*) as count_new
                from dev_atc.concept_relationship cr
                     join dev_atc.concept c1 on cr.concept_id_1 = c1.concept_id and c1.vocabulary_id = 'ATC'
                                                                              and length(c1.concept_code) = 7
                     join dev_atc.concept c2 on cr.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                              and cr.relationship_id = 'ATC - RxNorm')

select new.concept_code,
       new.concept_name,
       string_agg(new.id_new::varchar, ' |') as ids_new,
       string_agg(new.name_new, ' |') as names_new,
       count(*) as new_count
from CTE_new new left join CTE_old as old on new.concept_code = old.concept_code
                                             and new.id_new = old.id_old
where old.concept_code is NULL or old.id_old is NULL
group by new.concept_code, new.concept_name;

----- What ATC - RxNorm disappeared after refreshment

WITH
    CTE_old as(
                select c1.concept_code,
                       c1.concept_name,
                       c2.concept_id as id_old,
                       c2.concept_name as name_old
--                        string_agg(c2.concept_id::VARCHAR, ' |') as ids_old,
--                        string_agg(c2.concept_name, ' |') as names_old,
--                        count(*) as count_old
                from devv5.concept_relationship cr
                     join devv5.concept c1 on cr.concept_id_1 = c1.concept_id and c1.vocabulary_id = 'ATC'
                                                                              and length(c1.concept_code) = 7
                     join devv5.concept c2 on cr.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                              and cr.relationship_id = 'ATC - RxNorm'),
    CTE_new as(
                select c1.concept_code,
                       c1.concept_name,
                       c2.concept_id as id_new,
                       c2.concept_name as name_new
--                        string_agg(c2.concept_id::VARCHAR, ' |') as ids_new,
--                        string_agg(c2.concept_name, ' |') as names_new,
--                        count(*) as count_new
                from dev_atc.concept_relationship cr
                     join dev_atc.concept c1 on cr.concept_id_1 = c1.concept_id and c1.vocabulary_id = 'ATC'
                                                                              and length(c1.concept_code) = 7
                     join dev_atc.concept c2 on cr.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                              and cr.relationship_id = 'ATC - RxNorm')

select old.concept_code,
       old.concept_name,
       string_agg(new.id_new::varchar, ' |') as ids_new,
       string_agg(new.name_new, ' |') as names_new,
       count(*) as new_count
from  CTE_old old left join CTE_new new on old.concept_code = new.concept_code
                                             and old.id_old = new.id_new
where new.concept_code is NULL or new.id_new is NULL
group by old.concept_code, old.concept_name;


--- What ATC - RxNorm connections are deprecated after update and which are de-depricated

SELECT
    c1.concept_id,
    c1.concept_code,
    c1.concept_name,
    old.relationship_id,
    c2.concept_code,
    c2.concept_id,
    c2.concept_name,
    c2.concept_code,
    old.invalid_reason AS old_invalid_reason,
    new.invalid_reason AS new_invalid_reason
FROM
    devv5.concept_relationship AS old JOIN dev_atc.concept_relationship AS new
                                            ON
                                                old.concept_id_1 = new.concept_id_1
                                                AND old.concept_id_2 = new.concept_id_2
                                                AND old.relationship_id = new.relationship_id
    JOIN dev_atc.concept c1 on old.concept_id_1 = c1.concept_id and c1.vocabulary_id = 'ATC' and c1.invalid_reason is null
    JOIN dev_atc.concept c2 on old.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension') and c2.invalid_reason is null
WHERE
    old.relationship_id IN ('ATC - RxNorm')
    AND old.invalid_reason IS DISTINCT FROM new.invalid_reason;

---- What new ATC - Ings connections appeared for every code compared to the old version

WITH
    CTE_old as(
                select c1.concept_code,
                       c1.concept_name,
                       cr.relationship_id,
                       c2.concept_id as id_old,
                       c2.concept_name as name_old
                from devv5.concept_relationship cr
                     join devv5.concept c1 on cr.concept_id_1 = c1.concept_id and c1.vocabulary_id = 'ATC'
                                                                              and length(c1.concept_code) = 7
                     join devv5.concept c2 on cr.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                              and cr.relationship_id in ('ATC - RxNorm pr lat',
                                                                                                        'ATC - RxNorm sec lat',
                                                                                                        'ATC - RxNorm pr up',
                                                                                                        'ATC - RxNorm sec up')),
    CTE_new as(
                select c1.concept_code,
                       c1.concept_name,
                       cr.relationship_id,
                       c2.concept_id as id_new,
                       c2.concept_name as name_new
                from dev_atc.concept_relationship cr
                     join dev_atc.concept c1 on cr.concept_id_1 = c1.concept_id and c1.vocabulary_id = 'ATC'
                                                                              and length(c1.concept_code) = 7
                     join dev_atc.concept c2 on cr.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                              and cr.relationship_id in ('ATC - RxNorm pr lat',
                                                                                                        'ATC - RxNorm sec lat',
                                                                                                        'ATC - RxNorm pr up',
                                                                                                        'ATC - RxNorm sec up'))
select new.concept_code,
       new.concept_name,
       new.relationship_id,
       string_agg(new.id_new::varchar, ' |') as ids_new,
       string_agg(new.name_new, ' |') as names_new,
       count(*) as new_count
from CTE_new new left join CTE_old as old on new.concept_code = old.concept_code
                                             and new.id_new = old.id_old
                                             and new.relationship_id = old.relationship_id
where old.concept_code is NULL or old.id_old is NULL
group by new.concept_code, new.concept_name, new.relationship_id;

---- What old ATC - Ings connections we loose after update

select c1.concept_code,
       c1.concept_name,
       cr.relationship_id,
       c2.concept_id as id_old,
       c2.concept_name as name_old
from devv5.concept_relationship cr
     join devv5.concept c1 on cr.concept_id_1 = c1.concept_id and c1.vocabulary_id = 'ATC'
                                                              and length(c1.concept_code) = 7
     join devv5.concept c2 on cr.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                              and cr.relationship_id in ('ATC - RxNorm pr lat',
                                                                                         'ATC - RxNorm sec lat',
                                                                                         'ATC - RxNorm pr up',
                                                                                         'ATC - RxNorm sec up')
WHERE (cr.concept_id_1, cr.relationship_id, cr.concept_id_2) not in
        (
        select cr.concept_id_1,
               cr.relationship_id,
               cr.concept_id_2
        from dev_atc.concept_relationship cr
             join dev_atc.concept c1 on cr.concept_id_1 = c1.concept_id and c1.vocabulary_id = 'ATC'
                                                                        and length(c1.concept_code) = 7
             join dev_atc.concept c2 on cr.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                        and cr.relationship_id in ('ATC - RxNorm pr lat',
                                                                                                   'ATC - RxNorm sec lat',
                                                                                                   'ATC - RxNorm pr up',
                                                                                                   'ATC - RxNorm sec up')

            );

--- What ATC - Ings connections are deprecated after update and which are dedepricated

SELECT
    c1.concept_id,
    c1.concept_name,
    old.relationship_id,
    c2.concept_code,
    c2.concept_id,
    c2.concept_name,
    c2.concept_code,
    old.invalid_reason AS old_invalid_reason,
    new.invalid_reason AS new_invalid_reason
FROM
    devv5.concept_relationship AS old JOIN dev_atc.concept_relationship AS new
                                            ON
                                                old.concept_id_1 = new.concept_id_1
                                                AND old.concept_id_2 = new.concept_id_2
                                                AND old.relationship_id = new.relationship_id
    JOIN devv5.concept c1 on old.concept_id_1 = c1.concept_id and c1.vocabulary_id = 'ATC' and c1.invalid_reason is NUll
    JOIN devv5.concept c2 on old.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension') and c2.invalid_reason is NULL
WHERE
    old.relationship_id IN ('ATC - RxNorm pr lat', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up', 'ATC - RxNorm sec up')
    AND old.invalid_reason IS DISTINCT FROM new.invalid_reason;

------- Change of concept_names
select c1.concept_code,
       c1.concept_name as new_name,
       c2.concept_name as old_name
from dev_atc.concept c1
     left join devv5.concept c2 on c1.concept_id = c2.concept_id and c1.vocabulary_id = 'ATC' and length(c1.concept_code) = 7
where c1.concept_name IS DISTINCT FROM  c2.concept_name;


---- Change of synonyms

select c.concept_id,
       c.concept_code,
       cs1.concept_synonym_name as new_synonym,
       cs2.concept_synonym_name as old_synonym
from dev_atc.concept c
    join dev_atc.concept_synonym cs1 on c.concept_id = cs1.concept_id and c.vocabulary_id = 'ATC' and length(concept_code) = 7
    join devv5.concept_synonym cs2 on c.concept_id = cs2.concept_id
where lower(cs1.concept_synonym_name) is distinct from  lower(cs2.concept_synonym_name);


--- Number of one_component drugs for combo codes
WITH CTE_2 as (
with CTE as (SELECT
    c1.concept_code,
    c1.concept_name,
    c2.concept_name as secondary,
    count(c3.concept_name) as n_ings
FROM
    dev_atc.concept_relationship cr
    join dev_atc.concept c1 on cr.concept_id_1 = c1.concept_id
                          and c1.vocabulary_id = 'ATC'
                          and length(c1.concept_code) = 7
                          and c1.invalid_reason is NULL
                          and cr.invalid_reason is NULL
                          and cr.relationship_id = 'ATC - RxNorm'
    join dev_atc.concept c2 on cr.concept_id_2 = c2.concept_id
                          and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                          and c2.concept_class_id = 'Clinical Drug Form'
                          and c2.invalid_reason is NULL
    join dev_atc.concept_relationship cr2 on cr.concept_id_2 = cr2.concept_id_1
                          and cr2.relationship_id = 'RxNorm has ing'
    join dev_atc.concept c3 on cr2.concept_id_2 = c3.concept_id
group by c1.concept_code, c1.concept_name, c2.concept_name)

select
concept_code,
concept_name,
CASE WHEN n_ings = 1 then 1
     ELSE 0 end as one_ing,
CASE WHEN n_ings > 1 then 1
     ELSE 0 end as multi_ing
from CTE)

SELECT
    concept_code,
    concept_name,
    SUM(one_ing) as one_ing,
    SUM(multi_ing) as multi_ing
FROM CTE_2
group by concept_code, concept_name
order by concept_code;


--- New ATC - RxNorm Links
select c1.vocabulary_id,
       count(*)
from dev_atc.concept_relationship cr
     join dev_atc.concept c1 on cr.concept_id_2 = c1.concept_id
where relationship_id = 'ATC - RxNorm'
and (cr.concept_id_1, cr.concept_id_2) not in (select
                                                     concept_id_1,
                                                     concept_id_2
                                                 from devv5.concept_relationship
                                                 where relationship_id = 'ATC - RxNorm'
                                                 and invalid_reason is null)
and cr.invalid_reason is null
group by c1.vocabulary_id;

--- deprecated links
select c1.vocabulary_id,
       count(*)
from devv5.concept_relationship cr
     join devv5.concept c1 on cr.concept_id_2 = c1.concept_id
where relationship_id = 'ATC - RxNorm'
and (cr.concept_id_1, cr.concept_id_2) not in (select
                                             concept_id_1,
                                             concept_id_2
                                         from dev_atc.concept_relationship
                                         where relationship_id = 'ATC - RxNorm'
                                               AND invalid_reason IS NULL)
AND cr.invalid_reason IS NULL
group by c1.vocabulary_id;




---------- Check of accordance of ATC_Code - Dose Forms

-- DROP TABLE IF EXISTS root_forms_for_check;
-- create table root_forms_for_check as   ---- Take actual roots from current dev_atc.concept
-- select
--     trim(t5.new) as coalesce,
--     string_agg(distinct t3.concept_name, ',')
-- from
--     dev_atc.concept t1
--     join dev_atc.concept_relationship cr on t1.concept_id = cr.concept_id_1 and t1.invalid_reason is null
--                                                                           and cr.invalid_reason is null
--                                                                           and cr.relationship_id = 'ATC - RxNorm'
--                                                                           and t1.concept_class_id = 'ATC 5th'
--     join dev_atc.new_adm_r t5 on t1.concept_code = t5.class_code
--     join dev_atc.concept t2 on cr.concept_id_2 = t2.concept_id and t2.invalid_reason is null
--                                                              and t2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
--                                                              and t2.concept_class_id = 'Clinical Drug Form'
--     join dev_atc.concept_relationship cr2 on cr2.concept_id_1 = t2.concept_id and cr2.invalid_reason is Null
--                                                                             and cr2.relationship_id = 'RxNorm has dose form'
--     join dev_atc.concept t3 on cr2.concept_id_2 = t3.concept_id and t3.invalid_reason is NULL
--
-- group by  t5.new;
--
-- select *
--     from dev_atc.root_forms_for_check;

---- Here is manual curated list of adm.r - Dose Forms from previous query.
DROP TABLE IF EXISTS root_forms_for_check;
CREATE TABLE root_forms_for_check as
    SELECT
        coalesce,
        string_agg(concept_name, ',')
        FROM dev_atc.all_adm_r_filter
        group by coalesce
        ;

DROP TABLE IF EXISTS temp_check;
create table temp_check as
select
    c1.concept_id as atc_concept_id,
    c1.concept_code as atc_concept_code,
    c1.concept_name as atc_concept_name,
    trim(split_part(c1.concept_name, ';', 2)) as root,
    c3.concept_name as rxnorm_form,
    c2.concept_id as rxnorm_concept_id,
    c2.concept_name as rxnorm_concept_name,
    string_agg
from dev_atc.concept_relationship t1
     join dev_atc.concept c1 on t1.concept_id_1=c1.concept_id
                                    and length(c1.concept_code) = 7
                                    and c1.vocabulary_id = 'ATC'
                                    and c1.invalid_reason is NULL
                                    and t1.invalid_reason is NULL
     join dev_atc.concept c2 on t1.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                --and c2.concept_class_id = 'Clinical Drug Form'
                                                                and t1.relationship_id = 'ATC - RxNorm'
                                                                and t1.invalid_reason is NULL
                                                                and c2.invalid_reason is NULL
     join dev_atc.root_forms_for_check t2 on trim(split_part(c1.concept_name, ';', 2)) = trim(t2.coalesce)
     join dev_atc.concept_relationship cr on t1.concept_id_2 = cr.concept_id_1 and cr.relationship_id = 'RxNorm has dose form'
     join dev_atc.concept c3 on c3.concept_id = cr.concept_id_2 and c3.vocabulary_id in ('RxNorm', 'RxNorm Extension');

DROP TABLE IF EXISTS temp_check_results;
create table temp_check_results as
    SELECT
    atc_concept_id,
    atc_concept_code,
    atc_concept_name,
    root,
    rxnorm_form,
    rxnorm_concept_id,
    rxnorm_concept_name,
    string_agg,
    CASE
        WHEN rxnorm_form ILIKE ANY (string_to_array(string_agg, ',')) THEN 'NO'
        ELSE 'YES'
    END AS for_check
FROM
    dev_atc.temp_check;

drop table if exists temp_check_results_only_yes;
create table temp_check_results_only_yes as
select
    distinct atc_concept_id,
    atc_concept_code,
    atc_concept_name,
    root,
    rxnorm_form,
    rxnorm_concept_name,
    rxnorm_concept_id
from dev_atc.temp_check_results
where for_check = 'YES';

select distinct atc_concept_id,
       atc_concept_code,
       atc_concept_name,
       root,
       NULL as drop,
       rxnorm_form,
       rxnorm_concept_id,
       rxnorm_concept_name
FROM dev_atc.temp_check_results_only_yes
where rxnorm_form  != 'Pack'
order by root, rxnorm_form;



-------- Compare of counts different concept_class_id's connected to ATC
SELECT t1.dev_atc_cr,
       t1.dev_atc_atccid,
       t1.dev_atc_cid,
       t1.dev_atc_count,
       t2.devv5_count,
       t2.devv5_cid,
       t2.dev_atc_atccid,
       t2.devv5_cr
FROM
(select
    cr.relationship_id as dev_atc_cr,
    c1.concept_class_id as dev_atc_atccid,
    c2.concept_class_id as dev_atc_cid,
    count(*) as dev_atc_count
from dev_atc.concept_relationship cr
     join dev_atc.concept c1 on cr.concept_id_1 = c1.concept_id
                             and cr.invalid_reason is null
                             and c1.invalid_reason is null
                             and c1.vocabulary_id = 'ATC'
     join dev_atc.concept c2 on cr.concept_id_2 = c2.concept_id
                             and cr.invalid_reason is null
                             and c2.invalid_reason is null
                             and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
group by cr.relationship_id, c1.concept_class_id, c2.concept_class_id) t1

FULL JOIN

(select
    cr.relationship_id as devv5_cr,
    c1.concept_class_id as dev_atc_atccid,
    c2.concept_class_id as devv5_cid,
    count(*) as devv5_count
from devv5.concept_relationship cr
     join devv5.concept c1 on cr.concept_id_1 = c1.concept_id
                             and cr.invalid_reason is null
                             and c1.invalid_reason is null
                             and c1.vocabulary_id = 'ATC'
     join devv5.concept c2 on cr.concept_id_2 = c2.concept_id
                             and cr.invalid_reason is null
                             and c2.invalid_reason is null
                             and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
group by cr.relationship_id, c1.concept_class_id, c2.concept_class_id) t2

on t1.dev_atc_cr = t2.devv5_cr
       and t1.dev_atc_atccid = t2.dev_atc_atccid
       and t1.dev_atc_cid = t2.devv5_cid

ORDER BY t1.dev_atc_cr, t1.dev_atc_cid;


---- Number and types of different RxN Clinical Drug Forms that have more then 1 ATC Code

SELECT c2.concept_name,
       count(DISTINCT c1.concept_code),
       string_agg(DISTINCT c1.concept_code || ' - ' || c1.concept_name, ' | ')
FROM dev_atc.concept_relationship cr
     JOIN dev_atc.concept c1 ON cr.concept_id_1 = c1.concept_id
                             AND c1.vocabulary_id = 'ATC'
                             AND cr.relationship_id = 'ATC - RxNorm'
                             AND cr.invalid_reason is NULL
                             AND c1.invalid_reason is NULL
     JOIN dev_atc.concept c2 ON cr.concept_id_2 = c2.concept_id
                             AND c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                             AND c2.invalid_reason is NULL
                             AND c2.concept_class_id = 'Clinical Drug Form'
GROUP BY c2.concept_name HAVING count(c1.concept_name) > 1
ORDER BY count(c1.concept_name) desc;

---- How many new links did each source give us, and how many of them were deprecated manually?
---- For this purposes we need sightly change load_input and remove all ' - aside' and ' - is a' from source names
---- to analyze what each source gives us in total. For this reason we generated table dev_atc.new_atc_codes_rxnorm_for_source_analysis

SELECT
    t1.source,
    t1.total_count,
    t2.count_after_cleaning,
    t3.new_concepts_for_devv_5
FROM
    (
        select source,
               count(*) as total_count
        from dev_atc.new_atc_codes_rxnorm_for_source_analysis
        where concept_class_id = 'Clinical Drug Form'
        group by source
    ) t1

    JOIN
    (
        select source,
               count(*) as count_after_cleaning
        from dev_atc.new_atc_codes_rxnorm_for_source_analysis
        where concept_class_id = 'Clinical Drug Form'
        AND
            ((class_code, ids) not in (select concept_code_atc,
                                             concept_id_rx
                                      from dev_atc.atc_rxnorm_to_drop_in_sources)
            AND
                (class_code, ids) not in (select atc_code,
                                             concept_id
                                      from dev_atc.existent_atc_rxnorm_to_drop))
        group by source
    ) t2  ON t1.source = t2.source

    JOIN

    (
        select source,
               count(*) as new_concepts_for_devv_5
        from dev_atc.new_atc_codes_rxnorm_for_source_analysis
        where concept_class_id = 'Clinical Drug Form'
        AND
        (    (class_code, ids) not in (select concept_code_atc,
                                             concept_id_rx
                                      from dev_atc.atc_rxnorm_to_drop_in_sources)
        AND
            (class_code, ids) not in (select atc_code,
                                             concept_id
                                      from dev_atc.existent_atc_rxnorm_to_drop)
        AND (class_code, ids) not in (select t1.concept_code,
                                               t2.concept_id
                                        FROM devv5.concept_relationship cr
                                             JOIN devv5.concept t1 on cr.concept_id_1 = t1.concept_id and t1.vocabulary_id = 'ATC'
                                                                                                      and cr.invalid_reason is NULL
                                                                                                      and t1.invalid_reason is NULL
                                                                                                      and cr.relationship_id = 'ATC - RxNorm'
                                             JOIN devv5.concept t2 on cr.concept_id_2 = t2.concept_id and t2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                                                      and t2.invalid_reason is NULL
                                                                                                      and t2.concept_class_id = 'Clinical Drug Form'
                                        WHERE (t1.concept_code, t2.concept_id) NOT IN (select concept_code_atc,
                                                                                             concept_id_rx
                                                                                      from dev_atc.atc_rxnorm_to_drop_in_sources)
                                        AND (t1.concept_code, t2.concept_id) NOT IN (select atc_code,
                                                                                             concept_id
                                                                                      from dev_atc.existent_atc_rxnorm_to_drop)
                                        )
            )
        group by source
    ) t3
on t1.source = t3.source;


---- How many monoingredient RxNorm codes from new sources have >1 ATC code.

WITH distinct_class_codes AS (
    SELECT
        ids,
        source,
        class_code
    from dev_atc.new_atc_codes_rxnorm_for_source_analysis
        where concept_class_id = 'Clinical Drug Form'
        AND
            ((class_code, ids) not in (select concept_code_atc,
                                             concept_id_rx
                                      from dev_atc.atc_rxnorm_to_drop_in_sources)
            AND
                (class_code, ids) not in (select atc_code,
                                             concept_id
                                      from dev_atc.existent_atc_rxnorm_to_drop))
        and length (class_code) = 7
),
class_code_discrepancies AS (
    SELECT
        ids,
        ARRAY_AGG(DISTINCT class_code) AS class_codes,
        --ARRAY_AGG(DISTINCT class_code || ' - ' || source) AS class_codes,
        COUNT(DISTINCT class_code) AS class_code_count
    FROM
        distinct_class_codes
    GROUP BY
        ids
)
SELECT
    ids,
    class_codes,
    class_code_count
FROM
    class_code_discrepancies t1
    join dev_atc.concept_relationship cr on t1.ids = cr.concept_id_1 and cr.relationship_id = 'RxNorm has ing'
WHERE
    class_code_count > 1
group by ids,
    class_codes,
    class_code_count having count(*)=1;