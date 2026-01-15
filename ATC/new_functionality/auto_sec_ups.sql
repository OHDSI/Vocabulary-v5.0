WITH atc_codes as
                    (
                    select DISTINCT class_code, class_name
                    from sources.atc_codes
                    where length (class_code) = 7
                    ),
    rxn_ingredients as
                    (
                    select concept_id, concept_name
                    from devv5.concept t1
                    where vocabulary_id in ('RxNorm', 'RxNorm Extension')
                    and concept_class_id in ('Ingredient', 'Precise Ingredient')
                    and invalid_reason is NULL

                    UNION

                    select t2.concept_id, concept_synonym_name
                    from devv5.concept t1
                        join devv5.concept_synonym t2 on t1.concept_id = t2.concept_id
                                        and t1.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                        and t1.concept_class_id in ('Ingredient', 'Precise Ingredient')
                                        and t1.invalid_reason is null
                    )
SELECT *
from atc_codes t1
     left join RXN_INGREDIENTS t2 on lower(t1.class_name) = lower(t2.concept_name)
where concept_name is null ;



WITH all_ids_except_secups as
(
    WITH sec_up_conns as
    (
        select *
        from dev_atc.new_atc_codes_ings_for_manual
        where relationship_id = 'ATC - RxNorm sec up'
    )
    SELECT class_code,
           string_agg(ids, ',') as ids
    FROM dev_atc.new_atc_codes_ings_for_manual
    where class_code in (select class_code from sec_up_conns)
      and relationship_id != 'ATC - RxNorm sec up'
    GROUP BY class_code
),
main_query as
(
    select t1.class_code,
           string_agg(DISTINCT c.concept_id::text, ',') as all_ids_on_markt,
           t2.ids as except_secups
    from dev_atc.new_unique_atc_codes_rxnorm t1
         join devv5.concept_ancestor ca on ca.descendant_concept_id = t1.ids
         join devv5.concept c on ca.ancestor_concept_id = c.concept_id
                                and c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                and c.concept_class_id in ('Ingredient', 'Precise Ingredient')
         join all_ids_except_secups t2 on t1.class_code = t2.class_code
    group by t1.class_code, t2.ids
)
SELECT class_code,
       all_ids_on_markt,
       except_secups,
       -- Вычитаем except_secups из all_ids_on_markt
       (SELECT string_agg(id::text, ',')
        FROM (SELECT unnest(string_to_array(all_ids_on_markt, ',')::bigint[]) as id
              EXCEPT
              SELECT unnest(string_to_array(except_secups, ',')::bigint[]) as id
             ) t
       ) as result_ids_without_secups
FROM main_query;


create table auto_sec_ups as
WITH all_ids_except_secups as
(
    WITH sec_up_conns as
    (
        select *
        from dev_atc.new_atc_codes_ings_for_manual
        where relationship_id = 'ATC - RxNorm sec up'
    )
    SELECT class_code,
           string_agg(ids, ',') as ids
    FROM dev_atc.new_atc_codes_ings_for_manual
    where class_code in (select class_code from sec_up_conns)
      and relationship_id != 'ATC - RxNorm sec up'
    GROUP BY class_code
),
main_query as
(
    select t1.class_code,
           string_agg(DISTINCT c.concept_id::text, ',') as all_ids_on_markt,
           t2.ids as except_secups
    from dev_atc.new_unique_atc_codes_rxnorm t1
         join devv5.concept_ancestor ca on ca.descendant_concept_id = t1.ids
         join devv5.concept c on ca.ancestor_concept_id = c.concept_id
                                and c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                and c.concept_class_id in ('Ingredient', 'Precise Ingredient')
         join all_ids_except_secups t2 on t1.class_code = t2.class_code
    group by t1.class_code, t2.ids
),
resulting_secups as (
    SELECT class_code,
           all_ids_on_markt,
           except_secups,
           (SELECT string_agg(id::text, ',')
            FROM (SELECT unnest(string_to_array(all_ids_on_markt, ',')::bigint[]) as id
                  EXCEPT
                  SELECT unnest(string_to_array(except_secups, ',')::bigint[]) as id
                 ) t
           ) as result_ids_without_secups
    FROM main_query
),
ingredient_names as (
    -- Получаем названия для всех ID
    SELECT
        rs.class_code,
        -- Название класса ATC
        MAX(atc.concept_name) as atc_class_name,
        -- Названия всех ингредиентов
        (SELECT string_agg(concept_name, '; ' ORDER BY concept_name)
         FROM devv5.concept c
         WHERE c.concept_id::text IN (
             SELECT unnest(string_to_array(rs.all_ids_on_markt, ','))
         )
        ) as all_ingredient_names,
        -- Названия исключенных ингредиентов
        (SELECT string_agg(concept_name, '; ' ORDER BY concept_name)
         FROM devv5.concept c
         WHERE c.concept_id::text IN (
             SELECT unnest(string_to_array(rs.except_secups, ','))
         )
        ) as except_ingredient_names,
        -- Названия оставшихся ингредиентов
        (SELECT string_agg(concept_name, '; ' ORDER BY concept_name)
         FROM devv5.concept c
         WHERE c.concept_id::text IN (
             SELECT unnest(string_to_array(rs.result_ids_without_secups, ','))
         )
        ) as remaining_ingredient_names
    FROM resulting_secups rs
    LEFT JOIN devv5.concept atc ON atc.vocabulary_id = 'ATC'
        AND atc.concept_code = rs.class_code
    GROUP BY rs.class_code, rs.all_ids_on_markt, rs.except_secups, rs.result_ids_without_secups
)
SELECT
    rs.class_code,
    in_names.atc_class_name,
    rs.all_ids_on_markt,
    rs.except_secups,
    rs.result_ids_without_secups,
    in_names.all_ingredient_names,
    in_names.except_ingredient_names,
    in_names.remaining_ingredient_names
