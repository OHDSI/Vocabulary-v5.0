/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
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
* Authors: Anna Ostropolets
* Date: 2017
**************************************************************************/

--1 Update latest_update field to new date

do $_$
begin
	perform VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CTD',
	pVocabularyDate			=> current_date,
	pVocabularyVersion		=> 'CTD '||current_date,
	pVocabularyDevSchema	=> 'DEV_CTD'
);
	perform VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'RxNorm Extension',
 pVocabularyDate   => current_date,
 pVocabularyVersion  => 'RxNorm Extension '||current_date,
	pVocabularyDevSchema	=> 'DEV_CTD',
	pAppendVocabulary		=> true
);
end $_$;

--2. Truncate all working tables
truncate table concept_stage;
truncate table concept_relationship_stage;
truncate table concept_synonym_stage;
truncate table drug_strength_stage;
truncate table pack_content_stage;


-- 3. Step 1. create pull of mapped drugs for Z-index. Source file = cascodes_nlm
drop table if exists cas_mapping;
create table cas_mapping
as
select ltrim(cascode, '0')                                               as cascode,
       z.sourcename                                                      as source_name,
       regexp_replace(coalesce(name, googletranslatedterm), ' \[.*', '') as standard_name,
       coalesce(formula, z.checmicalformula)                             as formula,
       targetid                                                          as concept_id,
       targetname                                                        as concept_name
from z_index_ctd z
       join z_index_ingredient_mapping z2 using (cascode)
       left join cascodes_nlm on id = ltrim(cascode, '0') -- left join because 138 concepts cannot be found in cascodes_nlm
where targetid != '0'
  and targetid is not null
;

-- 4. Step 2. Add manual mapping for Z-index
select ltrim(cascode, '0'),
       sourcename                                                        as source_name,
       regexp_replace(coalesce(name, googletranslatedterm), ' \[.*', '') as standard_name,
       coalesce(formula, checmicalformula)                               as formula
from z_index_ingredient_mapping
       left join cascodes_nlm on id = ltrim(cascode, '0')
where targetid is null
  and cascode is not null
  and recordcount != '-1';

-- 4.1 Map and upload manual mapping back to the database
insert into cas_mapping
select *
from manual_mapping
where concept_id not in (0, 1);

-- 5. Step 3. Add other codes from nlm
-- 5.1 exact matching
insert into cas_mapping
select id, null, regexp_replace(name, ' \[.*', ''), formula, concept_id, concept_name
from cascodes_nlm
       join devv5.concept c on lower(regexp_replace(name, ' \[.*', '')) = lower(concept_name)
  and standard_concept = 'S' and concept_class_id = 'Ingredient' and vocabulary_id like 'Rx%'
where id not in (select cascode from cas_mapping)
;

-- 5.2 non-standard ingredients
drop table if exists map_1;
create table map_1
as
select distinct cs.*, c2.*
from cascodes_nlm cs
       join devv5.concept c
            on lower(regexp_replace(name, ' \[.*', '')) = lower(concept_name) and concept_class_id = 'Ingredient'
       join devv5.concept_relationship cr on c.concept_id = cr.concept_id_1
       join devv5.concept c2
            on c2.concept_id = cr.concept_id_2 and cr.invalid_reason is null and cr.relationship_id = 'Maps to'
where id not in (select cascode from cas_mapping)
;

insert into cas_mapping
select distinct id, null, regexp_replace(name, ' \[.*', ''), formula, concept_id, concept_name
from map_1
;

-- 5.3 For source_name add synonyms only if not equal to standard name
update cas_mapping
set formula = NULL
where formula = 'Unspecified';

update cas_mapping
set source_name = NULL
where lower(source_name) = lower(standard_name);


-- 6. populate concept_stage
-- 6.1 source
insert into concept_stage
  (concept_name,
   domain_id,
   vocabulary_id,
   concept_class_id,
   standard_concept,
   concept_code,
   valid_start_date,
   valid_end_date,
   invalid_reason)
select initcap(coalesce(standard_name,concept_name)),
       'Drug'                          AS domain_id,
       'CTD'                           as vocabulary_id,
       'Ingredient'                    as concept_class_id,
       null                            as standard_concept,
       cascode                         as concept_code,
       TO_DATE('19700101', 'yyyymmdd') as valid_start_date,
       TO_DATE('20991231', 'yyyymmdd') as valid_end_date,
       null                            as invalid_reason
from cas_mapping
union
select initcap(coalesce(standard_name,concept_name)),
       'Drug'                          AS domain_id,
       'CTD'                           as vocabulary_id,
       'Ingredient'                    as concept_class_id,
       null                            as standard_concept,
       cascode                         as concept_code,
       TO_DATE('19700101', 'yyyymmdd') as valid_start_date,
       TO_DATE('20991231', 'yyyymmdd') as valid_end_date,
       null                            as invalid_reason
