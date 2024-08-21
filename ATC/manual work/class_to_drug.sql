
-- prelim
create temp table rx as
    select
                c.concept_id,
                c.concept_code,
                c.concept_name,
                count(cr.concept_id_2) as n_ings
            FROM
                devv5.concept c
                    join devv5.concept_relationship cr on cr.concept_id_1 = c.concept_id
                    and c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                    and c.concept_class_id = 'Clinical Drug Form'
                    and cr.invalid_reason is null
                    and cr.relationship_id = 'RxNorm has ing'
            group by c.concept_id, c.concept_code, c.concept_name
;

-- forgot what to do with things like contact laxatives in combination, query:
select * from dev_atc.concept_relationship_stage crs where crs.relationship_id like '%pr up%'
                                                       and not exists (select * from dev_atc.concept_relationship_stage crs2
                                                                       where crs2.concept_code_1 = crs.concept_code_1
                                                                         and (crs2.relationship_id like '%lat%'))


-- orders
-- 1. Manual
-- 2. Mono: Ingredient A; form
-- 3. Mono: Ingredient A
-- 4. Combo: Ingredient A + Ingredient B
-- 5. Combo: Ingredient A + group B
-- 6. Combo: Ingredient A, combination; form
-- 7. Combo: Ingredient A, combination
-- 8. Any packs
-- covid
SELECT *, 1 as order FROM dev_atc.covid19_atc_rxnorm_manual cov where cov.to_drop IS NULL;

-- getting ATC that are 1 ingredient (combining scenario 2 and 3)
select *, 2 as order from dev_atc.concept_stage cs
    join dev_atc.concept_relationship_stage crs on crs.concept_code_1=cs.concept_code
                                                and cs.concept_class_id = 'ATC 5th'
                                                and crs.invalid_reason is null
                                                and crs.relationship_id = 'ATC - RxNorm'
-- probably concept_id_2 is erased during prep stages so need to replace by cc+v pair
    join rx on rx.concept_id = crs.concept_id_2
                   and n_ings = 1
         where not exists (select * from dev_atc.concept_relationship_stage crs2
                            where crs2.concept_code_1 = crs.concept_code_1
                            and (crs2.relationship_id like '%sec%'
                                 or crs2.relationship_id like '%pr up%')   -- forgot what this refers to, check
                            and crs2.invalid_reason is null
)
-- and concept pairs not in order 1
;

-- scenario 4
select *, 3 as order from dev_atc.concept_stage cs
                              join dev_atc.concept_relationship_stage crs on crs.concept_code_1=cs.concept_code
    and cs.concept_class_id = 'ATC 5th'
    and crs.invalid_reason is null
    and crs.relationship_id = 'ATC - RxNorm'
-- probably concept_id_2 is erased during prep stages so need to replace by cc+v pair
                              join rx on rx.concept_id = crs.concept_id_2
    and n_ings = 2
where not exists (select * from dev_atc.concept_relationship_stage crs2
                  where crs2.concept_code_1 = crs.concept_code_1
                    and (crs2.relationship_id like '%up%')
                    and crs2.invalid_reason is null
)
    and exists (select * from dev_atc.concept_relationship_stage crs2
                where crs2.concept_code_1 = crs.concept_code_1
                  and crs2.relationship_id like '%sec%lat%' -- assuming everything has pr lat hence only allowing pr lat and sec lat
                  and crs2.invalid_reason is null
               )
-- and concept pairs not in order 1 or 2;


