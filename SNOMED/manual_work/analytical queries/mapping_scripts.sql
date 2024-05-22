--1. Refresh snomed_mapped table to add standard targets and mark the mappings that require review:
--- Following flags are used:
---!non-standard target! - a target concept became non-standard with no mapping to standard
---!no target! - a target concept absent (mapping to 0, may be improved)
with reviewed as (
select source_code_description,
       source_code,
       source_concept_class_id,
       source_invalid_reason,
       source_domain_id,
       source_vocabulary_id,
       cr_invalid_reason,
       mapping_tool,
       mapping_source,
       confidence,
       m.relationship_id,
       relationship_id_predicate,
       m.source,
       case when m.target_concept_id != c.concept_id then '!target updated!' END as comments,
       c.concept_id as target_concept_id,
       c.concept_code as target_concept_code,
       c.concept_name as target_concept_name,
       c.concept_class_id as target_concept_class_id,
       c.standard_concept as target_standard_concept,
       c.invalid_reason as target_invalid_reason,
       c.domain_id as target_domain_id,
       c.vocabulary_id as target_vocabulary_id,
       mapper_id,
       reviewer_id
from snomed_mapped m
join concept cc on (cc.concept_code, cc.vocabulary_id) = (m.target_concept_code, m.target_vocabulary_id)
left join devv5.concept_relationship cr on cc.concept_id = cr.concept_id_1 and cr.relationship_id = 'Maps to' and cr.invalid_reason is null
left join devv5.concept c on c.concept_id = cr.concept_id_2
where m.cr_invalid_reason  is NULL
and cr.relationship_id in ('Maps to', 'Maps to value')

union

select source_code_description,
       source_code,
       source_concept_class_id,
       source_invalid_reason,
       source_domain_id,
       source_vocabulary_id,
       cr_invalid_reason,
       mapping_tool,
       mapping_source,
       confidence,
       m.relationship_id,
       relationship_id_predicate,
       m.source,
       case when target_concept_code is NULL then '!no target!' end as comments,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_concept_class_id,
       target_standard_concept,
       target_invalid_reason,
       target_domain_id,
       target_vocabulary_id,
       mapper_id,
       reviewer_id
from snomed_mapped m
where relationship_id not in ('Maps to', 'Maps to value')
or (relationship_id in ('Maps to', 'Maps to value') and cr_invalid_reason = 'D')
or target_concept_id = 0
or target_concept_code is null
),

to_review as (
select source_code_description,
       source_code,
       source_concept_class_id,
       source_invalid_reason,
       source_domain_id,
       source_vocabulary_id,
       cr_invalid_reason,
       mapping_tool,
       mapping_source,
       confidence,
       m.relationship_id,
       relationship_id_predicate,
       m.source,
       case when c.standard_concept is null and c.concept_code is not null then '!non-standard target!'
              else null end as comments,
       c.concept_id as target_concept_id,
       c.concept_code as target_concept_code,
       c.concept_name as target_concept_name,
       c.concept_class_id as target_concept_class_id,
       c.standard_concept as target_standard_concept,
       c.invalid_reason as target_invalid_reason,
       c.domain_id as target_domain_id,
       c.vocabulary_id as target_vocabulary_id,
       mapper_id,
       reviewer_id
from snomed_mapped m
join devv5.concept c on (c.concept_code, c.vocabulary_id) = (m.target_concept_code, m.target_vocabulary_id)
where not exists (select 1
                  from reviewed r
                  where (r.source_code, r.relationship_id, r.cr_invalid_reason) = (m.source_code, m.relationship_id, m.cr_invalid_reason)))

select * from reviewed
union
select * from to_review
order by source, source_code, relationship_id
;

-- 2. Many concepts can be mapped using their hierarchies or attributive relationships:
--- Extract such mappings and pass them for review:

