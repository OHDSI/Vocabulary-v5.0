--RUN before --11. Making concepts with mapping Non-standard
SELECT *
FROM concept_stage
    WHERE standard_concept IS NOT NULL
AND concept_code IN (SELECT concept_code_1 FROM concept_relationship_stage crs WHERE relationship_id = 'Maps to' AND crs.invalid_reason IS NULL);



--+ UKB_source_of_admission
--Question: Non-standard
/*
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code = 'admisorc_uni';
 */

SELECT * FROM concept WHERE concept_code = 'postdur';

--Non-standard even without mapping
/*
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code ilike '265-%' AND domain_id = 'Meas Value';
 */

SELECT * FROM concept_stage WHERE concept_code ilike '265-%' AND domain_id = 'Meas Value';



--+ UKB_destination_on_discharge
--Question: Non-standard
--TODO: Answers: Non-Standard or mapped to visits ???
/*
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code = 'disdest_uni';
 */

SELECT * FROM concept_stage WHERE concept_code = 'disdest_uni';

/*
--Non-standard even without mapping
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code ~* '267-';
 */

SELECT * FROM concept_stage WHERE concept_code ilike '267-' AND domain_id = 'Meas Value';



--+ UKB_treatment_specialty
--Question: Non-standard
--Answers: Standard or mapped to provider ???
/*
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code = 'tretspef_uni' OR concept_code = '41246';
 */

SELECT * FROM concept_stage WHERE concept_code = 'tretspef_uni' OR concept_code = '41246';

/*
--Non-standard even without mapping
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code ~* '269-';
 */

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
/*
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code = '20001' AND vocabulary_id = 'UK Biobank';
 */

SELECT * FROM concept_stage WHERE concept_code = '20001';

SELECT * FROM concept_stage WHERE concept_code ilike '3-';



--+ UKB_noncancer
--Question: Non-standard with mapping to 'history of clinical finding in subject'
--Answers: Standard or mapped to conditions
/*
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code = '20002' AND vocabulary_id = 'UK Biobank';
 */

SELECT * FROM concept_stage WHERE concept_code = '20002';

SELECT * FROM concept_stage WHERE concept_code ilike '6-';



--+ UKB_treatment_medication
--Question: Non-standard with mapping to 'history of drug therapy'
--Answers: Non-standard or mapped to drugs
/*
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code = '20003' AND vocabulary_id = 'UK Biobank';
 */
 /*
--All answers are non-standard regardless of mapping
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code ~* '4-';
  */

SELECT * FROM concept_stage WHERE concept_code = '20003';

SELECT * FROM concept_stage WHERE concept_code ilike '4-';



--+ UKB_units
SELECT * FROM dev_oleg.concept_relationship_stage
    WHERE relationship_id = 'Maps to unit';



--+ UKB_health_and_medical_history
SELECT NULL,
       concat(f.title, ': ', aa.meaning),
       'Observation',
       'UK Biobank',
       'Precoordinated pair',
       NULL,
       concat(f.field_id, '-', aa.encoding_id, '-', aa.value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_field f
JOIN all_answers aa
ON f.encoding_id = aa.encoding_id
WHERE main_category
IN (100041, 100046, 100042, 100037, 100038, 100048, 100039, 100040, 100047, 100044, 100045, 100043)
--TODO: DONE ProcessManualRelationships before and use CR_stage instead of CRM in this query
AND concat(f.field_id, '-', aa.encoding_id, '-', aa.value) IN (SELECT concept_code_1 FROM concept_relationship_stage)
;



--+ UKB_operations
/*
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code = '20004' AND vocabulary_id = 'UK Biobank';
 */

SELECT * FROM concept_stage WHERE concept_code = '20004';

SELECT * FROM concept_stage WHERE concept_code ilike '5-';



--+ UKB_BS_Sample_inventory
SELECT * FROM concept_stage WHERE concept_code IN (30314,30324,30334,30344,30354,30364,30374,30384,30394,30404,30414,30424,40425);



--+ 12 category_id = 100079 - Biological samples 🡪 Assay results
SELECT NULL,
       concat(f.title, ': ', aa.meaning),
       'Observation',
       'UK Biobank',
       'Precoordinated pair',
       NULL,
       concat(f.field_id, '-', aa.encoding_id, '-', aa.value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_field f
JOIN all_answers aa
ON f.encoding_id = aa.encoding_id
WHERE main_category IN ('148', '1307', '9081', '17518', '18518', '51428', '100079', '100080', '100081', '100082', '100083')
AND f.title !~* 'aliquot|reportability|missing reason|correction reason|correction level|acquisition route|device ID'
--TODO: DONE ProcessManualRelationships before and use CR_stage instead of CRM in this query
AND concat(f.field_id, '-', aa.encoding_id, '-', aa.value) IN (SELECT concept_code_1 FROM concept_relationship_stage)
;