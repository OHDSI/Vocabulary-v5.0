/**************************************************************************
    this script updates manual tables according to manual checks and
    deprecates wrong mappings
**************************************************************************/

---ATC - RxNorm
UPDATE concept_relationship_manual
SET invalid_reason = 'D',
    valid_end_date = CURRENT_DATE
WHERE (concept_code_1, concept_code_2) IN (
                                            SELECT t1.atc_code, t2.concept_code
                                            FROM dev_atc.existent_atc_rxnorm_to_drop t1
                                            JOIN devv5.concept t2 ON t1.concept_id = t2.concept_id
                                            WHERE t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                            AND t1.to_drop = 'D'
                                            )
AND vocabulary_id_1 = 'ATC'
AND relationship_id = 'ATC - RxNorm'
AND vocabulary_id_2 in ('RxNorm', 'RxNorm Extension');


UPDATE concept_relationship_manual
SET invalid_reason = 'D',
    valid_end_date = CURRENT_DATE
WHERE (concept_code_1, concept_code_2) IN (
                                        SELECT distinct t1.concept_code_atc, t2.concept_code
                                        FROM dev_atc.atc_rxnorm_to_drop_in_sources t1
                                        JOIN devv5.concept t2 ON t1.concept_id_rx = t2.concept_id
                                        WHERE t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                        AND t1.drop = 'D'
                                    )
AND vocabulary_id_1 = 'ATC'
AND relationship_id = 'ATC - RxNorm'
AND vocabulary_id_2 in ('RxNorm', 'RxNorm Extension');

---ATC - Ings
UPDATE concept_relationship_manual
SET invalid_reason = 'D',
    valid_end_date = CURRENT_DATE
WHERE (concept_code_1, relationship_id, concept_code_2) not in
                                                          (
                                                                WITH CTE as (
                                                                                SELECT class_code as concept_code_1,
                                                                                       relationship_id,
                                                                                       unnest(string_to_array(ids, ', '))::int as concept_id
                                                                                FROM dev_atc.new_atc_codes_ings_for_manual)
                                                                SELECT
                                                                    t1.concept_code_1,
                                                                    t1.relationship_id,
                                                                    t2.concept_code as concept_code_2
                                                                FROM CTE as t1
                                                                     join devv5.concept t2 on t1.concept_id = t2.concept_id
                                                          )
AND vocabulary_id_1 = 'ATC'
AND vocabulary_id_2 in ('RxNorm', 'RxNorm Extension')
AND relationship_id in ('ATC - RxNorm pr lat',
                        'ATC - RxNorm sec lat',
                        'ATC - RxNorm pr up',
                        'ATC - RxNorm sec up')
AND invalid_reason is NULL;

--This step is needed to deprecate wrong connections

--- ATC - RxNorm
INSERT INTO concept_relationship_manual
    (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
	)
SELECT t1.concept_code,
       t2.concept_code,
       t1.vocabulary_id,
       t2.vocabulary_id,
       cr.relationship_id,
       cr.valid_start_date,
       CURRENT_DATE as date,
       'D' as invalid
FROM devv5.concept_relationship cr
     JOIN devv5.concept t1 on cr.concept_id_1 = t1.concept_id AND t1.vocabulary_id = 'ATC'
                                                              AND length(t1.concept_code) = 7
     JOIN devv5.concept t2 on cr.concept_id_2 = t2.concept_id AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                                              AND cr.invalid_reason IS NULL

WHERE

    (

    (t1.concept_code, t2.concept_code) IN
                                           (select DISTINCT t1.atc_code, --- Concept in manually reviewed list of existent codes
                                                            t2.concept_code
                                            from dev_atc.existent_atc_rxnorm_to_drop t1
                                                     join devv5.concept t2
                                                          on t1.concept_id = t2.concept_id and t2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                            where to_drop = 'D')
    OR

    (t1.concept_code, t2.concept_code) IN
                                           (SELECT DISTINCT t1.concept_code_atc, ---- Or in manually reviwed drop-list of source codes
                                                            t2.concept_code
                                            FROM dev_atc.atc_rxnorm_to_drop_in_sources t1
                                                     join devv5.concept t2
                                                          on t1.concept_id_rx::INT = t2.concept_id and t2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                            WHERE drop = 'D')
    )

AND (t1.concept_code, cr.relationship_id, t2.concept_code) not in (
                                                                    SELECT concept_code_1,
                                                                           relationship_id,
                                                                           concept_code_2
                                                                    from dev_atc.concept_relationship_manual
                                                                    where vocabulary_id_1 = 'ATC'
                                                                    and vocabulary_id_2 in ('RxNorm', 'RxNorm Extension')
                                                                    and relationship_id = 'ATC - RxNorm')
;

--- ATC - Ings
INSERT INTO concept_relationship_manual
    (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
	)
SELECT t1.concept_code,
       t2.concept_code,
       t1.vocabulary_id,
       t2.vocabulary_id,
       cr.relationship_id,
       cr.valid_start_date,
       CURRENT_DATE as date,
       'D' as invalid
from devv5.concept_relationship cr
     join devv5.concept t1 on cr.concept_id_1 = t1.concept_id and t1.vocabulary_id = 'ATC'
                                                                    and cr.invalid_reason is NULL
                                                                    and cr.relationship_id in ('ATC - RxNorm pr lat',
                                                                                              'ATC - RxNorm sec lat',
                                                                                              'ATC - RxNorm pr up',
                                                                                              'ATC - RxNorm sec up')
     join devv5.concept t2 on cr.concept_id_2 = t2.concept_id and t2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
where (t1.concept_code, cr.relationship_id, t2.concept_code) not in
      (WITH CTE as (SELECT class_code                              as concept_code_1,
                           relationship_id,
                           unnest(string_to_array(ids, ', '))::int as concept_id
                    FROM dev_atc.new_atc_codes_ings_for_manual)
       SELECT t1.concept_code_1,
              t1.relationship_id,
              t2.concept_code as concept_code_2
       FROM CTE as t1
                join devv5.concept t2 on t1.concept_id = t2.concept_id
       )

AND (t1.concept_code, cr.relationship_id, t2.concept_code) not in (
                                                                    SELECT concept_code_1,
                                                                           relationship_id,
                                                                           concept_code_2
                                                                    from dev_atc.concept_relationship_manual
                                                                    where vocabulary_id_1 = 'ATC'
                                                                    and vocabulary_id_2 in ('RxNorm', 'RxNorm Extension')
                                                                    and relationship_id in ('ATC - RxNorm pr lat',
                                                                                              'ATC - RxNorm sec lat',
                                                                                              'ATC - RxNorm pr up',
                                                                                              'ATC - RxNorm sec up'))
;