--2.1 Pre-coordinated measurements:
with target_exclusion as (-- Exclude too non-specific targets
       select * from concept
			  where concept_id in (4048365, --Measurement
								   4098214, --Histopathology test
								   4326835, --Measurement of substance
								   4005184, --Antigen assay
								   4080843, --Eye measure
								   4297090, -- Evaluation procedure
								   4215986, --Organic chemical level
			                      4237017, -- Genetic test
			                       4023405, -- Cytologic test
			                      20135006 -- Screening procedure
					 )
),

source_exclusion as(
             select descendant_concept_code
             from snomed_ancestor
             where ancestor_concept_code in (
                    '301978000', -- Finding of vision of eye (impossible to postcoordinate)
					'301120008', -- Electrocardiogram finding
					'292003', -- EEG finding
					'364974006', --Nerve conduction pattern
	                '1255670000', --Finding of increased risk level
	                '8116006', -- Phenotype
					'365857001', --Child examination finding
					'366219004', -- Tendency to bleed
					'365619003', -- Finding of red blood cell morphology
					'250373003', --Blood transfusion finding
              		'395538009', -- Microscopic specimen observation
					'250537006', -- Histopathology finding
					'363171000000104', -- Timed collection of specimen
					'365853002', -- Imaging finding
					'29679002', -- Carrier of disorder
					'365690003', -- Presence of organism
              		'106221001', -- Genetic finding
                    '107674006', -- Cytology finding
                    '250429001', -- Macroscopic specimen observation
                    '72724002', -- Morphologic finding
              		'118207001', --Finding related to molecular conformation
              		'107650008' -- Finding of color
					)
	   )
select distinct c.concept_name as source_name,
        c.concept_code as source_code,
        c.concept_class_id,
        c.invalid_reason,
        c.domain_id,
        c.vocabulary_id,
		null as invalid_reason,
     	null as mapping_tool,
        null as mapping_source,
		'1' as confidence,
        'Maps to' as relationship_id,
       	null as relationship_preference,
       	'evaluation finding' as source,
      	null as comment,
case when ii.concept_id IN (select concept_id from target_exclusion) then '0'
       else ii.concept_id END as target_concept_id,
case when ii.concept_id IN (select concept_id from target_exclusion) then null
	   else ii.concept_code END as target_concept_code,
case when ii.concept_id IN (select concept_id from target_exclusion) then null
	   else ii.concept_name END as target_concept_name,
case when ii.concept_id IN (select concept_id from target_exclusion) then null
	   else ii.concept_class_id END as target_concept_class_id,
case when ii.concept_id IN (select concept_id from target_exclusion) then null
	   else ii.standard_concept END as target_standard_concept,
case when ii.concept_id IN (select concept_id from target_exclusion) then null
	   else ii.invalid_reason END as target_invalid_reason,
case when ii.concept_id IN (select concept_id from target_exclusion) then null
	   else ii.domain_id END as target_domain_id,
case when ii.concept_id IN (select concept_id from target_exclusion) then null
	   else ii.vocabulary_id END as target_vocabulary_id,
     	'your_name' as mapper_id
from concept c
join concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id = 'Has interprets' and cr.invalid_reason IS NULL
join concept_relationship ccr on ccr.concept_id_1 = cr.concept_id_2 and ccr.relationship_id = 'Maps to' and cr.invalid_reason IS NULL
join concept ii on ii.concept_id = ccr.concept_id_2
join snomed_ancestor sa ON sa.descendant_concept_code::TEXT = c.concept_code
where c.vocabulary_id = 'SNOMED'
	and ii.standard_concept = 'S'
	and (c.invalid_reason is null or c.invalid_reason = 'D')
	and sa.ancestor_concept_code = '441742003' -- Evaluation finding
	and c.concept_code not in (select descendant_concept_code from source_exclusion)
	and c.concept_code not in (select source_code
	                           from snomed_mapped m
	                           where m.relationship_id = 'Maps to'
	                           and m.cr_invalid_reason is null)

union all

