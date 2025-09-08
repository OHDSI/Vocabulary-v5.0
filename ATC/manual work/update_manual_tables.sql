/**************************************************************************
This script updates concept_relationship_manual and deprecates wrong mappings
**************************************************************************/

---ATC - RxNorm
UPDATE concept_relationship_manual
SET invalid_reason = 'D',
    valid_end_date = CURRENT_DATE
WHERE (concept_code_1, concept_code_2) IN (SELECT t1.atc_code,
                                                  t2.concept_code
                                           FROM dev_atc.existent_atc_rxnorm_to_drop t1
                                                    JOIN devv5.concept t2 ON t1.concept_id = t2.concept_id
                                           WHERE t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                             AND t1.to_drop = 'D')
  AND vocabulary_id_1 = 'ATC'
  AND relationship_id = 'ATC - RxNorm'
  AND vocabulary_id_2 IN ('RxNorm', 'RxNorm Extension');


UPDATE concept_relationship_manual
SET invalid_reason = 'D',
    valid_end_date = CURRENT_DATE
WHERE (concept_code_1, concept_code_2) IN (SELECT DISTINCT t1.concept_code_atc, t2.concept_code
                                           FROM dev_atc.atc_rxnorm_to_drop_in_sources t1
                                                    JOIN devv5.concept t2 ON t1.concept_id_rx = t2.concept_id
                                           WHERE t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                             AND t1.drop = 'D')
  AND vocabulary_id_1 = 'ATC'
  AND relationship_id = 'ATC - RxNorm'
  AND vocabulary_id_2 IN ('RxNorm', 'RxNorm Extension');

---ATC - Ings
----- Dedeprecate Ings connections, that are in manual table and are deprecated in manual
UPDATE concept_relationship_manual
SET invalid_reason = NULL,
    valid_end_date = TO_DATE('20991231', 'yyyymmdd')
WHERE (concept_code_1, relationship_id, concept_code_2) IN (WITH CTE AS (SELECT class_code AS concept_code_1,
                                                                                    relationship_id,
                                                                                    UNNEST(STRING_TO_ARRAY(ids, ', '))::INT AS concept_id
                                                                             FROM dev_atc.new_atc_codes_ings_for_manual)
                                                                SELECT t1.concept_code_1,
                                                                       t1.relationship_id,
                                                                       t2.concept_code AS concept_code_2
                                                                FROM CTE AS t1
                                                                         JOIN devv5.concept t2 ON t1.concept_id = t2.concept_id)
  AND vocabulary_id_1 = 'ATC'
  AND vocabulary_id_2 IN ('RxNorm', 'RxNorm Extension')
  AND relationship_id IN ('ATC - RxNorm pr lat',
                          'ATC - RxNorm sec lat',
                          'ATC - RxNorm pr up',
                          'ATC - RxNorm sec up')
  AND invalid_reason IS NOT NULL;

--- Deprecate Ings connections that are not in manual table
UPDATE concept_relationship_manual
SET invalid_reason = 'D',
    valid_end_date = CURRENT_DATE
WHERE (concept_code_1, relationship_id, concept_code_2) NOT IN (WITH CTE AS (SELECT class_code AS concept_code_1,
                                                                                    relationship_id,
                                                                                    UNNEST(STRING_TO_ARRAY(ids, ', '))::INT AS concept_id
                                                                             FROM dev_atc.new_atc_codes_ings_for_manual)
                                                                SELECT t1.concept_code_1,
                                                                       t1.relationship_id,
                                                                       t2.concept_code AS concept_code_2
                                                                FROM CTE AS t1
                                                                         JOIN devv5.concept t2 ON t1.concept_id = t2.concept_id)
  AND vocabulary_id_1 = 'ATC'
  AND vocabulary_id_2 IN ('RxNorm', 'RxNorm Extension')
  AND relationship_id IN ('ATC - RxNorm pr lat',
                          'ATC - RxNorm sec lat',
                          'ATC - RxNorm pr up',
                          'ATC - RxNorm sec up')
  AND invalid_reason IS NULL;

--------------------------------

--This step is needed to deprecate wrong relationships

--- ATC - RxNorm
INSERT INTO concept_relationship_manual
            (concept_code_1,
             concept_code_2,
             vocabulary_id_1,
             vocabulary_id_2,
             relationship_id,
             valid_start_date,
             valid_end_date,
             invalid_reason)
