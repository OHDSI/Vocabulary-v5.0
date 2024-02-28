--Check how domain_ids are consistent with concept_class_ids
--current selection of domains and concept_classes is based on a current state of OHDSI vocabs
SELECT c.domain_id, c.concept_class_id, count(c.concept_id)
FROM devv5.concept c

WHERE (c.domain_id = 'Unit' AND c.concept_class_id NOT IN ('Canonical Unit', 'Unit'))
        OR (c.domain_id = 'Visit' AND c.concept_class_id NOT IN ('Visit'))
        OR (c.domain_id = 'Type Concept' AND c.concept_class_id NOT IN ('Type Concept'))
        OR (c.domain_id = 'Sponsor' AND c.concept_class_id NOT IN ('Sponsor'))
        OR (c.domain_id = 'Specimen' AND c.concept_class_id NOT IN ('Specimen'))
        OR (c.domain_id = 'Spec Disease Status' AND c.concept_class_id NOT IN ('Qualifier Value'))
        OR (c.domain_id = 'Spec Anatomic Site' AND c.concept_class_id NOT IN ('Body Structure', 'CPT4 Modifier', 'ICDO Topography'))
        OR (c.domain_id = 'Route' AND c.concept_class_id NOT IN ('Qualifier Value'))
        OR (c.domain_id = 'Revenue Code' AND c.concept_class_id NOT IN ('Revenue Code'))
        OR (c.domain_id = 'Relationship' AND c.concept_class_id NOT IN ('Social Context'))
        OR (c.domain_id = 'Regimen' AND c.concept_class_id NOT IN ('Regimen', 'Modality'))
        OR (c.domain_id = 'Race' AND c.concept_class_id NOT IN ('Race'))
        OR (c.domain_id = 'Provider' AND c.concept_class_id NOT IN ('Physician Specialty', 'Provider'))
        OR (c.domain_id = 'Procedure' AND c.concept_class_id NOT IN ('ICD10PCS Hierarchy', 'ICD10PCS', 'Procedure', 'CPT4', 'Clinical Observation',
                                                                    'NAACCR Procedure', 'HCPCS', 'CPT4 Hierarchy', 'CPT4 Modifier', 'NAACCR Value', 'Context',
                                                                    'HCPCS Modifier'))
        OR (c.domain_id = 'Plan Stop Reason' AND c.concept_class_id NOT IN ('Plan Stop Reason'))
        OR (c.domain_id = 'Payer' AND c.concept_class_id NOT IN ('Payer'))
        OR (c.domain_id = 'Plan' AND c.concept_class_id NOT IN ('Plan'))

--TODO: proceed with other domains

GROUP BY domain_id, concept_class_id;



--Check if new domains in standard concepts appear outside of these vocabularies
SELECT c.vocabulary_id, c.domain_id, count(c.concept_id) AS counts
FROM devv5.concept c

WHERE c.standard_concept = 'S'
GROUP BY vocabulary_id, domain_id
ORDER BY vocabulary_id, counts DESC
;


--Text matching if measurements are assigned Measurement domain
--1203
SELECT count(*)
FROM devv5.concept c
WHERE standard_concept ='S'
AND domain_id != 'Measurement'
AND concept_name ILIKE '%measurement%';


--Number of Standard procedures that have a Measurement (not necessarily Standard) with a same name and not mapped to them
--160
SELECT COUNT(DISTINCT c1.concept_id)
FROM devv5.concept c1
INNER JOIN devv5.concept c2 ON c1.concept_name = c2.concept_name
    AND c1.standard_concept = 'S'
    AND c1.domain_id = 'Procedure'
    AND c2.domain_id = 'Measurement'
WHERE NOT EXISTS (SELECT 1
    FROM (SELECT c.concept_id AS id_1, cr.relationship_id, cc.concept_id AS id_2, cc.domain_id
          FROM devv5.concept c
          INNER JOIN devv5.concept_relationship cr ON c.concept_id = cr.concept_id_1
          INNER JOIN devv5.concept cc ON cr.concept_id_2 = cc.concept_id) sub
    WHERE sub.id_1 = c2.concept_id
    AND sub.relationship_id = 'Maps to'
    AND sub.domain_id = 'Procedure')
;


--Number of Standard Measurements that have a Procedure with a same name and not mapped to them
--345
SELECT COUNT(DISTINCT c2.concept_id)
FROM devv5.concept c1
INNER JOIN devv5.concept c2 ON c1.concept_name = c2.concept_name
    AND c1.standard_concept = 'S'
    AND c1.domain_id = 'Measurement'
    AND c2.domain_id = 'Procedure'
WHERE NOT EXISTS (SELECT 1
    FROM (SELECT c.concept_id AS id_1, cr.relationship_id, cc.concept_id AS id_2, cc.domain_id
          FROM devv5.concept c
          INNER JOIN devv5.concept_relationship cr ON c.concept_id = cr.concept_id_1
          INNER JOIN devv5.concept cc ON cr.concept_id_2 = cc.concept_id) sub
    WHERE sub.id_1 = c2.concept_id
    AND sub.relationship_id = 'Maps to'
    AND sub.domain_id = 'Measurement')
;


