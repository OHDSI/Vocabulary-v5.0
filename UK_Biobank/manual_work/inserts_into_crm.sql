--Run inserts_into_crm.sql only after steps 1-5 from the load_stage.sql

--TODO: Go and check through all the inserts

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


--+ UKB_cancer
--Answers mapped to conditions/observations
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT concat('3-', source_code) AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       'Maps to',
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.ukb_cancer_mapped
WHERE target_concept_id != 0
AND concat('3-', source_code) IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank')

UNION

--20001 Cancer code, self-reported
SELECT '20001' AS concept_code_1,
       '417662000' AS concept_code_2,   --3380974	417662000	History of clinical finding in subject
       'UK Biobank',
       'SNOMED',
       'Maps to',
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
;


--+ UKB_noncancer
--Answers mapped to conditions/observations
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT concat('6-', source_code) AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       'Maps to',
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.ukb_noncancer_mapped
WHERE target_concept_id != 0
AND concat('6-', source_code) IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank')

UNION

--Non-cancer illness code, self-reported
SELECT '20002' AS concept_code_1,
       '417662000' AS concept_code_2,   --3380974	417662000	History of clinical finding in subject
       'UK Biobank',
       'SNOMED',
       'Maps to',
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
;


--+ UKB_treatment_medication
--Answers mapped to drugs/procedures (administration of insulin)
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT concat('4-', source_code) AS concept_code_1,
       concept_code AS concept_code_2,
       'UK Biobank',
       vocabulary_id,
       'Maps to',
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.ukb_treatment_medication_validated_mapping
WHERE concept_id != 0
AND concat('4-', source_code) IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank')

UNION

--Treatment/medication code
SELECT '20003' AS concept_code_1,
       '428961000124106' AS concept_code_2,     --762564	428961000124106	Medication therapy continued
       'UK Biobank',
       'SNOMED',
       'Maps to',
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
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


--+ UKB_health_and_medical_history
--QA pairs mapped to standard concepts
--Questions mapped to standard concepts with 'History of context'
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT CASE WHEN flag != 'Q' THEN concat(field_id, '-', source_code) ELSE field_id END AS concept_code_1,  --Separated mapping for questions
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       CASE WHEN to_value ~* 'value' THEN 'Maps to value'
           ELSE 'Maps to' END,
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.ukb_health_and_medical_history_mapped
WHERE target_concept_id != 0
;


--+ UKB_operations
--Answers mapped to procedures
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT concat('5-', source_code) AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       CASE WHEN to_value ~* 'value' THEN 'Maps to value' ELSE 'Maps to' END,
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.ukb_operations_mapped
WHERE target_concept_id != 0
AND concat('5-', source_code) IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank')

UNION

--Operation code
SELECT '20004' AS concept_code_1,
       '416940007' AS concept_code_2,       --3481729	416940007	Past history of procedure
       'UK Biobank',
       'SNOMED',
       'Maps to',
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
;


--+ UKB_BS_Sample_inventory
--Questions mapped to Specimen
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
FROM dev_oleg.UKB_BS_Sample_inventory_mapped
WHERE target_concept_id != 0
;


--+ 12 category_id = 100079 - Biological samples 🡪 Assay results
--Categorical values

--QA pairs mapped to standard concepts
--Questions mapped to standard Lab tests
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT CASE WHEN flag != 'Q' THEN concat(field_id, '-', source_code) ELSE field_id END AS concept_code_1,  --Separated mapping for questions
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       CASE WHEN to_value ~* 'value' THEN 'Maps to value'
           ELSE 'Maps to' END,
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.ukb_assay_results_categorical_mapped
WHERE target_concept_id != 0
;

--Numerical values

--Questions mapped to standard Lab tests
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT source_code AS concept_code_1,  --Separated mapping for questions
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       CASE WHEN to_value ~* 'value' THEN 'Maps to value'
           ELSE 'Maps to' END,
       current_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.ukb_assay_results_numeric_mapped
WHERE target_concept_id != 0
;