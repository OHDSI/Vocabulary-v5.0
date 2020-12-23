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
;
--New covid concepts and their mappings (All UK -- US changes were already managed by SNOMED US)
select c.concept_code, c.concept_name, r.relationship_id, c2.concept_code, c2.vocabulary_id, c2.concept_name
from dev_snomed.concept c
join dev_snomed.concept_relationship r on
	r.concept_id_1 = c.concept_id and
	r.relationship_id in ('Maps to', 'Maps to value')
join dev_snomed.concept c2 on
	c2.concept_id = r.concept_id_2
where
	c.vocabulary_id = 'SNOMED' and
	c.concept_code in
	(
		'1321241000000105','1321701000000102','1321661000000108',
		'1321701000000102','1321661000000108','1322901000000109',
		'1322891000000108','1322871000000109','1322911000000106',
		'1322801000000101','1322791000000100','1322781000000102',
		'1322821000000105','1321771000000105','1322841000000103',
		'1321791000000109','1321761000000103','1321781000000107',
		'1321591000000103','1322831000000107','1321571000000102',
		'1321541000000108','1321641000000107','1321631000000103',
		'1322851000000100','1321561000000109','1321551000000106',
		'1321581000000100','1322901000000109','1322891000000108',
		'1322871000000109','1322911000000106','1322801000000101',
		'1322791000000100','1322781000000102','1322821000000105',
		'1321771000000105','1322841000000103','1321791000000109',
		'1321761000000103','1321781000000107','1321591000000103',
		'1322831000000107','1321571000000102','1321541000000108',
		'1321641000000107','1321631000000103','1322851000000100',
		'1321561000000109','1321551000000106','1321581000000100',
		'1321621000000100','1321651000000105','1321681000000104',
		'1321691000000102','1321621000000100','1321651000000105',
		'1321681000000104','1321691000000102','1321821000000104',
		'1321801000000108','1321811000000105','1321341000000103',
		'1321321000000105','1321351000000100','1321311000000104',
		'1321301000000101','1321741000000104','1321721000000106',
		'1321731000000108','1321711000000100','1321291000000100'
	)
;

--All new peaks and their changed descendants
select p.concept_code as peak_code,
       p.concept_name as peak_name,
       c1.concept_code,
       c1.concept_name,
       c1.invalid_reason,
       c2.domain_id as old,
       c1.domain_id as new
from dev_snomed.concept c1
join devv5.concept c2 on
	(c1.vocabulary_id, c1.concept_code) = (c2.vocabulary_id, c2.concept_code) and
	c1.domain_id != c2.domain_id and
	c1.invalid_reason is null
join dev_snomed.concept p on
	p.vocabulary_id = 'SNOMED' and
	p.concept_code :: int8 in (SELECT peak_code FROM peak WHERE
	                                                            valid_start_date > to_date ('20201101', 'YYYYMMDD') --peaks introduced in the recent refresh
	                                                        AND valid_end_date = to_date('20991231', 'YYYYMMDD'))   --active peaks
join snomed_ancestor a on
	p.concept_code = a.ancestor_concept_code::varchar and
	c2.concept_code = a.descendant_concept_code::varchar
order by p.concept_name, c1.domain_id, c2.domain_id