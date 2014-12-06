/*******************************************************************************
Script to update all domain_id and standard_concept fields to records in SNOMED

This script expects the following tables ready:
- concept_stage, with class_concept_id already filled
- snomed_ancestor: same as concept_ancestor except 
  - only containing snomed concetps
  - all records participate (no removal where standard_concept is null)
  - instead of concept_id use concept_code
********************************************************************************/


-- 1. Manually create table with "Peaks" = ancestors of records that are all of the same domain
-- drop table peak;
create table peak (
	peak_code integer, --the id of the top ancestor
	peak_domain_id varchar(20), -- the domain to assign to all its children
	ranked integer -- number for the order in which to assign
);

-- Fill in the various peak concepts
insert into peak (peak_code, peak_domain_id) values (4086921, 'Observation'); -- 'Context-dependent category' that has no ancestor
insert into peak (peak_code, peak_domain_id) values (4008453, 'Observation'); -- root
insert into peak (peak_code, peak_domain_id) values (4320145, 'Provider Specialty');
insert into peak (peak_code, peak_domain_id) values (4185257, 'Place of Service');	  -- Site of care
insert into peak (peak_code, peak_domain_id) values (4169112, 'Drug'); -- Aromatherapy agent
insert into peak (peak_code, peak_domain_id) values (4162709, 'Drug'); -- Pharmaceutical / biologic product
insert into peak (peak_code, peak_domain_id) values (4254051, 'Drug'); --	Drug or medicament
insert into peak (peak_code, peak_domain_id) values (4169265, 'Device');
insert into peak (peak_code, peak_domain_id) values (4128004, 'Device'); -- Surgical material
insert into peak (peak_code, peak_domain_id) values (4124754, 'Device'); -- Graft
insert into peak (peak_code, peak_domain_id) values (4303529, 'Device'); -- Adhesive agent
insert into peak (peak_code, peak_domain_id) values (441840, 'Condition'); -- Clinical Finding
insert into peak (peak_code, peak_domain_id) values (438949, 'Condition'); -- Adverse reaction to primarily systemic agents
insert into peak (peak_code, peak_domain_id) values (4196732, 'Condition'); -- Calculus observation
insert into peak (peak_code, peak_domain_id) values (4041436, 'Measurement'); -- 'Finding by measurement'
insert into peak (peak_code, peak_domain_id) values (443440, 'Observation'); -- 'History finding'
insert into peak (peak_code, peak_domain_id) values (4040739, 'Observation'); -- 'Finding of activity of daily living'
insert into peak (peak_code, peak_domain_id) values (4146314, 'Observation');-- 'Administrative statuses'
		-- 40416814, 'Observation'); Causes of injury and poisoning'
		-- 40418184,  -- '[X]External causes of morbidity and mortality'
