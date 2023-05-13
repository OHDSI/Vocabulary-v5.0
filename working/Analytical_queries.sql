--AddMapsToValue function: different cases examples to improve logic
--CASE 1: A maps to B, B maps to C and maps to value D
select c.concept_id as A_id, --A concept_id
       c.concept_name as A_name, --A concept_name
       cr.relationship_id as a_to_b_rels, --A to B links
       cr.invalid_reason as a_to_b_invalid_reason, --Validity of A to B links
       cc.concept_id as B_id, --B concept_id
       cc.concept_name as B_name, --B concept_name
       ccr.relationship_id b_to_c_d_rels, --B to C and D links
       ccr.invalid_reason b_to_c_d_invalid_reason, --Validity of B to C and D links
       ccc.concept_id as C_D_id, --C and D concept_id
       ccc.concept_name as C_D_name --C and D concept_name
from devv5.concept c --getting A
join devv5.concept_relationship cr ON c.concept_id = cr.concept_id_1 --getting B concept_id
join devv5.concept cc ON cr.concept_id_2 = cc.concept_id --getting B concept_name
join devv5.concept_relationship ccr ON cc.concept_id = ccr.concept_id_1 --getting C and D concept_id
join devv5.concept ccc ON ccc.concept_id = ccr.concept_id_2 --getting C and D concept_name
where ((cr.invalid_reason = 'D' and cr.relationship_id IN ('Maps to') and cr.concept_id_1 != cr.concept_id_2) --mapping to itself excluded, only deprecated Maps to links from A to B
    or (cr.invalid_reason IS NULL and cr.relationship_id IN ('Concept replaced by',
                                                             'Concept same_as to',
                                                             'Concept alt_to to',
                                                             'Concept was_a to'))) --actual replacement links from A to B
  and ccr.invalid_reason IS NULL --only actual links from B to C
  and ccr.relationship_id IN ('Maps to',
                              'Concept replaced by',
                              'Concept same_as to',
                              'Concept alt_to to',
                              'Concept was_a to',
                              'Maps to value')
  and ccr.concept_id_1 IN (select concept_id_1 --B must have maps to value link
                           from devv5.concept_relationship
                           where relationship_id = 'Maps to value'
                             and invalid_reason IS NULL)
  and ccr.concept_id_1 IN (select concept_id_1 --B must have any replacement links
                           from devv5.concept_relationship
                           where relationship_id IN ('Maps to',
                                                     'Concept replaced by',
                                                     'Concept same_as to',
                                                     'Concept alt_to to',
                                                     'Concept was_a to')
                             and invalid_reason IS NULL)
  and ccc.standard_concept = 'S' --C and D must be Standard
  AND cc.standard_concept IS NULL --B must be Non-Standard
  and ccc.invalid_reason IS NULL --C and D must be valid
order by c.concept_id, cc.concept_id, ccr.relationship_id;

--CASE 2: A maps to B, B maps to C and maps to value D, C maps to N
select c.concept_id as A_id, --A concept_id
       c.concept_name as A_name, --A concept_name
       cr.relationship_id, --A to B links
       cr.invalid_reason, --Validity of A to B links
       cc.concept_id as B_id, --B concept_id
       cc.concept_name as B_name, --B concept_name
       ccr.relationship_id, --B to C links
       ccr.invalid_reason, --Validity of B to C links
       ccc.concept_id as C_D_id, --C concept_id
       ccc.concept_name as C_D_name, --C concept_name
       cccr.relationship_id, --C to N links
       cccr.invalid_reason, --Validity of C to N links
       cccc.concept_id as n_id, --N concept_id
       cccc.concept_name as n_name --N concept_name
