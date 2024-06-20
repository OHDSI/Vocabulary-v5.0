--peak test
with code as (SELECT 'peak_code'::varchar as code)

--All the ancestors
SELECT * FROM (
SELECT DISTINCT
        CASE WHEN p.valid_end_date = to_date('20991231', 'YYYYMMDD') THEN 'IS PICK'
             WHEN p.valid_end_date < to_date('20991231', 'YYYYMMDD') THEN 'OLD PICK ' || p.valid_end_date
             ELSE NULL END as pick,
        CASE WHEN MIN(s.concept_code) = MIN(cs.concept_code) THEN 0 ELSE MIN (ca.min_levels_of_separation) END as level,
        cs.*

FROM concept_stage s

LEFT JOIN snomed_ancestor ca ON s.concept_code = ca.descendant_concept_code::varchar

JOIN concept_stage cs
    ON (ca.ancestor_concept_code::varchar = cs.concept_code OR s.concept_code = cs.concept_code) AND cs.vocabulary_id = 'SNOMED' --AND cs.standard_concept = 'S'

LEFT JOIN peak p ON p.peak_code::varchar = cs.concept_code

WHERE s.concept_code = (SELECT code from code) AND s.vocabulary_id = 'SNOMED' --AND cs.invalid_reason IS NULL
GROUP BY 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12

) as a

UNION

--All the descendants
SELECT * FROM (
SELECT DISTINCT
        CASE WHEN p.valid_end_date = to_date('20991231', 'YYYYMMDD') THEN 'IS PICK'
             WHEN p.valid_end_date < to_date('20991231', 'YYYYMMDD') THEN 'OLD PICK ' || p.valid_end_date
             ELSE NULL END as pick,
        CASE WHEN MIN(s.concept_code) = MIN(cs.concept_code) THEN 0 ELSE - MAX (ca.min_levels_of_separation) END as level,
        cs.*

FROM concept_stage s

LEFT JOIN snomed_ancestor ca ON s.concept_code = ca.ancestor_concept_code::varchar

JOIN concept_stage cs
    ON (ca.descendant_concept_code::varchar = cs.concept_code OR s.concept_code::varchar = cs.concept_code) AND cs.vocabulary_id = 'SNOMED' --AND cs.standard_concept = 'S'

LEFT JOIN peak p ON p.peak_code::varchar = cs.concept_code

WHERE s.concept_code = (SELECT code from code) AND s.vocabulary_id = 'SNOMED' --AND cs.invalid_reason IS NULL
GROUP BY 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12

) as b

ORDER BY level DESC,
         concept_name
;

--check whether the peak manual table contains several records for the same peak (make sure they're placed together in a group)
--run after the following part of the load_stage: Fill in the various peak concepts
--27 were found and placed correctly
SELECT peak_code
FROM peak p1
GROUP BY peak_code
HAVING count(*) > 1
;

--check whether the peak manual table contains active duplicates with the same levels_down value
--run after the following part of the load_stage: Fill in the various peak concepts
SELECT peak_code
FROM peak p1
WHERE valid_end_date = to_date('20991231', 'YYYYMMDD')
GROUP BY peak_code, levels_down
HAVING count(*) > 1
;

--check whether the peak manual table contains non-SNOMED concepts
SELECT *
FROM peak p1
LEFT JOIN concept c
    ON p1.peak_code::varchar = c.concept_code
        AND c.vocabulary_id = 'SNOMED'
WHERE c.concept_code IS NULL
;

--Domains should not change inside Generic update
--Hence we can check _stage tables during domain assignment
--Domain changes for active concepts
SELECT c1.concept_code || ',',c1.concept_name,
       CASE WHEN c1.concept_code::bigint IN
                 --Copy paste concept codes where new domain is correct
       (

           ) THEN 'correct' END AS flag,

       c1.concept_class_id, c1.invalid_reason, c2.domain_id as old, c1.domain_id AS new
FROM concept_stage c1
JOIN devv5.concept c2 ON
	(c1.vocabulary_id, c1.concept_code) = (c2.vocabulary_id, c2.concept_code) AND
	c1.domain_id != c2.domain_id AND
	c1.invalid_reason IS NULL
WHERE c1.vocabulary_id = 'SNOMED'
ORDER BY c1.domain_id, c2.domain_id
;

--check all the descendants for target ancestor (helpful while assigning new peak)
SELECT c.concept_code, c.concept_name, sa.min_levels_of_separation, c.concept_class_id, c.domain_id
FROM snomed_ancestor sa
JOIN dev_snomed.concept c
    ON c.concept_code = sa.descendant_concept_code::varchar AND c.vocabulary_id = 'SNOMED'
WHERE ancestor_concept_code = 'peak_code';

--quick workaround to check common ancestor for 2 concepts
--NB: Snomed ancestor does not have links with 0 levels of separation
WITH common_ancestors AS
         (WITH a AS (SELECT ancestor_concept_code FROM snomed_ancestor WHERE descendant_concept_code = 'peak_code'),
               b AS (SELECT ancestor_concept_code FROM snomed_ancestor WHERE descendant_concept_code = 'peak_code')

          SELECT *
          FROM a

          INTERSECT

          SELECT *
          FROM b
         )

SELECT c.concept_code, c.concept_name, sa.min_levels_of_separation, c.concept_class_id, c.domain_id
FROM common_ancestors ca
JOIN dev_snomed.concept c
    ON c.concept_code = ca.ancestor_concept_code::varchar AND c.vocabulary_id = 'SNOMED'
JOIN snomed_ancestor sa
ON sa.ancestor_concept_code = '138875005' AND sa.descendant_concept_code = ca.ancestor_concept_code
ORDER BY min_levels_of_separation;