insert into peak (peak_code, peak_domain_id) values (4037321, 'Observation'); -- Symptom description
-- insert into peak (peak_code, peak_domain_id) values (4084137,	'Observation');-- Sample observation
insert into peak (peak_code, peak_domain_id) values (4022232, 'Observation'); -- 'Health perception, health management pattern'
insert into peak (peak_code, peak_domain_id) values (4037706, 'Observation'); --'Patient not aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (4279142, 'Observation'); --'Victim status'
insert into peak (peak_code, peak_domain_id) values (4037705, 'Observation'); --'Patient aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (4167037, 'Observation'); --Patient condition finding
insert into peak (peak_code, peak_domain_id) values (4231688, 'Observation'); --'Staff member inattention'
insert into peak (peak_code, peak_domain_id) values (4236719, 'Observation'); --'Staff member ill'
insert into peak (peak_code, peak_domain_id) values (4225233, 'Observation'); --'Staff member distraction'
insert into peak (peak_code, peak_domain_id) values (4134868, 'Observation'); --Staff member fatigued
insert into peak (peak_code, peak_domain_id) values (4134549, 'Observation'); --Staff member inadequately assisted
insert into peak (peak_code, peak_domain_id) values (4134412, 'Observation'); --Staff member inadequately supervised
insert into peak (peak_code, peak_domain_id) values (4037137, 'Observation');--'Family not aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (4038236, 'Observation'); --'Family aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (4170588, 'Observation'); --Acceptance of illness
insert into peak (peak_code, peak_domain_id) values (4028922, 'Observation'); --	Social context condition
insert into peak (peak_code, peak_domain_id) values (4202797, 'Observation'); -- Drug therapy observations
insert into peak (peak_code, peak_domain_id) values (444035, 'Condition'); --Incontinence
-- insert into peak (peak_code, peak_domain_id) values (4025202, 'Condition'); --Elimination pattern
-- insert into peak (peak_code, peak_domain_id) values (4186437, 'Condition'); -- Urinary elimination alteration
--		4266236, 'Observation'); --'Cancer-related substance' - 4228508
insert into peak (peak_code, peak_domain_id) values (4028908, 'Measurement'); --'Laboratory procedures'
insert into peak (peak_code, peak_domain_id) values (4048365, 'Measurement'); --'Measurement'
-- 		4236002, 'Observation'); --'Allergen class'
-- 		4019381, 'Observation'); --'Biological substance'
--		4240422 -- 'Human body substance'
insert into peak (peak_code, peak_domain_id) values (4038503, 'Measurement');	-- 'Laboratory test finding' - child of excluded Sample observation
insert into peak (peak_code, peak_domain_id) values (4322976, 'Procedure'); --'Procedure'
insert into peak (peak_code, peak_domain_id) values (4126324, 'Procedure'); -- Resuscitate
insert into peak (peak_code, peak_domain_id) values (4119499, 'Procedure'); --DNR
insert into peak (peak_code, peak_domain_id) values (4013513, 'Procedure'); -- Cardiovascular measurement
insert into peak (peak_code, peak_domain_id) values (4175586, 'Observation'); --Family history of procedure
insert into peak (peak_code, peak_domain_id) values (4033224, 'Observation'); --Administrative procedure
insert into peak (peak_code, peak_domain_id) values (4215685, 'Observation'); --Past history of procedure
insert into peak (peak_code, peak_domain_id) values (4082089, 'Observation');-- Procedure contraindicated
insert into peak (peak_code, peak_domain_id) values (4231195, 'Observation');-- Administration of drug or medicament contraindicated
insert into peak (peak_code, peak_domain_id) values (40484042, 'Observation'); --Evaluation of urine specimen
insert into peak (peak_code, peak_domain_id) values (4260907, 'Observation'); -- Drug therapy status
insert into peak (peak_code, peak_domain_id) values (4271693, 'Procedure'); --Blood unit processing - inside Measurements
insert into peak (peak_code, peak_domain_id) values (4070456, 'Procedure'); -- Specimen collection treatments and procedures - - bad child of 4028908	Laboratory procedure
insert into peak (peak_code, peak_domain_id) values (4268709, 'Gender'); -- Gender
insert into peak (peak_code, peak_domain_id) values (4155301, 'Race'); --Ethnic group
insert into peak (peak_code, peak_domain_id) values (4216292, 'Race'); -- Racial group
insert into peak (peak_code, peak_domain_id) values (40642546, 'Metadata'); -- SNOMED CT Model Component
insert into peak (peak_code, peak_domain_id) values (4024728, 'Observation'); -- Linkage concept
insert into peak (peak_code, peak_domain_id) values (4121358, 'Unit'); -- Top unit

-- 2. Ancestors inherit the domain_id and standard_concept of their Peaks. However, the ancestors of Peaks are overlapping.
-- Therefore, the order by which the inheritance is passed depends on the "height" in the hierarchy: The lower the peak, the later it should be run
-- The following creates the right order by counting the number of ancestors: The more ancestors the lower in the hierarchy.
-- This could go wront if a parallel fork happens
update peak p set p.ranked=r.rnk
from (
	select ranked.pd as peak_code, count(8) as rnk from (
		select distinct pa.peak_code as pa, pd.peak_code as pd 
		from peak pa
		join snomed_ancestor a on a.ancestor_concept_code=pa.peak_code 
		join peak pd on a.descendant_concept_code=pd.peak_code
	) ranked
	group by ranked.pd
) r
where r.peak_code=p.peak_code
;