from devv5.concept c --getting A
join devv5.concept_relationship cr ON c.concept_id = cr.concept_id_1 --getting B_concept_id
join devv5.concept cc ON cr.concept_id_2 = cc.concept_id --getting B concept_name
join devv5.concept_relationship ccr ON cc.concept_id = ccr.concept_id_1 --getting C concept_id
join devv5.concept ccc ON ccc.concept_id = ccr.concept_id_2 --getting C concept_name
join devv5.concept_relationship cccr ON ccc.concept_id = cccr.concept_id_1 --getting N concept_id
join devv5.concept cccc ON cccc.concept_id = cccr.concept_id_2 --getting N_concept_name
where ((cr.invalid_reason = 'D' and cr.relationship_id IN ('Maps to') and cr.concept_id_1 != cr.concept_id_2) --mapping to itself excluded, only deprecated Maps to links from A to B
    or (cr.invalid_reason IS NULL and cr.relationship_id IN ('Concept replaced by',
                                                             'Concept same_as to',
                                                             'Concept alt_to to',
                                                             'Concept was_a to'))) --actual replacement links from A to B
  and cccr.invalid_reason IS NULL --only actual links to N
  and cccr.relationship_id IN ('Maps to',
                               'Concept replaced by',
                               'Concept same_as to',
                               'Concept alt_to to',
                               'Concept was_a to') --needed rels from C to N
  and ((ccr.invalid_reason IS NULL and ccr.relationship_id IN (
                               'Concept replaced by',
                              'Concept same_as to',
                              'Concept alt_to to',
                              'Concept was_a to',
                              'Maps to value')) or ccr.relationship_id = 'Maps to')
  and ccr.concept_id_1 IN (select concept_id_1 --checking B has actual maps to value link
                           from devv5.concept_relationship
                           where relationship_id = 'Maps to value'
                             and invalid_reason IS NULL)
  and ccr.concept_id_1 IN (select concept_id_1 --checking B has actual replacement link
                           from devv5.concept_relationship
                           where relationship_id IN ('Maps to',
                                                     'Concept replaced by',
                                                     'Concept same_as to',
                                                     'Concept alt_to to',
                                                     'Concept was_a to'))
  and cccr.concept_id_1 NOT IN (select concept_id_1 --C must not have maps to value links
                                from devv5.concept_relationship
                                where relationship_id = 'Maps to value'
                                  and invalid_reason IS NULL)
  and cccr.concept_id_1 IN (select concept_id_1 --C must have any replacement link
                            from devv5.concept_relationship
                            where relationship_id IN ('Maps to',
                                                      'Concept replaced by',
                                                      'Concept same_as to',
                                                      'Concept alt_to to',
                                                      'Concept was_a to'))
  and ccc.standard_concept IS NULL --C must be Non-Standard
  and cccc.standard_concept = 'S' --N must be Standard
order by c.concept_id, cc.concept_id, ccr.relationship_id, ccc.concept_id, cccr.relationship_id;


