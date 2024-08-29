--- What systemic forms of GCS we now loosing
with rxnorm as (
    select c2.*
    from devv5.concept_ancestor ca
             join devv5.concept c on c.concept_id = ca.descendant_concept_id
                                and c.concept_class_id = 'Ingredient'
                                and lower(c.concept_name) in ('betamethasone', 'cortisone', 'dexamethasone',
                                                              'fludrocortisone', 'fluocortolone', 'hydrocortisone',
                                                              'methylprednisolone', 'prednisolone', 'prednisone',
                                                              'prednylidene', 'triamcinolone', 'beclomethasone',
                                                              'budesonide', 'deflazacort', 'desonide', 'diflucortolone',
                                                              'fluocinonide', 'fluorometholone', 'fluticasone', 'halcinonide',
                                                              'mometasone', 'paramethasone','rimexolone')
        and ancestor_concept_id in (21602723,21602745)
             join devv5.concept_ancestor ca2 on c.concept_id = ca2.ancestor_concept_id
             join devv5.concept c2 on c2.concept_id = ca2.descendant_concept_id
        and c2.concept_name ~ 'Injec|Oral|Implant|Syringe|Pen' and c2.standard_concept = 'S'--and c2.vocabulary_id = 'RxNorm'
)
select cnt, db_cnt, r.concept_id, concept_name, vocabulary_id
from rxnorm r
left join dev_anna.count_standard_aggregated cs on cs.concept_id = r.concept_id
where r.concept_id not in (
    -- get systemic cordicosteroids through ATC
    select c.concept_id as atc_id
    from devv5.concept_ancestor ca
             join devv5.concept c on c.concept_id = ca.descendant_concept_id
    where ancestor_concept_id in (21602745, 21602723))
order by cnt desc;

---- Systemic GCS after pConceptAncestor update

with rxnorm as (
    select c2.*
    from dev_atc.concept_ancestor ca
             join dev_atc.concept c on c.concept_id = ca.descendant_concept_id
                                and c.concept_class_id = 'Ingredient'
                                and lower(c.concept_name) in  ('betamethasone', 'cortisone', 'dexamethasone',
                                                              'fludrocortisone', 'fluocortolone', 'hydrocortisone',
                                                              'methylprednisolone', 'prednisolone', 'prednisone',
                                                              'prednylidene', 'triamcinolone', 'beclomethasone',
                                                              'budesonide', 'deflazacort', 'desonide', 'diflucortolone',
                                                              'fluocinonide', 'fluorometholone', 'fluticasone', 'halcinonide',
                                                              'mometasone', 'paramethasone','rimexolone')
        and ancestor_concept_id in (21602723,21602745)
             join dev_atc.concept_ancestor ca2 on c.concept_id = ca2.ancestor_concept_id
             join dev_atc.concept c2 on c2.concept_id = ca2.descendant_concept_id
        and c2.concept_name ~ 'Injec|Oral|Implant|Syringe|Pen' and c2.standard_concept = 'S'--and c2.vocabulary_id = 'RxNorm'
)
select cnt, db_cnt, r.concept_id, concept_name, vocabulary_id
from rxnorm r
left join dev_anna.count_standard_aggregated cs on cs.concept_id = r.concept_id
where r.concept_id not in (
    -- get systemic cordicosteroids through ATC
    select c.concept_id as atc_id
    from dev_atc.concept_ancestor ca
             join dev_atc.concept c on c.concept_id = ca.descendant_concept_id
    where ancestor_concept_id in (21602745, 21602723))
order by cnt desc;


---- See, what new connections we have after modified pConceptAncestor, compared to Old
SELECT c1.concept_id,
       c1.concept_code,
       c1.concept_name,
       c2.concept_id,
       c2.concept_name,
       c2.concept_class_id
