/*****************************************************************************
* Copyright 2016-17 Observational Health Data Sciences and Informatics (OHDSI)
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
* Authors: Christian Reich, Anna Ostropolets, Dmitri Dimschits
***************************************************************************/

/******************************************************************************
* This script post-processes the result of Build_RxE.sql run against Rxfix    *
* (instead of a real drug database. It needs to be run before                 *
* generic_update.sql. It replaces all newly generated RxNorm Extension codes  *
* with the existing ones. It then new_rxes the few truly new RxNorm          *
* Extension ones                                                              *
******************************************************************************/

/***********************************************************************************************************
* 1. Create table with replacement of RxNorm Extension concept_codes with existing Rxfix/RxO concept_codes *
* and the ones remaining, who's codes need to be new_rxed                                                 *
***********************************************************************************************************/
-- For Rxfix-RxE relationship, pick the best one by name and name length
create table equiv_rxe nologging as
with maps as (
  select concept_code_1 as c1_code, concept_code_2 as c2_code,
    case when lower(c1.concept_name)=lower(c2.concept_name) then 1 else 2 end as match,
    length(c1.concept_name)/length(c2.concept_name) as l
  from concept_relationship_stage 
  join drug_concept_stage c1 on c1.concept_code=concept_code_1 -- for name comparison
  join concept_stage c2 on c2.concept_code=concept_code_2 -- for name comparison
  left join concept rxn on rxn.concept_code=concept_code_1 and rxn.vocabulary_id='RxNorm' -- checking it's not a RxNorm
  where relationship_id in ('Maps to', 'Source - RxNorm eq') and vocabulary_id_1='Rxfix' and vocabulary_id_2='RxNorm Extension'
  and rxn.concept_id is null
),
maps2 as ( -- flipping length difference l to be between 0 and 1
  select c1_code, c2_code, match, case when l>1 then 1/l else l end as l
  from maps
)
select distinct 
  first_value(c1_code) over (partition by c2_code order by match, l desc, c1_code) as rxf_code,
  c2_code as rxe_code
from maps2
;

exec DBMS_STATS.GATHER_TABLE_STATS (ownname=> USER, tabname => 'equiv_rxe', estimate_percent => null, cascade => true);
create index idx_equiv_rxe on equiv_rxe(rxe_code);
create index idx_equiv_rxf on equiv_rxe(rxf_code);

-- create sequence for "tight" OMOP codes
declare
 ex number;
begin
select max(iex)+1 into ex from (  
    select cast(substr(concept_code, 5) as integer) as iex from drug_concept_stage where concept_code like 'OMOP%' and concept_code not like '% %' -- Last valid value of the OMOP123-type codes
  union
    select cast(substr(concept_code, 5) as integer) as iex from concept where concept_code like 'OMOP%' and concept_code not like '% %'
);
  begin
    execute immediate 'create sequence omop_seq increment by 1 start with ' || ex || ' nocycle cache 20 noorder';
    exception
      when others then null;
  end;
end;
/

-- new_rxe the new RxE codes, where no traditional will be equiv_rxed
create table new_rxe ( 
  sparse_code varchar2(50),
  tight_code varchar2(50)
) nologging;

insert /*+ APPEND */ into new_rxe
select rxe.concept_code as sparse_code, 'OMOP'||omop_seq.nextval as tight_code
from concept_stage rxe
left join concept rxn on rxn.concept_code=rxe.concept_code and rxn.vocabulary_id='RxNorm' -- remove the Rxfix which are really RxNorm
where rxe.vocabulary_id='RxNorm Extension'
and rxe.concept_code not in (select rxe_code from equiv_rxe) -- those will be kept intact
and rxn.concept_id is null
;
commit;

exec DBMS_STATS.GATHER_TABLE_STATS (ownname=> USER, tabname => 'new_rxe', estimate_percent => null, cascade => true);
create index idx_new_sparse on new_rxe(sparse_code);

