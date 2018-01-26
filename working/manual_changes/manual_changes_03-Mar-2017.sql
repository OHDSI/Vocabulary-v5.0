--deprecate wrong links between Packs and Brand Names
update concept_relationship r set r.invalid_reason='D', r.valid_end_date=trunc(sysdate)-1
where (r.concept_id_1, r.concept_id_2)
in (
    select concept_id_1, concept_id_2 From (
        select concept_id_1, concept_id_2 From (
            select r.concept_id_1, r.concept_id_2, 
            c1.concept_name as c1_name, c2.concept_name as c2_name, 
            count(*) over(partition by r.concept_id_1) cnt
            From concept c1, concept c2, concept_relationship r
            where c1.concept_id=r.concept_id_1
            and c2.concept_id=r.concept_id_2
            and c1.vocabulary_id='RxNorm'
            and c1.concept_class_id like '%Pack'
            and c2.concept_class_id='Brand Name'
            and r.relationship_id='Has brand name'
            and r.invalid_reason is null 
        ) where cnt>1
        and lower(regexp_replace (c1_name,'.* Pack .*\[(.*)\]','\1'))<>lower(c2_name)
    )
    unpivot ((concept_id_1,concept_id_2) 
    FOR relationships IN ((concept_id_1,concept_id_2),(concept_id_2,concept_id_1)))
)
and r.invalid_reason is null
and r.relationship_id in ('Has brand name','Brand name of');
commit;