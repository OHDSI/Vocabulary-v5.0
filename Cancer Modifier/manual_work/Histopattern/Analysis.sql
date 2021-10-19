SELECT concept_name
FROM dev_mnerovnya.concept
where vocabulary_id = 'Cancer Modifier'
and concept_class_id = 'Histopattern'
ORDER BY concept_name;

SELECT DISTINCT *
FROM dev_mnerovnya.naaccr_to_cm
WHERE concept_class_id = 'Histopattern';

SELECT DISTINCT concept_name
FROM dev_mnerovnya.naaccr_to_cm
WHERE concept_class_id = 'Histopattern'
ORDER BY concept_name;

SELECT DISTINCT *
FROM dev_mnerovnya.cap_to_cm
WHERE concept_class_id = 'Histopattern'
and  vr_name != 'Additional Findings';

SELECT DISTINCT concept_name
FROM dev_mnerovnya.naaccr_to_cm
WHERE concept_class_id = 'Histopattern'
and concept_name /*not*/ in (SELECT concept_name
FROM dev_mnerovnya.cap_to_cm
WHERE concept_class_id = 'Histopattern');


SELECT DISTINCT concept_name
FROM dev_mnerovnya.cap_to_cm
WHERE concept_class_id = 'Histopattern'
and concept_name not in (SELECT concept_name
FROM dev_mnerovnya.naaccr_to_cm
WHERE concept_class_id = 'Histopattern');

with a as (SELECT concept_name
FROM dev_mnerovnya.concept
where vocabulary_id = 'Cancer Modifier'
and concept_class_id = 'Histopattern'
),
     b as (SELECT concept_name
FROM dev_mnerovnya.concept
where vocabulary_id = 'SNOMED'
)
SELECT DISTINCT lower(a.concept_name), b.concept_name
FROM a LEFT JOIN b using(concept_name);