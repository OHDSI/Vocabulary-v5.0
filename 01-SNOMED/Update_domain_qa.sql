-- Run after snomed domain construction

select domain_id,  count(8) from domain_id d, concept c where c.concept_id=d.concept_id and c.valid_start_date!='20140401' 
group by domain_id order by 2 desc;
select d.*, c.* from concept c, domain_id d where c.concept_id=d.concept_id 
and d.domain_id='Not assigned' 
limit 1000;

-- orphan concepts not in hierarchy
select * from concept c 
where concept_id not in (
	select distinct ancestor_concept_id from concept_ancestor)
--and concept_class_id='Clinical finding' 
and invalid_reason is null
and vocabulary_id=1
and valid_start_date!='20140401'
limit 100;

-- check how often the hierarchy switches classes
select an.concept_class_id ancestor, de.concept_class_id descendant, count(8) 
from concept an, concept de, concept_ancestor a
where a.ancestor_concept_id=an.concept_id and a.descendant_concept_id=de.concept_id
and an.concept_class_id!=de.concept_class_id
and an.valid_start_date!='20140401' and de.valid_start_date!='20140401'
and an.vocabulary_id=1 and de.vocabulary_id=1
group by an.concept_class_id, de.concept_class_id
order by 3 desc;

-- check how often the hierarchy witches domains
select ad.domain_id ancestor, ed.domain_id descendant, count(8) 
from concept an, domain_id ad, concept de, domain_id ed, concept_ancestor a
where an.concept_id=ad.concept_id and de.concept_id=ed.concept_id
and a.ancestor_concept_id=an.concept_id and a.descendant_concept_id=de.concept_id
and ad.domain_id!=ed.domain_id
and an.valid_start_date!='20140401' and de.valid_start_date!='20140401' and ad.domain_id!='Observation'
group by ad.domain_id, ed.domain_id
order by 3 desc;

-- see where it changes domain
select distinct
 an.concept_name, an.concept_id, ad.domain_id, 
	de.concept_name, de.concept_id, ed.domain_id
from concept an, domain_id ad, concept de, domain_id ed, concept_ancestor a
where an.concept_id=ad.concept_id and de.concept_id=ed.concept_id
and a.ancestor_concept_id=an.concept_id and a.descendant_concept_id=de.concept_id
and ad.domain_id='Procedure' and ed.domain_id='Measurement'
-- and an.concept_name not in ('SNOMED CT July 2002 Release: 20020731 [R]', 'Special concept', 'Navigational concept', 'Context-dependent category', 'Context-dependent finding', 'Procedure', 'Procedure by method', 'Patient evaluation procedure')
order by de.concept_name
limit 1000;

select * from concept where concept_id=40484042;
select * from domain_id d, concept c where d.concept_id=c.concept_id limit 100; --and d.domain_id='Clinical finding';

-- hierarchy down and up
select max_levels_of_separation min, c.* from concept_ancestor a, concept c where a.ancestor_concept_id in (4297090) and c.concept_id=a.descendant_concept_id order by min_levels_of_separation, concept_name;
select max_levels_of_separation min, c.* from concept_ancestor a, concept c where a.descendant_concept_id in (4047152) and c.concept_id=a.ancestor_concept_id order by maxa_levels_of_separation;
-- relationships down and up
select c.concept_id, c.concept_name, c.domain_id, r.relationship_id
from concept c, concept_relationship r, relationship s
where r.concept_id_1 in (4047152) and c.concept_id=r.concept_id_2
and s.reverse_relationship=r.relationship_id and r.invalid_reason is null and s.defines_ancestry=1;
select c.concept_id, c.concept_name, c.domain_id, r.relationship_id, s.relationship_name
from concept c, concept_relationship r, relationship s
where r.concept_id_1 in (4047152) and c.concept_id=r.concept_id_2
and s.relationship_id=r.relationship_id and r.invalid_reason is null and s.defines_ancestry=1;

select * from concept where concept_id='270999004';
select m.source_code, m.source_code_description, m.mapping_type, c.concept_id, c.concept_name, c.concept_class_id, d.domain_id
from icd9_to_snomed_fixed m
join domain_id d on d.concept_id=m.target_concept_id
join concept c on c.concept_id=m.target_concept_id
where m.mapping_type='CONDITION' and d.domain_id='Clinical finding' 
;

-- find the chain
select up.min_levels_of_separation up, d.domain_id, c.* from concept c, concept_ancestor up, concept_ancestor down, domain_id d
where up.descendant_concept_id=4059164
and down.ancestor_concept_id=4008453 -- root-- 4322976 -- Procedure -- 441840 -- Clinical finding --  4008453 -- root
and up.ancestor_concept_id=down.descendant_concept_id
and c.concept_id=up.ancestor_concept_id
and d.concept_id=c.concept_id 
order by up.min_levels_of_separation;

-- check classes against domains
select s.concept_class_id, d.domain_id, count(8) from concept s, domain_id d
where s.concept_id=d.concept_id
and s.valid_start_date < '2014-01-01' and s.invalid_reason=''
group by s.concept_class_id, d.domain_id
order by 3 desc
limit 100;

select s.*, d.domain_id from concept s, domain_id d
where s.concept_id=d.concept_id
and s.valid_start_date < '2014-01-01' and s.invalid_reason=''
and s.concept_class_id='Clinical finding' and d.domain_id='Observation';