--CASE 3: A maps to B, B maps to C and maps to value D, C maps to E and maps to value F
with t1 as (SELECT cr6.concept_id_1    as a_concept_id,            --A concept_id
                   c3.concept_name     as a_concept_name,          --A concept_name
                   cr6.relationship_id AS a_to_b_rels,             --links from A to B
                   cr6.invalid_reason  AS a_to_b_invalid_reason,   --validity of A to B links
                   cr4.concept_id_1    as b_concept_id,            --B concept_id
                   c2.concept_name     as b_concept_name,          --B concept_name
                   cr4.relationship_id AS b_to_c_rels,             --links from B to C
                   cr4.invalid_reason  AS b_to_c_invalid_reason,   --validity of B to C links
                   c.concept_id        AS c_concept_id,            --C concept_id
                   c.concept_name      AS c_concept_name,          --C concept_name
                   cr.relationship_id  AS c_to_d_f_rels,           --links from C to F
                   cr.invalid_reason   AS c_to_d_f_invalid_reason, --validity of C to F links
                   cr.concept_id_2     AS d_f_concept_id,          --F concept_id
                   c1.concept_name     AS d_f_concept_name         --F concept_name
            FROM devv5.concept c
                     JOIN devv5.concept_relationship cr ON cr.concept_id_1 = c.concept_id --getting F concept_id
                     JOIN devv5.concept c1 ON c1.concept_id = cr.concept_id_2 --getting F concept_name
                     JOIN devv5.concept_relationship cr4 ON cr4.concept_id_2 = c.concept_id --getting B concept_id
                     JOIN devv5.concept c2 ON cr4.concept_id_1 = c2.concept_id --getting B concept_name
                     JOIN devv5.concept_relationship cr6 ON cr6.concept_id_2 = c2.concept_id --getting A concept_id
                     JOIN devv5.concept c3 ON cr6.concept_id_1 = c3.concept_id --getting A concept_name
                AND cr.invalid_reason IS NULL AND cr.relationship_id IN ('Maps to value') --finding F
                AND ((cr4.relationship_id = 'Maps to' and cr4.concept_id_1 != cr4.concept_id_2) or (cr4.relationship_id IN ('Concept replaced by',
                                                                                   'Concept same_as to',
                                                                                   'Concept alt_to to',
                                                                                   'Concept was_a to') and
                                                           cr4.invalid_reason IS NULL)) --needed B to C relationships
                AND cr4.concept_id_1 IN (select concept_id_1
                                         from concept_relationship
                                         where relationship_id = 'Maps to value'
                                           and invalid_reason IS NULL) --B must have 'Maps to value'
                AND ((cr6.relationship_id = 'Maps to' and cr6.concept_id_1 != cr6.concept_id_2) or (cr6.relationship_id IN ('Concept replaced by',
                                                                                   'Concept same_as to',
                                                                                   'Concept alt_to to',
                                                                                   'Concept was_a to') and
                                                           cr6.invalid_reason IS NULL))
                AND EXISTS(select 1
                           from concept_relationship cr5
                           where cr4.concept_id_1 = cr5.concept_id_1
                             and cr5.relationship_id = 'Maps to value'
                             and cr5.invalid_reason IS NULL
                             and cr5.concept_id_2 != cr.concept_id_2) --F != E
--additional check
                AND EXISTS(
                                                      SELECT 1
                                                      FROM devv5.concept_relationship cr1 --finding B
                                                      WHERE cr1.relationship_id IN ('Maps to',
                                                                                    'Concept replaced by',
                                                                                    'Concept same_as to',
                                                                                    'Concept alt_to to',
                                                                                    'Concept was_a to')
                                                        AND cr1.concept_id_2 = cr.concept_id_1
                                                        AND cr1.concept_id_2 != cr1.concept_id_1
                                                        AND EXISTS(select 1 --checking E != F
                                                                   from devv5.concept_relationship cr2
                                                                   where cr2.relationship_id = 'Maps to value'
                                                                     and cr2.invalid_reason IS NULL
                                                                     and cr1.concept_id_1 = cr2.concept_id_1
                                                                     and cr2.concept_id_2 != cr.concept_id_2)
                                                        AND EXISTS(select 1 --checking existence of A
                                                                   from devv5.concept_relationship cr3
                                                                   where ((cr3.relationship_id = 'Maps to' and invalid_reason = 'D') or
                                                                          (cr3.relationship_id IN
                                                                           ('Concept replaced by',
                                                                            'Concept same_as to',
                                                                            'Concept alt_to to',
                                                                            'Concept was_a to') and
                                                                           invalid_reason IS NULL))
                                                                     and cr1.concept_id_1 = cr3.concept_id_2
                                                          )
                                                  )

            WHERE c.vocabulary_id != 'PCORNet')

select *
from t1

union
--getting C maps to links
select distinct a_concept_id,
                a_concept_name,
                a_to_b_rels,
                a_to_b_invalid_reason,
                b_concept_id,
                b_concept_name,
                b_to_c_rels,
                b_to_c_invalid_reason,
                c_concept_id,
                c_concept_name,
                cr.relationship_id as c_to_d_f_rels,
                cr.invalid_reason  as c_to_d_f_invalid_reason,
                cr.concept_id_2    as d_f_concept_id,
                c.concept_name     as d_f_concept_name
from t1
         join concept_relationship cr ON t1.c_concept_id = cr.concept_id_1
         join concept c ON cr.concept_id_2 = c.concept_id
    and cr.relationship_id = 'Maps to' and cr.invalid_reason IS NULL

union
--getting B maps to links
select a_concept_id,
       a_concept_name,
       a_to_b_rels,
       a_to_b_invalid_reason,
       b_concept_id,
       b_concept_name,
       cr.relationship_id as b_to_c_rels,
       cr.invalid_reason  as b_to_c_invalid_reason,
       cr.concept_id_2    as c_concept_id,
       c.concept_name     as c_concept_name,
       NULL               as c_to_d_f_rels,
       NULL               as c_to_d_f_invalid_reason,
       0                  as d_f_concept_id,
       NULL               as d_f_concept_name
from t1
         join concept_relationship cr ON t1.b_concept_id = cr.concept_id_1
         join concept c ON cr.concept_id_2 = c.concept_id
    and cr.relationship_id = 'Maps to value' and cr.invalid_reason IS NULL

order by a_concept_id, a_to_b_rels, b_concept_id, b_to_c_rels, c_concept_id, c_to_d_f_rels
;

