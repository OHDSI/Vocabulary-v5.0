--AddMapsToValue function: different cases examples to improve logic
--CASE 1: A maps to B, B maps to C and maps to value D
select c.concept_id as A_id,
       c.concept_name as A_name,
       cr.relationship_id,
       cr.invalid_reason,
       cc.concept_id as B_id,
       cc.concept_name as B_name,
       ccr.relationship_id,
       ccr.invalid_reason,
       ccc.concept_id as C_D_id,
       ccc.concept_name as C_D_name,
       ccc.standard_concept,
       ccc.invalid_reason
from devv5.concept c
join devv5.concept_relationship cr ON c.concept_id = cr.concept_id_1
join devv5.concept cc ON cr.concept_id_2 = cc.concept_id
join devv5.concept_relationship ccr ON cc.concept_id = ccr.concept_id_1
join devv5.concept ccc ON ccc.concept_id = ccr.concept_id_2
where cr.invalid_reason = 'D' and cr.relationship_id IN ('Maps to',
                                                         'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to')
and ccr.invalid_reason IS NULL and ccr.relationship_id IN ('Maps to',
                                                           'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to',
                                                           'Maps to value')
and ccr.concept_id_1 IN (select concept_id_1
                        from devv5.concept_relationship
                     where relationship_id = 'Maps to value'
                     and invalid_reason IS NULL
                     /*GROUP BY concept_id_1
                    HAVING count(*) = 1*/)
and ccr.concept_id_1 IN (select concept_id_1
                        from devv5.concept_relationship
                     where relationship_id IN ('Maps to',
                                               'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to')
                     and invalid_reason IS NULL)
and ccc.standard_concept = 'S' and ccc.invalid_reason IS NULL
order by c.concept_id, cc.concept_id, ccr.relationship_id;

--CASE 2: A maps to B, B maps to C and maps to value D, C maps to N
select c.concept_id as A_id,
       c.concept_name as A_name,
       cr.relationship_id,
       cr.invalid_reason,
       cc.concept_id as B_id,
       cc.concept_name as B_name,
       ccr.relationship_id,
       ccr.invalid_reason,
       ccc.concept_id as C_D_id,
       ccc.concept_name as C_D_name,
       cccr.relationship_id,
       cccr.invalid_reason,
       cccc.concept_id as n_id,
       cccc.concept_name as n_name
from devv5.concept c
join devv5.concept_relationship cr ON c.concept_id = cr.concept_id_1
join devv5.concept cc ON cr.concept_id_2 = cc.concept_id
join devv5.concept_relationship ccr ON cc.concept_id = ccr.concept_id_1
join devv5.concept ccc ON ccc.concept_id = ccr.concept_id_2
join devv5.concept_relationship cccr ON ccc.concept_id = cccr.concept_id_1
join devv5.concept cccc ON cccc.concept_id = cccr.concept_id_2
where cr.invalid_reason = 'D' and cr.relationship_id IN ('Maps to',
                                                         'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to')
  and cccr.invalid_reason IS NULL and cccr.relationship_id IN ('Maps to',
                                                         'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to')
and ccr.invalid_reason IS NULL and ccr.relationship_id IN ('Maps to',
                                                           'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to',
                                                           'Maps to value')
and ccr.concept_id_1 IN (select concept_id_1
                        from devv5.concept_relationship
                     where relationship_id = 'Maps to value'
                     and invalid_reason IS NULL)
and ccr.concept_id_1 IN (select concept_id_1
                        from devv5.concept_relationship
                     where relationship_id IN ('Maps to',
                                               'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to')
                     and invalid_reason IS NULL)
  and cccr.concept_id_1 NOT IN (select concept_id_1
                        from devv5.concept_relationship
                     where relationship_id = 'Maps to value'
                     and invalid_reason IS NULL)
and cccr.concept_id_1 IN (select concept_id_1
                        from devv5.concept_relationship
                     where relationship_id IN ('Maps to',
                                               'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to')
                     and invalid_reason IS NULL)
and ccc.standard_concept IS NULL
order by c.concept_id, cc.concept_id, ccr.relationship_id, ccc.concept_id, cccr.relationship_id;