select oben.ancestor_concept_id top, r.concept_id_1 middle, r.concept_id_2 bottom, min_levels_of_separation top_to_middle from concept_ancestor oben
join concept_relationship r on r.concept_id_1=oben.descendant_concept_id and r.invalid_reason is null
join concept c on c.concept_id=r.concept_id_2 and c.invalid_reason is null and c.VOCABULARY_ID=1
join concept m on m.concept_id=r.concept_id_1 and m.INVALID_REASON is null and m.vocabulary_id=1
join relationship s on s.relationship_id=r.relationship_id and s.defines_ancestry=1
where not exists (
	select 1 from concept_ancestor unten where oben.ancestor_concept_id=unten.ancestor_concept_id and unten.descendant_concept_id=r.concept_id_2
	and unten.ancestor_concept_id!=unten.descendant_concept_id
)
and oben.ancestor_concept_id!=oben.descendant_concept_id
and oben.ancestor_concept_id=4008453
order by min_levels_of_separation;

select * from concept where concept_id in (4008453, 374009, 4182210);
select * from concept_ancestor where ancestor_concept_id=4008453 and descendant_concept_id in (374009, 4182210);
-- hierarchy down and up
select min_levels_of_separation min, d.domain_id, c.* from concept_ancestor a, concept c, domain_id d where a.ancestor_concept_id in (4138972) and c.concept_id=a.descendant_concept_id and c.concept_id=d.concept_id order by min_levels_of_separation, concept_name limit 1000;
select min_levels_of_separation min, d.domain_id, c.* from concept_ancestor a, concept c, domain_id d where a.descendant_concept_id in (4225025) and c.concept_id=a.ancestor_concept_id and c.concept_id=d.concept_id order by min_levels_of_separation limit 100;
-- relationships down and up
select d.domain_id, c.concept_id, c.concept_name, r.relationship_id 
from concept c, concept_relationship r, domain_id d, relationship s
where r.concept_id_1 in (4225025) and c.concept_id=r.concept_id_1 and d.concept_id=c.concept_id 
and s.reverse_relationship=r.relationship_id and r.invalid_reason is null --and s.defines_ancestry=1
;
select d.domain_id, c.concept_id, c.concept_name, r.relationship_id, s.relationship_name
from concept c, concept_relationship r, domain_id d, relationship s
where r.concept_id_1 in (4225025) and c.concept_id=r.concept_id_2 and d.concept_id=c.concept_id 
and s.relationship_id=r.relationship_id and r.invalid_reason is null -- and s.defines_ancestry=1
;
select * from relationship where relationship_id=227;




/*************************************************************/

-- check Read-to_snomed
select rts.source_code_description, rts.concept_name, rts.concept_id, rts.domain, d.domain_id
-- select count(8) 
from read_to_snomed rts, concept c, domain_id d
where c.concept_id=d.concept_id and c.concept_id=rts.concept_id
and (case 
	when d.domain_id='observation' and rts.domain='observation' then 1
	when d.domain_id='condition_occurrence' and rts.domain='condition' then 1
	when d.domain_id='measurement' and rts.domain='lab test' then 1
	when d.domain_id='procedure_occurrence' and rts.domain='procedure' then 1
	else 0 end)=0
and c.valid_start_date!='01-APR-2014'
limit 1000;

-- find the chain
select up.min_levels_of_separation up, d.domain_id, c.concept_id, c.concept_name, c.concept_id 
from concept c, concept_ancestor up, concept_ancestor down, domain_id d, concept des
where des.concept_id='315364008'
-- and down.ancestor_concept_id=4322976 -- Procedure 
-- and down.ancestor_concept_id=441840 -- Clinical finding 
and down.ancestor_concept_id=4008453 -- root
-- and down.ancestor_concept_id=4196732 -- calculus observation
and up.ancestor_concept_id=down.descendant_concept_id
and c.concept_id=up.ancestor_concept_id
and d.concept_id=c.concept_id and des.concept_id=up.descendant_concept_id
order by up.min_levels_of_separation;




-- Create domain for those SNOMED concepts that have no domain assigned
insert into concept_domain
select 
  c.concept_id,
  case 
    when c.concept_class_id='Clinical finding' then 'Condition'
    when c.concept_class_id='Procedure' then 'Procedure'
    when c.concept_class_id='Pharmaceutical / biologic product' then 'Drug'
    when c.concept_class_id='Physical object' then 'Device'
    when c.concept_class_id='Model component' then 'Metadata'
    else 'Observation' 
  end as domain_name
from concept c where not exists (
  select 1 from concept_domain d where d.concept_id=c.concept_id
)
and vocabulary_id=1 and invalid_reason is null
;

select c.concept_class_id, c.valid_start_date, count(8) from concept c, domain_id d where d.concept_id=c.concept_id and d.domain_name='Not assigned'
group by c.concept_class_id, c.valid_start_date;

select d.domain_name, c.* from concept c, domain_id d where d.concept_id=c.concept_id and c.concept_class_id='Context-dependent category'
;

-- Manually fix 'Not assigned' 
update concept_domain d set
  d.domain_name=(select decode(c.concept_class_id,
    'Clinical finding', 'Condition',
    'Procedure', 'Procedure',
    'Pharmaceutical / biological product', 'Drug',
    'Physical object', 'Device',
    'Substance', 'Device',
    'Model component', 'Metadata',
    'Namespace concept', 'Metadata',
    'Observation'
  )
  from concept c
  where c.concept_id=d.concept_id 
)
where d.domain_name='Not assigned'
;

select * from concept_domain where domain_name='Not assigned';