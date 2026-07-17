-----------
-- Create source tables
-- This scripts performs the following:
-- 1. Truncate all working tables
-- 2. Set latest_update field to new date
-- 3. Fill_stage tables and do some modifications
-- 4. Renumber concept codes

-- APL 2.0
-- Authors: CReich, LLA 
-- (c) OHDSI
------------

---------------------------------
-- 1. Truncate all working tables
---------------------------------
truncate table concept_stage;
truncate table concept_relationship_stage;
truncate table concept_synonym_stage;
-- drug tables not affected
 
-----------------------
-- 2. Set latest_update
-----------------------
do $_$
begin
	perform vocabulary_pack.setlatestupdate(
	pvocabularyname			=> 'OMOP Genomic',
	pvocabularydate			=> to_date('20240216', 'yyyymmdd'),
	pvocabularyversion		=> 'OMOP Genomic ' || '20240216', 
	pvocabularydevschema	=> 'dev_omopgenomic'
);
end $_$;


------------------------------------------------
-- 3. Fill_stage tables and do some modifications
------------------------------------------------
truncate concept_stage;
truncate concept_relationship_stage;
truncate concept_synonym_stage;

create index idx_concept_code_2 on concept_relationship_stage using btree (concept_code_2);
create index idx_cs_concept_id on concept_stage using btree (concept_id);


-- Fill in stage tables
insert into concept_stage select * from concept_small;
insert into concept_stage select * from concept_large;
insert into concept_relationship_stage select * from relationship_small;
insert into concept_relationship_stage select * from relationship_large;
insert into concept_synonym_stage select * from synonym_small;

-- Remove synonyms for refreshed small concepts, new synonyms are in synonym_stage
delete from concept_synonym where concept_id in (select c.concept_id from concept c join concept_stage cs using(vocabulary_id, concept_code) where cs.invalid_reason is null);

-- Add deprecated records for all OMOP genomic that are not in concept_stage
insert into concept_stage
select c.* from (
  select cast (null as integer) as concept_id, concept_name, domain_id, vocabulary_id,
  case  -- this case will not be necessary in future
    when concept_name like 'Karyotype%' then 'Structural Variant'
    when concept_name like '%Fusion%' then 'Gene Variant'
    when concept_name like '%hromosome%' then 'Gene DNA Variant'
    when concept_name like '%ranscript%' then 'Gene RNA Variant'
    when concept_name like '%rotein%' then 'Gene Protein Variant'
    else 'Structural Variant'
  end as concept_class_id, 
  null as standard_concept, concept_code, valid_start_date, cast(null as date) as valid_end_date, 'D' as invalid_reason
  from concept where vocabulary_id='OMOP Genomic' and concept_class_id!='Genetic Variation' -- all old OMOP Genomic but the genes
) c left join ( -- union of concept_small and large
    select concept_code from concept_small union select concept_code from concept_large
) cs using(concept_code)
where cs.concept_code is null;

-- Deprecate concepts that have a concept replaced by relationship
delete from concept_relationship_stage 
where relationship_id!='Concept replaced by' and invalid_reason is null and concept_code_1 in (select concept_code_1 from concept_relationship_stage where relationship_id='Concept replaced by');
delete from concept_relationship_stage 
where relationship_id!='Concept replaces' and invalid_reason is null and concept_code_2 in (select concept_code_1 from concept_relationship_stage where relationship_id='Concept replaced by');
update concept_stage set invalid_reason='U', standard_concept=null
where concept_code in (select concept_code_1 from concept_relationship_stage where relationship_id='Concept replaced by');

-- Check code duplication
select * from concept_stage join (select concept_code from concept_stage group by concept_code having count(*)>1) d using(concept_code);

-- Check deprecation logic
select distinct standard_concept, invalid_reason from concept_stage
except select 'S', null -- proper standard concepts
except select null, 'U' -- upgraded concepts
except select null, 'D'; -- deleted concepts

