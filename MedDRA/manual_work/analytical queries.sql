--Check the parents of MedDRA code (including itselt)
SELECT cc.concept_name, cc.concept_class_id, ca.max_levels_of_separation, cc.concept_code
FROM devv5.concept c

JOIN devv5.concept_ancestor ca
    ON c.concept_id = ca.descendant_concept_id
JOIN devv5.concept cc
    ON ca.ancestor_concept_id = cc.concept_id

WHERE c.concept_code = '10013722' AND c.vocabulary_id = 'MedDRA' AND cc.vocabulary_id = 'MedDRA'
ORDER BY ca.max_levels_of_separation DESC;


--Check the children of MedDRA code (including itselt)
SELECT cc.concept_name, cc.concept_class_id, ca.max_levels_of_separation, cc.concept_code
FROM devv5.concept c

JOIN devv5.concept_ancestor ca
    ON c.concept_id = ca.ancestor_concept_id
JOIN devv5.concept cc
    ON ca.descendant_concept_id = cc.concept_id

WHERE c.concept_code = '10028594' AND c.vocabulary_id = 'MedDRA' AND cc.vocabulary_id = 'MedDRA'
ORDER BY ca.max_levels_of_separation;


--Look up maps between MedDRA and SNOMED (current source)
with a as (
SELECT meddra_code, meddra_llt as meddra_term, 'MedDRA to SNOMED', snomed_code, snomed_ct_fsn
FROM SOURCES.MEDDRA_MAPSTO_SNOMED
UNION ALL
SELECT meddra_code, meddra_llt as meddra_term, 'SNOMED to MedDRA', snomed_code, snomed_ct_fsn
FROM SOURCES.MEDDRA_MAPPEDFROM_SNOMED
)

SELECT *
FROM a
WHERE meddra_code IN ('', '')
        OR snomed_code IN ('', '')
;


--Look up maps between MedDRA and SNOMED (old source)
with a as (
SELECT referencedcomponentid ::varchar as  meddra_code, 'MedDRA to SNOMED' as rel, maptarget::varchar as snomed_code
FROM dev_meddra.der2_srefset_meddratosnomedmap
UNION ALL
SELECT maptarget ::varchar as meddra_code, 'SNOMED to MedDRA' as rel, referencedcomponentid::varchar as snomed_code
FROM dev_meddra.der2_srefset_snomedtomeddramap
)

SELECT meddra_code, c1.concept_name as meddra_term, rel, snomed_code, c2.concept_name as snomed_ct_fsn
FROM a
LEFT JOIN devv5.concept c1
    ON a.meddra_code = c1.concept_code
        AND c1.vocabulary_id = 'MedDRA'
LEFT JOIN devv5.concept c2
    ON a.snomed_code = c2.concept_code
        AND c2.vocabulary_id = 'SNOMED'

WHERE meddra_code IN ('', '')
        OR snomed_code IN ('', '')
;