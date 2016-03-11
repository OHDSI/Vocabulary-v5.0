update concept set concept_name = 'OMOP Standardized Vocabularies' where concept_id = 44819096;

-- Add new Unit for building Drug Strength
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (9693, 'index of reactivity', 'Unit', 'UCUM', 'Unit', 'S', '{ir}', '1-Dec-2014', '31-Dec-99', null);


select * from concept_class where concept_class_id like 'Branded%';
select * from concept where concept_id=44819004;

-- add boxed drug concept_class_id values
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (200, 'Quantified Branded Drug Box', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Quant Branded Box', 'Quantified Clinical Drug Box', (select concept_id from concept where concept_name = 'Quantified Branded Drug Box'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Quantified Clinical Drug Box', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Quant Clinical Box', 'Quantified Clinical Drug Box', (select concept_id from concept where concept_name = 'Quantified Clinical Drug Box'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Branded Drug Box', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Branded Drug Box', 'Branded Drug Box', (select concept_id from concept where concept_name = 'Branded Drug Box'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Clinical Drug Box', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Clinical Drug Box', 'Clinical Drug Box', (select concept_id from concept where concept_name = 'Clinical Drug Box'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Disease Analyzer France (IMS)', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id)
values ('DA_France', 'Disease Analyzer France', 'IMS proprietary', '20151215', (select concept_id from concept where concept_name = 'Disease Analyzer France (IMS)'));

