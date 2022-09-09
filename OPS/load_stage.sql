/**************************************************************************
* Copyright 2020 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Eduard Korchmae, Timur Vakhitov, Dmitry Dymshyts, Christian Reich
* Date: 2020
**************************************************************************/

--0. Latest update construction
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'OPS',
	pVocabularyDate			=> TO_DATE ('20220101', 'yyyymmdd'),
	pVocabularyVersion		=> 'OPS Version 2022',
	pVocabularyDevSchema	=> 'DEV_OPS'
);
END $_$
;
--1. Input source tables ops_src_agg and ops_mod_src for all years
--WbImport example
;
--2. Unite sources in a single table with full names
drop table if exists hierarchy_full
;
create unlogged table hierarchy_full as
with codes_lifespan as
	(
		select code, min (year) as start_year, max (year) as end_year
		from ops_src_agg
		group by code
	),
codes_date as
	(
		select distinct
			code,
			(start_year || '-01-01') :: date as valid_start_date,
			case end_year
				when (select max(year) from ops_src_agg) then '2099-12-31' :: date
				else (end_year || '-12-31') :: date
			end as valid_end_date
		from codes_lifespan
	)
select o.code, o.label_de, o.superclass, o.modifiedby, d.valid_start_date, d.valid_end_date
from ops_src_agg o
join codes_lifespan c on
	c.code = o.code and
	o.year = c.end_year -- last appearance of the code contains the best label
join codes_date d on
	d.code = o.code
;
drop table if exists modifiers_append
;
create unlogged table modifiers_append as
with codes_lifespan as
	(
		select modifier, code, min (year) as start_year, max (year) as end_year
		from ops_mod_src
		group by modifier, code
	),
codes_date as
	(
		select distinct
			modifier,code,
			(start_year || '-01-01') :: date as valid_start_date,
			case end_year
				when (select max(year) from ops_src_agg) then '2099-12-31' :: date
				else (end_year+1 || '-01-01') :: date
			end as valid_end_date
		from codes_lifespan
	)
select o.modifier, o.code, o.label_de, o.superclass, d.valid_start_date, d.valid_end_date
from ops_mod_src o
join codes_lifespan c on
	c.modifier = o.modifier and
	c.code = o.code and
	o.year = c.end_year -- last appearance of the code contains the best label
join codes_date d on
	d.code = o.code and
	d.modifier = o.modifier
;
--imprint modifiers into main table
--modifier = superclass
insert into hierarchy_full (code,label_de,superclass,valid_start_date,valid_end_date)
select
	concat (h.code, a.code) as code,
	a.label_de as label_de,
	h.code as superclass,
	a.valid_start_date,
	a.valid_end_date
from hierarchy_full h
join modifiers_append a on
	h.modifiedby = a.modifier
where a.modifier = a.superclass
;
--superclass must be created from parent modifier
insert into hierarchy_full (code,label_de,superclass,valid_start_date,valid_end_date)
select
	concat (h.code, a.code) as code,
	a.label_de as label_de,
	concat (h.code, b.code) as superclass,
	a.valid_start_date,
	a.valid_end_date
from hierarchy_full h
join modifiers_append a on
	h.modifiedby = a.modifier
--get parent modifier
join modifiers_append b on
	b.modifier = a.modifier and
	b.code = a.superclass
where a.modifier != a.superclass
;
--3. Use hierarchy_full to create a single table concept_stage_de with full German concept names 
drop table if exists concept_stage_de
;
create table concept_stage_de as
with recursive code_full_term as
	(
		select
			code,
			label_de as full_term,
			superclass,
			valid_start_date,
			valid_end_date
		from hierarchy_full

			union all

		select
			t.code,
			s.label_de || ': ' || t.full_term as full_term,
			s.superclass,
			t.valid_start_date,
			t.valid_end_date
		from code_full_term t
		join hierarchy_full s on
			t.superclass = s.code
	)
select
	code as concept_code,
	full_term as concept_name_de,
	valid_start_date,
	valid_end_date
from code_full_term
where superclass like '%...%' -- down to lowest parental level for full name
;
--4. Rely on concept_manual and concept_relationship_manual to retrieve correct translated names
;
truncate concept_stage
;
insert into concept_stage (concept_name,domain_id,vocabulary_id,concept_class_id,concept_code,valid_start_date,valid_end_date,invalid_reason)
select distinct
	'Placeholder English term' concept_name,
	'Procedure' as domain_id,
	'OPS' as vocabulary_id,
	'Procedure' as concept_class_id,
	concept_code,
	valid_start_date,
	valid_end_date,
	case
		when valid_end_date < current_date then 'D'
	end as invalid_reason
from concept_stage_de
;
--5. Fill concept_synonym_stage with original full German names
truncate concept_synonym_stage
;
insert into concept_synonym_stage (synonym_name, synonym_concept_code, synonym_vocabulary_id, language_concept_id)
select
	concept_name_de,
	concept_code,
	'OPS',
	4182504 --German
from concept_stage_de
;
--6. Fill internal hierarchy in concept_relationship_stage; Mappings come from manual table
truncate concept_relationship_stage
;
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	code,
	superclass,
	'OPS',
	'OPS',
	'Is a',
	'1970-01-01' :: date,
	'2099-12-31' :: date
from hierarchy_full h
join concept_stage a on
	h.superclass = a.concept_code
;
delete from concept_stage 
where concept_code in (
select concept_code from concept_stage
group by concept_code
having count (1) > 1) and
invalid_reason is null
;
--7. Process manual tables
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

;
--8. Automated scripts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