select distinct c.concept_name as source_name,
        c.concept_code as source_code,
        c.concept_class_id,
        c.invalid_reason,
        c.domain_id,
        c.vocabulary_id,
		null as invalid_reason,
     	null as mapping_tool,
        null as mapping_source,
		'1' as confidence,
        'Maps to value' as relationship_id,
       	null as relationship_preference,
       	'evaluation finding' as source,
       	null as comment,
		ii.concept_id as target_concept_id,
		ii.concept_code as target_concept_code,
		ii.concept_name as target_concept_name,
		ii.concept_class_id as target_concept_class_id,
		ii.standard_concept as target_standard_concept,
		ii.invalid_reason as target_invalid_reason,
		ii.domain_id as target_domain_id,
		ii.vocabulary_id as target_vocabulary_id,
     	'your_name' as mapper_id
from concept c
join concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id = 'Has interpretation' and cr.invalid_reason IS NULL
left join concept_relationship ccr on ccr.concept_id_1 = cr.concept_id_2 and ccr.relationship_id = 'Maps to' and cr.invalid_reason IS NULL
join concept ii on ii.concept_id = ccr.concept_id_2
join snomed_ancestor sa ON sa.descendant_concept_code::TEXT = c.concept_code
where c.vocabulary_id = 'SNOMED'
	and ii.standard_concept = 'S'
	and (c.invalid_reason is null or c.invalid_reason = 'D')
	and sa.ancestor_concept_code = '441742003' -- Evaluation finding
	and c.concept_code not in (select descendant_concept_code from source_exclusion)
	and c.concept_code not in (select source_code
	                           from snomed_mapped m
	                           where m.relationship_id = 'Maps to'
	                           and m.cr_invalid_reason is null)

order by source_code, relationship_id
;

--2.2 Personal history:
with source_inclusion as(
             select c.*
                    from concept c
                    join concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id = 'Has temporal context'
                                       and cr.concept_id_2 = 4132507 -- Past
                                       and cr.invalid_reason IS NULL
       			union
--Procedures with context 'Done'
       		  select c.*
                    from concept c
                    join concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id = 'Has proc context'
                                       and cr.concept_id_2 = 4295937 -- Done
                                       and cr.invalid_reason IS NULL
					),

source_exclusion as(
             select descendant_concept_code
             from snomed_ancestor
             where ancestor_concept_code in ('57177007') -- Family history with explicit context
					)

select distinct c.concept_name as source_name,
        c.concept_code as source_code,
        c.concept_class_id,
        c.invalid_reason,
        c.domain_id,
        c.vocabulary_id,
		null as invalid_reason,
     	null as mapping_tool,
        null as mapping_source,
		'1' as confidence,
        'Maps to' as relationship_id,
       	null as relationship_preference,
       	'History of' as source,
      	null as comment,
		ii.concept_id as target_concept_id,
		ii.concept_code as target_concept_code,
		ii.concept_name as target_concept_name,
		ii.concept_class_id as target_concept_class_id,
		ii.standard_concept as target_standard_concept,
		ii.invalid_reason as target_invalid_reason,
		ii.domain_id as target_domain_id,
		ii.vocabulary_id as target_vocabulary_id,
     	'your_name' as mapper_id
from concept c, concept ii
where c.vocabulary_id = 'SNOMED'
	and (c.concept_code, c.vocabulary_id) in (select concept_code, vocabulary_id from source_inclusion)
	and c.concept_code not in (select descendant_concept_code from source_exclusion)
	and ii.concept_id = '1340204' --History of event
	and (c.invalid_reason is null or c.invalid_reason = 'D')
	and c.concept_code not in (select source_code
	                           from snomed_mapped m
	                           where m.relationship_id = 'Maps to'
	                           and m.cr_invalid_reason is null)

union all

