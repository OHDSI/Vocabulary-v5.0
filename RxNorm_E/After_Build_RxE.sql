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
  where relationship_id='Maps to' and vocabulary_id_1='Rxfix' and vocabulary_id_2='RxNorm Extension'
),
maps2 as ( -- flipping length difference l to be between 0 and 1
  select c1_code, c2_code, match, case when l>1 then 1/l else l end as l
  from maps
)
select distinct 
  first_value(c1_code) over (partition by c2_code order by match, l, c1_code) as rxf_code,
  c2_code as rxe_code
from maps2
;

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

create table keep_rxe (
  sparce_code varchar2(50),
  tight_code varchar2(50)
) nologging;

-- generate OMOP codes for new concepts
insert /*+ APPEND */ into keep_rxe
select concept_code as sparce_code, 'OMOP'||omop_seq.nextval as tight_code
from concept_stage 
where vocabulary_id='RxNorm Extension'
and concept_code not in (select rxe_code from drop_rxe) -- those will be replaced
;
commit;

/*************************************
* 2. Fix the Rxfix/RxO end of things *
*************************************/
-- Delete those Maps to relationships for the ones that are updated with the old codes
delete from concept_relationship_stage where rowid in (
  select r.rowid from concept_relationship_stage r join drop_rxe on r.concept_code_1=rxf_code and r.concept_code_2=rxe_code 
  where r.relationship_id='Maps to' and r.vocabulary_id_1='Rxfix' and r.vocabulary_id_2='RxNorm Extension'
);

-- Delete those Rxfix concepts that are updated in RxE
delete from concept where concept_code in (select rxf_code from drop_rxe where vocabulary_id='Rxfix');

-- Obsolete the remaining ones
update concept set vocabulary_id='RxNorm Extension', invalid_reason='U'
where concept_code in (
  select concept_code_1 from concept_relationship_stage where vocabulary_id_1='Rxfix' and relationship_id='Maps to'
) and vocabulary_id='RxO';

-- Change Maps to to Concept replaced by since it is both RxNorm Extension now
update concept_relationship_stage set relationship_id='Concept replaced by' where relationship_id='Maps to';

/********************************************************************
* 3. Change the concept_codes of the RxE we give the old codes back *
********************************************************************/
-- Replace RxNorm Extension concept_codes in concept_stage and concept_relationship_stage with old RxO codes
update concept_stage set (vocabulary_id, concept_code)=(
  select 'RxNorm Extension', rxf_code from drop_rxe where concept_code=rxe_code
)
where exists (
  select 1 from drop_rxe where concept_code=rxe_code
);

update concept_relationship_stage set (concept_code_1, vocabulary_id_1)=(
  select rxf_code, 'RxNorm Extension' from drop_rxe where concept_code_1=rxe_code
)
where exists (
  select 1 from drop_rxe where concept_code_1=rxe_code and vocabulary_id_1='RxNorm Extension'
);

update concept_relationship_stage set (concept_code_2, vocabulary_id_2)=(
  select rxf_code, 'RxNorm Extension' from drop_rxe where concept_code_2=rxe_code
)
where exists (
  select 1 from drop_rxe where concept_code_2=rxe_code and vocabulary_id_2='RxNorm Extension'
);

/**********************************************************************************************
* 4. Condense the remaining RxNorm Extension codes so they don't take up as much number space *
**********************************************************************************************/
-- Replace RxNorm Extension concept_codes in concept_stage and concept_relationship_stage with old RxO codes
update concept_stage set (vocabulary_id, concept_code)=(select 'RxNorm Extension', tight_code from keep_rxe where concept_code=sparse_code)
where exists (select 1 from drop_rxe where concept_code=sparse_code and vocabulary_id_1='RxNorm Extension');

-- Replace the sparse with the tight RxNorm Extension code
update concept_relationship_stage set concept_code_1=(select tight_code from keep_rxe where concept_code_1=sparse_code)
where exists (select 1 from keep_rxe where concept_code_1=sparse_code and vocabulary_id_1='RxNorm Extension');

update concept_relationship_stage set concept_code_2=(select tight_code from keep_rxe where concept_code_2=sparse_code)
where exists (select 1 from keep_rxe where concept_code_2=sparse_code and vocabulary_id_2='RxNorm Extension');

/**************
* 5. Clean up *
**************/
drop table drop_rxe purge;
drop table keep_rxe purge;
drop sequence omop_replace purge;
