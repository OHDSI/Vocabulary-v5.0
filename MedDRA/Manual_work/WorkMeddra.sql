SELECT  con.concept_class_id,relationship_id,cc.concept_class_id, count(*)
FROM devv5.concept  AS con
 join devv5.concept_relationship AS conrel
on con.concept_id=conrel.concept_id_1
 join devv5.concept cc
on cc.concept_id=conrel.concept_id_2
where cc.vocabulary_id='SNOMED'
AND con.vocabulary_id='MedDRA'
GROUP BY 1,2,3
ORDER BY 4 DESC;


SELECT vocabulary_date, vocabulary_version
FROM sources.hlt_pref_comp




SELECT con.concept_name, cc.concept_name, con.concept_id, cc.concept_id,  relationship_id, con.concept_class_id, cc.concept_class_id
FROM devv5.concept  AS con
 join devv5.concept_relationship AS conrel
on con.concept_id=conrel.concept_id_1
 join devv5.concept cc
on cc.concept_id=conrel.concept_id_2
where cc.vocabulary_id='SNOMED'
AND con.vocabulary_id='MedDRA'
AND con.concept_class_id = 'LLT'
AND cc.concept_class_id = 'Specimen'
/*
ORDER BY random()
LIMIT 100
*/

select distinct c.code as concept_code,
                             ccc.concept_id, c.str as meddra_name, c2.code as target_code,c2.str as target_name,  'SNOMED' as taget_vocab
             from SOURCES.MRCONSO AS c
                      join SOURCES.MRREL AS r on cui1 = c.cui
                      join SOURCES.MRCONSO AS c2 on c2.cui = cui2
                      join devv5.concept AS cc
                           ON c2.code = cc.concept_code AND cc.vocabulary_id = 'SNOMED'
                      join devv5.concept_relationship cr
                           ON cc.concept_id = cr.concept_id_1 AND cr.relationship_id = 'Maps to'
                      join devv5.concept ccc
                           ON cr.concept_id_2 = ccc.concept_id AND ccc.standard_concept = 'S'

             where c.sab = 'MDR'
               and r.rel = 'RQ'
               and c2.sab in ('SNOMEDCT_US') --  ,'ICD10CM' also exists, can be compared
               and rela like '%mapped_to%'
               AND c.code in
                   (SELECT DISTINCT s.concept_code FROM devv5.concept  s where vocabulary_id='MedDRA')
;


SELECT *
FROM  SOURCES.MRCONSO
LIMIT 100


--Check the parents of MedDRA code (including itselt)
SELECT cc.concept_name, cc.concept_class_id, ca.max_levels_of_separation, cc.concept_code
FROM devv5.concept c

JOIN devv5.concept_ancestor ca
    ON c.concept_id = ca.descendant_concept_id
JOIN devv5.concept cc
    ON ca.ancestor_concept_id = cc.concept_id

WHERE c.concept_code = '10026865' AND c.vocabulary_id = 'MedDRA' AND cc.vocabulary_id = 'MedDRA'
ORDER BY ca.max_levels_of_separation DESC;




--Check the children of MedDRA code (including itselt)
SELECT cc.concept_name, cc.concept_class_id, ca.max_levels_of_separation, cc.concept_code
FROM devv5.concept c

JOIN devv5.concept_ancestor ca
    ON c.concept_id = ca.ancestor_concept_id
JOIN devv5.concept cc
    ON ca.descendant_concept_id = cc.concept_id

WHERE c.concept_code = '10026865' AND c.vocabulary_id = 'MedDRA' AND cc.vocabulary_id = 'MedDRA'
ORDER BY ca.max_levels_of_separation;


SELECT *
FROM dev_meddra.meddra_mapping_manual
ORDER BY target_domain_id, target_vocabulary_id, target_concept_class_id, target_concept_code, target_concept_name,
         target_concept_id;