--CASE 3: A maps to B, B maps to C and maps to value D, C maps to E and maps to value F
select c.concept_id as A_id,
       c.concept_name as A_name,
       cr.relationship_id,
       cr.invalid_reason,
       cc.concept_id as B_id,
       cc.concept_name as B_name,
       ccr.relationship_id,
       ccr.invalid_reason,
       ccc.concept_id as C_D_id,
       ccc.concept_name as C_D_name,
       cccr.relationship_id,
       cccr.invalid_reason,
       cccc.concept_id as n_id,
       cccc.concept_name as n_name
from devv5.concept c
join devv5.concept_relationship cr ON c.concept_id = cr.concept_id_1
join devv5.concept cc ON cr.concept_id_2 = cc.concept_id
join devv5.concept_relationship ccr ON cc.concept_id = ccr.concept_id_1
join devv5.concept ccc ON ccc.concept_id = ccr.concept_id_2
join devv5.concept_relationship cccr ON ccc.concept_id = cccr.concept_id_1
join devv5.concept cccc ON cccc.concept_id = cccr.concept_id_2
where cr.invalid_reason = 'D' and cr.relationship_id IN ('Maps to',
                                                         'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to')
  and cccr.invalid_reason IS NULL and cccr.relationship_id IN ('Maps to',
                                                         'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to',
                                                           'Maps to value')
and ccr.invalid_reason IS NULL and ccr.relationship_id IN ('Maps to',
                                                           'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to',
                                                           'Maps to value')
and ccr.concept_id_1 IN (select concept_id_1
                        from devv5.concept_relationship
                     where relationship_id = 'Maps to value'
                     and invalid_reason IS NULL)
and ccr.concept_id_1 IN (select concept_id_1
                        from devv5.concept_relationship
                     where relationship_id IN ('Maps to',
                                               'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to')
                     and invalid_reason IS NULL)
  and cccr.concept_id_1 IN (select concept_id_1
                        from devv5.concept_relationship
                     where relationship_id = 'Maps to value'
                     and invalid_reason IS NULL)
and cccr.concept_id_1 IN (select concept_id_1
                        from devv5.concept_relationship
                     where relationship_id IN ('Maps to',
                                               'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to')
                     and invalid_reason IS NULL)
and ccc.standard_concept IS NULL
order by c.concept_id, cc.concept_id, ccr.relationship_id, ccc.concept_id, cccr.relationship_id;


--CASE 4: A maps to B, B maps to C and maps to value D, D maps to E and maps to value F
select c.concept_id as A_id,
       c.concept_name as A_name,
       cr.relationship_id,
       cr.invalid_reason,
       cc.concept_id as B_id,
       cc.concept_name as B_name,
       ccr.relationship_id,
       ccr.invalid_reason,
       ccc.concept_id as C_D_id,
       ccc.concept_name as C_D_name,
       ccc.standard_concept,
       ccc.invalid_reason
from devv5.concept c
join devv5.concept_relationship cr ON c.concept_id = cr.concept_id_1
join devv5.concept cc ON cr.concept_id_2 = cc.concept_id
join devv5.concept_relationship ccr ON cc.concept_id = ccr.concept_id_1
join devv5.concept ccc ON ccc.concept_id = ccr.concept_id_2
where cr.invalid_reason = 'D' and cr.relationship_id IN ('Maps to',
                                                         'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to')
and ccr.invalid_reason IS NULL /*and ccr.relationship_id IN ('Maps to',
                                                           'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to',
                                                           'Maps to value')*/
and ccr.concept_id_1 IN (select concept_id_1
                        from devv5.concept_relationship
                     where relationship_id = 'Maps to value'
                     and invalid_reason IS NULL)
and ccr.concept_id_1 IN (select concept_id_1
                        from devv5.concept_relationship
                     where relationship_id IN ('Maps to',
                                               'Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept was_a to')
                     and invalid_reason IS NULL)
and ccc.standard_concept IS NULL and ccr.relationship_id = 'Maps to value'
order by c.concept_id, cc.concept_id, ccr.relationship_id;

--Test commit
--Test commit 2
--Test commit 3
--Test commit 4
--Test commit 5