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
where lower(cs1.concept_synonym_name) is distinct from  lower(cs2.concept_synonym_name)

;