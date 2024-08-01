--1 Populate cdisc_mapped with manually curated content;

--2 cdisc_mapped cleanup before ingestion of new portion of AUTO-mappings
--TODO: during refresh logic should be refined (incl. DELETE below)
DELETE
FROM  cdisc_mapped
where 'manual' != all(mapping_source)
;

-- Mapping to standard using SNOMED
INSERT INTO cdisc_mapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
'external_org' as mapper_id,
'load_stage'   as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'SNOMED'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'SNOMEDCT_US'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_mapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;

-- Mapping to standard using LOINC
INSERT INTO cdisc_mapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
'external_org' as mapper_id,
'load_stage'   as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'LOINC'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'lnc'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_mapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;

--Mapping to S using ICD10
INSERT INTO cdisc_mapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
'external_org' as mapper_id,
'load_stage'   as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'ICD10'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'ICD10'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_mapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;


--Mapping to S using HCPCS
INSERT INTO cdisc_mapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
'external_org' as mapper_id,
'load_stage'   as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'HCPCS'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'HCPCS'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_mapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;


--Mapping to S using CPT4
INSERT INTO cdisc_mapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
'external_org' as mapper_id,
'load_stage'   as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'CPT4'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'CPT'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_mapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;


--Mapping to S using MedDRA
INSERT INTO cdisc_mapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
'external_org' as mapper_id,
'load_stage'   as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'MedDRA'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'MDR'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_mapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;

--Mapping to S using HemOnc
INSERT INTO cdisc_mapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
'external_org' as mapper_id,
'load_stage'   as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'HemOnc'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'HemOnc'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_mapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;

--Mapping to RxNorm
INSERT INTO cdisc_mapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
'external_org' as mapper_id,
'load_stage'   as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'RxNorm'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'RXNORM'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_mapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;

--Mapping to non-Defined standard by name-match (OMOP)
INSERT INTO cdisc_mapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
'Maps to'     as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-OMOP-name_match',':', cc.vocabulary_id),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', cc.concept_code)) as mapping_path,
TRUE as decision,
1 as confidence,
'load_stage' as mapper_id,
'load_stage'   as reviewer_id,
CURRENT_DATE	AS  valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
  FROM source m
      JOIN sources.meta_mrsty st ON m.cui = st.cui
                          JOIN concept cc
                               ON trim(lower(cc.concept_name)) =trim(lower(m.concept_name))
                                   AND cc.standard_concept = 'S'
                                   AND cc.vocabulary_id IN ('SNOMED', 'LOINC')
                                   AND cc.domain_id IN ('Condition', 'Procedure', 'Measurement', 'Observation')
                                   AND cc.concept_class_id <> 'Substance'
WHERE  m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_mapped)
GROUP BY m.concept_code,
m.concept_name,
string_to_array(CONCAT('Auto-OMOP-name_match',':', cc.vocabulary_id),':','NULL') ,
TRUE,
CURRENT_DATE ,
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;


--Mapping to non-Defined standard by synonym name-match (OMOP)
INSERT INTO cdisc_mapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
'Maps to'     as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-OMOP-synonym_match',':', cc.vocabulary_id),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', cc.concept_code)) as mapping_path,
TRUE as decision,
1 as confidence,
'load_stage' as mapper_id,
'load_stage'   as reviewer_id,
CURRENT_DATE	AS valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
  FROM source m
      JOIN sources.meta_mrsty st ON m.cui = st.cui
                          JOIN concept cc
                              JOIN concept_synonym cs
                                  on cc.concept_id=cs.concept_id
                               ON trim(lower(cs.concept_synonym_name)) =trim(lower(m.concept_name))
                                   AND cc.standard_concept = 'S'
                                   AND cc.vocabulary_id IN ('SNOMED', 'LOINC')
                                   AND cc.domain_id IN ('Condition', 'Procedure', 'Measurement', 'Observation')
                                   AND cc.concept_class_id NOT IN ( 'Substance','Organism')
WHERE  m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_mapped)
GROUP BY m.concept_code,
m.concept_name,
string_to_array(CONCAT('Auto-OMOP-synonym_match',':', cc.vocabulary_id),':','NULL') ,
TRUE,
CURRENT_DATE,
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;