-- Invalidate Rxfix records that are not equiv_rxed and rename their link to 'Concept replaced by'
create table inval_rxe nologging as
select rxf.concept_code 
from concept_stage rxf
left join concept rxn on rxn.concept_code=rxf.concept_code and rxn.vocabulary_id='RxNorm' -- remove the Rxfix which are really RxNorm
where rxf.vocabulary_id='Rxfix'
and rxf.concept_code not in (select rxf_code from equiv_rxe) -- those will be gone
and rxn.concept_id is null
;

-- For Rxfix records that have RxNorm equivalents, rxe_rxn drug_strengh_stage and pack_content_stage records, or replace components with RxNorm
create table rxn_rxn nologging as
select concept_code_1 as rxf_code, concept_code_2 as rxn_code
from concept_relationship_stage 
join concept on concept_code=concept_code_1 and vocabulary_id='RxNorm' -- remove the Rxfix which are really RxNorm
where relationship_id in ('Maps to', 'Source - RxNorm eq') and vocabulary_id_1='Rxfix' and vocabulary_id_2='RxNorm'
;

exec DBMS_STATS.GATHER_TABLE_STATS (ownname=> USER, tabname => 'rxn_rxn', estimate_percent => null, cascade => true);
create index idx_rxn_rxf on rxn_rxn(rxf_code);

/*******************************************************
* 2. Deal with equivalent rxf-rxe concepts (equiv_rxe) *
*******************************************************/
-- Delete identity relationships 
delete from concept_relationship_stage where concept_code_1 in (select rxf_code from equiv_rxe) and vocabulary_id_1='Rxfix';

-- Delete no longer needed Rxfix concepts 
delete from concept_stage where concept_code in (select rxf_code from equiv_rxe) and vocabulary_id='Rxfix';

-- Restore concept_stage: Replace RxNorm Extension concept_codes with the original RxNorm Extension codes from Rxfix
update concept_stage set concept_code=(select rxf_code from equiv_rxe where concept_code=rxe_code)
where exists (select 1 from equiv_rxe where concept_code=rxe_code) and vocabulary_id='RxNorm Extension';

-- Restore concept_relationship_stage
update concept_relationship_stage set concept_code_1=(select rxf_code from equiv_rxe where concept_code_1=rxe_code)
where exists (select 1 from equiv_rxe where concept_code_1=rxe_code) and vocabulary_id_1='RxNorm Extension';

update concept_relationship_stage set concept_code_2=(select rxf_code from equiv_rxe where concept_code_2=rxe_code)
where exists (select 1 from equiv_rxe where concept_code_2=rxe_code) and vocabulary_id_2='RxNorm Extension';

-- Restore drug_strength_stage
update drug_strength_stage set drug_concept_code=(select rxf_code from equiv_rxe where drug_concept_code=rxe_code)
where exists (select 1 from equiv_rxe where drug_concept_code=rxe_code) and vocabulary_id_1='RxNorm Extension';

update drug_strength_stage set ingredient_concept_code=(select rxf_code from equiv_rxe where ingredient_concept_code=rxe_code)
where exists (select 1 from equiv_rxe where ingredient_concept_code=rxe_code) and vocabulary_id_2='RxNorm Extension';

-- Restore pack_concent_stage
update pack_content_stage set pack_concept_code=(select rxf_code from equiv_rxe where pack_concept_code=rxe_code)
where exists (select 1 from equiv_rxe where pack_concept_code=rxe_code) and pack_vocabulary_id='RxNorm Extension';

update pack_content_stage set drug_concept_code=(select rxf_code from equiv_rxe where drug_concept_code=rxe_code)
where exists (select 1 from equiv_rxe where drug_concept_code=rxe_code) and drug_vocabulary_id='RxNorm Extension';

/*******************************************************************
* 3. Invalidate RxE concepts that are no longer needed (inval_rxe) *
*******************************************************************/
-- Fix the ones with a 'Maps to'
update concept_stage c set c.vocabulary_id='RxNorm Extension', c.valid_end_date=(select latest_update-1 from vocabulary where vocabulary_id='Rxfix')-1, c.invalid_reason='U'
where exists (select 1 from inval_rxe i where c.concept_code=i.concept_code) -- is not slotted for turning into active RxE
and exists (select 1 from concept_relationship_stage where concept_code_1=c.concept_code) -- has a relationship to something
and vocabulary_id='Rxfix';

