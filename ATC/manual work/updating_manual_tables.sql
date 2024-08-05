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
