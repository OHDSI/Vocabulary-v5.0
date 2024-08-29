-- prelim
drop table if exists rx;
create temp table rx as
select
    c.concept_id,
    c.concept_code,
    c.concept_name,
    c.concept_class_id,
    count(cr.concept_id_2) as n_ings
FROM
    devv5.concept c
        join devv5.concept_relationship cr on cr.concept_id_1 = c.concept_id
        and c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
        and cr.invalid_reason is null
        and cr.relationship_id = 'RxNorm has ing'
group by c.concept_id, c.concept_code, c.concept_name
;
insert into rx
select     c.concept_id,
           c.concept_code,
           c.concept_name,
           c.concept_class_id,
           count(cc.concept_id) as n_ings
from devv5.concept c
    join devv5.concept_ancestor ca on c.concept_id = ca.descendant_concept_id
                                          and c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                          and c.concept_class_id != 'Ingredient'
    join devv5.concept cc on cc.concept_id = ca.ancestor_concept_id and cc.concept_class_id = 'Ingredient'
    where c.concept_id not in (select concept_id from rx)
group by c.concept_id, c.concept_code, c.concept_name
;
-- manual: covid, vaccines, insulines
-- covid 19
drop table if exists class_to_drug;
create table class_to_drug
as
select cs.concept_code as class_code, cs.concept_name as class_name, c.concept_id, c.concept_name, c.concept_class_id, 1 as concept_order
from dev_atc.covid19_atc_rxnorm_manual cov
join dev_atc.concept_stage cs on cov.concept_code_atc = cs.concept_code
join devv5.concept c on cov.concept_id = c.concept_id
where cov.to_drop is null;

-- vaccines, insulins
insert into class_to_drug
select distinct cs.concept_code, cs.concept_name, c.concept_id, c.concept_name, c.concept_class_id, 1 as concept_order
from dev_atc.concept_stage cs
         join dev_atc.concept_relationship_stage crs on crs.concept_code_1=cs.concept_code
    and cs.concept_class_id = 'ATC 5th'
    and crs.invalid_reason is null
    and crs.relationship_id = 'ATC - RxNorm'
         join devv5.concept c on c.concept_id = crs.concept_id_2
where cs.concept_code in (select class_code from dev_atc.class_to_drug_manual)
-- and (cs.concept_code, c.concept_id) not in (select class_code, concept_id from dev_atc.class_to_drug_manual) -- this is for review of the new links
;

-- Scenario 2 & 3, mono: Ingredient A
-- 3847 ATCs and 17K Rx
insert into class_to_drug
select distinct cs.concept_code, cs.concept_name, rx.concept_id, rx.concept_name, rx.concept_class_id, 2 as concept_order
from dev_atc.concept_stage cs
    join dev_atc.concept_relationship_stage crs on crs.concept_code_1=cs.concept_code
                                                and cs.concept_class_id = 'ATC 5th'
                                                and crs.invalid_reason is null
                                                and crs.relationship_id = 'ATC - RxNorm'
    join rx on rx.concept_id = crs.concept_id_2
                   and n_ings = 1
         where not exists (select * from dev_atc.concept_relationship_stage crs2
                            where crs2.concept_code_1 = crs.concept_code_1
                            and (crs2.relationship_id like '%sec%' --or crs2.relationship_id like '%pr up%'
                                )
                            and crs2.invalid_reason is null
)
and (cs.concept_code, rx.concept_id) not in (select class_code, concept_id from class_to_drug)
;