-- Obsolete the remaining ones 
update concept_stage c set c.vocabulary_id='RxNorm Extension', c.valid_end_date=(select latest_update-1 from vocabulary where vocabulary_id='Rxfix')-1, c.invalid_reason='D'
where exists (select 1 from inval_rxe i where c.concept_code=i.concept_code) -- is not slotted for turning into active RxE
and not exists (select 1 from concept_relationship_stage where concept_code_1=c.concept_code) -- has a relationship to something
and vocabulary_id='Rxfix';

-- Change vocabulary_id for all those in concept_relationship_stage
update concept_relationship_stage c set vocabulary_id_1='RxNorm Extension'
where concept_code_1 in (select concept_code from inval_rxe) -- is not slotted for turning into active RxE
and vocabulary_id_1='Rxfix';

/***************************************************
* 4. Remove Rxfix that are really RxNorm (rxn_rxn) *
****************************************************/
-- Delete relationships 
delete from concept_relationship_stage where concept_code_1 in (select rxf_code from rxn_rxn) and vocabulary_id_1='Rxfix';

-- Delete concepts 
delete from concept_stage where concept_code in (select rxf_code from rxn_rxn) and vocabulary_id='Rxfix';

-- Turn target into RxNorm extension 
update concept_stage c set c.vocabulary_id='RxNorm Extension'
where exists (select 1 from concept_relationship_stage where concept_code_2=concept_code and vocabulary_id_1='Rxfix'

-- Add replacement code to new_rxe
insert into new_rxe
select concept_code_2, 'OMOP'||omop_seq.nextval from concept_relationship_stage where vocabulary_id_1='Rxfix';

-- Turn source into RxNorm
update concept_stage c set c.vocabulary_id='RxNorm', c.valid_end_date=nvl(nullif(c.valid_end_date, to_date('20991231', 'yyyymmdd'), (select latest_update-1 from vocabulary where vocabulary_id='Rxfix')-1)), c.invalid_reason='U'
where vocabulary_id='Rxfix';

-- Fix concept_relationship_stage
update concept_relationship_stage c set vocabulary_id_1='RxNorm'
where vocabulary_id_1='Rxfix';

/**********************************************************************************************
* 5. Condense the remaining RxNorm Extension codes so they don't take up as much number space *
**********************************************************************************************/
-- Fix concept_stage
update concept_stage set concept_code=(select tight_code from new_rxe where concept_code=sparse_code)
where exists (select 1 from new_rxe where concept_code=sparse_code) and vocabulary_id='RxNorm Extension';

-- Fix concept_relationship_stage
update concept_relationship_stage set concept_code_1=(select tight_code from new_rxe where concept_code_1=sparse_code)
where exists (select 1 from new_rxe where concept_code_1=sparse_code) and vocabulary_id_1='RxNorm Extension';

update concept_relationship_stage set concept_code_2=(select tight_code from new_rxe where concept_code_2=sparse_code)
where exists (select 1 from new_rxe where concept_code_2=sparse_code) and vocabulary_id_2='RxNorm Extension';

-- Fix drug_strength_stage
update drug_strength_stage set drug_concept_code=(select tight_code from new_rxe where drug_concept_code=sparse_code)
where exists (select 1 from new_rxe where drug_concept_code=sparse_code) and vocabulary_id_1='RxNorm Extension';

update drug_strength_stage set ingredient_concept_code=(select tight_code from new_rxe where ingredient_concept_code=sparse_code)
where exists (select 1 from new_rxe where ingredient_concept_code=sparse_code) and vocabulary_id_2='RxNorm Extension';

-- Fix pack_content_stage
update pack_content_stage set pack_concept_code=(select tight_code from new_rxe where pack_concept_code=sparse_code)
where exists (select 1 from new_rxe where pack_concept_code=sparse_code) and pack_vocabulary_id='RxNorm Extension';

update pack_content_stage set drug_concept_code=(select tight_code from new_rxe where drug_concept_code=sparse_code)
where exists (select 1 from new_rxe where drug_concept_code=sparse_code) and drug_vocabulary_id='RxNorm Extension';

/******************************************************************************************
* 6. Rename all 'Maps to' and 'Source – RxNorm eq' relationships to 'Concept replaced by' *
******************************************************************************************/
update concept_relationship_stage set relationship_id='Concept replaced by' where relationship_id in ('Maps to', 'Source - RxNorm eq');
commit;

/******************************************************************************
* 7. Return all relationships that were in the base tables but no longer here *
*    The internal RxE will be deprecated, those to ATC will be copied         *
******************************************************************************/
-- Within RxE
insert /*+ APPEND */ into concept_relationship_stage
select 
  null as concept_id_1, null as concept_id_2, 
  concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id,
  r.valid_start_date, (select latest_update-1 from vocabulary where vocabulary_id='Rxfix')-1 as valid_end_date, 'D' as invalid_reason
from (
  select 
    c1.concept_code as concept_code_1, c1.vocabulary_id as vocabulary_id_1, c2.concept_code as concept_code_2, c2.vocabulary_id as vocabulary_id_2,
    relationship_id, r.valid_start_date
  from devv5.concept_relationship r
  join devv5.concept c1 on r.concept_id_1=c1.concept_id
  join devv5.concept c2 on r.concept_id_2=c2.concept_id
  -- only within RxE, and but no RxNorm to RxNorm
  where c1.vocabulary_id='RxNorm Extension' and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
    or c1.vocabulary_id in ('RxNorm', 'RxNorm Extension') and c2.vocabulary_id='RxNorm Extension'
) r
left join concept_relationship_stage s using(concept_code_1, vocabulary_id_1, concept_code_2, vocabulary_id_2, relationship_id)
where s.valid_start_date is null
;
commit;

-- To ATC etc.
insert  /*+ APPEND */ into concept_relationship_stage
select 
  null as concept_id_1, null as concept_id_2, 
  c1.concept_code as concept_code_1, c2.concept_code as concept_code_2, c1.vocabulary_id as vocabulary_id_1, c2.vocabulary_id as vocabulary_id_2,
  relationship_id, r.valid_start_date, r.valid_end_date, r.invalid_reason
from devv5.concept_relationship r
join devv5.concept c1 on r.concept_id_1=c1.concept_id
join devv5.concept c2 on r.concept_id_2=c2.concept_id
where c1.vocabulary_id='RxNorm Extension' and c2.domain_id='Drug' and c2.standard_concept='C'
  or c2.domain_id='Drug' and c1.standard_concept='C' and c2.vocabulary_id='RxNorm Extension'
;
commit;

begin
DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'RxNorm Extension',
                                          pVocabularyDate        => TO_DATE ('20170610', 'yyyymmdd'), --The 2017 changes became effective on October 1, 2016.
                                          pVocabularyVersion     => '0',
                                          pVocabularyDevSchema   => 'DEV_RXE');