-- 3. Find clashes, where one child has two or more Peak concepts as ancestors and display them with ordered by levels of separation
-- Currently these clashes are dealt with by precedence, not through rank. This might need to change
-- Also, this script needs to do this within a rank. Not done yet.
select conflict.concept_name as child, min_levels_of_separation as min, d.peak_domain_id, c.concept_name as peak, c.concept_class_id as peak_class_id
from snomed_ancestor a, concept_stage c, peak d, concept_stage conflict 
where a.descendant_concept_code in (
	select concept_code from (
		select child.concept_code, count(8)
		from (
			select distinct p.peak_domain_id, a.descendant_concept_code as concept_code from peak p, snomed_ancestor a 
			where a.ancestor_concept_code=p.peak_code
		) child
		group by child.concept_code having count(8)>1
	) clash
) 
and c.concept_code=a.ancestor_concept_code and c.concept_code=d.concept_code and c.concept_code in (select peak_code from peak)
and conflict.concept_code=a.descendant_concept_code
order by conflict.concept_name, min_levels_of_separation, c.concept_name
;

-- 4. Find other peak concepts (orphans) that are missed from the above manual list, and assign them a domain_id based on heuristic. 
-- Peak concepts are those ancestors that are not also descendants somewhere, except in their own record
-- If there are mistakes, the manual list needs be updated and everything re-run
insert into peak -- before doing that check first out without the insert
select distinct
	c.concept_code as peak_code,
	case 
		when c.concept_class_id='Clinical finding' then 'Condition'
		when c.concept_class_id='Model component' then 'Metadata'
		when c.concept_class_id='Observable entity' then 'Observation'
		when c.concept_class_id='Organism' then 'Observation'
		when c.concept_class_id='Pharmaceutical / biologic product' then 'Drug'
		else 'Manual'
	end as peak_domain_id
from snomed_ancestor a, concept_stage c
where a.ancestor_concept_code not in (
	select distinct descendant_concept_code from snomed_ancestor where ancestor_concept_code!=descendant_concept_code
)
and c.concept_code=a.ancestor_concept_code
;

-- 5. Start building domains, preassign all them with "Not assigned"
-- drop table domain;
create table domain as 
select concept_code, 'Not assigned' as domain_id from concept_stage;

-- 6. Pass out domain_ids
-- Method 1: Assign domains to children of peak concepts in the order rank, and within rank by order of precedence
-- Do that for all peaks by order of ranks. The highest first, the lower ones second, etc. There are 4 ranks right now
update domain d set
	d.domain_id=child.peak_domain_id
from (
	select distinct 
		-- if there are two conflicting domains in the rank (both equally distant from the ancestor) then use precedence
		first_value(p.peak_domain_id) over (partition by a.descendant_concept_code order by decode(peak_domain_id,
			'Measurement', 1,
			'Procedure', 2,
			'Device', 3,
			'Condition', 4,
			'Provider', 5,
			'Drug', 6,
			'Gender', 7,
			'Race', 8,
			10) -- everything else is Observation
		) as peak_domain_id,
		a.descendant_concept_code as concept_code 
	from peak p, snomed_ancestor a 
	where a.ancestor_concept_code=p.peak_code and p.ranked=1 
) child
where child.concept_code=d.concept_code
;

-- Secondary in precedence
update domain d set
	d.domain_id=child.peak_domain_id
from (
	select distinct 
		first_value(p.peak_domain_id) over (partition by a.descendant_concept_code order by decode(peak_domain_id,
			'Measurement', 1,
			'Procedure', 2,
			'Device', 3,
			'Condition', 4,
			'Provider', 5,
			'Drug', 6,
			'Gender', 7,
			'Race', 8,
			10) -- everything else is Observation
		) as peak_domain_id,
		a.descendant_concept_code as concept_code 
	from peak p, snomed_ancestor a 
	where a.ancestor_concept_code=p.peak_code and p.ranked=2
) child
where child.concept_code=d.concept_code
;

-- Tertiary
update domain d set
	d.domain_id=child.peak_domain_id