--CASE 3.1 where E = F
/*select c.concept_id as A_id,
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
where ((cr.invalid_reason = 'D' and cr.relationship_id IN ('Maps to') and cr.concept_id_1 != cr.concept_id_2)
    or (cr.invalid_reason IS NULL and cr.relationship_id IN ('Concept replaced by',
                                                             'Concept same_as to',
                                                             'Concept alt_to to',
                                                             'Concept was_a to')))
  and cccr.invalid_reason IS NULL
  and cccr.relationship_id IN ('Maps to',
                               'Concept replaced by',
                               'Concept same_as to',
                               'Concept alt_to to',
                               'Concept was_a to',
                               'Maps to value')
  and ccr.invalid_reason IS NULL
  and ccr.relationship_id IN ('Maps to',
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
order by c.concept_id, cc.concept_id, ccr.relationship_id, ccc.concept_id, cccr.relationship_id;*/


--CASE 4: B maps to C and maps to value E, E maps to D and maps to value F
with b_maps_to_value AS (SELECT /*cr2.concept_id_1 as a_concept_id,
       cr2.relationship_id,
       cr2.invalid_reason,*/ -- getting A concepts (don't exist)
                             cr1.concept_id_1    AS b_concept_id, --B concept_id
                             cc1.concept_name    as b_concept_name, --B concept_name
                             cr1.relationship_id as b_relationship_id, --B to E links
                             cr1.invalid_reason, --Validity of B to E links
                             c.concept_id        AS e_c_concept_id, --E concept_id
                             c.concept_name      AS e_c_concept_name, --E concept_name
                             cr.relationship_id  as relationship_id, --E to D and F links
                             cr.invalid_reason   as invalid_reason, --Validity of E to D and F links
                             cr.concept_id_2     as d_f_concept_id, --D and F concept_id
                             cc.concept_name     as d_f_name --D and F concept_name
                         FROM devv5.concept c --getting E
                                  JOIN devv5.concept_relationship cr ON cr.concept_id_1 = c.concept_id --getting E and F concept_id
                                  JOIN devv5.concept cc ON cr.concept_id_2 = cc.concept_id --getting E and F concept_name
                                  JOIN devv5.concept_relationship cr1 ON cr1.concept_id_2 = c.concept_id --getting B concept_id
                                  JOIN devv5.concept cc1 ON cr1.concept_id_1 = cc1.concept_id --getting B concept_name
                             /*JOIN devv5.concept_relationship cr2 ON cc1.concept_id = cr2.concept_id_2
                             /*AND cr2.relationship_id = 'Maps to' and cr.invalid_reason = 'D'*/*/ --getting A concepts (don't exist)
                             AND cr.relationship_id IN ('Maps to', 'Maps to value') and cr.invalid_reason IS NULL --E must have valid both valid links
                             AND cr.concept_id_1 IN (select concept_id_1 --checking E has maps to value link
                                                     from devv5.concept_relationship
                                                     where relationship_id = 'Maps to value'
                                                       and invalid_reason IS NULL)
                             AND cr.concept_id_1 IN (select concept_id_1 --checking E has map to link
                                                     from devv5.concept_relationship
                                                     where relationship_id = 'Maps to'
                                                       and invalid_reason IS NULL)
                             AND cr1.relationship_id = 'Maps to value' --E must be value of B
                             AND cr1.concept_id_1 NOT IN (select concept_id_1
                                                          from concept_relationship
                                                          where relationship_id = 'Maps to'
                                                            and invalid_reason = 'D') --excluding possible case 5, all concept have active "maps to" link, but these also have deprecated

                         WHERE c.vocabulary_id != 'PCORNet')

SELECT distinct b_concept_id, --getting C
                b_concept_name,
                cr.relationship_id as b_relationship_id,
                cr.invalid_reason,
                cr.concept_id_2    as e_c_concept_id,
                c1.concept_name    as e_c_concept_name,
                NULL               as relationship_id,
                NULL               as invalid_reason,
                0                  as d_f_concept_id,
                NULL               as d_f_name
from b_maps_to_value
         join concept_relationship cr ON b_concept_id = cr.concept_id_1
         join concept c1 ON c1.concept_id = cr.concept_id_2
    AND cr.relationship_id = 'Maps to' and cr.invalid_reason IS NULL

union

select *
from b_maps_to_value
order by b_concept_id, b_relationship_id
;

--CASE 5: B maps to C and maps to value E, E maps to D and maps to value F, C maps to G and maps to value H
--These links never existed at the same time
with b_maps_to_value AS (SELECT /*cr2.concept_id_1 as a_concept_id,
       cr2.relationship_id,
       cr2.invalid_reason,*/ -- getting A concepts (don't exist)
                             cr1.concept_id_1    AS b_concept_id, --B concept_id
                             cc1.concept_name    as b_concept_name, --B concept_name
                             cr1.relationship_id as b_relationship_id, --B to E links
                             cr1.invalid_reason, --Validity of B to E links
                             cr1.valid_start_date, --Shows when B to E links became valid
                             cr1.valid_end_date, --Shows when B to E links became invalid
                             c.concept_id        AS e_c_concept_id, --E concept_id
                             c.concept_name      AS e_c_concept_name, --E concept_name
                             cr.relationship_id  as relationship_id, --E links to D and F
                             cr.invalid_reason   as invalid_reason, --Validity of E to D and F links
                             cr.concept_id_2     as d_f_concept_id, --D and F concept_id
                             cc.concept_name     as d_f_name --D and F concept_name
                         FROM devv5.concept c --getting E
                                  JOIN devv5.concept_relationship cr ON cr.concept_id_1 = c.concept_id --getting D and F concept_id
                                  JOIN devv5.concept cc ON cr.concept_id_2 = cc.concept_id --getting D and F concept_name
                                  JOIN devv5.concept_relationship cr1 ON cr1.concept_id_2 = c.concept_id --getting B concept_id
                                  JOIN devv5.concept cc1 ON cr1.concept_id_1 = cc1.concept_id --getting B concept_name
                             /*JOIN devv5.concept_relationship cr2 ON cc1.concept_id = cr2.concept_id_2
                             /*AND cr2.relationship_id = 'Maps to' and cr.invalid_reason = 'D'*/*/ --getting A concepts (don't exist)
                             AND cr.relationship_id IN ('Maps to', 'Maps to value') and cr.invalid_reason IS NULL --both actual links from E to D and F
                             AND cr.concept_id_1 IN (select concept_id_1 --checking E has maps to value link
                                                     from devv5.concept_relationship
                                                     where relationship_id = 'Maps to value'
                                                       and invalid_reason IS NULL)
                             AND cr.concept_id_1 IN (select concept_id_1 --checking E has maps to link
                                                     from devv5.concept_relationship
                                                     where relationship_id = 'Maps to'
                                                       and invalid_reason IS NULL)
                             AND cr1.relationship_id = 'Maps to value' --E must be value of B
                             AND cr1.concept_id_1 IN (select concept_id_1
                                                      from concept_relationship
                                                      where relationship_id = 'Maps to'
                                                        and invalid_reason = 'D') --B has invalid link to C

                         WHERE c.vocabulary_id != 'PCORNet')

SELECT distinct b_concept_id, --getting C and its mapping
                b_concept_name,
                cr.relationship_id  as b_relationship_id,
                cr.invalid_reason,
                cr.valid_start_date,
                cr.valid_end_date,
                cr.concept_id_2     as e_c_concept_id,
                c1.concept_name     as e_c_concept_name,
                cr2.relationship_id as relationship_id,
                cr2.invalid_reason  as invalid_reason,
                cr2.concept_id_2    as d_f_concept_id,
                c2.concept_name     as d_f_name
from b_maps_to_value
         join concept_relationship cr ON b_concept_id = cr.concept_id_1
         join concept c1 ON c1.concept_id = cr.concept_id_2
         join concept_relationship cr2 ON cr2.concept_id_1 = c1.concept_id
         join concept c2 ON cr2.concept_id_2 = c2.concept_id
    AND cr.relationship_id = 'Maps to' and cr.invalid_reason = 'D'
    AND cr2.relationship_id IN ('Maps to', 'Maps to value') and cr2.invalid_reason IS NULL
    AND EXISTS(
                                    SELECT 1
                                    FROM devv5.concept_relationship cr1
                                    WHERE cr1.relationship_id = 'Maps to value'
                                      AND cr.concept_id_2 = cr1.concept_id_1
                                )

union

select *
from b_maps_to_value
order by b_concept_id, b_relationship_id, relationship_id
;