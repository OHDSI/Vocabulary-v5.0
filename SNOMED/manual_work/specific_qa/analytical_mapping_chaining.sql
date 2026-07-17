--! Start from here
--Concepts changed their mappings
with new_map as (
select a.concept_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as relationship_agg,
       string_agg (case when a.concept_id = b.concept_id then '<Mapped to itself>' else b.concept_code end, '-/-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as code_agg,
       string_agg (case when a.concept_id = b.concept_id then '<Mapped to itself>' else b.concept_name end, '-/-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as name_agg
from concept a
left join concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Maps to', 'Maps to value') and r.invalid_reason is null
left join concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN (:your_vocabs)
    --and a.invalid_reason is null --to exclude invalid concepts
group by a.concept_id, a.vocabulary_id, a.concept_class_id, a.standard_concept, a.concept_code, a.concept_name
)
,
old_map as (
select a.concept_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as relationship_agg,
       string_agg (case when a.concept_id = b.concept_id then '<Mapped to itself>' else b.concept_code end, '-/-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as code_agg,
       string_agg (case when a.concept_id = b.concept_id then '<Mapped to itself>' else b.concept_name end, '-/-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as name_agg
from devv5.concept a
left join devv5.concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Maps to', 'Maps to value') and r.invalid_reason is null
left join devv5.concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN (:your_vocabs)
    --and a.invalid_reason is null --to exclude invalid concepts
group by a.concept_id, a.vocabulary_id, a.concept_class_id, a.standard_concept, a.concept_code, a.concept_name
)
select b.vocabulary_id as vocabulary_id,
       b.concept_class_id,
       b.standard_concept,
       b.concept_code as source_code,
       b.concept_name as source_name,
       a.relationship_agg as old_relat_agg,
       a.code_agg as old_code_agg,
       a.name_agg as old_name_agg,
       b.relationship_agg as new_relat_agg,
       b.code_agg as new_code_agg,
       b.name_agg as new_name_agg
from old_map a
join new_map b
on a.concept_id = b.concept_id and ((coalesce (a.code_agg, '') != coalesce (b.code_agg, '')) or (coalesce (a.relationship_agg, '') != coalesce (b.relationship_agg, '')))
order by a.concept_code;



--02.5. concepts changed their mapping ('Maps to', 'Maps to value')
--Maps to-Maps to
--JOIN to test table
with x AS
(with new_map as (
select a.concept_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as relationship_agg,
       string_agg (case when a.concept_id = b.concept_id then '<Mapped to itself>' else b.concept_code end, '-/-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as code_agg,
       string_agg (case when a.concept_id = b.concept_id then '<Mapped to itself>' else b.concept_name end, '-/-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as name_agg
from concept a
left join concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Maps to', 'Maps to value') and r.invalid_reason is null
left join concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN (:your_vocabs)
    --and a.invalid_reason is null --to exclude invalid concepts
group by a.concept_id, a.vocabulary_id, a.concept_class_id, a.standard_concept, a.concept_code, a.concept_name
)
,
old_map as (
select a.concept_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as relationship_agg,
       string_agg (case when a.concept_id = b.concept_id then '<Mapped to itself>' else b.concept_code end, '-/-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as code_agg,
       string_agg (case when a.concept_id = b.concept_id then '<Mapped to itself>' else b.concept_name end, '-/-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as name_agg
from devv5.concept a
left join devv5.concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Maps to', 'Maps to value') and r.invalid_reason is null
left join devv5.concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN (:your_vocabs)
    --and a.invalid_reason is null --to exclude invalid concepts
group by a.concept_id, a.vocabulary_id, a.concept_class_id, a.standard_concept, a.concept_code, a.concept_name
)
select b.vocabulary_id as vocabulary_id,
       b.concept_class_id,
       b.standard_concept,
       b.concept_code as source_code,
       b.concept_name as source_name,
       a.relationship_agg as old_relat_agg,
       a.code_agg as old_code_agg,
       a.name_agg as old_name_agg,
       b.relationship_agg as new_relat_agg,
       b.code_agg as new_code_agg,
       b.name_agg as new_name_agg
from old_map a
join new_map b
on a.concept_id = b.concept_id and ((coalesce (a.code_agg, '') != coalesce (b.code_agg, '')) or (coalesce (a.relationship_agg, '') != coalesce (b.relationship_agg, '')))
order by a.concept_code)

select m.* from dev_test.MapsToValueValidation2 m 
JOIN x 
ON x.source_code = m.concept_code_1 AND x.vocabulary_id = m.vocabulary_id_1
WHERE new_relat_agg ~* 'Maps to-Maps to'
;




--Examples of poor mapping chaining (mostly one to many)
--102293005 (not fully represented in MapsToValueValidation2)
--103076008

-- 40268232 Perfect example (code 105425004)

--Example 1
--40268232	Lack of education	Condition	SNOMED	Clinical Finding		105425004	1970-01-01	2022-01-27	U
SELECT * FROM devv5.concept WHERE concept_id = 40268232;
--No manual mapping
SELECT * FROM devv5.base_concept_relationship_manual WHERE concept_id_1 = 40268232;
--Maps to to id 4059164; replaced by id 4237536; Maps to to id 4237536 (same as replaced by - good)
SELECT * FROM devv5.concept_relationship WHERE concept_id_1 = 40268232;
--Potential targets have different mappings
SELECT * FROM devv5.concept_relationship 
         WHERE concept_id_1 IN (4059164, 4237536) 
         AND relationship_id = 'Maps to'
         ORDER BY concept_id_1, relationship_id, invalid_reason;
--No manual relationships for potential targets
SELECT * FROM devv5.base_concept_relationship_manual WHERE concept_id_1 IN (4059164, 4237536);
--Both targets are present as targets in manual check after generic 
SELECT * FROM devv5.concept 
WHERE concept_id IN (4059164, 4237536);


--21475 concepts
--With valid replacement relationships, but without Maps to to target replacement concept
--May be absolutely valid, if replacement target is not standard anymore.
--However, it may result in discrepancies (see below another query)
SELECT DISTINCT c.*
FROM devv5.concept_relationship cr 
JOIN devv5.concept c 
ON c.concept_id = cr.concept_id_1 AND c.vocabulary_id = 'SNOMED'
WHERE cr.relationship_id IN ('Concept replaced by',
								'Concept same_as to',
								'Concept alt_to to',
								'Concept was_a to') 
AND cr.invalid_reason IS NULL 
  --Exists mapping to another concept
AND EXISTS(
    SELECT 1 FROM devv5.concept_relationship cr1 
    WHERE cr1.relationship_id = 'Maps to'
    AND cr1.invalid_reason IS NULL 
    AND cr1.concept_id_1 = cr.concept_id_1 AND cr1.concept_id_2 != cr.concept_id_2
    )
  --Not exists mapping to target replacement concept
AND NOT EXISTS(
    SELECT 1 FROM devv5.concept_relationship cr1 
    WHERE cr1.relationship_id = 'Maps to'
    AND cr1.invalid_reason IS NULL 
    AND cr1.concept_id_1 = cr.concept_id_1 AND cr1.concept_id_2 = cr.concept_id_2
    );


--Example 2 (one of those 20k concepts) - not present in mapping delta
--73066	Traumatic amputation of thumb without mention of complication	Condition	SNOMED	Clinical Finding		210612009	2002-01-31	2010-01-31	U
SELECT * FROM devv5.concept WHERE concept_id = 73066;
--No manual mapping
SELECT * FROM devv5.base_concept_relationship_manual WHERE concept_id_1 = 73066;
--Maps to to id 443982; Concept same_as to id 3519372; Concept was_a to id 443982 (same as replaced by - good)
SELECT * FROM devv5.concept_relationship WHERE concept_id_1 = 73066;
--Potential targets have identical mappings
SELECT * FROM devv5.concept_relationship 
         WHERE concept_id_1 IN (443982, 3519372) 
         AND relationship_id = 'Maps to'
         ORDER BY concept_id_1, relationship_id, invalid_reason;
--No manual relationships for potential targets
SELECT * FROM devv5.base_concept_relationship_manual WHERE concept_id_1 IN (443982, 3519372);
--Both targets are present as targets in manual check after generic 
--It all lines up to one target concept, therefore, it is not present in mapping delta








-- concepts
SELECT DISTINCT c.*
FROM devv5.concept_relationship cr 
JOIN devv5.concept c 
ON c.concept_id = cr.concept_id_1 AND c.vocabulary_id = 'SNOMED'
WHERE cr.relationship_id IN ('Concept poss_eq to') 
AND cr.invalid_reason IS NULL 
  --Exists mapping to the same poss eq to concept
AND EXISTS(
    SELECT 1 FROM devv5.concept_relationship cr1 
    WHERE cr1.relationship_id = 'Maps to'
    AND cr1.invalid_reason IS NULL 
    AND cr1.concept_id_1 = cr.concept_id_1 AND cr1.concept_id_2 = cr.concept_id_2
    )
  --Exists mapping to another concept
AND EXISTS(
    SELECT 1 FROM devv5.concept_relationship cr1 
    WHERE cr1.relationship_id = 'Maps to'
    AND cr1.invalid_reason IS NULL 
    AND cr1.concept_id_1 = cr.concept_id_1 AND cr1.concept_id_2 != cr.concept_id_2
    )
AND c.concept_id NOT IN (SELECT concept_id_1 FROM devv5.base_concept_relationship_manual)
;