--check that Qr has links to Qs
--should return 0
SELECT count(*)
FROM concept_relationship a
JOIN  concept aa
on aa.concept_id=a.concept_id_1
WHERE  NOT EXISTS(   SELECT 1
                        FROM concept_relationship b
                        LEFT JOIN concept c
                            ON c.concept_id = b.concept_id_2
                        WHERE a.concept_id_1 = b.concept_id_1
                          AND c.concept_class_id in ('SYMPTOM SCALE')
                          AND (b.relationship_id = 'Subsumes')
                         and b.invalid_reason is null
              )
  and aa.concept_class_id  IN (
                                    'CORE', 'MODULE', 'STANDALONE', 'CAT', 'CATSHORT',
                                    'PREVIOUS') --filer questionnaire
and aa.vocabulary_id IN (:your_vocabs)

and  NOT EXISTS(   SELECT 1
                        FROM concept_relationship b1
                        LEFT JOIN concept c1
                            ON c1.concept_id = b1.concept_id_2
                        WHERE a.concept_id_1 = b1.concept_id_1
                          AND c1.concept_class_id in ('QUESTION')
                          AND c1.standard_concept is null
                          AND (b1.relationship_id = 'Subsumes')
                         and b1.invalid_reason is null
              )
  and aa.concept_class_id  IN (
                                    'CORE', 'MODULE', 'STANDALONE', 'CAT', 'CATSHORT',
                                    'PREVIOUS') --filer questionnaire
and aa.vocabulary_id IN (:your_vocabs)
;