select distinct c.concept_name as source_name,
        c.concept_code as source_code,
        c.concept_class_id,
        c.invalid_reason,
        c.domain_id,
        c.vocabulary_id,
		null as invalid_reason,
     	null as mapping_tool,
        null as mapping_source,
		'1' as confidence,
        'Maps to value' as relationship_id,
       	null as relationship_preference,
       	'History of' as source,
       	null as comment,
		ii.concept_id as target_concept_id,
		ii.concept_code as target_concept_code,
		ii.concept_name as target_concept_name,
		ii.concept_class_id as target_concept_class_id,
		ii.standard_concept as target_standard_concept,
		ii.invalid_reason as target_invalid_reason,
		ii.domain_id as target_domain_id,
		ii.vocabulary_id as target_vocabulary_id,
     	'your_name' as mapper_id
from concept c
join concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id in ('Has asso proc', 'Has asso finding') and cr.invalid_reason IS NULL
left join concept_relationship ccr on ccr.concept_id_1 = cr.concept_id_2 and ccr.relationship_id = 'Maps to' and cr.invalid_reason IS NULL
join concept ii on ii.concept_id = ccr.concept_id_2
join snomed_ancestor sa ON sa.descendant_concept_code::TEXT = c.concept_code
where c.vocabulary_id = 'SNOMED'
	and (c.concept_code, c.vocabulary_id) in (select concept_code, vocabulary_id from source_inclusion)
	and c.concept_code not in (select descendant_concept_code from source_exclusion)
	and ii.standard_concept = 'S'
	and (c.invalid_reason is null or c.invalid_reason = 'D')
	and c.concept_code not in (select source_code
	                           from snomed_mapped m
	                           where m.relationship_id = 'Maps to'
	                           and m.cr_invalid_reason is null)

order by source_code, relationship_id
;

-- 2.3 Allergies
with source_inclusion as(
             select descendant_concept_code
             from snomed_ancestor
             where ancestor_concept_code in ('609328004') -- Allergic disposition
					),

drugs as(
             select descendant_concept_code
             from snomed_ancestor
             where ancestor_concept_code in ('416098002') -- Allergy to drug
					)

select distinct c.concept_name as source_name,
        c.concept_code as source_code,
        c.concept_class_id,
        c.invalid_reason,
        c.domain_id,
        c.vocabulary_id,
		null as invalid_reason,
     	null as mapping_tool,
        null as mapping_source,
		'1' as confidence,
        'Maps to' as relationship_id,
       	null as relationship_preference,
       	'Allergies' as source,
      	null as comment,
		ii.concept_id as target_concept_id,
		ii.concept_code as target_concept_code,
		ii.concept_name as target_concept_name,
		ii.concept_class_id as target_concept_class_id,
		ii.standard_concept as target_standard_concept,
		ii.invalid_reason as target_invalid_reason,
		ii.domain_id as target_domain_id,
		ii.vocabulary_id as target_vocabulary_id,
     	'your_name' as mapper_id
from concept c, concept ii
where c.vocabulary_id = 'SNOMED'
	and c.concept_code in (select descendant_concept_code from source_inclusion)
	and ii.concept_id = (case when c.concept_code in (select descendant_concept_code from drugs)
	       then 439224 -- Allergy to drug
	       else 43530807 end)
	and (c.invalid_reason is null or c.invalid_reason = 'D')
	and c.concept_code not in (select source_code
	                           from snomed_mapped m
	                           where m.relationship_id in ('Maps to', 'Maps to value')
	                           and m.cr_invalid_reason is null)

union all

select distinct c.concept_name as source_name,
        c.concept_code as source_code,
        c.concept_class_id,
        c.invalid_reason,
        c.domain_id,
        c.vocabulary_id,
		null as invalid_reason,
     	null as mapping_tool,
        null as mapping_source,
		'1' as confidence,
        'Maps to value' as relationship_id,
       	null as relationship_preference,
       	'Allergies' as source,
       	null as comment,
		ii.concept_id as target_concept_id,
		ii.concept_code as target_concept_code,
		ii.concept_name as target_concept_name,
		ii.concept_class_id as target_concept_class_id,
		ii.standard_concept as target_standard_concept,
		ii.invalid_reason as target_invalid_reason,
		ii.domain_id as target_domain_id,
		ii.vocabulary_id as target_vocabulary_id,
     	'your_name' as mapper_id
