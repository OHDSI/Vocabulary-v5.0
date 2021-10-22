--RUN before --11. Making concepts with mapping Non-standard
SELECT *
FROM concept_stage
    WHERE standard_concept IS NOT NULL
AND concept_code IN (SELECT concept_code_1 FROM concept_relationship_stage crs WHERE relationship_id = 'Maps to' AND crs.invalid_reason IS NULL);

--+ UKB_source_of_admission
--Question: Non-standard

SELECT * FROM concept WHERE concept_code = 'postdur';

SELECT c.concept_code, c.concept_name, c2.concept_name, c2.concept_class_id, c2.domain_id,c2.vocabulary_id
FROM concept c

JOIN concept_relationship cr
    ON c.concept_id = cr.concept_id_1 AND cr.invalid_reason IS NULL AND cr.relationship_id = 'Has precoord pair'

JOIN concept c2
    ON cr.concept_id_2 = c2.concept_id
;

--Non-standard even without mapping

SELECT * FROM concept_stage WHERE concept_code ilike '265-%' AND domain_id = 'Meas Value';

--+ UKB_destination_on_discharge
--Question: Non-standard
SELECT * FROM concept_stage WHERE concept_code = 'disdest_uni';

SELECT * FROM concept_stage WHERE concept_code ilike '267-' AND domain_id = 'Meas Value';

--+ UKB_treatment_specialty
--Question: Non-standard
--Answers: Standard or mapped to provider ???

SELECT * FROM concept_stage WHERE concept_code = 'tretspef_uni' OR concept_code = '41246';

SELECT * FROM concept_stage WHERE concept_code ilike '269-' AND domain_id = 'Meas Value';

--+ UKB_psychiatry
SELECT * FROM concept_stage
WHERE concept_code ilike 'mentcat%'
    OR concept_code ilike 'admistat%'
    OR concept_code ilike 'detncat%'
    OR concept_code ilike 'leglstat%';

--+ UKB_maternity
SELECT * FROM concept_stage
WHERE concept_code ilike 'delchang%'
    OR concept_code ilike 'delinten%'
    OR concept_code ilike 'delonset%'
    OR concept_code ilike 'delposan%'
    OR concept_code ilike 'delprean%'
    OR concept_code ilike 'numbaby%'
;

--+ UKB_delivery
SELECT * FROM concept_stage
WHERE concept_code ilike 'biresus%'
    OR concept_code ilike 'birordr%'
    OR concept_code ilike 'birstat%'
    OR concept_code ilike 'birweight%'
    OR concept_code ilike 'delmeth%'
    OR concept_code ilike 'delplac%'
    OR concept_code ilike 'delstat%'
    OR concept_code ilike 'sexbaby%'
    OR concept_code ilike 'gestat%'
;

--+ UKB_cancer
--Question: Non-standard with mapping to 'history of clinical finding in subject'
--Answers: Standard or mapped to conditions

SELECT * FROM concept_stage WHERE concept_code = '20001';

SELECT * FROM concept_stage WHERE concept_code ilike '3-';

--+ UKB_noncancer
--Question: Non-standard with mapping to 'history of clinical finding in subject'
--Answers: Standard or mapped to conditions

SELECT * FROM concept_stage WHERE concept_code = '20002';

SELECT * FROM concept_stage WHERE concept_code ilike '6-';

--+ UKB_treatment_medication
--Question: Non-standard with mapping to 'history of drug therapy'
--Answers: Non-standard or mapped to drugs

--All answers are non-standard regardless of mapping
SELECT * FROM concept_stage WHERE concept_code = '20003';

SELECT * FROM concept_stage WHERE concept_code ilike '4-';

--+ UKB_units
SELECT * FROM dev_oleg.concept_relationship_stage
    WHERE relationship_id = 'Maps to unit';

--+ UKB_operations

SELECT * FROM concept_stage WHERE concept_code = '20004';

SELECT * FROM concept_stage WHERE concept_code ilike '5-';

--+ UKB_BS_Sample_inventory
SELECT * FROM concept_stage WHERE concept_code IN (30314,30324,30334,30344,30354,30364,30374,30384,30394,30404,30414,30424,40425);