/*
-- check if pr up can be included in scenario 2&3, for this rough assembly doesn't matter,
-- includes things like contact laxatives in combination; oral OR cocaine; otic
select *, 2 as order
from dev_atc.concept_stage cs
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
                      )   -- forgot what this refers to, check
                    and crs2.invalid_reason is null
)
and exists (select * from dev_atc.concept_relationship_stage crs3
            where crs3.concept_code_1 = crs.concept_code_1
              and crs3.relationship_id like '%pr up%'
              and crs3.invalid_reason is null)
;
*/
-- scenario 4, combo: Ingredient A + Ingredient B
-- 214 ATC, 500 Rx
insert into class_to_drug
select distinct cs.concept_code, cs.concept_name, rx.concept_id, rx.concept_name, rx.concept_class_id, 3 as concept_order
from dev_atc.concept_stage cs
     join dev_atc.concept_relationship_stage crs on crs.concept_code_1=cs.concept_code
        and cs.concept_class_id = 'ATC 5th'
        and crs.invalid_reason is null
        and crs.relationship_id = 'ATC - RxNorm'
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
  and (cs.concept_code, rx.concept_id) not in (select class_code, concept_id from class_to_drug)
;

-- 3 and 4 fixed ingredients, some of the combos are wrong but keep due to the lack of time
-- 305 Rx
insert into class_to_drug
select distinct cs.concept_code, cs.concept_name, rx.concept_id, rx.concept_name, rx.concept_class_id, 4 as order
from dev_atc.concept_stage cs
         join dev_atc.concept_relationship_stage crs on crs.concept_code_1=cs.concept_code
    and cs.concept_class_id = 'ATC 5th'
    and crs.invalid_reason is null
    and crs.relationship_id = 'ATC - RxNorm'
         join rx on rx.concept_id = crs.concept_id_2
    and n_ings in (3, 4)
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
  and cs.concept_name not like '% comb%'
  and (cs.concept_code, rx.concept_id) not in (select class_code, concept_id from class_to_drug)
;

-- scenario 5, combo of
-- takes precedence because it is in fact Ingredient A + Ingredient B
-- ~20 ATC, 6K Rx
insert into class_to_drug
select distinct cs.concept_code, cs.concept_name, rx.concept_id, rx.concept_name, rx.concept_class_id, 5 as concept_order
from dev_atc.concept_stage cs
         join dev_atc.concept_relationship_stage crs on crs.concept_code_1=cs.concept_code
    and cs.concept_class_id = 'ATC 5th'
    and crs.invalid_reason is null
    and crs.relationship_id = 'ATC - RxNorm'
         join rx on rx.concept_id = crs.concept_id_2
where (cs.concept_name  like '%combinations of %' or cs.concept_name  like '%in combination%')
  and (cs.concept_code, rx.concept_id) not in (select class_code, concept_id from class_to_drug)
;

-- scenario 6, combo: Ingredient A + group B
-- if there is an extra ingredient beyond a and group b also goes here
insert into class_to_drug
select distinct cs.concept_code, cs.concept_name, rx.concept_id, rx.concept_name, rx.concept_class_id, 6 as concept_order
from dev_atc.concept_stage cs
    join dev_atc.concept_relationship_stage crs on crs.concept_code_1=cs.concept_code
        and cs.concept_class_id = 'ATC 5th'
        and crs.invalid_reason is null
        and crs.relationship_id = 'ATC - RxNorm'
     join rx on rx.concept_id = crs.concept_id_2
        and n_ings >= 2
where exists (select * from dev_atc.concept_relationship_stage crs2
              where crs2.concept_code_1 = crs.concept_code_1
                and (crs2.relationship_id like '%up%')
                and crs2.invalid_reason is null
)
  and cs.concept_name not like '%combinations%'
  and (cs.concept_code, rx.concept_id) not in (select class_code, concept_id from class_to_drug)
;

-- everything else
insert into class_to_drug
select distinct cs.concept_code, cs.concept_name, rx.concept_id, rx.concept_name, rx.concept_class_id, 7 as concept_order
from dev_atc.concept_stage cs
         join dev_atc.concept_relationship_stage crs on crs.concept_code_1=cs.concept_code
    and cs.concept_class_id = 'ATC 5th'
    and crs.invalid_reason is null
    and crs.relationship_id = 'ATC - RxNorm'
         join rx on rx.concept_id = crs.concept_id_2
  where (cs.concept_code, rx.concept_id) not in (select class_code, concept_id from class_to_drug)
;