FROM dev_atc.concept_ancestor ca
     JOIN dev_atc.concept c1 on ca.ancestor_concept_id = c1.concept_id
                                and c1.vocabulary_id = 'ATC'
                                and c1.concept_class_id = 'ATC 5th'
                                and c1.invalid_reason is NULL
     JOIN dev_atc.concept c2 on ca.descendant_concept_id = c2.concept_id
                                and c2.vocabulary_id in ('RxNorm','RxNorm Extension')
                                and c2.invalid_reason is NULL
WHERE (c1.concept_id, c2.concept_id) NOT IN (
                                            SELECT c1.concept_id,
                                                   c2.concept_id
                                            FROM devv5.concept_ancestor ca
                                                 JOIN devv5.concept c1 on ca.ancestor_concept_id = c1.concept_id
                                                                            and c1.vocabulary_id = 'ATC'
                                                                            and c1.concept_class_id = 'ATC 5th'
                                                                            and c1.invalid_reason is NULL
                                                 JOIN devv5.concept c2 on ca.descendant_concept_id = c2.concept_id
                                                                            and c2.vocabulary_id in ('RxNorm','RxNorm Extension')
                                                                            and c2.invalid_reason is NULL);

---- What new connections for systemic GCS we get after pConceptAncestor update.
SELECT c1.concept_id,
       c1.concept_code,
       c1.concept_name,
       c2.concept_id,
       c2.concept_name,
       c2.concept_class_id
FROM dev_atc.concept_ancestor ca
     JOIN dev_atc.concept c1 on ca.ancestor_concept_id = c1.concept_id
                                and c1.vocabulary_id = 'ATC'
                                and c1.concept_class_id = 'ATC 5th'
                                and c1.invalid_reason is NULL
                                and left(c1.concept_code, 4) in ('H02B', 'H02A')
     JOIN dev_atc.concept c2 on ca.descendant_concept_id = c2.concept_id
                                and c2.vocabulary_id in ('RxNorm','RxNorm Extension')
                                and c2.invalid_reason is NULL
WHERE (c1.concept_id, c2.concept_id) NOT IN (
                                            SELECT c1.concept_id,
                                                   c2.concept_id
                                            FROM dev_atatur.concept_ancestor ca
                                                 JOIN dev_atatur.concept c1 on ca.ancestor_concept_id = c1.concept_id
                                                                            and c1.vocabulary_id = 'ATC'
                                                                            and c1.concept_class_id = 'ATC 5th'
                                                                            and c1.invalid_reason is NULL
                                                 JOIN dev_atatur.concept c2 on ca.descendant_concept_id = c2.concept_id
                                                                            and c2.vocabulary_id in ('RxNorm','RxNorm Extension')
                                                                            and c2.invalid_reason is NULL);


---- See, what connections we have after classic pConceptAncestor, compared to modified pConceptAncestor
    SELECT c1.concept_id,
       c1.concept_code,
       c1.concept_name,
       c2.concept_id,
       c2.concept_name,
       c2.concept_class_id
FROM devv5.concept_ancestor ca
     JOIN devv5.concept c1 on ca.ancestor_concept_id = c1.concept_id
                                and c1.vocabulary_id = 'ATC'
                                and c1.concept_class_id = 'ATC 5th'
                                and c1.invalid_reason is NULL
     JOIN devv5.concept c2 on ca.descendant_concept_id = c2.concept_id
                                and c2.vocabulary_id in ('RxNorm','RxNorm Extension')
                                and c2.invalid_reason is NULL
WHERE (c1.concept_id, c2.concept_id) NOT IN (
                                            SELECT c1.concept_id,
                                                   c2.concept_id
                                            FROM dev_atc.concept_ancestor ca
                                                 JOIN dev_atc.concept c1 on ca.ancestor_concept_id = c1.concept_id
                                                                            and c1.vocabulary_id = 'ATC'
                                                                            and c1.concept_class_id = 'ATC 5th'
                                                                            and c1.invalid_reason is NULL
                                                 JOIN dev_atc.concept c2 on ca.descendant_concept_id = c2.concept_id
                                                                            and c2.vocabulary_id in ('RxNorm','RxNorm Extension')
                                                                            and c2.invalid_reason is NULL);