FROM resulting_secups rs
JOIN ingredient_names in_names ON rs.class_code = in_names.class_code
ORDER BY rs.class_code;


create table new_atc_codes_ings_for_manual_only_sec_ups as
select *
    from new_atc_codes_ings_for_manual
where relationship_id = 'ATC - RxNorm sec up';

SELECT
    n.class_code,
    t2.atc_class_name,
    n.relationship_id,
    n.ids as ids_old,
    (
        SELECT string_agg(c.concept_name, '; ' ORDER BY unnest_id.idx)
        FROM unnest(string_to_array(n.ids, ',')) WITH ORDINALITY AS unnest_id(id, idx)
        JOIN devv5.concept c ON c.concept_id = unnest_id.id::bigint
    ) as concept_names_old,
    length(n.ids) - length(replace(n.ids, ',', '')) + 1 as num_of_elem_old,
    t2.result_ids_without_secups as ids_new,
    length(t2.result_ids_without_secups) - length(replace(t2.result_ids_without_secups, ',', '')) + 1 as num_of_elem_new
FROM new_atc_codes_ings_for_manual_only_sec_ups n
LEFT JOIN auto_sec_ups t2 on n.class_code = t2.class_code
ORDER BY n.class_code;

select *
from new_atc_codes_ings_for_manual_only_sec_ups
ORDER BY class_code;
select *
from auto_sec_ups
order by class_code;

WITH all_ids_except_secups as
(
    WITH sec_up_conns as
    (
        select *
        from dev_atc.new_atc_codes_ings_for_manual
        where relationship_id = 'ATC - RxNorm sec up'
    )
    SELECT class_code,
           string_agg(ids, ',') as ids
    FROM dev_atc.new_atc_codes_ings_for_manual
    where class_code in (select class_code from sec_up_conns)
      and relationship_id != 'ATC - RxNorm sec up'
    GROUP BY class_code
),
main_query as
(
    select t1.class_code,
           string_agg(DISTINCT c.concept_id::text, ',') as all_ids_on_markt,
           t2.ids as except_secups
    from dev_atc.new_unique_atc_codes_rxnorm t1
         join devv5.concept_ancestor ca on ca.descendant_concept_id = t1.ids
         join devv5.concept c on ca.ancestor_concept_id = c.concept_id
                                and c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                and c.concept_class_id in ('Ingredient', 'Precise Ingredient')
         join all_ids_except_secups t2 on t1.class_code = t2.class_code
    group by t1.class_code, t2.ids
),
    ONLY_SEC_UPS as (
                    SELECT class_code,
                           (SELECT string_agg(id::text, ',')
                            FROM (SELECT unnest(string_to_array(all_ids_on_markt, ',')::bigint[]) as id
                                  EXCEPT
                                  SELECT unnest(string_to_array(except_secups, ',')::bigint[]) as id
                                 ) t
                           ) as result_ids_only_secups
                    FROM main_query),
    class_code_secup_id as (
                            SELECT
                                class_code,
                                unnest(string_to_array(result_ids_only_secups, ','))::INT as ids
                            FROM ONLY_SEC_UPS)
    SELECT
        NULL::INT AS concept_id_1,
       NULL::INT AS concept_id_2,
       t1.class_code AS concept_code_1,
       t2.concept_code AS concept_code_2,
       'ATC' AS vocabulary_id_1,
       t2.vocabulary_id AS vocabulary_id_2,
       'ATC - RxNorm sec up',
       CURRENT_DATE AS valid_start_date,
       TO_DATE('2099-12-31', 'YYYY-MM-DD') AS valid_end_date,
       NULL AS invalid_reason
    FROM CLASS_CODE_SECUP_ID t1 join concept t2 on t1.ids = t2.concept_id
                                                and t2.invalid_reason is NULL
                                                and t2.standard_concept = 'S';
