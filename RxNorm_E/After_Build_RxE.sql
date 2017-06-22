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
* with the existing ones. It then condenses the few truly new RxNorm          *
* Extension ones                                                              *
******************************************************************************/

/***********************************************************************************************************
* 1. Create table with replacement of RxNorm Extension concept_codes with existing Rxfix/RxO concept_codes *
* and the ones remaining, who's codes need to be condensed                                                 *
***********************************************************************************************************/
-- Pick the one to keep that matches best by concept_name and then by length
create table drop_rxe nologging as
with maps as (
  select concept_code_1 as c1_code, concept_code_2 as c2_code,
    case when lower(c1.concept_name)=lower(c2.concept_name) then 1 else 2 end as match,
    length(c1.concept_name)/length(c2.concept_name) as l
  from concept_relationship_stage 
  join drug_concept_stage c1 on c1.concept_code=concept_code_1
  join concept_stage c2 on c2.concept_code=concept_code_2
  where relationship_id in ('Maps to', 'Source - RxNorm eq') and vocabulary_id_1='Rxfix' and vocabulary_id_2='RxNorm Extension'
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

create table keep_rxe ( 
  sparse_code varchar2(50),
  tight_code varchar2(50)
) nologging;

-- generate OMOP codes for new concepts
insert /*+ APPEND */ into keep_rxe
select concept_code as sparse_code, 'OMOP'||omop_seq.nextval as tight_code
from concept_stage 
where vocabulary_id='RxNorm Extension'
and concept_code not in (select rxe_code from drop_rxe) -- those will be gone
;
commit;

/*************************************
* 2. Fix the Rxfix/RxO end of things *
*************************************/
-- Delete those Maps to/Source - RxNorm eq relationships, since we are making them the same concept
delete from concept_relationship_stage where rowid in (
  select r.rowid from concept_relationship_stage r join drop_rxe on r.concept_code_1=rxf_code and r.concept_code_2=rxe_code 
  where r.relationship_id in ('Maps to', 'Source - RxNorm eq') and r.vocabulary_id_1='Rxfix' and r.vocabulary_id_2='RxNorm Extension'
);

-- Delete those Rxfix concepts that will merge with their corresponding RxNorm Extension records
delete from concept_stage where concept_code in (select rxf_code from drop_rxe where vocabulary_id='Rxfix');

-- Delete those records that like RxNorm codes
delete from concept_relationship_stage where rowid in (
  select r.rowid from concept_relationship_stage r join concept on r.concept_code_1=concept_code and vocabulary_id='RxNorm'
  where r.relationship_id in ('Maps to', 'Source - RxNorm eq') and r.vocabulary_id_1='Rxfix'
);

-- Delete RxNorm records from concept_stage
delete from concept_stage where concept_code in (select concept_code from concept where vocabulary_id='RxNorm');

-- Delete RxNorm records from concept_stage
delete from drug_strength_stage where drug_concept_code in (select concept_code from concept where vocabulary_id='RxNorm');

-- Obsolete the remaining ones that have a link - to Upgrade
update concept_stage set vocabulary_id='RxNorm Extension', valid_end_date=sysdate-1, invalid_reason='U' where exists (
  select 1 from concept_relationship_stage where concept_code_1=concept_code and vocabulary_id_1='Rxfix' and relationship_id in ('Maps to', 'Source - RxNorm eq')
) and vocabulary_id='Rxfix';

-- Obsolete the remaining ones - to Deprecated
update concept_stage set vocabulary_id='RxNorm Extension', valid_end_date=sysdate-1, invalid_reason='D' where vocabulary_id='Rxfix';

-- Change Maps to to Concept replaced by since it is both RxNorm Extension now
update concept_relationship_stage set relationship_id='Concept replaced by' where relationship_id in ('Maps to', 'Source - RxNorm eq');

/********************************************************************
* 3. Change the concept_codes of the RxE we give the old codes back *
********************************************************************/
create index idx_rxe_code on drop_rxe (rxe_code);
exec DBMS_STATS.GATHER_TABLE_STATS (ownname=> USER, tabname => 'drop_rxe', estimate_percent => null, cascade => true);

-- Fis concept_stage: Replace RxNorm Extension concept_codes with the original RxNorm Extension codes
update concept_stage set (vocabulary_id, concept_code)=(select 'RxNorm Extension', rxf_code from drop_rxe where concept_code=rxe_code)
where exists (select 1 from drop_rxe where concept_code=rxe_code);

-- Fix concept_relationship_stage
update concept_relationship_stage set concept_code_1=(select rxf_code from drop_rxe where concept_code_1=rxe_code)
where exists (select 1 from drop_rxe where concept_code_1=rxe_code and vocabulary_id_1='RxNorm Extension');

update concept_relationship_stage set concept_code_2=(select rxf_code from drop_rxe where concept_code_2=rxe_code)
where exists (select 1 from drop_rxe where concept_code_2=rxe_code and vocabulary_id_2='RxNorm Extension');

-- Fix drug_strength_stage
update drug_strength_stage set drug_concept_code=(select rxf_code from drop_rxe where drug_concept_code=rxe_code)
where exists (select 1 from drop_rxe where ingredient_concept_code=rxe_code and drug_vocabulary_id='RxNorm Extension');

update drug_strength_stage set ingredient_concept_code=(select rxf_code from drop_rxe where ingredient_concept_code=rxe_code)
where exists (select 1 from drop_rxe where ingredient_concept_code=rxe_code and ingredient_vocabulary_id='RxNorm Extension');

-- Fix pack_concent_stage
update pack_content_stage set pack_concept_code=(select rxf_code from drop_rxe where pack_concept_code=rxe_code)
where exists (select 1 from drop_rxe where pack_concept_code=rxe_code and vocabulary_id_2='RxNorm Extension');

update drug_content_stage set pack_concept_code=(select rxf_code from drop_rxe where drug_concept_code=rxe_code)
where exists (select 1 from drop_rxe where drug_concept_code=rxe_code and vocabulary_id_2='RxNorm Extension');


select * from concept_relationship_stage where concept_code_2='792497';
select * from maps_to where from_code='792497';
select * from concept_relationship_stage where relationship_id='Maps to';
update drug_strength_stage set (ingredient_concept_code, vocabulary_id_1)=(select rxf_code, 'RxNorm Extension' from drop_rxe where ingredient_concept_code=rxe_code)
where exists (select 1 from drop_rxe where ingredient_concept_code=rxe_code and vocabulary_id_2='RxNorm Extension');

select * from drug_strength_stage join drop_rxe on drug_concept_code=rxe_code and rxf_code not like 'OMOP%';
select * from drop_rxe where rxf_code not like 'OMOP%';
/**********************************************************************************************
* 4. Condense the remaining RxNorm Extension codes so they don't take up as much number space *
**********************************************************************************************/
-- Replace newly formed RxNorm Extension concept_codes (not deleted in previous step) with condensed ones
update concept_stage set vocabulary_id=(select tight_code from keep_rxe where concept_code=sparse_code)
where exists (select 1 from keep_rxe where concept_code=sparse_code and vocabulary_id_1='RxNorm Extension');

-- Fix concept_relationship_stage
update concept_relationship_stage set concept_code_1=(select tight_code from keep_rxe where concept_code_1=sparse_code)
where exists (select 1 from keep_rxe where concept_code_1=sparse_code and vocabulary_id_1='RxNorm Extension');

update concept_relationship_stage set concept_code_2=(select tight_code from keep_rxe where concept_code_2=sparse_code)
where exists (select 1 from keep_rxe where concept_code_2=sparse_code and vocabulary_id_2='RxNorm Extension');

-- Fix drug_strength_stage
update drug_strength_stage set drug_concept_code=(select tight_code from keep_rxe where drug_concept_code=sparse_code)
where exists (select 1 from keep_rxe where drug_concept_code=sparse_code and drug_vocabulary_id='RxNorm Extension');

update ingredient_strength_stage set drug_concept_code=(select tight_code from keep_rxe where ingredient_concept_code=sparse_code)
where exists (select 1 from keep_rxe where ingredient_concept_code=sparse_code and ingredient_vocabulary_id='RxNorm Extension');

-- Fix pack_content_stage
update pack_content_stage set pack_concept_code=(select tight_code from keep_rxe where pack_concept_code=sparse_code)
where exists (select 1 from keep_rxe where pack_concept_code=sparse_code and pack_vocabulary_id='RxNorm Extension');

update pack_content_stage set drug_concept_code=(select tight_code from keep_rxe where drug_concept_code=sparse_code)
where exists (select 1 from keep_rxe where drug_concept_code=sparse_code and drug_vocabulary_id='RxNorm Extension');

/**************
* 5. Clean up *
**************/
drop table drop_rxe purge;
drop table keep_rxe purge;
drop sequence omop_replace purge;