-- Add links between small concepts and their genes
insert into concept_relationship_stage
with gene_ref as ( -- full list of genes, concept_class_id should change in next iteration to "Gene Variant"
  select distinct concept_code as gene_code, first_value(gene_name) over (partition by concept_code order by precedence) as gene_name from (
    select 2 as precedence, substr(concept_name, 1, position(' ' in concept_name)-1) as gene_name, concept_code 
    from concept c where c.vocabulary_id='OMOP Genomic' and c.concept_class_id='Genetic Variation' and standard_concept='S'
  union -- with new and updated genes
    select 1 as precedence, substr(concept_name, 1, position(' ' in concept_name)-1) as gene_name, concept_code
    from concept_large c where c.concept_class_id='Gene Variant' and concept_code not like 'OMOP%' and standard_concept='S'
  ) a
),
with_gene as (
  select concept_code, concept_name, substr(concept_name, 1, position(' ' in concept_name)-1) as gene_name from concept_small
)
select null, null, concept_code as concept_code_1, gene_code as concept_code_2, 'OMOP Genomic' as vocabulary_id_1, 'OMOP Genomic' as vocabulary_id_2,
'Is a' as relationship_id, null as valid_start_date, to_date('20991231', 'yyyyMMdd') as valid_end_date, null as invalid_reason
from with_gene join gene_ref using(gene_name)
where not exists (
  select 1 from concept_relationship_stage crs where crs.relationship_id='Is a'
  and crs.concept_code_1=concept_code and crs.concept_code_2=gene_code 
);

-- And reverse
insert into concept_relationship_stage
with gene_ref as ( -- full list of genes, concept_class_id should change in next iteration to "Gene Variant"
  select distinct concept_code as gene_code, first_value(gene_name) over (partition by concept_code order by precedence) as gene_name from (
    select 2 as precedence, substr(concept_name, 1, position(' ' in concept_name)-1) as gene_name, concept_code 
    from concept c where c.vocabulary_id='OMOP Genomic' and c.concept_class_id='Genetic Variation' and standard_concept='S'
  union
    select 1 as precedence, substr(concept_name, 1, position(' ' in concept_name)-1) as gene_name, concept_code
    from concept_large c where c.concept_class_id='Gene Variant' and concept_code not like 'OMOP%' and standard_concept='S'
  ) a
),
with_gene as (
  select concept_code, concept_name, substr(concept_name, 1, position(' ' in concept_name)-1) as gene_name from concept_small
)
select null, null, gene_code as concept_code_1, concept_code as concept_code_2, 'OMOP Genomic' as vocabulary_id_1, 'OMOP Genomic' as vocabulary_id_2,
'Subsumes' as relationship_id, null as valid_start_date, to_date('20991231', 'yyyyMMdd') as valid_end_date, null as invalid_reason
from with_gene join gene_ref using(gene_name)
where not exists (
  select 1 from concept_relationship_stage crs where crs.relationship_id='Subsumes'
  and crs.concept_code_1=gene_code and crs.concept_code_2=concept_code 
);

