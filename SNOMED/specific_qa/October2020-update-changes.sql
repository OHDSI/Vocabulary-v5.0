select c.concept_code, c.concept_name as new_name, c2.concept_name as old_name
from dev_snomed.concept c
join devv5.concept c2 using (concept_id)
where 
	c.concept_name != c2.concept_name and
	c.invalid_reason is null
--contents of braaackets are no longer lost, leading to way less duplication
--Prefer US spelling over UK
--Better overall
;
select *
from dev_snomed.concept c
join devv5.concept c2 using (concept_id)
where 
	c.invalid_reason is not null and
	c2.invalid_reason is not null and
	(c.valid_start_date, c.valid_end_date) != (c2.valid_start_date, c2.valid_end_date)
limit 1000

--dates better correspond to source values;
--150 000 rows in full list
;
select c1.concept_code,c1.concept_name, c1.invalid_reason, c2.domain_id as old, c1.domain_id as new
from dev_snomed.concept c1
join devv5.concept c2 on
	(c1.vocabulary_id, c1.concept_code) = (c2.vocabulary_id, c2.concept_code) and
	c1.domain_id != c2.domain_id and
	c1.invalid_reason is null
order by c1.domain_id, c2.domain_id
--domain changes for active concepts
--Mostly due to new added peaks; some changes are caused by hierarchy changes
--Units lost their domains because UK hhierarchhy is broken; will fix itself next release cycle
;
select c1.concept_code,c1.concept_name, c1.invalid_reason, c2.domain_id as old, c1.domain_id as new
from dev_snomed.concept c1
join devv5.concept c2 on
	(c1.vocabulary_id, c1.concept_code) = (c2.vocabulary_id, c2.concept_code) and
	c1.domain_id != c2.domain_id and
	c1.invalid_reason is not null
order by c1.domain_id, c2.domain_id
--domain changes for inactive concepts
--now inherit domain from map target
;
select c1.concept_class_id, count (1)
from concept c1
left join devv5.concept c2 on
	(c1.vocabulary_id, c1.concept_code) = (c2.vocabulary_id, c2.concept_code)
where c2.concept_id is null and
	c1.invalid_reason is not null
group by c1.concept_class_id
--Concepts that don't have a name with a hierarchy tag (and whhose hierarchy is long gone) get Context-dependent class
--Some are Undefined; but no active concepts are undefined
;
--New aactive concepts; no dsicernible problems
select c1.*
from concept c1
left join devv5.concept c2 on
	(c1.vocabulary_id, c1.concept_code) = (c2.vocabulary_id, c2.concept_code)
where c2.concept_id is null and
	c1.invalid_reason is null
