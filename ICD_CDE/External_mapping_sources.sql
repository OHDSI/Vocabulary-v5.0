--External mappings sources exploration

CREATE TABLE map_for_review (
    source_code varchar,
    source_code_description varchar,
    source_vocabulary_id varchar,
    relationship_id varchar,
    target_concept_id bigint,
    target_concept_code varchar,
    target_concept_name varchar,
    target_concept_class varchar,
    target_standard_concept varchar,
    target_domain_id varchar,
    target_vocabulary_id varchar,
    mappings_origin varchar);


-- SNOMED-to-ICD10(ICD10CM) equivalence
SELECT DISTINCT maptarget, cc.concept_name, 'Maps to' AS relat, referencedcomponentid, c.concept_name, s.*
FROM sources.der2_iisssccrefset_extendedmapfull_us s
JOIN concept c ON s.referencedcomponentid = c.concept_code AND c.vocabulary_id = 'SNOMED' AND c.standard_concept = 'S'
JOIN concept cc ON cc.concept_code = s.maptarget AND cc.vocabulary_id = 'ICD10'
WHERE refsetid = '447562003'
 AND active = '1'
 AND maprule = 'TRUE'
 AND mapcategoryid = '447637006' --Map source concept is properly classified; --125962 -- Similarity? + Hier


-- Mappings through UMLS (NCI)
-- Mapping ICD10 to standard using SNOMED
INSERT INTO map_for_review (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            relationship_id,
                            target_concept_id,
                            target_concept_code,
                            target_concept_name,
                            target_concept_class,
                            target_standard_concept,
                            target_domain_id,
                            target_vocabulary_id,
                            mappings_origin)
SELECT DISTINCT
m.code as source_code,
sr.concept_name as source_name,
'ICD10' as source_vocabulary_id,
cr.relationship_id       as relationship_id,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id,
'UMLS/NCIm' as mappings_origin
FROM sources.mrconso m
JOIN concept sr on m.code = sr.concept_code
JOIN sources.mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'SNOMED'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ('Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE m.sab = 'ICD10'
AND s.sab = 'SNOMEDCT_US'
AND sr.vocabulary_id = 'ICD10'
AND cc.standard_concept = 'S'
AND cc.invalid_reason is null --6276

UNION

-- Mapping ICD10 to standard using MedDRA
SELECT DISTINCT
m.code as source_code,
sr.concept_name as source_name,
'ICD10' as source_vocabulary_id,
cr.relationship_id       as relationship_id,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id,
'UMLS/NCIm' as mappings_origin
FROM sources.mrconso m
JOIN concept sr on m.code = sr.concept_code
JOIN sources.mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'MedDRA'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ('Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE m.sab = 'ICD10'
AND s.sab = 'MDR'
AND sr.vocabulary_id = 'ICD10'
AND cc.standard_concept = 'S'
AND cc.invalid_reason is null --6276

UNION

-- Mapping ICD10CM to standard using SNOMED
SELECT DISTINCT
m.code as source_code,
sr.concept_name as source_name,
'ICD10CM' as source_vocabulary_id,
cr.relationship_id       as relationship_id,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id,
'UMLS/NCIm' as mappings_origin
FROM sources.mrconso m
JOIN concept sr on m.code = sr.concept_code
JOIN sources.mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'SNOMED'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ('Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE m.sab = 'ICD10CM'
AND s.sab = 'SNOMEDCT_US'
AND sr.vocabulary_id = 'ICD10CM'
AND cc.standard_concept = 'S'
AND cc.invalid_reason is null --6276

UNION

-- Mapping ICD10CM to standard using MedDRA
SELECT DISTINCT
m.code as source_code,
sr.concept_name as source_name,
'ICD10CM' as source_vocabulary_id,
cr.relationship_id       as relationship_id,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id,
'UMLS/NCIm' as mappings_origin
FROM sources.mrconso m
JOIN concept sr on m.code = sr.concept_code
JOIN sources.mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'MedDRA'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ('Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE m.sab = 'ICD10CM'
AND s.sab = 'MDR'
AND sr.vocabulary_id = 'ICD10CM'
AND cc.standard_concept = 'S'
AND cc.invalid_reason is null --6276
;

SELECT * FROM map_for_review; -- 21246

SELECT * FROM concept_ancestor;