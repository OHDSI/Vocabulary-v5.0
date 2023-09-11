-- This check allows us to see mismatches of valid_start_dates and/or valid_end_dates in source files and concept table after GenericUpdate.
--- This check should retrieve NULL.

WITH a AS(
       SELECT src.id::TEXT AS concept_code,
              FIRST_VALUE(src.effectivetime) OVER (
			PARTITION BY src.id ORDER BY src.active DESC, src.effectivetime
			) AS effectivestart
              FROM sources.sct2_concept_full_merged src
),

b as (
SELECT c.id::TEXT as concept_code,
		MAX(c.effectivetime) AS effectiveend
	FROM sources.sct2_concept_full_merged c
	LEFT JOIN sources.sct2_concept_full_merged c2 ON --ignore all entries before latest one with active = 1
		c2.active = 1
		AND c.id = c2.id
		AND c.effectivetime < c2.effectivetime
	WHERE c2.id IS NULL
		AND c.active = 0
	GROUP BY c.id
)

SELECT c.concept_code, c.concept_name, c.valid_start_date, c.valid_end_date,
       to_date(a.effectivestart, 'YYYYMMDD') as effectivestart,
       to_date(b.effectiveend, 'YYYYMMDD') as effectiveend
       FROM concept c
JOIN a on a.concept_code = c.concept_code
JOIN b on b.concept_code = c.concept_code
where c.vocabulary_id = 'SNOMED'
and to_date(a.effectivestart, 'YYYYMMDD') = c.valid_start_date
or to_date(b.effectiveend, 'YYYYMMDD') != c.valid_end_date;
;