from concept c
left join concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id = 'Has causative agent' and cr.invalid_reason IS NULL
left join concept_relationship ccr on ccr.concept_id_1 = cr.concept_id_2 and ccr.relationship_id = 'Maps to' and cr.invalid_reason IS NULL
join concept ii on ii.concept_id = ccr.concept_id_2
join snomed_ancestor sa ON sa.descendant_concept_code::TEXT = c.concept_code
where c.vocabulary_id = 'SNOMED'
	and c.concept_code in (select descendant_concept_code from source_inclusion)
	and ii.standard_concept = 'S'
	and (c.invalid_reason is null or c.invalid_reason = 'D')
	and c.concept_code not in (select source_code
	                           from snomed_mapped m
 								where m.relationship_id in ('Maps to', 'Maps to value')
 								  and m.cr_invalid_reason is null)

order by source_code, relationship_id
;

-- 2.4 Drugs
select distinct c.concept_name as source_name,
        c.concept_code as source_code,
        c.concept_class_id,
        c.invalid_reason,
        c.domain_id,
        c.vocabulary_id,
		null as invalid_reason,
     	null as mapping_tool,
        null as mapping_source,
		'1' as confidence,
        'Maps to' as relationship_id,
       	null as relationship_preference,
       	'drugs' as source,
       	null as comment,
		cc.concept_id as target_concept_id,
		cc.concept_code as target_concept_code,
		cc.concept_name as target_concept_name,
		cc.concept_class_id as target_concept_class_id,
		cc.standard_concept as target_standard_concept,
		cc.invalid_reason as target_invalid_reason,
		cc.domain_id as target_domain_id,
		cc.vocabulary_id as target_vocabulary_id,
     	'your_name' as mapper_id
from sources.rxnconso rx
join sources.rxnconso s using(rxcui)
join concept c on c.concept_code = s.code and c.vocabulary_id = 'SNOMED'
join concept cc on cc.concept_code = rx.code and cc.vocabulary_id = 'RxNorm' and cc.standard_concept = 'S'
where rx.sab = 'RXNORM'
and s.sab  = 'SNOMEDCT_US'
and not exists (select 1
       			from concept_relationship cr
       			join concept i on i.concept_id = cr.concept_id_2 and i.domain_id = 'Drug'
       			where cr.concept_id_1 = c.concept_id
	          		and relationship_id = 'Maps to'
	                and cr.invalid_reason is null)
;

-- 2.5 Countries
select c.concept_name,
        c.concept_code,
        c.concept_class_id,
        c.invalid_reason ,
        c.domain_id ,
        c.vocabulary_id,
		null as cr_invalid_reason,
        null as mapping_tool,
        null as mapping_source,
        '1' as confidence,
        'Maps to' as relationship_id,
        'eq' as relationship_preference,
        'geography' as source,
        null as comment,
		cc.concept_id,
		cc.concept_code,
       	cc.concept_name,
       	cc.concept_class_id as target_concept_class_id,
       	cc.standard_concept as target_standard_concept,
       	cc.invalid_reason as target_invalid_reason,
       	cc.domain_id as target_domain_id,
       	cc.vocabulary_id as target_vocabulary_id,
       	'your_name' as mapper_id
from concept c
join concept cc using (concept_name, domain_id, standard_concept)
where c.domain_id = 'Geography'
and c.standard_concept = 'S'
and c.vocabulary_id != cc.vocabulary_id
and c.vocabulary_id = 'SNOMED'
and cc.concept_class_id = '2nd level';