from (
	select distinct 
		first_value(p.peak_domain_id) over (partition by a.descendant_concept_code order by decode(peak_domain_id,
			'Measurement', 1,
			'Procedure', 2,
			'Device', 3,
			'Condition', 4,
			'Provider', 5,
			'Drug', 6,
			'Gender', 7,
			'Race', 8,
			10) -- everything else is Observation
		) as peak_domain_id,
		a.descendant_concept_code as concept_code 
	from peak p, snomed_ancestor a 
	where a.ancestor_concept_code=p.peak_code and p.ranked=3
) child
where child.concept_code=d.concept_code
;

-- 4th
update domain d set
	d.domain_id=child.peak_domain_id
from (
	select distinct 
		first_value(p.peak_domain_id) over (partition by a.descendant_concept_code order by decode(peak_domain_id,
			'Measurement', 1,
			'Procedure', 2,
			'Device', 3,
			'Condition', 4,
			'Provider', 5,
			'Drug', 6,
			'Gender', 7,
			'Race', 8,
			10) -- everything else is Observation
		) as peak_domain_id,
		a.descendant_concept_code as concept_code 
	from peak p, snomed_ancestor a 
	where a.ancestor_concept_code=p.peak_code and p.ranked=4 -- currently only 4 ranks
) child
where child.concept_code=d.concept_code
;

-- 5th
update domain d set
	d.domain_id=child.peak_domain_id
from (
	select distinct 
		first_value(p.peak_domain_id) over (partition by a.descendant_concept_code order by decode(peak_domain_id,
			'Measurement', 1,
			'Procedure', 2,
			'Device', 3,
			'Condition', 4,
			'Provider', 5,
			'Drug', 6,
			'Gender', 7,
			'Race', 8,
			10) -- everything else is Observation
		) as peak_domain_id,
		a.descendant_concept_code as concept_code 
	from peak p, snomed_ancestor a 
	where a.ancestor_concept_code=p.peak_code and p.ranked=5 -- currently only 4 ranks
) child
where child.concept_code=d.concept_code
;

-- Check orphans whether they contain mixed children with different multipe concept_class_ids or domains. 
-- If they have mixed children, the concept_class_id-based heuristic might create problems
-- Add those to the peak table (including assigning domains to the various descendants) and re-run
select distinct orphan.concept_code, orphan.concept_name, child.concept_class_id, d.domain_id from (
	select distinct
		c.concept_code, concept_name
	from snomed_ancestor a, concept_stage c
	where a.ancestor_concept_code not in (
		select distinct descendant_concept_code from snomed_ancestor where ancestor_concept_code!=descendant_concept_code
	)
	and c.concept_code=a.ancestor_concept_code
	and c.concept_code not in (select distinct peak_code from peak)
)	orphan
join snomed_ancestor a on a.ancestor_concept_code=orphan.concept_code
join domain d on d.concept_code=a.descendant_concept_code
join concept child on child.concept_code=a.descendant_concept_code
order by 1;

-- Method 2: For those that slipped through the cracks assign domains by using the class_concept_id
-- Check out which these are and potentially fix and re-run Method 1
update domain d set
	d.domain_id = (select
    case c.concept_class_id
      when 'Clinical Finding' then 'Condition'
      when 'Procedure' then 'Procedure'
      when 'Pharma/Biol Product' then 'Drug'
      when 'Physical Object' then 'Device'
      when 'Model comp' then 'Metadata'
      else 'Observation' 
    end
  from concept_stage c
  where c.concept_code=d.concept_code
)
where d.domain_id='Not assigned'
;

-- 5. Update concept_stage from newly created domains
update concept_stage c 
  set c.domain_id = (
    select d.domain_id from domain d where d.concept_code=c.concept_code
  )
;

-- 6. Set standard_concept based on domain_id
update concept_stage 
  set standard_concept =
    case domain_id
      when 'Drug' then null -- Drugs are RxNorm
      when 'Metadata' then null -- Not used in CDM
      when 'Race' then null -- Race are CDC
      when 'Provider Specialty' then null
      when 'Place of Service' then null
      when 'Unit' then null -- Units are UCUM
      else 'S' 
    end
;