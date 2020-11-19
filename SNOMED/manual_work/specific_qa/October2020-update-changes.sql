--Name changes
select c.concept_code, c.concept_name as new_name, c2.concept_name as old_name
from dev_snomed.concept c
join devv5.concept c2 using (concept_id)
where 
	c.concept_name != c2.concept_name and
	c.invalid_reason is null
--contents of brackets are no longer lost, leading to way less duplication
--Prefer US spelling over UK
--Better overall
;
--Validity dates changes
select c.concept_code, c.concept_name, c2.valid_start_date as old_start, c2.valid_end_date as old_end, c.valid_start_date as new_start, c.valid_end_date as new_end
from dev_snomed.concept c
join devv5.concept c2 using (concept_id)
where 
	c.invalid_reason is not null and
	c2.invalid_reason is not null and
	(c.valid_start_date, c.valid_end_date) != (c2.valid_start_date, c2.valid_end_date)
limit 1000
--dates better correspond to source values rathher then our release cycles
--150 000 rows in full list
;
--domain changes for active concepts
select c1.concept_code,c1.concept_name, c1.invalid_reason, c2.domain_id as old, c1.domain_id as new
from dev_snomed.concept c1
join devv5.concept c2 on
	(c1.vocabulary_id, c1.concept_code) = (c2.vocabulary_id, c2.concept_code) and
	c1.domain_id != c2.domain_id and
	c1.invalid_reason is null
order by c1.domain_id, c2.domain_id
--Mostly due to new added peaks; some changes are caused by hierarchy changes
--Units lost their domains because UK hhierarchhy is broken; will fix itself next release cycle
;
--domain changes for inactive concepts
select c1.concept_code,c1.concept_name, c1.invalid_reason, c2.domain_id as old, c1.domain_id as new
from dev_snomed.concept c1
join devv5.concept c2 on
	(c1.vocabulary_id, c1.concept_code) = (c2.vocabulary_id, c2.concept_code) and
	c1.domain_id != c2.domain_id and
	c1.invalid_reason is not null
order by c1.domain_id, c2.domain_id
--now inherit domain from map target
;
--New invalid concepts class stats
select c1.concept_class_id, count (1)
from concept c1
left join devv5.concept c2 on
	(c1.vocabulary_id, c1.concept_code) = (c2.vocabulary_id, c2.concept_code)
where c2.concept_id is null and
	c1.invalid_reason is not null
group by c1.concept_class_id
--New invalid concepts are created because of new extraction logic, which no longer ignores them
--Concepts that don't have a name with a hierarchy tag (and whose hierarchy is long gone) get Context-dependent class
--Some are Undefined; but no active concepts are undefined
;
--New active concepts; no dsicernible problems
select c1.*
from concept c1
left join devv5.concept c2 on
	(c1.vocabulary_id, c1.concept_code) = (c2.vocabulary_id, c2.concept_code)
where c2.concept_id is null and
	c1.invalid_reason is null
;
--New logic for Observable entities, making them Measurements: complete overview
select c.concept_code, c.concept_name, c2.domain_id as old, c.domain_id as new
from devv5.concept_ancestor a --new concept ancestor is not yet built
join devv5.concept c2 on
	a.ancestor_concept_id = 4181663 and --Observable entity
	a.descendant_concept_id = c2.concept_id and
	c2.vocabulary_id = 'SNOMED'
join dev_snomed.concept c on
	(c.vocabulary_id, c.concept_code) = (c2.vocabulary_id, c2.concept_code) and
	c.domain_id != c2.domain_id
where c.invalid_reason is null
;
--New logic for Numbers and Letters, making them Measurement Values: complete overview
select c.concept_code, c.concept_name, c2.domain_id as old, c.domain_id as new
from devv5.concept_ancestor a --new concept ancestor is not yet built
join devv5.concept c2 on
	a.ancestor_concept_id in (4126548,4156064) and --Number, Alphanumeric
	a.descendant_concept_id = c2.concept_id and
	c2.vocabulary_id = 'SNOMED'
join dev_snomed.concept c on
	(c.vocabulary_id, c.concept_code) = (c2.vocabulary_id, c2.concept_code) and
	c.domain_id != c2.domain_id
where c.invalid_reason is null