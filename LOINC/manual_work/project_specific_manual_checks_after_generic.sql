--01. LOINC concepts changed their SNOMED ancestry
with new_map as (
select a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from concept a
left join concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Is a') and r.invalid_reason is null
left join concept b on b.concept_id = concept_id_2 and b.vocabulary_id = 'SNOMED'
where a.vocabulary_id = 'LOINC'
group by a.concept_code, a.concept_name
)
,
old_map as (
select a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from devv5.concept a
left join devv5.concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Is a') and r.invalid_reason is null
left join devv5.concept b on b.concept_id = concept_id_2 and b.vocabulary_id = 'SNOMED'
where a.vocabulary_id = 'LOINC'
group by a.concept_code, a.concept_name
)
select a.concept_code     as source_code,
       a.concept_name     as source_name,
       a.relationship_agg as old_relat_agg,
       a.code_agg         as old_code_agg,
       a.name_agg         as old_name_agg,
       b.relationship_agg as new_relat_agg,
       b.code_agg         as new_code_agg,
       b.name_agg         as new_name_agg
from old_map a
join new_map b
on a.concept_code = b.concept_code and
                 coalesce(a.code_agg, '') != coalesce(b.code_agg, '')
WHERE a.code_agg IS NOT NULL OR b.code_agg IS NOT NULL
order by a.concept_code
;

--02. Standard concepts with additional mapping
-- in stage table
SELECT *
FROM dev_loinc.concept_stage cs

/*JOIN dev_loinc.concept_relationship_manual crm
    ON cs.concept_code = crm.concept_code_1
        AND cs.vocabulary_id = crm.vocabulary_id_1*/

WHERE EXISTS (
		SELECT 1
		FROM dev_loinc.concept_relationship_stage crs
		WHERE crs.relationship_id = 'Maps to'
			AND crs.invalid_reason IS NULL
			AND cs.concept_code = crs.concept_code_1
			AND cs.vocabulary_id = crs.vocabulary_id_1
		)

	AND cs.standard_concept = 'S'
;

--in basic table
SELECT *
FROM dev_loinc.concept c

/*JOIN dev_loinc.concept_relationship_manual crm
    ON cs.concept_code = crm.concept_code_1
        AND cs.vocabulary_id = crm.vocabulary_id_1*/

WHERE EXISTS (
		SELECT 1
		FROM dev_loinc.concept_relationship cr
		WHERE cr.relationship_id = 'Maps to'
			AND cr.invalid_reason IS NULL
			AND c.concept_id = cr.concept_id_1
            AND cr.concept_id_1 != cr.concept_id_2
		)

	AND c.standard_concept = 'S'
    AND c.vocabulary_id = 'LOINC'
;