END;
/

/**************
* 8. Clean up *
**************/
drop table equiv_rxe purge;
drop table new_rxe purge;
drop sequence omop_seq;
drop table inval_rxe purge;
drop table rxn_rxn purge;

/*
delete from vocabulary where vocabulary_id in ('RxO','Rxfix'); 

begin
    delete from drug_strength ds where drug_concept_id in (select concept_id from concept where vocabulary_id='RxO');
    delete from drug_strength ds where ingredient_concept_id in (select concept_id from concept where vocabulary_id='RxO');
    delete from pack_content ds where pack_concept_id in (select concept_id from concept where vocabulary_id='RxO');
    delete from pack_content ds where drug_concept_id in (select concept_id from concept where vocabulary_id='RxO');
    delete from concept_relationship where concept_id_1 in (select concept_id from concept where vocabulary_id='RxO');
    delete from concept_relationship where concept_id_2 in (select concept_id from concept where vocabulary_id='RxO');
    delete from concept_synonym where concept_id in (select concept_id from concept where vocabulary_id='RxO');
    delete from concept where vocabulary_id='RxO';
end;
/
commit;

drop table drug_concept_stage purge;
drop pack_content_stage purge;
drop table ds_stage purge;
drop table internal_relationship_stage purge;
drop table pc_stage purge;
drop table relationship_to_concept purge;
*/