from manual_mapping
where concept_id=1
;


-- 6.2 RxE
do $$
  declare
    ex integer;
  begin
    select MAX(replace(concept_code, 'OMOP', '')::int4) + 1 into ex
    from (
           select concept_code
           from concept
           where concept_code like 'OMOP%' and concept_code not like '% %' -- Last valid value of the OMOP123-type codes
         ) as s0;
    drop sequence if exists omop_seq;
    execute 'CREATE SEQUENCE omop_seq INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
  end $$;


-- create table with new codes for RxNorm Ext
drop table if exists temp_rx;
create table temp_rx
(
  concept_name varchar(50),
  concept_code varchar(50)
);

insert into temp_rx
select standard_name                 as concept_name,
       'OMOP' || nextval('omop_seq') as concept_code
from manual_mapping
where concept_id = 1;

insert into concept_stage
  (concept_name,
   domain_id,
   vocabulary_id,
   concept_class_id,
   standard_concept,
   concept_code,
   valid_start_date,
   valid_end_date,
   invalid_reason)
select concept_name,
       'Drug'                          as domain_id,
       'RxNorm Extension'              as vocabulary_id,
       'Ingredient'                    as concept_class_id,
       'S'                             as standard_concept,
       concept_code                    as concept_code,
       TO_DATE('19700101', 'yyyymmdd') as valid_start_date,
       TO_DATE('20991231', 'yyyymmdd') as valid_end_date,
       null                            as invalid_reason
from temp_rx
;

-- 6.3 source in concept_relationship_stage
insert into concept_relationship_stage
(concept_code_1,
 concept_code_2,
 vocabulary_id_1,
 vocabulary_id_2,
 relationship_id,
 valid_start_date,
 valid_end_date,
 invalid_reason)
select cascode,
       concept_code,
       'CTD',
       vocabulary_id,
       'Maps to',
       TO_DATE('19700101', 'yyyymmdd') as valid_start_date,
       TO_DATE('20991231', 'yyyymmdd') as valid_end_date,
       null                            as invalid_reason
from cas_mapping
       join concept using (concept_id);


insert into concept_relationship_stage
(concept_code_1,
 concept_code_2,
 vocabulary_id_1,
 vocabulary_id_2,
 relationship_id,
 valid_start_date,
 valid_end_date,
 invalid_reason)
select cascode,
       t.concept_code,
       'CTD',
       'RxNorm Extension',
       'Maps to',
       TO_DATE('19700101', 'yyyymmdd') as valid_start_date,
       TO_DATE('20991231', 'yyyymmdd') as valid_end_date,
       null                            as invalid_reason
from manual_mapping m
       join temp_rx t on m.standard_name = t.concept_name
where m.concept_id = 1;

insert into temp_rx
select standard_name                 as concept_name,
       'OMOP' || nextval('omop_seq') as concept_code
from manual_mapping
where concept_id = 1;


insert into concept_relationship_stage
(concept_code_1,
 concept_code_2,
 vocabulary_id_1,
 vocabulary_id_2,
 relationship_id,
 valid_start_date,
 valid_end_date,
 invalid_reason)
select concept_code,
       concept_code,
       vocabulary_id,
       vocabulary_id,
       'Maps to',
       TO_DATE('19700101', 'yyyymmdd') as valid_start_date,
       TO_DATE('20991231', 'yyyymmdd') as valid_end_date,
       null                            as invalid_reason
from concept_stage
where vocabulary_id = 'RxNorm Extension';


insert into concept_synonym_stage
(synonym_concept_id,
 synonym_name,
 synonym_concept_code,
 synonym_vocabulary_id,
 language_concept_id
)
select null,
       source_name,
       cascode,
       'CTD',
       4182503
 from cas_mapping
where source_name is not null;

-- 7. Working with replacement mappings
do $_$
begin
  perform VOCABULARY_PACK.CheckReplacementMappings();
end $_$
;

-- 8. Add mapping FROM deprecated to fresh concepts
do $_$
begin
  perform VOCABULARY_PACK.AddFreshMAPSTO();
end $_$
;
-- 9. Deprecate 'Maps to' mappings to deprecated AND upgraded concepts
do $_$
begin
  perform VOCABULARY_PACK.DeprecateWrongMAPSTO();
end $_$
;

-- 10. DELETE ambiguous 'Maps to' mappings
do $_$
begin
  perform VOCABULARY_PACK.DELETEAmbiguousMAPSTO();
end $_$
;