----- See what links we have in CR table, and don't have in CA.
SELECT c.concept_id, c.concept_code, c.concept_name,
       cr.relationship_id,
       c1.concept_id, c1.concept_code, c1.concept_name
FROM dev_atc.concept_relationship cr
JOIN dev_atc.concept c
    ON c.concept_id = cr.concept_id_1
           AND c.invalid_reason IS NULL
           AND c.vocabulary_id = 'ATC'
           AND c.concept_class_id = 'ATC 5th'
JOIN dev_atc.concept c1
    ON c1.concept_id = cr.concept_id_2
           AND c1.invalid_reason IS NULL
           AND c1.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
           AND c1.concept_class_id = 'Clinical Drug Form'
LEFT JOIN dev_atc.concept_ancestor ca
    ON (cr.concept_id_1, cr.concept_id_2) = (ca.ancestor_concept_id, ca.descendant_concept_id)

WHERE cr.relationship_id = 'ATC - RxNorm'
    AND cr.invalid_reason IS NULL
    AND ca.ancestor_concept_id IS NULL;


----- See what links we have in CR table, and don't have in CA.
SELECT c.concept_id, c.concept_code, c.concept_name,
       cr.relationship_id,
       c1.concept_id, c1.concept_code, c1.concept_name
FROM dev_invdrug.concept_relationship cr
JOIN dev_invdrug.concept c
    ON c.concept_id = cr.concept_id_1
           AND c.invalid_reason IS NULL
           AND c.vocabulary_id = 'ATC'
           AND c.concept_class_id = 'ATC 5th'
JOIN dev_invdrug.concept c1
    ON c1.concept_id = cr.concept_id_2
           AND c1.invalid_reason IS NULL
           AND c1.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
           AND c1.concept_class_id = 'Clinical Drug Form'
LEFT JOIN dev_invdrug.concept_ancestor ca
    ON (cr.concept_id_1, cr.concept_id_2) = (ca.ancestor_concept_id, ca.descendant_concept_id)

WHERE cr.relationship_id = 'ATC - RxNorm'
    AND cr.invalid_reason IS NULL
    AND ca.ancestor_concept_id IS NULL;


---- Example of ancestor work : https://athena.ohdsi.org/search-terms/terms/41080245
--- Old
SELECT *
FROM dev_atatur.concept_ancestor ca
     join dev_atatur.concept c1 on ca.ancestor_concept_id = c1.concept_id and c1.vocabulary_id = 'ATC'
                                                                       and c1.invalid_reason is NULL
     join dev_atatur.concept c2 on ca.descendant_concept_id = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                         and c2.invalid_reason is NULL
                                                                         and c2.concept_id = 41080245;
--- New
SELECT *
FROM dev_atc.concept_ancestor ca
     join dev_atc.concept c1 on ca.ancestor_concept_id = c1.concept_id and c1.vocabulary_id = 'ATC'
                                                                       and c1.invalid_reason is NULL
     join dev_atc.concept c2 on ca.descendant_concept_id = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                         and c2.invalid_reason is NULL
                                                                         and c2.concept_id = 41080245;

SELECT *
FROM dev_invdrug.concept_ancestor ca
     join dev_invdrug.concept c1 on ca.ancestor_concept_id = c1.concept_id and c1.vocabulary_id = 'ATC'
                                                                       and c1.invalid_reason is NULL
     join dev_invdrug.concept c2 on ca.descendant_concept_id = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                         and c2.invalid_reason is NULL
                                                                         and c2.concept_id = 41080245;


SELECT c1.concept_id,
       c2.concept_id,
       c1.concept_code,
       c1.concept_name,
       c2.concept_name,
       cr.*
FROM dev_atc.concept_relationship cr
        join dev_atc.concept c1 on cr.concept_id_1 = c1.concept_id and c1.vocabulary_id = 'ATC'
                                                            and c1.concept_code = 'H02AB02'
                                                            --and cr.invalid_reason is NULL
        join dev_atc.concept c2 on cr.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension');

