--Run inserts_into_crm.sql right before the ProcessManualRelationships step

--+ UKB_source_of_admission
--Answers mapped to visits
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT source_code AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       'Maps to',
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.UKB_source_of_admission_mapped
WHERE target_concept_id != 0
;

--+ UKB_destination_on_discharge
--Answers mapped to visits
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT source_code AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       'Maps to',
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.UKB_destination_on_discharge_mapped
WHERE target_concept_id != 0
;

--+ UKB_treatment_specialty
--Answers mapped to providers
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT source_code AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       'Maps to',
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.UKB_treatment_specialty_mapped
WHERE target_concept_id != 0
;

--+ UKB_psychiatry
--QA pairs mapped to standard concepts
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT concat(field_id, '-', source_code) AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       CASE WHEN to_value ~* 'value' THEN 'Maps to value' ELSE 'Maps to' END,
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.UKB_psychiatry_mapped
WHERE target_concept_id != 0
;

--+ UKB_maternity
--QA pairs mapped to standard concepts
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT CASE WHEN source_code IS NOT NULL AND source_code != '' AND field_id != 'numpreg' THEN concat(field_id, '-', source_code) ELSE field_id END AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       CASE WHEN to_value ~* 'value' THEN 'Maps to value' ELSE 'Maps to' END,
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.UKB_maternity_mapped
WHERE target_concept_id != 0
;

--+ UKB_delivery
--QA pairs mapped to standard concepts
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT CASE WHEN field_id != 'gestat' THEN concat(field_id, '-', source_code) ELSE field_id END AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       CASE WHEN to_value ~* 'value' THEN 'Maps to value'
            WHEN to_value ~* 'unit' THEN 'Maps to unit'
           ELSE 'Maps to' END,
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.UKB_delivery_mapped
WHERE target_concept_id != 0
;

--+ UKB_units
--'Maps to unit' relationships from tests to units
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT f.field_id AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       'Maps to unit',
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.UKB_units_mapped m
JOIN sources.uk_biobank_field f
    ON f.units = m.source_code
WHERE target_concept_id != 0
AND f.field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE domain_id IN ('Observation', 'Measurement'))
;


--Deprecating all mappings that differ from the new version
UPDATE concept_relationship_manual
SET invalid_reason = 'D',
    valid_end_date = current_date
WHERE (concept_code_1, concept_code_2, relationship_id) IN

(SELECT concept_code_1, concept_code_2, relationship_id FROM concept_relationship_manual crm_old
--Mapping through precoordinated pairs
WHERE NOT exists(SELECT concat(question_concept_code, '-', answer_concept_code), concept_code, 'UK Biobank', vocabulary_id, CASE WHEN to_value !~* 'value' THEN 'Maps to' ELSE 'Maps to value' END
                FROM crm_manual_mappings_changed crm_new
                WHERE concat(question_concept_code, '-', answer_concept_code) = crm_old.concept_code_1
                AND crm_new.concept_code = crm_old.concept_code_2
                AND crm_new.vocabulary_id = crm_old.vocabulary_id_2
                AND CASE WHEN crm_new.to_value !~* 'value' THEN 'Maps to' ELSE 'Maps to value' END = crm_old.relationship_id
    )
--Mapping of questions
    AND NOT exists(SELECT question_concept_code, concept_code, 'UK Biobank', vocabulary_id, CASE WHEN to_value !~* 'value' THEN 'Maps to' ELSE 'Maps to value' END
                FROM crm_manual_mappings_changed crm_new
                WHERE question_concept_code = crm_old.concept_code_1
                AND crm_new.concept_code = crm_old.concept_code_2
                AND crm_new.vocabulary_id = crm_old.vocabulary_id_2
                AND CASE WHEN crm_new.to_value !~* 'value' THEN 'Maps to' ELSE 'Maps to value' END = crm_old.relationship_id)
--Mapping of answers
    AND NOT exists(SELECT answer_concept_code, concept_code, 'UK Biobank', vocabulary_id, CASE WHEN to_value !~* 'value' THEN 'Maps to' ELSE 'Maps to value' END
                FROM crm_manual_mappings_changed crm_new
                WHERE answer_concept_code = crm_old.concept_code_1
                AND crm_new.concept_code = crm_old.concept_code_2
                AND crm_new.vocabulary_id = crm_old.vocabulary_id_2
                AND CASE WHEN crm_new.to_value !~* 'value' THEN 'Maps to' ELSE 'Maps to value' END = crm_old.relationship_id)
-- Excluding mapping, that is not present in main table (HES data, etc.)

AND (concept_code_1, concept_code_2) NOT IN (SELECT field_id::varchar, target_concept_code FROM dev_oleg.UKB_units_mapped m JOIN sources.uk_biobank_field f ON f.units = m.source_code)
AND (concept_code_1, concept_code_2) NOT IN (SELECT CASE WHEN field_id != 'gestat' THEN concat(field_id, '-', source_code) ELSE field_id END, target_concept_code FROM dev_oleg.UKB_delivery_mapped)
AND (concept_code_1, concept_code_2) NOT IN (SELECT CASE WHEN source_code IS NOT NULL AND source_code != '' AND field_id != 'numpreg' THEN concat(field_id, '-', source_code) ELSE field_id END, target_concept_code FROM dev_oleg.ukb_maternity_mapped)
AND (concept_code_1, concept_code_2) NOT IN (SELECT source_code, target_concept_code FROM dev_oleg.UKB_source_of_admission_mapped)
AND (concept_code_1, concept_code_2) NOT IN (SELECT source_code, target_concept_code FROM dev_oleg.UKB_destination_on_discharge_mapped)
AND (concept_code_1, concept_code_2) NOT IN (SELECT source_code, target_concept_code FROM dev_oleg.UKB_treatment_specialty_mapped)
AND (concept_code_1, concept_code_2) NOT IN (SELECT concat(field_id, '-', source_code), target_concept_code FROM dev_oleg.UKB_psychiatry_mapped)
    )
