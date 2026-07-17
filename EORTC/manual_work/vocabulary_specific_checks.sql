--check that Qr has links to Qs
--should return 0
SELECT COUNT(*)
  FROM concept_relationship a
  JOIN  concept aa
    ON aa.concept_id=a.concept_id_1
 WHERE  NOT EXISTS (SELECT 1
                      FROM concept_relationship b
                      LEFT JOIN concept c
                        ON c.concept_id = b.concept_id_2
                     WHERE a.concept_id_1 = b.concept_id_1
                       AND c.concept_class_id IN ('SYMPTOM SCALE')
                       AND (b.relationship_id = 'Subsumes')
                       AND b.invalid_reason IS NULL)
  AND aa.concept_class_id  IN ('CORE', 'MODULE', 'STANDALONE', 'CAT', 'CATSHORT',
                               'PREVIOUS') --filer questionnaire
  AND aa.vocabulary_id IN (:your_vocabs)
  AND  NOT EXISTS (SELECT 1
                     FROM concept_relationship b1
                     LEFT JOIN concept c1
                       ON c1.concept_id = b1.concept_id_2
                    WHERE a.concept_id_1 = b1.concept_id_1
                      AND c1.concept_class_id IN ('QUESTION')
                      AND c1.standard_concept IS NULL
                      AND (b1.relationship_id = 'Subsumes')
                      AND b1.invalid_reason IS NULL)
  AND aa.concept_class_id  IN ('CORE', 'MODULE', 'STANDALONE', 'CAT', 'CATSHORT',
                               'PREVIOUS') --filer questionnaire
  AND aa.vocabulary_id IN (:your_vocabs)
;

