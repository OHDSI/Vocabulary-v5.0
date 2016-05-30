with t as (
    SELECT rel_id FROM
    (
        SELECT relationship_id, reverse_relationship_id FROM relationship 
        WHERE relationship_id in (
            'Concept replaced by',
            'Concept same_as to',
            'Concept alt_to to',
            'Concept poss_eq to',
            'Concept was_a to',
			'Maps to'
        )
    )
    UNPIVOT (rel_id FOR relationship_ids IN (relationship_id, reverse_relationship_id))
)
--cycle by same relationship_id
select 1 check_id, r.* from concept_relationship r, concept_relationship r_int
where r.invalid_reason is null
and r_int.concept_id_1=r.concept_id_2
and r_int.concept_id_2=r.concept_id_1
and r.concept_id_1<>r.concept_id_2
and r_int.relationship_id=r.relationship_id
and r_int.invalid_reason is null
and r.relationship_id in (select * from t)
union all
--two opposing relationships between same concepts
select 2 check_id, r.* from concept_relationship r, concept_relationship r_int, relationship rel
where r.invalid_reason is null
and r.relationship_id=rel.relationship_id
and r_int.concept_id_1=r.concept_id_1
and r_int.concept_id_2=r.concept_id_2
and r.concept_id_1<>r.concept_id_2
and r_int.relationship_id=rel.reverse_relationship_id
and r_int.invalid_reason is null
and r.relationship_id in (select * from t)
union all
--relationship without reverse
select 3 check_id, r.* from concept_relationship r, relationship rel
where r.invalid_reason is null
and r.relationship_id=rel.relationship_id
and r.concept_id_1<>r.concept_id_2
and not exists (
    select 1 from concept_relationship r_int
    where r_int.relationship_id=rel.reverse_relationship_id
    and r_int.invalid_reason is null
    and r_int.concept_id_1=r.concept_id_2
    and r_int.concept_id_2=r.concept_id_1    
)
and r.relationship_id in (select * from t)
union all
--replacing relationships between various vocabularies
select 4 check_id, r.* from concept_relationship r, concept c1, concept c2
where r.invalid_reason is null
and r.concept_id_1<>r.concept_id_2
and c1.concept_id=r.concept_id_1
and c2.concept_id=r.concept_id_2
and c1.vocabulary_id<>c2.vocabulary_id
and r.relationship_id in (select * from t where rel_id not in ('Maps to', 'Mapped from'))
union all
--'Maps to' should not be exist on 'U' and 'D' concepts, and  replacing relationships should not be exist on 'D' concepts
select 5 check_id, r.* From concept c2, concept_relationship r
where c2.concept_id=r.concept_id_2
and (
    (c2.invalid_reason in ('D', 'U') and r.relationship_id='Maps to')
    or
    (c2.invalid_reason = 'D' and r.relationship_id in ('Concept replaced by','Concept same_as to','Concept alt_to to','Concept poss_eq to','Concept was_a to'))
)
and r.invalid_reason is null
union all
--direct and reverse mappings have unequal status or date
select 6 check_id, r.* from concept_relationship r, relationship rel, concept_relationship r_int
where r.invalid_reason is null
and r.relationship_id=rel.relationship_id
and r_int.relationship_id=rel.reverse_relationship_id
and r_int.invalid_reason is null
and r_int.concept_id_1=r.concept_id_2
and r_int.concept_id_2=r.concept_id_1
and (r.valid_end_date<>r_int.valid_end_date or nvl(r.invalid_reason,'X')<>nvl(r_int.invalid_reason,'X'))
union all
--wrong valid_start_date, valid_end_date or invalid_reason
select 7 check_id, c.concept_id, null, c.vocabulary_id, c.valid_start_date, c.valid_end_date, c.invalid_reason from concept c
where c.valid_end_date<c.valid_start_date OR
(valid_end_date=TO_DATE ('20991231', 'YYYYMMDD') and invalid_reason is not null) OR
(valid_end_date<>TO_DATE ('20991231', 'YYYYMMDD') and invalid_reason is null) OR
valid_start_date>sysdate;