-- Presumably, concepts that represent ingredients of drugs should be drugs (SNOMED check)
SELECT c.*
FROM concept c
JOIN concept_relationship cr
    ON cr.concept_id_1 = c.concept_id
JOIN concept cc
    ON cc.concept_id = cr.concept_id_2
WHERE cr.relationship_id = 'Prec ingredient of' AND cr.invalid_reason IS NULL
AND cc.domain_id = 'Drug'
AND c.domain_id != 'Drug';


--Presumably, all concepts that have ingredient name in their concept_name, are drugs:
--! Very heavy query - DO NOT RUN, see below
WITH ingredients AS (
       SELECT DISTINCT concept_name
       FROM concept
       WHERE concept_class_id = 'Ingredient'
       AND standard_concept = 'S'
       and concept_name !~* '[0-9]'
),

ing_regexp AS (
SELECT string_agg(concept_name, '|') AS ing_regexp
       FROM ingredients
       where concept_name ~* '[0-9]'),

exclusion AS (SELECT 'adverse|spf|antiseptic|dressing|plaster' AS exclusion)

SELECT *
FROM concept c
WHERE c.concept_name ~* (SELECT ('||ing_regexp||') FROM ing_regexp)
AND c.concept_name !~* (SELECT exclusion FROM exclusion)
AND c.concept_class_id != 'Ingredient'
AND c.domain_id not in ('Drug', 'Provider')
AND vocabulary_id != 'AMIS' -- in German
ORDER BY vocabulary_id, domain_id, standard_concept, concept_name
;
--here's much more optimized query
--it returns so many 
--reactions to drug, 
--measurement of drugs, 
--similarly sounding things Entire alveolar epit*helium* -> helium: this can be fixed by adding spaces or symbols around the ingredient name
-- not sure it worth to look at all these exclusions
create table inged_domain_check as
select c2.concept_id as checked_concept_id, c2.concept_name as checked_concept_name,
c.concept_id as ingred_concept_id, c.concept_name as ingred_concept_name
from concept c 
join concept c2 on position (lower (c.concept_name) in lower (c2.concept_name)) >0
where c.standard_concept ='S' and c.concept_class_id ='Ingredient' and c.vocabulary_id ='RxNorm' and length (c.concept_name)>4 --exclude things such as  lead, air, tin, urea, neon, tin, etc
and c2.standard_concept ='S'
and c2.domain_id not in ('Drug', 'Regimen')
--and c2.vocabulary_id ='SNOMED' -- you can analyze one particular vocabulary
;
--modification of it, that looks at source procedure vocabularies, returns 271 concepts, so can be easily reviewed
--it assess the mapping of concepts, but technically it's the same in this case
--! \\d is a redshift dialect, use \d in PG
select c.* from concept c 
join concept c2 on  position (lower (c2.concept_name) in lower (c.concept_name)) >0
and (c2.standard_concept ='S' and c2.concept_class_id ='Ingredient' and c2.vocabulary_id ='RxNorm' and length (c2.concept_name)>4
or c2.invalid_reason is null and c2.concept_class_id ='Brand Name' and c2.vocabulary_id ='RxNorm' and length (c2.concept_name)>4)
where c.concept_id not in (
select c.concept_id  from concept c 
join concept_relationship cr on cr.concept_id_1 = c.concept_id and relationship_id = 'Maps to' 
 join concept c2 on c2.concept_id = cr.concept_id_2 and c2.domain_id ='Drug'
where c.vocabulary_id in ('ICD10PCS', 'ICD9Proc', 'HCPCS', 'CPT4')
and c.concept_class_id not in ('HCPCS class', 'CPT4 Hierarchy', 'HCPCS Class', 'ICD10PCS Hierarchy' )
and  c.concept_name ~*'Administration|administered through|\\d (mg|units|ml|meg|mcg|millicurie|gram|grams|million|cc)|Introduction of |per millicurie|vaccine|Injection|for intravenous use|releasing intrauterine system|patches, '
) 
and c.vocabulary_id in ('ICD10PCS', 'ICD9Proc', 'HCPCS', 'CPT4')
and c.concept_class_id not in ('HCPCS class', 'CPT4 Hierarchy', 'HCPCS Class', 'ICD10PCS Hierarchy' )
and  c.concept_name ~*'^Administration|administered through|^Introduction of |per millicurie|vaccine|for intravenous use|releasing intrauterine system|patches|\\d (mg|units|ml|meg|mcg|millicurie|gram|grams|million)'
--or c.concept_name ~* '\\d mg|units|ml|meg|mcg|millicurie|gram|grams|million|cc'
order by c.vocabulary_id , c.concept_code 
;




--concept is present in drug_strength but has not Drug domain
SELECT * FROM concept c
JOIN drug_strength ds
    ON ds.drug_concept_id =c.concept_id
WHERE c.domain_id != 'Drug'
;

--Standard drugs are either in drug_strength or in pack_content
SELECT *
FROM concept c
LEFT JOIN drug_strength ds
    ON ds.drug_concept_id = c.concept_id
LEFT JOIN pack_content
    ON pack_concept_id = c.concept_id
WHERE c.domain_id = 'Drug' AND c.standard_concept = 'S'
AND coalesce (ds.drug_concept_id, pack_concept_id) IS NULL
;