-- Add relationships for Brand Name so they don't short circuit RxNorm ancestry through Brand Name
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has brand name (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has brand name', 'Has brand name (OMOP)', 1, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has brand name (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Brand name of (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Brand name of', 'Brand name of (OMOP)', 1, 0, 'Has brand name', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Brand name of (OMOP)'));
update relationship set reverse_relationship_id='Brand name of' where relationship_id='Has brand name';

-- Add relationship to boxed drugs
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Is available in a prepackaged box (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Available as box', 'Is available in a prepackaged box (OMOP)', 1, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Is available in a prepackaged box (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Prepackaged box of (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Box of', 'Prepackaged box of (OMOP)', 1, 0, 'Available as box', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Prepackaged box of (OMOP)'));
update relationship set reverse_relationship_id='Box of' where relationship_id='Available as box';

-- Add relationship between Ingredients
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Is standard ingredient of ingredient (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Is standard ing of', 'Is standard ingredient of ingredient (OMOP)', 0, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Is standard ingredient of ingredient (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has standard ingredient (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has standard ing', 'Has standard ingredient (OMOP)', 0, 0, 'Is standard ing of', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has standard ingredient (OMOP)'));
update relationship set reverse_relationship_id='Has standard ing' where relationship_id='Is standard ing of';

-- Add relationship between Brand Names
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Is standard Brand Name of (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Is standard brand of', 'Is standard Brand Name of (OMOP)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Is standard Brand Name of (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has standard Brand Name (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has standard brand', 'Has standard Brand Name (OMOP)', 0, 0, 'Is standard ing of', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has standard Brand Name (OMOP)'));
update relationship set reverse_relationship_id='Has standard brand' where relationship_id='Is standard brand of';

-- Add relationship between Dose Forms
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Is standard Dose Form of (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Is standard form of', 'Is standard Dose Form of (OMOP)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Is standard Dose Form of (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has standard Dose Form (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has standard form', 'Has standard Dose Form (OMOP)', 0, 0, 'Is standard form of', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has standard Dose Form (OMOP)'));
update relationship set reverse_relationship_id='Has standard form' where relationship_id='Is standard form of';


-- Remove SPL duplicates and create replacement relationships
insert into concept_relationship
select distinct
  e.concept_id as concept_id_1,
  d.concept_id as concept_id_2,
  'Concept replaced by' as relationship_id,
  '25-Jan-2016' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from concept e
join concept d on e.concept_code = upper(d.concept_code) and d.vocabulary_id = 'SPL' and e.concept_id != d.concept_id
where e.vocabulary_id = 'SPL'
;

insert into concept_relationship
select distinct
  d.concept_id as concept_id_1,
  e.concept_id as concept_id_2,
  'Concept replaces' as relationship_id,
  '25-Jan-2016' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from concept e
join concept d on e.concept_code = upper(d.concept_code) and d.vocabulary_id = 'SPL' and e.concept_id != d.concept_id
where e.vocabulary_id = 'SPL'
;

update concept c set 
  concept_name = 'Duplicate of SPL Concept, do not use, use replacement from CONCEPT_RELATIONSHIP table instead',
  concept_code = concept_id,
  valid_end_date='25-Jan-2016',
  invalid_reason = 'U'
where c.vocabulary_id='SPL'
and exists (
  select 1 from concept m
  where c.concept_code = upper(m.concept_code)
  and m.vocabulary_id='SPL'
  and c.concept_id != m.concept_id
)
;

-- deprecate all relationships that are not replacement relationships from these
update concept_relationship r set
  r.valid_end_date = (select case when c.valid_end_date-1 < r.valid_end_date then c.valid_end_date-1 else r.valid_end_date end from concept c where c.concept_id = r.concept_id_1),
  r.invalid_reason = 'D'
where exists (
  select 1 from concept c
  where r.concept_id_1 = c.concept_id
  and c.concept_name like '%do not use%' and c.vocabulary_id = 'SPL'
)
and r.relationship_id not like '%replace%'
;


update concept_relationship r set
  r.valid_end_date = (select case when c.valid_end_date-1 < r.valid_end_date then c.valid_end_date-1 else r.valid_end_date end from concept c where c.concept_id = r.concept_id_2),
  r.invalid_reason = 'D'
where exists (
  select 1 from concept c
  where r.concept_id_2 = c.concept_id
  and c.concept_name like '%do not use%' and c.vocabulary_id = 'SPL'
)
and r.relationship_id not like '%replace%'
;

insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values(9689, 45891020, 'Concept replaces', '25-Jan-2016', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values(45891020, 9689, 'Concept replaced by', '25-Jan-2016', '31-Dec-2099', null);
update concept set standard_concept = null, invalid_reason = 'U' where concept_id=45891020;
update concept c set 
  concept_name = 'Duplicate of UCUM Concept, do not use, use replacement from CONCEPT_RELATIONSHIP table instead',
  concept_code = concept_id,
  valid_end_date='24-Jan-2016',
  invalid_reason = 'U'
where c.concept_id in (45891020, 8999, 9549, 9315)
;
update concept_relationship set valid_end_date = '24-Jan-2016', invalid_reason = 'D' where concept_id_1 = 45891020 and relationship_id not like '%replace%';
update concept_relationship set valid_end_date = '24-Jan-2016', invalid_reason = 'D' where concept_id_2 = 45891020 and relationship_id not like '%replace%';

-- fix wrong century in recently added unit
update concept set valid_end_date = '31-Dec-2099' where concept_id = 9693;

-- Make fixes to asymmetric relationships
-- Remove 'SPL to RxNorm' (Ingredient)
delete from devv5.concept_relationship where rowid in (
    select r.rowid from devv5.concept c, devv5.concept_relationship r
    where c.concept_id=r.concept_id_1
    and R.RELATIONSHIP_ID='RxNorm - SPL'
    and C.CONCEPT_CLASS_ID='Ingredient'
);

-- Fix wrong reverse_relationship of 'Has standard brand'
update relationship set reverse_relationship_id='Is standard brand of' where relationship_id='Has standard brand';
update concept_relationship r
  set relationship_id = 'Is standard brand of'
where exists (
  select 1 from concept_relationship r2
  where relationship_id='Has standard brand'
)
and r.relationship_id = 'Is standard ing of'
;
insert into concept_relationship
select concept_id_2 as concept_id_1, concept_id_1 as concept_id_2, 
  'Is standard ing of' as relationship_id, valid_start_date, valid_end_date, invalid_reason
from concept_relationship where relationship_id='Has standard ing';

delete from concept_relationship where rowid in (
  select r.rowid from concept_relationship r
  join concept c1 on c1.concept_id=r.concept_id_1
  join concept c2 on c2.concept_id=r.concept_id_2
  where c1.concept_class_id='Ingredient' and c2.concept_class_id='Ingredient' and r.relationship_id='Is standard brand of'
);

-- Fix remaining 'Has Quantified form of' for NDC
delete from concept_relationship where rowid in (
  select r.rowid from concept_relationship r
  join concept c1 on c1.concept_id=r.concept_id_1
  join concept c2 on c2.concept_id=r.concept_id_2
  where c2.concept_class_id in ('11-digit NDC', '9-digit NDC') and r.relationship_id='Has quantified form'
);

-- Fix funny relationship between domains and concept types
delete from concept_relationship where rowid in (
  select r.rowid from concept_relationship r
  join concept c1 on c1.concept_id=r.concept_id_1
  join concept c2 on c2.concept_id=r.concept_id_2
  where c1.concept_class_id in ('Domain') and r.relationship_id='SNOMED meas - HCPCS'
);

-- Fix asymmetrical deprecation in 'Concept replaced by'
merge into concept_relationship r
using (
    select r_int.concept_id_1, r_int.concept_id_2, r_int.invalid_reason, r_int.valid_end_date, rel_int.reverse_relationship_id from concept_relationship r_int, relationship rel_int 
    where r_int.relationship_id in (
        'ATC - RxNorm',
        'ATC - RxNorm name',
        'Concept replaced by',
        'Has Answer',
        'ATC - SNOMED eq',
        'VAProd - RxNorm eq',
        'NDFRT - SNOMED eq',
        'NDFRT - RxNorm eq',
        'Concept poss_eq to',
        'NDFRT - RxNorm name',
        'OPCS4 - SNOMED',
        'Concept same_as to',
        'Maps to',
        'Maps to value'
    )
    and r_int.relationship_id=rel_int.relationship_id
) i on (
    r.concept_id_1=i.concept_id_2 
    and r.concept_id_2=i.concept_id_1 
    and r.relationship_id=i.reverse_relationship_id
    and (nvl(r.invalid_reason,'X')<>nvl(i.invalid_reason,'X') or r.valid_end_date<>i.valid_end_date)
)
when matched then update
    set r.invalid_reason=i.invalid_reason,
        r.valid_end_date=i.valid_end_date
;

-- Remove 'Original maps to'
delete from concept_relationship where relationship_id='Original maps to';
delete from concept_relationship where relationship_id='Original mapped from';
update relationship set reverse_relationship_id='Is a' where relationship_id in ('Original maps to', 'Original mapped from');
delete from relationship where relationship_id='Original maps to';
delete from relationship where relationship_id='Original mapped from';

-- Fix upgraded ATC
update concept set invalid_reason = 'D' where vocabulary_id='ATC' and invalid_reason = 'U';

-- Remove GPI duplicates and create replacement relationships
insert into concept_relationship
with d as (
  select distinct
    first_value(concept_id) over (partition by concept_code order by length(concept_name) desc) as concept_id,
    concept_code
  from concept c
  where c.vocabulary_id='GPI'
  and concept_code in (
    select concept_code from concept where vocabulary_id = 'GPI'
    group by concept_code having count(8)>1
  )
)
select distinct
  d_in.concept_id as concept_id_1,
  d_out.concept_id as concept_id_2,
  'Concept replaces' as relationship_id,
  '25-Jan-2016' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from d d_in 
join concept d_out on d_out.concept_code=d_in.concept_code and d_out.concept_id!=d_in.concept_id and d_out.vocabulary_id='GPI'
;

insert into concept_relationship
with d as (
  select distinct
    first_value(concept_id) over (partition by concept_code order by length(concept_name) desc) as concept_id,
    concept_code
  from concept c
  where c.vocabulary_id='GPI'
  and concept_code in (
    select concept_code from concept where vocabulary_id = 'GPI'
    group by concept_code having count(8)>1
  )
)
select distinct
  d_out.concept_id as concept_id_1,
  d_in.concept_id as concept_id_2,
  'Concept replaced by' as relationship_id,
  '25-Jan-2016' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from d d_in 
join concept d_out on d_out.concept_code=d_in.concept_code and d_out.concept_id!=d_in.concept_id and d_out.vocabulary_id='GPI'
;

update concept set 
  concept_name = 'Duplicate of GPI Concept, do not use, use replacement from CONCEPT_RELATIONSHIP table instead',
  concept_code = concept_id,
  valid_end_date='25-Jan-2016',
  invalid_reason = 'U'
where rowid in (
  select c.rowid from concept c 
  join (
    select distinct
      first_value(concept_id) over (partition by concept_code order by length(concept_name) desc) as concept_id,
      concept_code
    from concept c
    where c.vocabulary_id='GPI'
    and concept_code in (
      select concept_code from concept where vocabulary_id = 'GPI'
      group by concept_code having count(8)>1
    )
  ) d on d.concept_code=c.concept_code and d.concept_id!=c.concept_id
  where vocabulary_id='GPI' 
);


-- deprecate all relationships that are not replacement relationships from these
update concept_relationship r set
  r.valid_end_date = (select case when c.valid_end_date-1 < r.valid_end_date then c.valid_end_date-1 else r.valid_end_date end from concept c where c.concept_id = r.concept_id_1),
  r.invalid_reason = 'D'
where exists (
  select 1 from concept c
  where r.concept_id_1 = c.concept_id
  and c.concept_name like '%do not use%' and c.vocabulary_id = 'GPI'
)
and r.relationship_id not like '%replace%'
;


update concept_relationship r set
  r.valid_end_date = (select case when c.valid_end_date-1 < r.valid_end_date then c.valid_end_date-1 else r.valid_end_date end from concept c where c.concept_id = r.concept_id_2),
  r.invalid_reason = 'D'
where exists (
  select 1 from concept c
  where r.concept_id_2 = c.concept_id
  and c.concept_name like '%do not use%' and c.vocabulary_id = 'GPI'
)
and r.relationship_id not like '%replace%'
;

-- Change mapping reported by George
update concept_relationship set 
  valid_end_date='3-Feb-2016',
  invalid_reason='D'
where concept_id_1=44830172 and concept_id_2=198185;

insert into concept_relationship
select 
  44830172 as concept_id_1,
  46271022 as concept_id_2,
  'Maps to' as relationship_id,
  '4-Feb-2016' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from dual
;
  
insert into concept_relationship
select 
  46271022 as concept_id_1,
  44830172 as concept_id_2,
  'Mapped from' as relationship_id,
  '4-Feb-2016' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from dual
;

-- Remove SNOMED replaced by relationship
delete from concept_relationship where rowid in (
    select r1.rowid from concept_relationship r1, concept_relationship r2
    where
    r1.invalid_reason is null and r2.invalid_reason is null
    and r1.relationship_id='SNOMED replaced by'
    and r2.relationship_id='Concept replaced by'
    and r1.concept_id_1=r2.concept_id_1 and r1.concept_id_2=r2.concept_id_2
);

delete from concept_relationship where rowid in (
    select r1.rowid from concept_relationship r1, concept_relationship r2
    where
    r1.invalid_reason is not null 
    and r1.relationship_id='Concept replaced by'
    and r2.relationship_id='SNOMED replaced by'
    and r1.concept_id_1=r2.concept_id_1 and r1.concept_id_2=r2.concept_id_2
); 

update concept_relationship set relationship_id='Concept replaced by' 
where relationship_id='SNOMED replaced by' and invalid_reason is null
;

update concept set
  valid_end_date='8-Feb-2016',
  invalid_reason='D'
where concept_id=44818948;

delete from concept_relationship where rowid in (
    select r1.rowid from concept_relationship r1, concept_relationship r2
    where
    r1.invalid_reason is null and r2.invalid_reason is null
    and r1.relationship_id='SNOMED replaces'
    and r2.relationship_id='Concept replaces'
    and r1.concept_id_1=r2.concept_id_1 and r1.concept_id_2=r2.concept_id_2
);

delete from concept_relationship where rowid in (
    select r1.rowid from concept_relationship r1, concept_relationship r2
    where
    r1.invalid_reason is not null 
    and r1.relationship_id='Concept replaces'
    and r2.relationship_id='SNOMED replaces'
    and r1.concept_id_1=r2.concept_id_1 and r1.concept_id_2=r2.concept_id_2
);

update concept_relationship set relationship_id='Concept replaced by' 
where relationship_id='SNOMED replaces' and invalid_reason is null
;

update concept set
  valid_end_date='8-Feb-2016',
  invalid_reason='D'
where concept_id=44818949;

update relationship set reverse_relationship_id='Is a' where relationship_id='SNOMED replaces';
update relationship set reverse_relationship_id='Is a' where relationship_id='SNOMED replaced by';
delete from relationship where relationship_id='SNOMED replaces';
delete from relationship where relationship_id='SNOMED replaced by';

-- Remove foul relationships between drug class and RxNorm Brand Name
update concept_relationship set valid_end_date='11-Feb-2016', invalid_reason='D' where rowid in (
  select r.rowid 
  from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id and r.invalid_reason is null
  join concept c2 on c2.concept_id=r.concept_id_2
  where c1.vocabulary_id = 'ETC' and c2.concept_class_id='Brand Name'
);

update concept_relationship set valid_end_date='11-Feb-2016', invalid_reason='D' where rowid in (
  select r.rowid 
  from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id and r.invalid_reason is null
  join concept c2 on c2.concept_id=r.concept_id_2
  where c1.concept_class_id='Brand Name' and c2.vocabulary_id = 'ETC'
);

-- Remove inferred class (should remove from relationship later)
update concept_relationship set valid_end_date='11-Feb-2016', invalid_reason='D' where relationship_id='Inferred class of';
update concept_relationship set valid_end_date='11-Feb-2016', invalid_reason='D' where relationship_id='Has inferred class';

-- Remove relationship by name (should remove from relationship later)
update concept_relationship set valid_end_date='11-Feb-2016', invalid_reason='D' where relationship_id='RxNorm - ETC name';
update concept_relationship set valid_end_date='11-Feb-2016', invalid_reason='D' where relationship_id='ETC - RxNorm name';

-- Set hierarchical relationships to 1 even if we don't want to count them. That is already done by the fact that the concepts are standard_concept=null
update relationship set is_hierarchical=1 
where relationship_id in ('Therap class of', 'Chem to Prep eq', 'NDFRT - RxNorm eq', 'NDFRT - RxNorm name', 'ETC - RxNorm name', 'Class - Multilex ing', 'Pharma prep in', 'Is standard ing of');

-- Fix wrong replacement deprecations for Concept replaces/replaced by relationships.
update concept_relationship set valid_end_date='31-Dec-2099'
where valid_end_date<'31-Dec-2099'
  and invalid_reason is null
;

--remove double spaces, carriage return, newline, vertical tab and form feed
UPDATE concept
SET concept_name = REGEXP_REPLACE (concept_name, '[[:space:]]+', ' ')
WHERE REGEXP_LIKE (concept_name, '[[:space:]]+[[:space:]]+');

-- Put standard concept to null if invalid
UPDATE concept c SET
c.standard_concept = NULL
WHERE c.valid_end_date != TO_DATE ('20991231', 'YYYYMMDD')
AND c.standard_concept IS NOT NULL;

-- de-standardize SNOMED gender concepts
update concept set standard_concept=null where vocabulary_id='SNOMED' and domain_id='Gender';

-- remove replacement links between vocabularies
-- SNOMED to UCUM
update concept_relationship set concept_id_2=9439 where concept_id_1=45891020 and concept_id_2=45756994;
update concept_relationship set relationship_id='Mapped from'
where rowid in (
  select r.rowid
  from concept_relationship r 
  join concept c1 on r.concept_id_1=c1.concept_id 
  join concept c2 on c2.concept_id=r.concept_id_2
  where c1.vocabulary_id='UCUM' and c2.vocabulary_id='SNOMED' and r.relationship_id='Concept replaced by' and r.invalid_reason is null
);

update concept_relationship set concept_id_1=9439 where concept_id_2=45891020 and concept_id_1=45756994;
update concept_relationship set relationship_id='Maps to'
where rowid in (
  select r.rowid
  from concept_relationship r 
  join concept c1 on r.concept_id_1=c1.concept_id 
  join concept c2 on c2.concept_id=r.concept_id_2
  where c1.vocabulary_id='SNOMED' and c2.vocabulary_id='UCUM' and r.invalid_reason is null and r.relationship_id='Concept replaced by' 
);

-- Dead ICD10 codes which are really ICD10CM codes. Delete all concpets, relationships and synonyms
update concept set concept_name='DELETE'
where concept_id in ( 
  select concept_id_1
  from concept_relationship r 
  join concept c1 on r.concept_id_1=c1.concept_id 
  join concept c2 on c2.concept_id=r.concept_id_2
  where c1.vocabulary_id='ICD10' and c2.vocabulary_id='ICD10CM' and r.invalid_reason is null and r.relationship_id='Concept replaced by' 
union
  select concept_id_2
  from concept_relationship r 
  join concept c1 on r.concept_id_1=c1.concept_id 
  join concept c2 on c2.concept_id=r.concept_id_2
  where c1.vocabulary_id='ICD10CM' and c2.vocabulary_id='ICD10' and r.invalid_reason is null and r.relationship_id='Concept replaces' 
);

delete from concept_relationship 
where rowid in (
  select r.rowid
  from concept_relationship r 
  join concept c1 on r.concept_id_1=c1.concept_id 
  join concept c2 on c2.concept_id=r.concept_id_2
  where c1.vocabulary_id='ICD10' and c2.vocabulary_id='ICD10CM' and r.invalid_reason is null and r.relationship_id='Concept replaced by' 
);

delete from concept_relationship 
where rowid in (
  select r.rowid
  from concept_relationship r 
  join concept c1 on r.concept_id_1=c1.concept_id 
  join concept c2 on c2.concept_id=r.concept_id_2
  where c1.vocabulary_id='ICD10CM' and c2.vocabulary_id='ICD10' and r.invalid_reason is null and r.relationship_id='Concept replaces' 
);

select c1.concept_id as c1_id, c1.concept_name as c1_name, c1.vocabulary_id as c1_vocab, c1.domain_id as c1_domain, c1.concept_class_id as c1_class, c1.invalid_reason as c1_ir,
  r.relationship_id as rel, r.invalid_reason as r_ir, 
  c2.concept_id as c2_id, c2.concept_name as c2_name, c2.vocabulary_id as c2_vocab, c2.domain_id as c2_domain, c2.concept_class_id as c2_class, c2.invalid_reason as c2_ir
from concept c1
join concept_relationship r on r.concept_id_1=c1.concept_id 
join concept c2 on c2.concept_id=r.concept_id_2
where c1.concept_name='DELETE';

delete from concept_relationship where concept_id_1 in (select concept_id from concept where concept_name='DELETE');
delete from concept_relationship where concept_id_2 in (select concept_id from concept where concept_name='DELETE');
delete from concept_synonym where concept_id in (select concept_id from concept where concept_name='DELETE');
delete from concept where concept_name='DELETE';

-- Remove cyclical UCUM replacement
update concept_relationship set relationship_id='Concept replaces' where concept_id_2=9439 and concept_id_1=45891020;
	

-- All sorts of fixes to get the replacement and mapping relationships right
--rename 'RxNorm replaced by' to 'Concept replaced by'
update concept_relationship r set relationship_id='Concept replaced by' where r.relationship_id='RxNorm replaced by'
and not exists (
select 1 from concept_relationship r_int where
r_int.concept_id_1=r.concept_id_1
and r_int.concept_id_2=r.concept_id_2
and r_int.relationship_id='Concept replaced by'
);
--same for reverse
update concept_relationship r set relationship_id='Concept replaces' where r.relationship_id='RxNorm replaces'
and not exists (
select 1 from concept_relationship r_int where
r_int.concept_id_1=r.concept_id_1
and r_int.concept_id_2=r.concept_id_2
and r_int.relationship_id='Concept replaces'
);

--delete all others 'RxNorm replaced by' (right mapping are already exists)
delete from concept_relationship r where r.relationship_id in ('RxNorm replaced by', 'RxNorm replaces');
commit;

--some manual fixes
update concept_relationship set relationship_id='Concept replaces' where relationship_id='Concept replaced by' and concept_id_1=45956995 and concept_id_2=40562617;
update concept_relationship set relationship_id='Concept replaces' where relationship_id='Concept replaced by' and concept_id_1=45957138 and concept_id_2=40517420;
update concept_relationship set relationship_id='Concept replaces' where relationship_id='Concept replaced by' and concept_id_1=45957143 and concept_id_2=40517436;
update concept_relationship set relationship_id='Concept replaces' where relationship_id='Concept replaced by' and concept_id_1=45972381 and concept_id_2=40526632;
update concept_relationship set relationship_id='Concept replaces' where relationship_id='Concept replaced by' and concept_id_1=45958139 and concept_id_2=4247854;
update concept set invalid_reason='D', valid_end_date=trunc(sysdate), standard_concept = NULL where concept_id=45958139;
delete from concept_relationship where relationship_id='Concept replaces' and concept_id_1=4029184 and concept_id_2=40623421;
delete from concept_relationship where relationship_id='Concept replaced by' and concept_id_1=40623421 and concept_id_2=4029184;

delete from concept_relationship where relationship_id='Concept same_as to' and concept_id_1=132617 and concept_id_2=4170132;
delete from concept_relationship where relationship_id='Concept same_as from' and concept_id_1=4170132 and concept_id_2=132617;
delete from concept_relationship where relationship_id='Concept same_as to' and concept_id_1=373198 and concept_id_2=40621771;
delete from concept_relationship where relationship_id='Concept same_as from' and concept_id_1=373198 and concept_id_2=40621771;
delete from concept_relationship where relationship_id='Concept same_as to' and concept_id_1=40621771 and concept_id_2=373198;
delete from concept_relationship where relationship_id='Concept same_as from' and concept_id_1=40621771 and concept_id_2=373198;

update concept set invalid_reason='U', valid_end_date=trunc(sysdate) where concept_id=4006143;
update concept_relationship set relationship_id='Concept replaces' where relationship_id='Concept replaced by' and concept_id_1=4006143 and concept_id_2=45960216;
update concept_relationship set relationship_id='Concept replaces' where relationship_id='Concept replaced by' and concept_id_1=45971710 and concept_id_2=4006143;

--rename wrong 'Concept replaced by' to true 'Concept replaces'
update concept_relationship r set r.relationship_id='Concept replaces' where
r.relationship_id='Concept replaced by'
and r.invalid_reason is null
and exists (
  select 1 from concept c where r.concept_id_2=c.concept_id
  and c.invalid_reason in ('U', 'D')
)
and exists (
  select 1 from concept c where r.concept_id_1=c.concept_id
  and (c.invalid_reason is null or c.invalid_reason='D')
)
and exists (
  select 1 from concept_relationship r_int where
  r_int.relationship_id='Concept replaced by'
  and r_int.invalid_reason is null
  and r_int.concept_id_1= r.concept_id_2
  and r_int.concept_id_2= r.concept_id_1
);

--delete duplicate mappings (one concept has multiply target concepts)
DELETE FROM concept_relationship
WHERE (concept_id_1, relationship_id) IN
( SELECT c1.concept_id, r.relationship_id
FROM concept c1, concept c2, concept_relationship r
WHERE r.relationship_id IN ('Concept replaced by',
'Concept same_as to',
'Concept alt_to to',
'Concept poss_eq to',
'Concept was_a to')
AND r.invalid_reason IS NULL
AND c1.concept_id = r.concept_id_1
AND c2.concept_id = r.concept_id_2
AND c1.vocabulary_id = c2.vocabulary_id
GROUP BY c1.concept_id, r.relationship_id
HAVING COUNT (DISTINCT c2.concept_id) > 1)
AND invalid_reason IS NULL;

--same for reverse
DELETE FROM concept_relationship
WHERE (concept_id_2, relationship_id) IN ( 
  SELECT c2.concept_id, r.relationship_id
  FROM concept c1, concept c2, concept_relationship r
  WHERE r.relationship_id IN (
    'Concept replaces',
    'Concept same_as from',
    'Concept alt_to from',
    'Concept poss_eq from',
    'Concept was_a from'
  )
  AND r.invalid_reason IS NULL
  AND c1.concept_id = r.concept_id_1
  AND c2.concept_id = r.concept_id_2
  AND c1.vocabulary_id = c2.vocabulary_id
  GROUP BY c2.concept_id, r.relationship_id
  HAVING COUNT (DISTINCT c1.concept_id) > 1)
  AND invalid_reason IS NULL;
commit;

--deprecate concepts if we have no active replacement record in the concept_relationship
UPDATE concept c SET
c.valid_end_date = TRUNC (SYSDATE),
c.invalid_reason = 'D',
c.standard_concept = NULL
WHERE
NOT EXISTS (
  SELECT 1
  FROM concept_relationship r
  WHERE r.concept_id_1 = c.concept_id
  AND r.invalid_reason IS NULL
  AND r.relationship_id in (
    'Concept replaced by',
    'Concept same_as to',
    'Concept alt_to to',
    'Concept poss_eq to',
    'Concept was_a to'
  )
)
AND c.invalid_reason = 'U' ;

--make sure invalid_reason = 'U' if we have an active replacement record in the concept_relationship table
UPDATE concept c SET
c.valid_end_date = TRUNC (SYSDATE),
c.invalid_reason = 'U',
c.standard_concept = NULL
WHERE EXISTS (
  SELECT 1
  FROM concept_relationship r
  WHERE r.concept_id_1 = c.concept_id
  AND r.invalid_reason IS NULL
  AND r.relationship_id in (
    'Concept replaced by',
    'Concept same_as to',
    'Concept alt_to to',
    'Concept poss_eq to',
    'Concept was_a to'
  )
)
AND (c.invalid_reason IS NULL OR c.invalid_reason = 'D')-- not already upgraded
;

--build new 'Maps to' mappings (or update existing) from deprecated to fresh concept
MERGE INTO concept_relationship r
USING (WITH upgraded_concepts
AS (
  SELECT DISTINCT
  concept_id_1,
  FIRST_VALUE (concept_id_2) OVER (PARTITION BY concept_id_1 ORDER BY rel_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS concept_id_2
  FROM (
    SELECT r.concept_id_1,
      r.concept_id_2,
      CASE
        WHEN r.relationship_id = 'Concept replaced by' THEN 1
        WHEN r.relationship_id = 'Concept same_as to' THEN 2
        WHEN r.relationship_id = 'Concept alt_to to' THEN 3
        WHEN r.relationship_id = 'Concept poss_eq to' THEN 4
        WHEN r.relationship_id = 'Concept was_a to' THEN 5
        WHEN r.relationship_id = 'Maps to' THEN 6
      END AS rel_id
    FROM concept c1, concept c2, concept_relationship r
    WHERE (
      r.relationship_id IN (
        'Concept replaced by',
        'Concept same_as to',
        'Concept alt_to to',
        'Concept poss_eq to',
        'Concept was_a to'
      )
      OR (
        r.relationship_id = 'Maps to'
        AND c2.invalid_reason = 'U'
      )
    )
    AND r.invalid_reason IS NULL
    AND c1.concept_id = r.concept_id_1
    AND c2.concept_id = r.concept_id_2
    AND ((
      c1.vocabulary_id = c2.vocabulary_id AND r.relationship_id <> 'Maps to') 
      OR r.relationship_id = 'Maps to'
    )
    AND c2.concept_code <> 'OMOP generated'
    AND r.concept_id_1 <> r.concept_id_2
  )
)
SELECT 
  CONNECT_BY_ROOT concept_id_1 AS root_concept_id_1, u.concept_id_2,
  'Maps to' AS relationship_id,
  TO_DATE ('19700101', 'YYYYMMDD') AS valid_start_date,
  TO_DATE ('20991231', 'YYYYMMDD') AS valid_end_date,
  NULL AS invalid_reason
FROM upgraded_concepts u
WHERE CONNECT_BY_ISLEAF = 1
CONNECT BY NOCYCLE PRIOR concept_id_2 = concept_id_1
START WITH concept_id_1 IN (
  SELECT concept_id_1 FROM upgraded_concepts
  MINUS
  SELECT concept_id_2 FROM upgraded_concepts
) i ON ( r.concept_id_1 = i.root_concept_id_1
  AND r.concept_id_2 = i.concept_id_2
  AND r.relationship_id = i.relationship_id)
WHEN NOT MATCHED THEN
INSERT (
  concept_id_1,
  concept_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
VALUES (
  i.root_concept_id_1,
  i.concept_id_2,
  i.relationship_id,
  i.valid_start_date,
  i.valid_end_date,
  i.invalid_reason
)
WHEN MATCHED
THEN
UPDATE SET r.invalid_reason = NULL, r.valid_end_date = i.valid_end_date
WHERE r.invalid_reason IS NOT NULL;

-- 'Maps to' or 'Mapped from' relationships should not exist where
-- a) the source concept has standard_concept = 'S', unless it is to self
-- b) the target concept has standard_concept = 'C' or NULL

UPDATE concept_relationship d
SET d.valid_end_date = trunc(sysdate),
d.invalid_reason = 'D'
WHERE d.ROWID IN (
  SELECT r.ROWID FROM concept_relationship r, concept c1, concept c2 WHERE
  r.concept_id_1 = c1.concept_id
  AND r.concept_id_2 = c2.concept_id
  AND (
  -- rule a)
    (c1.standard_concept = 'S' AND c1.concept_id != c2.concept_id)
  -- rule b)
    OR COALESCE (c2.standard_concept, 'X') != 'S'
  )
  AND r.relationship_id = 'Maps to'
  AND r.invalid_reason IS NULL
);
commit;

--deprecate replacement records if target concept was deprecated
MERGE INTO concept_relationship r
USING (
  WITH upgraded_concepts AS (
    SELECT r.concept_id_1,
    r.concept_id_2,
    r.relationship_id,
    c2.invalid_reason
    FROM concept c1, concept c2, concept_relationship r
    WHERE r.relationship_id IN (
      'Concept replaced by',
      'Concept same_as to',
      'Concept alt_to to',
      'Concept poss_eq to',
      'Concept was_a to'
    )
    AND r.invalid_reason IS NULL
    AND c1.concept_id = r.concept_id_1
    AND c2.concept_id = r.concept_id_2
    AND c1.vocabulary_id = c2.vocabulary_id
    AND c2.concept_code <> 'OMOP generated'
    AND r.concept_id_1 <> r.concept_id_2
  )
  SELECT u.concept_id_1, u.concept_id_2, u.relationship_id
  FROM upgraded_concepts u
  CONNECT BY NOCYCLE PRIOR concept_id_1 = concept_id_2
  START WITH concept_id_2 IN (
    SELECT concept_id_2
    FROM upgraded_concepts
    WHERE invalid_reason = 'D'
  )
) i
ON (r.concept_id_1 = i.concept_id_1 AND r.concept_id_2 = i.concept_id_2 AND r.relationship_id = i.relationship_id)
WHEN MATCHED
THEN
UPDATE SET r.invalid_reason = 'D', r.valid_end_date = TRUNC (SYSDATE);

--deprecate concepts if we have no active replacement record in the concept_relationship
UPDATE concept c SET
c.valid_end_date = TRUNC (SYSDATE),
c.invalid_reason = 'D',
c.standard_concept = NULL
WHERE
NOT EXISTS (
  SELECT 1
  FROM concept_relationship r
  WHERE r.concept_id_1 = c.concept_id
  AND r.invalid_reason IS NULL
  AND r.relationship_id in (
    'Concept replaced by',
    'Concept same_as to',
    'Concept alt_to to',
    'Concept poss_eq to',
    'Concept was_a to'
  )
)
AND c.invalid_reason = 'U' ;

--deprecate 'Maps to' mappings to deprecated and upgraded concepts
UPDATE concept_relationship r
SET r.valid_end_date = TRUNC (SYSDATE), r.invalid_reason = 'D'
WHERE r.relationship_id = 'Maps to'
AND r.invalid_reason IS NULL
AND EXISTS (
  SELECT 1
  FROM concept c
  WHERE c.concept_id = r.concept_id_2 AND c.invalid_reason IN ('U', 'D')
);

--reverse (reversing new mappings and deprecate existings)
MERGE INTO concept_relationship r
USING (
  SELECT r.*, rel.reverse_relationship_id
  FROM concept_relationship r, relationship rel
  WHERE r.relationship_id IN (
    'Concept replaced by',
    'Concept same_as to',
    'Concept alt_to to',
    'Concept poss_eq to',
    'Concept was_a to',
    'Maps to'
  )
  AND r.relationship_id = rel.relationship_id
) i
ON (r.concept_id_1 = i.concept_id_2 AND r.concept_id_2 = i.concept_id_1 AND r.relationship_id = i.reverse_relationship_id)
WHEN NOT MATCHED
THEN
INSERT (
  concept_id_1,
  concept_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason)
VALUES (
  i.concept_id_2,
  i.concept_id_1,
  i.reverse_relationship_id,
  i.valid_start_date,
  i.valid_end_date,
  i.invalid_reason
)
WHEN MATCHED
THEN
UPDATE SET r.invalid_reason = i.invalid_reason, r.valid_end_date = i.valid_end_date
WHERE (NVL (r.invalid_reason, 'X') <> NVL (i.invalid_reason, 'X') OR r.valid_end_date <> i.valid_end_date);

commit;