--2.6 Scores and scales
select c.concept_name,
        c.concept_code,
        c.concept_class_id,
        c.invalid_reason,
        c.domain_id,
        c.vocabulary_id,
		null as cr_invalid_reason,
        null as mapping_tool,
        null as mapping_source,
        '1' as confidence,
        'Maps to' as relationship_id,
        'eq' as relationship_preference,
        'score/scale dedup' as source,
        null as comment,
        cc.concept_id,
		cc.concept_code,
       	cc.concept_name,
       	cc.concept_class_id as target_concept_class_id,
       	cc.standard_concept as target_standard_concept,
       	cc.invalid_reason as target_invalid_reason,
       	cc.domain_id as target_domain_id,
       	cc.vocabulary_id as target_vocabulary_id,
       	'MK' as mapper_id
from concept c
left join concept cc on regexp_replace(c.concept_name, ' score', '') = regexp_replace(cc.concept_name, ' scale', '')
where c.vocabulary_id = 'SNOMED'
and cc.vocabulary_id = 'SNOMED'
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.domain_id = 'Measurement'
and c.concept_class_id = 'Observable Entity'
and cc.concept_class_id = 'Staging / Scales'
;

-- 3. Extract source concepts for manual mapping
select c.concept_name,
        c.concept_code,
        c.concept_class_id,
        c.invalid_reason ,
        c.domain_id ,
        c.vocabulary_id,
		null as cr_invalid_reason,
        null as mapping_tool,
        null as mapping_source,
        '1' as confidence,
        'Maps to' as relationship_id,
        '' as relationship_preference,
        null as source
from concept c
where vocabulary_id = 'SNOMED'
and domain_id in ('Race', 'Gender', 'Unit', 'Provider')
	and (c.invalid_reason is null or c.invalid_reason = 'D')
	and c.concept_code not in (select source_code
	                           from snomed_mapped m
	                           where m.relationship_id = 'Maps to'
	                           and m.cr_invalid_reason is null)
and not exists (select 1
       			from concept_relationship cr
       			--join concept i on i.concept_id = cr.concept_id_2 and i.domain_id = 'Drug'
       			where cr.concept_id_1 = c.concept_id
	          		and relationship_id = 'Maps to'
	                and cr.invalid_reason is null);


--4. Draft script to explore and map duplicates within SNOMED:
with uk as (
select concept_id_1, 'UK' as flag from concept_relationship
where relationship_id = 'Has Module'
and concept_id_2 = 44812389
),
us as (
select concept_id_1, 'US' as flag from concept_relationship
where relationship_id = 'Has Module'
and concept_id_2 in (3169365, 764868)
),
int as (
select concept_id_1, 'INT' as flag from concept_relationship
where relationship_id = 'Has Module'
and concept_id_2 in (40642539, 40642533)
),
modules as (
select * from uk
union
select * from us
union
select * from int
)

select c.concept_name,
        c.concept_code,
        m.flag as source_module,
        c.concept_class_id,
        c.invalid_reason ,
        c.domain_id ,
        c.vocabulary_id,
		null as cr_invalid_reason,
        null as mapping_tool,
        null as mapping_source,
        '1' as confidence,
        'Maps to' as relationship_id,
        'eq' as relationship_preference,
        'dedup' as source,
        '' as comment,
		cc.concept_id,
		cc.concept_code,
		m1.flag as target_module,
       	cc.concept_name,
       	cc.concept_class_id as target_concept_class_id,
       	cc.standard_concept as target_standard_concept,
       	cc.invalid_reason as target_invalid_reason,
       	cc.domain_id as target_domain_id,
       	cc.vocabulary_id as target_vocabulary_id,
       	'your_name' as mapper_id
