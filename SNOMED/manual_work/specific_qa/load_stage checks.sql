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
--26 were found and placed correctly
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