;


--Inserting new mappings + corrected mappings
with mapping_of_questions AS
    (
        SELECT DISTINCT question_concept_code AS concept_code_1,
               concept_code AS concept_code_2,
               'UK Biobank' AS vocabulary_id_1,
               vocabulary_id AS vocabulary_id_2,
               CASE WHEN to_value !~* 'value' THEN 'Maps to' ELSE 'Maps to value' END AS relationship_id,
               current_date AS valid_start_date,
               to_date('20991231','yyyymmdd') AS valid_end_date,
               NULL AS invalid_reason
        FROM crm_manual_mappings_changed
        WHERE flag IN ('Q', 'q') AND concept_id IS NOT NULL AND concept_id != 0
        AND cat NOT IN ('100069', '100058', '100051', '132')
    ),

     mapping_of_answers AS
         (
            SELECT DISTINCT answer_concept_code AS concept_code_1,
               concept_code AS concept_code_2,
               'UK Biobank' AS vocabulary_id_1,
               vocabulary_id AS vocabulary_id_2,
               CASE WHEN to_value !~* 'value' THEN 'Maps to' ELSE 'Maps to value' END AS relationship_id,
               current_date AS valid_start_date,
               to_date('20991231','yyyymmdd') AS valid_end_date,
               NULL AS invalid_reason
        FROM crm_manual_mappings_changed
        WHERE flag IN ('A', 'a') AND concept_id IS NOT NULL AND concept_id != 0
        AND cat NOT IN ('100069', '100058', '100051', '132')
         ),

     mapping_of_pairs AS
         (
            SELECT DISTINCT concat(question_concept_code, '-', answer_concept_code) AS concept_code_1,
               concept_code AS concept_code_2,
               'UK Biobank' AS vocabulary_id_1,
               vocabulary_id AS vocabulary_id_2,
               CASE WHEN to_value !~* 'value' THEN 'Maps to' ELSE 'Maps to value' END AS relationship_id,
               current_date AS valid_start_date,
               to_date('20991231','yyyymmdd') AS valid_end_date,
               NULL AS invalid_reason
        FROM crm_manual_mappings_changed
        WHERE flag IN ('P', 'p') AND concept_id IS NOT NULL AND concept_id != 0
        AND cat NOT IN ('100069', '100058', '100051', '132')
         )


INSERT INTO concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
(SELECT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM mapping_of_questions mq
WHERE NOT exists(SELECT concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, invalid_reason FROM concept_relationship_manual
                WHERE concept_code_1 = mq.concept_code_1
                    AND concept_code_2 = mq.concept_code_2
                    AND vocabulary_id_1 = mq.vocabulary_id_1
                    AND vocabulary_id_2 = mq.vocabulary_id_2
                    AND relationship_id = mq.relationship_id
                    AND invalid_reason IS NULL
    )

UNION ALL

SELECT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM mapping_of_answers ma
WHERE NOT exists(SELECT concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, invalid_reason FROM concept_relationship_manual
                WHERE concept_code_1 = ma.concept_code_1
                    AND concept_code_2 = ma.concept_code_2
                    AND vocabulary_id_1 = ma.vocabulary_id_1
                    AND vocabulary_id_2 = ma.vocabulary_id_2
                    AND relationship_id = ma.relationship_id
                    AND invalid_reason IS NULL
    )

UNION ALL

SELECT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM mapping_of_pairs mp
WHERE NOT exists(SELECT concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, invalid_reason FROM concept_relationship_manual
                WHERE concept_code_1 = mp.concept_code_1
                    AND concept_code_2 = mp.concept_code_2
                    AND vocabulary_id_1 = mp.vocabulary_id_1
                    AND vocabulary_id_2 = mp.vocabulary_id_2
                    AND relationship_id = mp.relationship_id
                    AND invalid_reason IS NULL
    )
    )
;