from concept c, concept cc, modules m, modules m1
where lower(c.concept_name) = lower(cc.concept_name)
and c.concept_id != cc.concept_id
and c.domain_id = cc.domain_id
and c.vocabulary_id = 'SNOMED'
and cc.vocabulary_id = 'SNOMED'
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.concept_id = m.concept_id_1
and m.flag != 'INT' -- we map local SNOMEDs to the international module
and cc.concept_id = m1.concept_id_1
and c.concept_class_id not in ('Organism', 'Disposition', 'Substance', 'Qualifier Value', 'Physical Object', 'Morph Abnormality')
and cc.concept_class_id not in ('Organism', 'Disposition', 'Substance', 'Qualifier Value', 'Physical Object', 'Morph Abnormality')
order by c.domain_id, c.concept_name, c.concept_class_id;

-- 5. Script to populate concept_mapped table
select distinct null as concept_name,
       null as domain_id,
       source_vocabulary_id,
       null as concept_class_id,
       null as standard_concept,
       source_code,
       null as valid_start_date,
       null as valid_end_date,
       'X' as invalid_reason
from snomed_mapped m
where source_code in (
       select concept_code
       from concept
       where standard_concept = 'S'
       and vocabulary_id = 'SNOMED'
	   )
and m.relationship_id in ('Maps to', 'Maps to value')
and m.cr_invalid_reason is null
and m.target_concept_code is not null
and m.target_concept_id != 0;

--6. Check for personal history concepts without value:
with without_values as (
select c.*
from concept c
join concept_relationship cr on cr.concept_id_1 = c.concept_id
where cr.relationship_id = 'Maps to'
and cr.invalid_reason is null
--and cr.concept_id_2 = 1340204 -- History of event
and c.concept_id not in (
       select concept_id_1
       from concept_relationship
       where relationship_id = 'Maps to value'
       and invalid_reason is null
	   )
and c.vocabulary_id = 'SNOMED')

select distinct c.concept_name,
        c.concept_code,
        c.concept_class_id,
        c.invalid_reason,
        c.domain_id ,
        c.vocabulary_id,
		null as cr_invalid_reason,
        null as mapping_tool,
        null as mapping_source,
        '1' as confidence,
        'Maps to value' as relationship_id,
        'eq' as relationship_preference,
        'lost values' as source,
        '' as comment,
        cc.concept_id,
		cc.concept_code,
       	cc.concept_name,
       	cc.concept_class_id as target_concept_class_id,
       	cc.standard_concept as target_standard_concept,
       	cc.invalid_reason as target_invalid_reason,
       	cc.domain_id as target_domain_id,
       	cc.vocabulary_id as target_vocabulary_id,
       	'MK' as mapper_id

from concept_relationship cr
join concept_relationship cr1 on cr.concept_id_1 = cr1.concept_id_2
                                        and cr1.relationship_id in ('Maps to',
                                                               'Concept replaced by',
                                                               'Concept same_as to',
                                                               'Concept alt_to to',
                                                               'Concept was_a to')
join concept c on cr1.concept_id_1 = c.concept_id and c.vocabulary_id = 'SNOMED'
join concept cc on cc.concept_id = cr.concept_id_2
where cr.relationship_id = 'Maps to value'
	and cr.invalid_reason is null
	and c.concept_id in (
	   select concept_id
	   from without_values
			  );

-- 7. Check for concepts that have 'Maps to value' relationships without 'Maps to' to Observation/Measurement target:
select *
from dev_snomed.concept_relationship a
join dev_snomed.concept aa
on aa.concept_id=a.concept_id_1
where exists(
       select 1
       from dev_snomed.concept_relationship c
       where a.concept_id_1 = c.concept_id_1
       and (c.relationship_id = 'Maps to value')
       and c.invalid_reason is null
            )
and not exists(
       select 1
       from dev_snomed.concept_relationship b
       left join dev_snomed.concept c
       on c.concept_id = b.concept_id_2
       where a.concept_id_1 = b.concept_id_1
       and c.domain_id in ('Observation', 'Measurement')
       and (b.relationship_id = 'Maps to')
       and b.invalid_reason is null
              )
and aa.vocabulary_id IN (:your_vocabs)
;