SELECT t1.concept_code,
       t2.concept_code,
       t1.vocabulary_id,
       t2.vocabulary_id,
       cr.relationship_id,
       cr.valid_start_date,
       CURRENT_DATE AS date,
       'D'          AS invalid
FROM devv5.concept_relationship cr
         JOIN devv5.concept t1 ON cr.concept_id_1 = t1.concept_id AND t1.vocabulary_id = 'ATC'
                                                                  AND LENGTH(t1.concept_code) = 7
         JOIN devv5.concept t2 ON cr.concept_id_2 = t2.concept_id AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                                                  AND cr.invalid_reason IS NULL

WHERE (
    (t1.concept_code, t2.concept_code) IN
                                        (SELECT DISTINCT t1.atc_code, --- Concept in manually reviewed list of existent codes
                                                         t2.concept_code
                                         FROM dev_atc.existent_atc_rxnorm_to_drop t1
                                                  JOIN devv5.concept t2 ON t1.concept_id = t2.concept_id AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                         WHERE to_drop = 'D')
    OR
    (t1.concept_code, t2.concept_code) IN
                                        (SELECT DISTINCT t1.concept_code_atc, ---- Or in manually reviewed drop-list of source codes
                                                         t2.concept_code
                                         FROM dev_atc.atc_rxnorm_to_drop_in_sources t1
                                                  JOIN devv5.concept t2 ON t1.concept_id_rx::INT = t2.concept_id AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                         WHERE drop = 'D')
    )

  AND (t1.concept_code, cr.relationship_id, t2.concept_code) NOT IN (SELECT concept_code_1,
                                                                            relationship_id,
                                                                            concept_code_2
                                                                     FROM concept_relationship_manual
                                                                     WHERE vocabulary_id_1 = 'ATC'
                                                                       AND vocabulary_id_2 IN ('RxNorm', 'RxNorm Extension')
                                                                       AND relationship_id = 'ATC - RxNorm')
;

--- ATC - Ings
INSERT INTO concept_relationship_manual
            (concept_code_1,
             concept_code_2,
             vocabulary_id_1,
             vocabulary_id_2,
             relationship_id,
             valid_start_date,
             valid_end_date,
             invalid_reason)
SELECT t1.concept_code,
       t2.concept_code,
       t1.vocabulary_id,
       t2.vocabulary_id,
       cr.relationship_id,
       cr.valid_start_date,
       CURRENT_DATE AS date,
       'D'          AS invalid
FROM devv5.concept_relationship cr
         JOIN devv5.concept t1
              ON cr.concept_id_1 = t1.concept_id AND t1.vocabulary_id = 'ATC'
                  AND cr.invalid_reason IS NULL
                  AND cr.relationship_id IN ('ATC - RxNorm pr lat',
                                             'ATC - RxNorm sec lat',
                                             'ATC - RxNorm pr up',
                                             'ATC - RxNorm sec up')
         JOIN devv5.concept t2 ON cr.concept_id_2 = t2.concept_id AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')

WHERE (t1.concept_code, cr.relationship_id, t2.concept_code) NOT IN (WITH CTE AS (SELECT class_code AS concept_code_1,
                                                                                         relationship_id,
                                                                                         UNNEST(STRING_TO_ARRAY(ids, ', '))::INT AS concept_id
                                                                                  FROM dev_atc.new_atc_codes_ings_for_manual)
                                                                     SELECT t1.concept_code_1,
                                                                            t1.relationship_id,
                                                                            t2.concept_code AS concept_code_2
                                                                     FROM CTE AS t1
                                                                              JOIN devv5.concept t2 ON t1.concept_id = t2.concept_id)

  AND (t1.concept_code, cr.relationship_id, t2.concept_code) NOT IN (SELECT concept_code_1,
                                                                            relationship_id,
                                                                            concept_code_2
                                                                     FROM concept_relationship_manual
                                                                     WHERE vocabulary_id_1 = 'ATC'
                                                                       AND vocabulary_id_2 IN ('RxNorm', 'RxNorm Extension')
                                                                       AND relationship_id IN ('ATC - RxNorm pr lat',
                                                                                               'ATC - RxNorm sec lat',
                                                                                               'ATC - RxNorm pr up',
                                                                                               'ATC - RxNorm sec up'));

--- Maps to to drop
UPDATE concept_relationship_manual
SET invalid_reason = 'D',
    valid_end_date = CURRENT_DATE
WHERE relationship_id = 'Maps to'
  AND (concept_code_1, concept_code_2) IN (SELECT source_code_atc, source_code_rx FROM dev_atc.drop_maps_to);