-- Deprecate mappings from karyotypes to fusion proteins
insert into concept_relationship_stage (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
select c1.concept_code, c2.concept_code, c1.vocabulary_id, c2.vocabulary_id, relationship_id, r.valid_start_date, cast(null as date), 'D' 
from concept c1
join concept_relationship r on r.concept_id_1=c1.concept_id and r.invalid_reason is null and concept_id_1!=concept_id_2 and relationship_id='Maps to'
join concept c2 on c2.concept_id=r.concept_id_2
join concept_stage cs on cs.vocabulary_id=c2.vocabulary_id and cs.concept_code=c2.concept_code 
where cs.standard_concept is not null and c1.vocabulary_id='OMOP Genomic'
and not exists (
  select 1 from concept_relationship_stage crs where crs.relationship_id=r.relationship_id
  and crs.concept_code_1=c1.concept_code and crs.vocabulary_id_1=c1.vocabulary_id
  and crs.concept_code_2=c2.concept_code and crs.vocabulary_id_2=c2.vocabulary_id
);

-- Deprecate all relationships to deprecated OMOP Genomics.
insert into concept_relationship_stage (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
select c1.concept_code, c2.concept_code, c1.vocabulary_id, c2.vocabulary_id, relationship_id, r.valid_start_date, cast(null as date), 'D' 
from concept c1
join concept_relationship r on r.concept_id_1=c1.concept_id and r.invalid_reason is null
join concept c2 on c2.concept_id=r.concept_id_2 and c2.vocabulary_id='OMOP Genomic' 
  and (c2.concept_code like 'OMOP%' or c2.concept_code like 'N%')
left join ( -- union of concept_small and large
    select concept_code, invalid_reason from concept_small union select concept_code, invalid_reason from concept_large
) cs on cs.concept_code=c2.concept_code
where (cs.concept_code is null or cs.invalid_reason is not null)
and not exists (
  select 1 from concept_relationship_stage crs where crs.relationship_id=r.relationship_id
  and crs.concept_code_1=c1.concept_code and crs.vocabulary_id_1=c1.vocabulary_id
  and crs.concept_code_2=c2.concept_code and crs.vocabulary_id_2=c2.vocabulary_id
);

-- Create reverse relationships
insert into concept_relationship_stage (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
select concept_code_2, concept_code_1, vocabulary_id_2, vocabulary_id_1, reverse_relationship_id, valid_start_date, valid_end_date, invalid_reason 
from concept_relationship_stage r join relationship using(relationship_id)
where not exists (
  select 1 from concept_relationship_stage crs where crs.relationship_id=reverse_relationship_id
  and crs.concept_code_1=r.concept_code_2 and crs.vocabulary_id_1=r.vocabulary_id_2
  and crs.concept_code_2=r.concept_code_1 and crs.vocabulary_id_2=r.vocabulary_id_1
);

-- check for duplicate relationships
select * from concept_relationship_stage join (
  select concept_code_1, concept_code_2, relationship_id from concept_relationship_stage where concept_code_1!=concept_code_2 
  group by concept_code_1, concept_code_2, relationship_id having count(*)>1) a using(concept_code_1, concept_code_2, relationship_id)
order by 1,2
limit 100;

-- add dates
update concept_stage set valid_start_date=(select latest_update from vocabulary where vocabulary_id='OMOP Genomic') where valid_start_date is null;
update concept_stage set valid_end_date=(select latest_update-1 from vocabulary where vocabulary_id='OMOP Genomic') where valid_end_date is null;
update concept_relationship_stage set valid_start_date=(select latest_update from vocabulary where vocabulary_id='OMOP Genomic') where valid_start_date is null;
update concept_relationship_stage set valid_end_date=(select latest_update-1 from vocabulary where vocabulary_id='OMOP Genomic') where valid_end_date is null;

-- add constraints
alter table concept_stage alter column concept_code set not null;
alter table concept_stage alter column valid_end_date set not null;
alter table concept_stage alter column valid_start_date set not null;
alter table concept_stage alter column vocabulary_id set not null;
alter table concept_relationship_stage alter column concept_code_1 set not null;
alter table concept_relationship_stage alter column concept_code_2 set not null;
alter table concept_relationship_stage alter column relationship_id set not null;
alter table concept_relationship_stage alter column valid_end_date set not null;
alter table concept_relationship_stage alter column valid_start_date set not null;
alter table concept_relationship_stage alter column vocabulary_id_1 set not null;
alter table concept_relationship_stage alter column vocabulary_id_2 set not null;
alter table concept_stage add constraint idx_pk_cs primary key (concept_code, vocabulary_id);
alter table concept_relationship_stage add constraint idx_pk_crs primary key (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id);
alter table concept_synonym_stage alter column language_concept_id set not null;
alter table concept_synonym_stage alter column synonym_concept_code set not null;
alter table concept_synonym_stage alter column synonym_name set not null;
alter table concept_synonym_stage alter column synonym_vocabulary_id set not null;
alter table concept_synonym_stage add constraint idx_pk_css primary key (synonym_vocabulary_id, synonym_name, synonym_concept_code, language_concept_id);

---------------------------
-- 4. Renumber concept codes
---------------------------
drop table if exists recount;
create table recount as
select concept_code as old_code, 
  'OMOP'||(select max(cast(substr(concept_code, 5, 7) as integer)) from concept where vocabulary_id='OMOP Genomic' and concept_code like 'OMOP%')+row_number() over () as new_code
from (
  select cs.concept_code from concept_small cs left join concept c using(vocabulary_id, concept_code) where cs.concept_code like 'OMOP%' and c.concept_code is null
union 
  select cl.concept_code from concept_large cl left join concept c using(vocabulary_id, concept_code) where cl.concept_code like 'OMOP%' and c.concept_code is null
) a
;

-- replace codes
update concept_stage set concept_code=new_code from recount where concept_code=old_code;
update concept_relationship_stage set concept_code_1=new_code from recount where concept_code_1=old_code;
update concept_relationship_stage set concept_code_2=new_code from recount where concept_code_2=old_code;
update concept_synonym_stage set synonym_concept_code=new_code from recount where synonym_concept_code=old_code;

drop table concept_small;
drop table relationship_small;
drop table synonym_small;
drop table concept_large;
drop table relationship_large;

a---- Done
