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
* Authors: Timur Vakhitov, Christian Reich
* Date: 2016
**************************************************************************/

/*********************************************
* Script to create input tables according to *
* http://www.ohdsi.org/web/wiki/doku.php?id=documentation:international_drugs *
* for HCPCS procedure drugs                  *
*********************************************/

-- Create products
create table drug_concept_stage (
  concept_name varchar2(255),
  vocabulary_id varchar2(20),
  concept_class_id varchar2(20),
  standard_concept varchar2(1),
  concept_code varchar2(255), -- need a long one because Ingredient and Dose Form string used as concept_code
  possible_excipient varchar2(1),
  valid_start_date date,
  valid_end_date date,
  invalid_reason varchar2(1),
  dose_form varchar2(20) -- temporary till we create relationships, then dropped
)
NOLOGGING;

create table relationship_to_concept (
  concept_code_1 varchar2(255),
  vocabulary_id_1 varchar2(20),
  concept_id_2 integer,
  precedence integer,
  conversion_factor float
)
NOLOGGING;

create table internal_relationship_stage (
  concept_code_1 varchar2(255),
  vocabulary_id_1 varchar2(20),
  concept_code_2 varchar2(255),
  vocabulary_id_2 varchar2(20)
)
NOLOGGING;

create table ds_stage (
  drug_concept_code	varchar2(255),  --	The source code of the Drug or Drug Component, either Branded or Clinical.
  ingredient_concept_code	varchar2(255), --	The source code for one of the Ingredients.
  amount_value float,	-- The numeric value for absolute content (usually solid formulations).
  amount_unit varchar2(255), --	The verbatim unit of the absolute content (solids).
  numerator_value float, --	The numerator value for a concentration (usally liquid formulations).
  numerator_unit varchar(255), --	The verbatim numerator unit of a concentration (liquids).
  denominator_value float, --	The denominator value for a concentration (usally liquid formulations).
  denominator_unit varchar2(255), --	The verbatim denominator unit of a concentration (liquids).
  box_size integer
)
NOLOGGING;

/************************************
* 1. Create Procedure Drug products *
*************************************/
insert /*+ APPEND */ into drug_concept_stage
select * from (
  select distinct concept_name, 'HCPCS' as vocabulary_id, 'Procedure Drug' as concept_class_id, null as standard_concept, concept_code, null as possible_excipient, 
  null as valid_start_date, null as valid_end_date, null as invalid_reason,
  case 
-- things that look like procedure drugs but are not
    when lower(concept_name) like '%dialysate%' then 'Device'
    when lower(concept_name) like 'platelets%' then 'Device'
    when lower(concept_name) like 'red blood cells, %' then 'Device'
    when lower(concept_name) like 'whole blood%' then 'Device'
    when lower(concept_name) like 'granulocytes, %' then 'Device'
    when lower(concept_name) like '%pharma supply fee%' then 'Observation'
    when lower(concept_name) like 'plasma, %' then 'Device'
    when lower(concept_name) like '%frozen plasma%' then 'Device'
    when lower(concept_name) like '%nutrition%' then 'Device'
    when lower(concept_name) like '%insulin%delivery%device%' then 'Device'
    when lower(concept_name) like 'injection%procedure%' then 'Procedure'
    when lower(concept_name) like '%ocular implant%' then 'Device'
    when lower(concept_name) like '%cochlear implant%' then 'Device'
    when lower(concept_name) like '%implant system%' and lower(concept_name) not like '%(contraceptive)%' then 'Device'
    when lower(concept_name) like '%porcine implant%' then 'Device'
    when lower(concept_name) like '%eye patch%' then 'Device'
    when lower(concept_name) like '%, per visit%' then 'Procedure'
    when lower(concept_name) like '%contrast agent%' then 'Device'
    when lower(concept_name) like '%contrast material%' then 'Device'
    when lower(concept_name) like '%, per %millicurie%' then 'Device'
    when lower(concept_name) like '%, per %microcurie%' then 'Device'
    when lower(concept_name) like '%up to%millicurie%' then 'Device'
    when lower(concept_name) like '%up to%microcurie%' then 'Device'
    when lower(concept_name) like '%iodine i-131%' then 'Device'
    when lower(concept_name) like '%technetium%' then 'Device'
    when lower(concept_name) like '%dermal%substitute%' then 'Device'
    when lower(concept_name) like '%document%' then 'Observation'
    when lower(concept_name) like '%enteral formula%' then 'Device'
    when lower(concept_name) like '%vaccine status%' then 'Observation'
    when lower(concept_name) like '%ordered%' then 'Observation'
    when lower(concept_name) like '%prescribed%' then 'Observation'
    when lower(concept_name) like '%patient%' then 'Observation'
    when lower(concept_name) like '%person%' then 'Observation'
    when lower(concept_name) like '%supply fee%' then 'Observation'
    when lower(concept_name) like '%matrix%' then 'Device'
-- remove inhalant solutions before designating "administered" as Observation
    when lower(concept_name) like '%suppository%' then 'Suppository'
    when lower(concept_name) like 'injection%' then 'Injection'
    when lower(concept_name) like '%inhalation solution%' then 'Inhalant'
-- resume taking out non-drug
    when lower(concept_name) like '%infusion pump%' then 'Device'
    when lower(concept_name) like '%administered%' and lower(concept_name) not like '%through dme%' then 'Observation'
-- Procedure drug definitions
    when lower(concept_name) like '%vaccine%' then 'Vaccine'
    when lower(concept_name) like '%immunization%' then 'Vaccine'
    when lower(concept_name) like '%dextrose%' then 'Unknown'
    when lower(concept_name) like '%nasal spray, %' then 'Spray'
    when lower(concept_name) like '%patch, %' then 'Patch'
    when lower(concept_name) like 'infusion, %' then 'Infusion'
    when lower(concept_name) like '% patch%' then 'Patch'
    when lower(concept_name) like '%parenteral, %' then 'Parenteral' -- like Injection, but different parsing. After Ingredient parsing changed to Injection
    when lower(concept_name) like '%topical, %' then 'Topical'
    when lower(concept_name) like '%for topical%' then 'Topical'
    when regexp_like (concept_name, ', implant', 'i') then 'Implant'
    when lower(concept_name) like '%oral, %' then 'Oral'
    when lower(concept_name) like '%, oral%' then 'Oral'
    when lower(concept_name) like '% per i.u.%' then 'Unit' -- like Injection, but different parsing. After Ingredient parsing to Injection
    when lower(concept_name) like '%, each unit%' then 'Unit' -- like Injection, but different parsing. After Ingredient parsing to Injection
    when lower(concept_name) like '% per instillation%' then 'Instillation'
    when lower(concept_name) like '%per dose' then 'Unknown'
    when regexp_like(concept_name, 'cd54\+ cell', 'i') then 'Unknown'    
    when regexp_like (concept_name, '([;,] |per |up to )[0-9\.,]+ ?(g|mg|ml|microgram|units?|cc)', 'i') then 'Unknown'
  end as dose_form -- will be turned into a relationship
  from concept
  where vocabulary_id='HCPCS'
)
where dose_form is not null
and dose_form not in ('Device', 'Procedure', 'Observation')
-- and concept_name is not null
;
commit;

/*******************************
* 2. Create parsed Ingredients *
********************************/
-- Fix spelling so parser will find
update drug_concept_stage set concept_name = regexp_replace(lower(concept_name), 'insulin,', 'insulin') where lower(concept_name) like '%insulin%';
update drug_concept_stage set concept_name = regexp_replace(lower(concept_name), 'albuterol.+?ipratropium bromide, ', 'albuterol/ipratropium bromide ') where lower(concept_name) like '%albuterol%ipratropium%';
update drug_concept_stage set concept_name = regexp_replace(lower(concept_name), 'doxorubicin hydrochloride, liposomal', 'doxorubicin hydrochloride liposomal') where lower(concept_name) like '%doxorubicin%';
update drug_concept_stage set concept_name = regexp_replace(lower(concept_name), 'injectin,', 'injection') where lower(concept_name) like 'injectin%';
update drug_concept_stage set concept_name = regexp_replace(lower(concept_name), 'interferon,', 'interferon') where lower(concept_name) like '%interferon%';

-- Create temp holding table to unique the resulting 
create table drug_concept_stage_tmp nologging as
select * from drug_concept_stage where 1=0;

-- Injections
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, null as standard_concept, 
  regexp_replace(regexp_replace(lower(concept_name), 'injection,? (iv, )?([^,]+).*', '\1|\2'), '.*?\|(.+)', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Injection' -- and concept_name like '%betamethasone%'
;
commit;
-- Vaccines
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, null as standard_concept, 
  regexp_replace(regexp_replace(lower(concept_name), '(.+?vaccine)(.+?for intramuscular use \(.+?\))?(.+vaccine)?', '\1\2'), '.+ of ', '') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Vaccine' 
;
commit;
-- Orals
insert /*+ APPEND */into drug_concept_stage_tmp
select 
  '' as concept_name, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, null as standard_concept, lower(regexp_substr(c1_cleanname, '[^,]+')) as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from (
  select concept_name, regexp_replace(concept_name, ',?;? ?oral,? ?', ', ') as c1_cleanname
  from drug_concept_stage where dose_form='Oral'
) 
;
commit;
-- Units
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, null as standard_concept, regexp_replace(lower(concept_name), '(.+?),? ?(per|each) (unit|i.u.).*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Unit' 
;
commit;
-- Instillations
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, null as standard_concept, regexp_replace(lower(concept_name), '(.+?),? ?per instillation.*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Instillation' 
;
commit;
-- Patches
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, null as standard_concept, regexp_replace(regexp_replace(lower(concept_name), '(.+?),? ?(per )?patch.*', '\1'), '\d+(%| ?mg)', '') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Patch' 
;
commit;
-- Sprays
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, null as standard_concept, regexp_replace(lower(concept_name), '(.+?),? ?(nasal )?spray.*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Spray'
;
commit;
-- Infusions
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, null as standard_concept, 
  regexp_replace(lower(concept_name), 'infusion,? (.+?) ?,.*', '\1') as concept_code, null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Infusion'
;
commit;
-- Guess Topicals
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, null as standard_concept, regexp_replace(lower(concept_name), '(.+?)(, | for )topical.*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Topical'
;
commit;
-- Implants
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, null as standard_concept, regexp_replace(lower(concept_name), '(.+?), implant.*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Implant'
;
commit;
-- Parenterals
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, null as standard_concept, regexp_replace(lower(concept_name), '(.+?), parenteral.*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Parenteral'
;
commit;
-- Suppositories
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, null as standard_concept, regexp_replace(lower(concept_name), '(.+?),? ?(urethral )?(rectal\/)?suppository.*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Suppository'
;
commit;
-- Inhalant
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, null as standard_concept, 
  regexp_replace(lower(concept_name), '(.+?),? ?(administered as )?(all formulations including separated isomers, )?inhalation solution.*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Inhalant'
;
commit;
-- Unknown
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, null as standard_concept, 
  regexp_replace(regexp_replace(lower(concept_name), '(.+?)(, |; | \(?for | gel |sinus implant| implant| per).*', '\1'), '(administration and supply of )?(.+)', '\2') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Unknown'
;
commit;

-- push distinct new ingredients
insert /*+ APPEND */ into drug_concept_stage select distinct * from drug_concept_stage_tmp;
commit;

-- Create relationships between Procedure Drugs and its parsed ingredients
-- Injections
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1, vocabulary_id as vocabulary_id_1, 
  regexp_replace(regexp_replace(lower(concept_name), 'injection,? (iv, )?([^,]+).*', '\1|\2'), '.*?\|(.+)', '\1') as concept_code_2, 
  vocabulary_id as vocabulary_id_2
from drug_concept_stage where dose_form='Injection' -- and length(regexp_substr(concept_name, ' [^,]+'))>3
;
commit;
-- Vaccines
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1, vocabulary_id as vocabulary_id_1, 
  regexp_replace(regexp_replace(lower(concept_name), '(.+?vaccine)(.+?for intramuscular use \(.+?\))?(.+vaccine)?', '\1\2'), '.+ of ', '') as concept_code_2, 
  vocabulary_id as vocabulary_id_2
from drug_concept_stage where dose_form='Vaccine' 
;
commit;
-- Orals
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1, vocabulary_id as vocabulary_id_1, lower(regexp_substr(c1_cleanname, '[^,]+')) as concept_code_2, 
  vocabulary_id as vocabulary_id_2
from (
  select concept_code, vocabulary_id, regexp_replace(concept_name, ',?;? ?oral,? ?', ', ') as c1_cleanname
  from drug_concept_stage where dose_form='Oral'
) 
;
commit;
-- Units
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1, vocabulary_id as vocabulary_id_1, regexp_replace(lower(concept_name), '(.+?),? ?(per|each) (unit|i.u.).*', '\1') as concept_code_2, 
  vocabulary_id as vocabulary_id_2
from drug_concept_stage where dose_form='Unit' 
;
commit;
-- Instillations
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1, vocabulary_id as vocabulary_id_1, regexp_replace(lower(concept_name), '(.+?),? ?per instillation.*', '\1') as concept_code_2, 
  vocabulary_id as vocabulary_id_2
from drug_concept_stage where dose_form='Instillation' 
;
commit;
-- Patches
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1, vocabulary_id as vocabulary_id_1, regexp_replace(regexp_replace(lower(concept_name), '(.+?),? ?(per )?patch.*', '\1'), '\d+(%| ?mg)', '') as concept_code_2, 
  vocabulary_id as vocabulary_id_2
from drug_concept_stage where dose_form='Patch' 
;
commit;
-- Sprays
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1, vocabulary_id as vocabulary_id_1, regexp_replace(lower(concept_name), '(.+?),? ?(nasal )?spray.*', '\1') as concept_code_2, 
  vocabulary_id as vocabulary_id_2
from drug_concept_stage where dose_form='Spray'
;
commit;
-- Infusions
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1, vocabulary_id as vocabulary_id_1, regexp_replace(lower(concept_name), 'infusion,? (.+?) ?,.*', '\1') as concept_code_2, vocabulary_id as vocabulary_id_2
from drug_concept_stage where dose_form='Infusion'
;
commit;
-- Guess Topicals
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1, vocabulary_id as vocabulary_id_1, regexp_replace(lower(concept_name), '(.+?)(, | for )topical.*', '\1') as concept_code_2, 
  vocabulary_id as vocabulary_id_2
from drug_concept_stage where dose_form='Topical'
;
commit;
-- Implants
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1, vocabulary_id as vocabulary_id_1, regexp_replace(lower(concept_name), '(.+?), implant.*', '\1') as concept_code_2, 
  vocabulary_id as vocabulary_id_2
from drug_concept_stage where dose_form='Implant'
;
commit;
-- Parenterals
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1, vocabulary_id as vocabulary_id_1, regexp_replace(lower(concept_name), '(.+?), parenteral.*', '\1') as concept_code_2, 
  vocabulary_id as vocabulary_id_2
from drug_concept_stage where dose_form='Parenteral'
;
commit;
-- Suppositories
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1, vocabulary_id as vocabulary_id_1, regexp_replace(lower(concept_name), '(.+?),? ?(urethral )?(rectal\/)?suppository.*', '\1') as concept_code_2, 
  vocabulary_id as vocabulary_id_2
from drug_concept_stage where dose_form='Suppository'
;
commit;
-- Inhalant
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1, vocabulary_id as vocabulary_id_1, 
  regexp_replace(lower(concept_name), '(.+?),? ?(administered as )?(all formulations including separated isomers, )?inhalation solution.*', '\1') as concept_code_2, 
  vocabulary_id as vocabulary_id_2
from drug_concept_stage where dose_form='Inhalant'
;
commit;
-- Unknown
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1, vocabulary_id as vocabulary_id_1, 
  regexp_replace(regexp_replace(lower(concept_name), '(.+?)(, |; | \(?for | gel |sinus implant| implant| per).*', '\1'), '(administration and supply of )?(.+)', '\2') as concept_code_2, 
  vocabulary_id as vocabulary_id_2
from drug_concept_stage where dose_form='Unknown'
;
commit;

-- Manually create mappings from Ingredients to RxNorm ingredients
begin
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('(e.g. liquid)', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('5% dextrose/water (500 ml = 1 unit)', 'HCPCS', 1560524, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('abarelix', 'HCPCS', 19010868, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('abatacept', 'HCPCS', 1186087, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('abciximab', 'HCPCS', 19047423, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('abobotulinumtoxina', 'HCPCS', 40165377, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('acetaminophen', 'HCPCS', 1125315, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('acetazolamide sodium', 'HCPCS', 929435, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('acetylcysteine', 'HCPCS', 1139042, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('acyclovir', 'HCPCS', 1703687, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('adalimumab', 'HCPCS', 1119119, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('adenosine', 'HCPCS', 1309204, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('adenosine for diagnostic use', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('adenosine for therapeutic use', 'HCPCS', 1309204, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('administration', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ado-trastuzumab emtansine', 'HCPCS', 43525787, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('adrenalin', 'HCPCS', 1343916, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('aflibercept', 'HCPCS', 40244266, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('agalsidase beta', 'HCPCS', 1525746, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('alatrofloxacin mesylate', 'HCPCS', 19018154, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('albumin (human)', 'HCPCS', 1344143, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('albuterol', 'HCPCS', 1154343, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('aldesleukin', 'HCPCS', 1309770, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('alefacept', 'HCPCS', 909959, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('alemtuzumab', 'HCPCS', 1312706, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('alglucerase', 'HCPCS', 19057354, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('alglucosidase alfa', 'HCPCS', 19088328, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('alglucosidase alfa (lumizyme)', 'HCPCS', 19088328, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('alpha 1 proteinase inhibitor (human)', 'HCPCS', 40181679, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('alprostadil', 'HCPCS', 1381504, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('alteplase recombinant', 'HCPCS', 1347450, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('amantadine hydrochloride', 'HCPCS', 19087090, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('amifostine', 'HCPCS', 1350040, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('amikacin sulfate', 'HCPCS', 1790868, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('aminocaproic acid', 'HCPCS', 1369939, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('aminolevulinic acid hcl', 'HCPCS', 19025194, null); -- it's meant methyl 5-aminolevulinate
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('aminophyllin', 'HCPCS', 1105775, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('amiodarone hydrochloride', 'HCPCS', 1309944, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('amitriptyline hcl', 'HCPCS', 710062, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('amobarbital', 'HCPCS', 712757, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('amphotericin b', 'HCPCS', 1717240, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('amphotericin b cholesteryl sulfate complex', 'HCPCS', 1717240, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('amphotericin b lipid complex', 'HCPCS', 19056402, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('amphotericin b liposome', 'HCPCS', 19056402, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ampicillin sodium', 'HCPCS', 1717327, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('anastrozole', 'HCPCS', 1348265, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('anidulafungin', 'HCPCS', 19026450, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('anistreplase', 'HCPCS', 19044890, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('anti-inhibitor', 'HCPCS', 19080406, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('antiemetic drug', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('antithrombin iii (human)', 'HCPCS', 1436169, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('antithrombin recombinant', 'HCPCS', 1436169, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('apomorphine hydrochloride', 'HCPCS', 837027, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('aprepitant', 'HCPCS', 936748, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('aprotonin', 'HCPCS', 19000729, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('arbutamine hcl', 'HCPCS', 19086330, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('arformoterol', 'HCPCS', 1111220, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('argatroban', 'HCPCS', 1322207, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('aripiprazole', 'HCPCS', 757688, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('arsenic trioxide', 'HCPCS', 19010961, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('artificial saliva', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('asparaginase', 'HCPCS', 19012585, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('asparaginase (erwinaze)', 'HCPCS', 19055717, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('asparaginase erwinia chrysanthemi', 'HCPCS', 43533115, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('atropine', 'HCPCS', 914335, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('atropine sulfate', 'HCPCS', 914335, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('aurothioglucose', 'HCPCS', 1163570, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('autologous cultured chondrocytes', 'HCPCS', 40224705, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('azacitidine', 'HCPCS', 1314865, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('azathioprine', 'HCPCS', 19014878, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('azithromycin', 'HCPCS', 1734104, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('azithromycin dihydrate', 'HCPCS', 1734104, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('aztreonam', 'HCPCS', 1715117, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('baclofen', 'HCPCS', 715233, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('basiliximab', 'HCPCS', 19038440, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('bcg (intravesical)', 'HCPCS', 19086176, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('becaplermin', 'HCPCS', 912476, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('beclomethasone', 'HCPCS', 1115572, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('belatacept', 'HCPCS', 40239665, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('belimumab', 'HCPCS', 40236987, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('belinostat', 'HCPCS', 45776670, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('bendamustine hcl', 'HCPCS', 19015523, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('benztropine mesylate', 'HCPCS', 719174, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('betamethasone', 'HCPCS', 920458, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('betamethasone acetate 3 mg and betamethasone sodium phosphate 3 mg', 'HCPCS', 920458, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('betamethasone sodium phosphate', 'HCPCS', 920458, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('bethanechol chloride', 'HCPCS', 937439, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('bevacizumab', 'HCPCS', 1397141, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('biperiden lactate', 'HCPCS', 724908, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('bitolterol mesylate', 'HCPCS', 1138050, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('bivalirudin', 'HCPCS', 19084670, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('blinatumomab', 'HCPCS', 45892531, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('bleomycin sulfate', 'HCPCS', 1329241, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('bortezomib', 'HCPCS', 1336825, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('brentuximab vedotin', 'HCPCS', 40241969, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('brompheniramine maleate', 'HCPCS', 1130863, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('budesonide', 'HCPCS', 939259, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('bumetanide', 'HCPCS', 932745, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('bupivacaine liposome', 'HCPCS', 40244151, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('bupivicaine hydrochloride', 'HCPCS', 732893, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('buprenorphine', 'HCPCS', 1133201, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('buprenorphine hydrochloride', 'HCPCS', 1133201, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('bupropion hcl sustained release tablet', 'HCPCS', 750982, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('busulfan', 'HCPCS', 1333357, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('butorphanol tartrate', 'HCPCS', 1133732, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('c-1 esterase inhibitor (human)', 'HCPCS', 45892906, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('c1 esterase inhibitor (human)', 'HCPCS', 45892906, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('c1 esterase inhibitor (recombinant)', 'HCPCS', 45892906, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('c-1 esterase inhibitor (recombinant)', 'HCPCS', 45892906, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cabazitaxel', 'HCPCS', 40222431, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cabergoline', 'HCPCS', 1558471, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('caffeine citrate', 'HCPCS', 1134439, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('calcitonin salmon', 'HCPCS', 1537655, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('calcitriol', 'HCPCS', 19035631, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('calcitrol', 'HCPCS', 19035631, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('calcium gluconate', 'HCPCS', 19037038, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('canakinumab', 'HCPCS', 40161669, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cangrelor', 'HCPCS', 46275677, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('capecitabine', 'HCPCS', 1337620, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('capsaicin', 'HCPCS', 939881, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('capsaicin ', 'HCPCS', 939881, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('carboplatin', 'HCPCS', 1344905, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('carfilzomib', 'HCPCS', 42873638, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('carmustine', 'HCPCS', 1350066, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('caspofungin acetate', 'HCPCS', 1718054, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cefazolin sodium', 'HCPCS', 1771162, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cefepime hydrochloride', 'HCPCS', 1748975, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cefoperazone sodium', 'HCPCS', 1773402, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cefotaxime sodium', 'HCPCS', 1774470, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cefotetan disodium', 'HCPCS', 1774932, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cefoxitin sodium', 'HCPCS', 1775741, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ceftaroline fosamil', 'HCPCS', 40230597, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ceftazidime', 'HCPCS', 1776684, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ceftizoxime sodium', 'HCPCS', 1777254, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ceftriaxone sodium', 'HCPCS', 1777806, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('centruroides (scorpion) immune f(ab)2 (equine)', 'HCPCS', 40241715, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('centruroides immune f(ab)2', 'HCPCS', 40241715, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cephalothin sodium', 'HCPCS', 19086759, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cephapirin sodium', 'HCPCS', 19086790, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('certolizumab pegol', 'HCPCS', 912263, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cetuximab', 'HCPCS', 1315411, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('chlorambucil', 'HCPCS', 1390051, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('chloramphenicol sodium succinate', 'HCPCS', 990069, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('chlordiazepoxide hcl', 'HCPCS', 990678, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('chlorhexidine containing antiseptic', 'HCPCS', 1790812, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('chloroprocaine hydrochloride', 'HCPCS', 19049410, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('chloroquine hydrochloride', 'HCPCS', 1792515, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('chlorothiazide sodium', 'HCPCS', 992590, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('chlorpromazine hcl', 'HCPCS', 794852, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('chlorpromazine hydrochloride', 'HCPCS', 794852, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('chorionic gonadotropin', 'HCPCS', 1563600, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cidofovir', 'HCPCS', 1745072, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cilastatin sodium; imipenem', 'HCPCS', 1797258, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cimetidine hydrochloride', 'HCPCS', 997276, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ciprofloxacin for intravenous infusion', 'HCPCS', 1797513, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cisplatin', 'HCPCS', 1397599, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cladribine', 'HCPCS', 19054825, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('clevidipine butyrate', 'HCPCS', 19089969, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('clindamycin phosphate', 'HCPCS', 997881, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('clofarabine', 'HCPCS', 19054821, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('clonidine hydrochloride', 'HCPCS', 1398937, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('clozapine', 'HCPCS', 800878, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('codeine phosphate', 'HCPCS', 1201620, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('colchicine', 'HCPCS', 1101554, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('colistimethate sodium', 'HCPCS', 1701677, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('collagenase', 'HCPCS', 980311, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('collagenase clostridium histolyticum', 'HCPCS', 40172153, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('contraceptive supply, hormone containing', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('corticorelin ovine triflutate', 'HCPCS', 19020789, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('corticotropin', 'HCPCS', 1541079, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cosyntropin', 'HCPCS', 19008009, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cosyntropin (cortrosyn)', 'HCPCS', 19008009, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cromolyn sodium', 'HCPCS', 1152631, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('crotalidae polyvalent immune fab (ovine)', 'HCPCS', 19071744, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cryoprecipitate', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cyclophosphamide', 'HCPCS', 1310317, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cyclosporin', 'HCPCS', 19010482, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cyclosporine', 'HCPCS', 19010482, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cymetra', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cytarabine', 'HCPCS', 1311078, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cytarabine liposome', 'HCPCS', 40175460, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('cytomegalovirus immune globulin intravenous (human)', 'HCPCS', 586491, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('d5w', 'HCPCS', 1560524, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dacarbazine', 'HCPCS', 1311409, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('daclizumab', 'HCPCS', 19036892, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dactinomycin', 'HCPCS', 1311443, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dalbavancin', 'HCPCS', 45774861, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dalteparin sodium', 'HCPCS', 1301065, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('daptomycin', 'HCPCS', 1786617, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('darbepoetin alfa', 'HCPCS', 1304643, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('daunorubicin', 'HCPCS', 1311799, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('daunorubicin citrate', 'HCPCS', 1311799, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('decitabine', 'HCPCS', 19024728, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('deferoxamine mesylate', 'HCPCS', 1711947, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('degarelix', 'HCPCS', 19058410, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('denileukin diftitox', 'HCPCS', 19051642, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('denosumab', 'HCPCS', 40222444, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('depo-estradiol cypionate', 'HCPCS', 1548195, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('desmopressin acetate', 'HCPCS', 1517070, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dexamethasone', 'HCPCS', 1518254, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dexamethasone acetate', 'HCPCS', 1518254, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dexamethasone intravitreal implant', 'HCPCS', 1518254, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dexamethasone sodium phosphate', 'HCPCS', 1518254, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dexrazoxane hydrochloride', 'HCPCS', 1353011, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dextran 40', 'HCPCS', 19019122, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dextran 75', 'HCPCS', 19019193, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dextroamphetamine sulfate', 'HCPCS', 719311, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dialysis/stress vitamin supplement', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('diazepam', 'HCPCS', 723013, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('diazoxide', 'HCPCS', 1523280, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dicyclomine hcl', 'HCPCS', 924724, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('didanosine (ddi)', 'HCPCS', 1724869, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('diethylstilbestrol diphosphate', 'HCPCS', 1525866, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('digoxin', 'HCPCS', 19045317, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('digoxin immune fab (ovine)', 'HCPCS', 19045317, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dihydroergotamine mesylate', 'HCPCS', 1126557, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dimenhydrinate', 'HCPCS', 928744, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dimercaprol', 'HCPCS', 1728903, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('diphenhydramine hcl', 'HCPCS', 1129625, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('diphenhydramine hydrochloride', 'HCPCS', 1129625, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dipyridamole', 'HCPCS', 1331270, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dmso', 'HCPCS', 928980, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dobutamine hydrochloride', 'HCPCS', 1337720, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('docetaxel', 'HCPCS', 1315942, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dolasetron mesylate', 'HCPCS', 903459, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dopamine hcl', 'HCPCS', 1337860, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('doripenem', 'HCPCS', 1713905, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dornase alfa', 'HCPCS', 1125443, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('doxercalciferol', 'HCPCS', 1512446, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('doxorubicin hydrochloride', 'HCPCS', 1338512, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('doxorubicin hydrochloride liposomal', 'HCPCS', 19051649, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dronabinol', 'HCPCS', 40125879, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('droperidol', 'HCPCS', 739323, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dyphylline', 'HCPCS', 1140088, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ecallantide', 'HCPCS', 40168938, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('eculizumab', 'HCPCS', 19080458, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('edetate calcium disodium', 'HCPCS', 43013616, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('edetate disodium', 'HCPCS', 19052936, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('efalizumab', 'HCPCS', 936429, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('elosulfase alfa', 'HCPCS', 44814525, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('enfuvirtide', 'HCPCS', 1717002, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('enoxaparin sodium', 'HCPCS', 1301025, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('epifix', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('epirubicin hcl', 'HCPCS', 1344354, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('epoetin alfa', 'HCPCS', 1301125, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('epoetin beta', 'HCPCS', 19001311, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('epoprostenol', 'HCPCS', 1354118, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('eptifibatide', 'HCPCS', 1322199, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ergonovine maleate', 'HCPCS', 1345205, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('eribulin mesylate', 'HCPCS', 40230712, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ertapenem sodium', 'HCPCS', 1717963, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('erythromycin lactobionate', 'HCPCS', 1746940, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('estradiol valerate', 'HCPCS', 1548195, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('estrogen  conjugated', 'HCPCS', 1549080, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('estrone', 'HCPCS', 1549254, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('etanercept', 'HCPCS', 1151789, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ethanolamine oleate', 'HCPCS', 19095285, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('etidronate disodium', 'HCPCS', 1552929, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('etoposide', 'HCPCS', 1350504, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('everolimus', 'HCPCS', 19011440, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('excellagen', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('exemestane', 'HCPCS', 1398399, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('factor ix', 'HCPCS', 1351935, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('factor ix (antihemophilic factor', 'HCPCS', 1351935, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('factor ix (antihemophilic factor, purified, non-recombinant)', 'HCPCS', 1351935, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('factor ix (antihemophilic factor, recombinant), alprolix', 'HCPCS', 1351935, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('factor ix (antihemophilic factor, recombinant), rixubis', 'HCPCS', 1351935, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('factor ix, complex', 'HCPCS', 1351935, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('factor viia (antihemophilic factor', 'HCPCS', 1352141, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('factor viii', 'HCPCS', 1352213, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('factor viii (antihemophilic factor', 'HCPCS', 1352213, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('factor viii (antihemophilic factor (porcine))', 'HCPCS', 1352213, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('factor viii (antihemophilic factor, human)', 'HCPCS', 1352213, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('factor viii (antihemophilic factor, recombinant)', 'HCPCS', 1352213, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('factor xiii (antihemophilic factor', 'HCPCS', 1352213, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('factor xiii a-subunit', 'HCPCS', 45776421, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('factor viii fc fusion (recombinant)', 'HCPCS', 45776421, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('famotidine', 'HCPCS', 953076, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('fentanyl citrate', 'HCPCS', 1154029, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ferric carboxymaltose', 'HCPCS', 43560392, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ferric pyrophosphate citrate solution', 'HCPCS', 46221255, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ferumoxytol', 'HCPCS', 40163731, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('filgrastim (g-csf)', 'HCPCS', 1304850, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('finasteride', 'HCPCS', 996416, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('floxuridine', 'HCPCS', 1355509, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('fluconazole', 'HCPCS', 1754994, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('fludarabine phosphate', 'HCPCS', 1395557, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('flunisolide', 'HCPCS', 1196514, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('fluocinolone acetonide', 'HCPCS', 996541, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('fluocinolone acetonide intravitreal implant', 'HCPCS', 996541, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('fluorouracil', 'HCPCS', 955632, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('fluphenazine decanoate', 'HCPCS', 756018, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('flutamide', 'HCPCS', 1356461, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('follitropin alfa', 'HCPCS', 1542948, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('follitropin beta', 'HCPCS', 1597235, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('fomepizole', 'HCPCS', 19022479, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('fomivirsen sodium', 'HCPCS', 19048999, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('fondaparinux sodium', 'HCPCS', 1315865, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('formoterol', 'HCPCS', 1196677, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('formoterol fumarate', 'HCPCS', 1196677, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('fosaprepitant', 'HCPCS', 19022131, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('foscarnet sodium', 'HCPCS', 1724700, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('fosphenytoin', 'HCPCS', 713192, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('fosphenytoin sodium', 'HCPCS', 713192, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('fulvestrant', 'HCPCS', 1304044, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('furosemide', 'HCPCS', 956874, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('gadobenate dimeglumine (multihance multipack)', 'HCPCS', 19097468, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('gadobenate dimeglumine (multihance)', 'HCPCS', 19097468, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('gadobutrol', 'HCPCS', 19048493, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('gadofosveset trisodium', 'HCPCS', 43012718, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('gadoterate meglumine', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('gadoteridol', 'HCPCS', 19097463, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('gadoxetate disodium', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('gallium nitrate', 'HCPCS', 42899259, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('galsulfase', 'HCPCS', 19078649, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('gamma globulin', 'HCPCS', 19117912, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ganciclovir', 'HCPCS', 1757803, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ganciclovir sodium', 'HCPCS', 1757803, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ganirelix acetate', 'HCPCS', 1536743, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('garamycin', 'HCPCS', 919345, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('gatifloxacin', 'HCPCS', 1789276, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('gefitinib', 'HCPCS', 1319193, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('gemcitabine hydrochloride', 'HCPCS', 1314924, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('gemtuzumab ozogamicin', 'HCPCS', 19098566, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('glatiramer acetate', 'HCPCS', 751889, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('glucagon hydrochloride', 'HCPCS', 1560278, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('glucarpidase', 'HCPCS', 42709319, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('glycopyrrolate', 'HCPCS', 963353, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('gold sodium thiomalate', 'HCPCS', 1152134, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('golimumab', 'HCPCS', 19041065, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('gonadorelin hydrochloride', 'HCPCS', 19089810, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('goserelin acetate', 'HCPCS', 1366310, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('graftjacket xpress', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('granisetron hydrochloride', 'HCPCS', 1000772, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('haloperidol', 'HCPCS', 766529, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('haloperidol decanoate', 'HCPCS', 766529, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hemin', 'HCPCS', 19067303, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('heparin sodium', 'HCPCS', 1367571, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hepatitis b immune globulin (hepagam b)', 'HCPCS', 501343, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hepatitis b vaccine', 'HCPCS', 528323, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hexaminolevulinate hydrochloride', 'HCPCS', 43532423, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('high risk population (use only with codes for immunization)', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('histrelin', 'HCPCS', 1366773, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('histrelin acetate', 'HCPCS', 1366773, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('home infusion therapy', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('human fibrinogen concentrate', 'HCPCS', 19044986, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('human plasma fibrin sealant', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hyaluronan or derivative', 'HCPCS', 787787, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hyaluronidase', 'HCPCS', 19073699, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hydralazine hcl', 'HCPCS', 1373928, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hydrocortisone acetate', 'HCPCS', 975125, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hydrocortisone sodium  phosphate', 'HCPCS', 975125, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hydrocortisone sodium succinate', 'HCPCS', 975125, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hydromorphone', 'HCPCS', 1126658, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hydromorphone hydrochloride', 'HCPCS', 1126658, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hydroxyprogesterone caproate', 'HCPCS', 19077143, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hydroxyurea', 'HCPCS', 1377141, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hydroxyzine hcl', 'HCPCS', 777221, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hydroxyzine pamoate', 'HCPCS', 777221, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hyoscyamine sulfate', 'HCPCS', 923672, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('hypertonic saline solution', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ibandronate sodium', 'HCPCS', 1512480, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ibuprofen', 'HCPCS', 1177480, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ibutilide fumarate', 'HCPCS', 19050087, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('icatibant', 'HCPCS', 40242044, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('idarubicin hydrochloride', 'HCPCS', 19078097, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('idursulfase', 'HCPCS', 19091430, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ifosfamide', 'HCPCS', 19078187, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('iloprost', 'HCPCS', 1344992, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('imatinib', 'HCPCS', 1304107, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('imiglucerase', 'HCPCS', 1348407, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('immune globulin', 'HCPCS', 19117912, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('immune globulin (bivigam)', 'HCPCS', 19117912, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('immune globulin (gammaplex)', 'HCPCS', 19117912, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('immune globulin (hizentra)', 'HCPCS', 19117912, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('immune globulin (privigen)', 'HCPCS', 19117912, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('immune globulin (vivaglobin)', 'HCPCS', 19117912, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('immunizations/vaccinations', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('incobotulinumtoxin a', 'HCPCS', 40224763, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('infliximab', 'HCPCS', 937368, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('influenza vaccine, recombinant hemagglutinin antigens, for intramuscular use (flublok)', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('influenza virus vaccine', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('influenza virus vaccine, split virus, for intramuscular use (agriflu)', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('injectable anesthetic', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('injectable bulking agent', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('injectable poly-l-lactic acid', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('insulin', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('insulin intermediate acting (nph or lente)', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('insulin long acting', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('insulin most rapid onset (lispro or aspart)', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('insulin per 5 units', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('insulin rapid onset', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('interferon alfa-2a', 'HCPCS', 1379969, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('interferon alfa-2b', 'HCPCS', 1380068, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('interferon alfacon-1', 'HCPCS', 1781314, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('interferon alfa-n3', 'HCPCS', 1385645, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('interferon beta-1a', 'HCPCS', 722424, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('interferon beta-1b', 'HCPCS', 713196, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('interferon gamma 1-b', 'HCPCS', 1380191, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pegylated interferon alfa-2a', 'HCPCS', 1714165, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pegylated interferon alfa-2b', 'HCPCS', 1797155, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('intravenous', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ipilimumab', 'HCPCS', 40238188, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ipratropium bromide', 'HCPCS', 1112921, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('irinotecan', 'HCPCS', 1367268, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('iron dextran', 'HCPCS', 1381661, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('iron dextran 165', 'HCPCS', 1381661, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('iron dextran 267', 'HCPCS', 1381661, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('iron sucrose', 'HCPCS', 1395773, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('irrigation solution', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('isavuconazonium', 'HCPCS', 46221284, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('isavuconazonium sulfate', 'HCPCS', 46221284, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('isoetharine hcl', 'HCPCS', 1181809, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('isoproterenol hcl', 'HCPCS', 1183554, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('itraconazole', 'HCPCS', 1703653, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ixabepilone', 'HCPCS', 19025348, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('kanamycin sulfate', 'HCPCS', 1784749, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ketorolac tromethamine', 'HCPCS', 1136980, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('lacosamide', 'HCPCS', 19087394, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('lanreotide', 'HCPCS', 1503501, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('lanreotide acetate', 'HCPCS', 1503501, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('laronidase', 'HCPCS', 1543229, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('lepirudin', 'HCPCS', 19092139, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('leucovorin calcium', 'HCPCS', 1388796, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('leuprolide acetate', 'HCPCS', 1351541, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('leuprolide acetate (for depot suspension)', 'HCPCS', 1351541, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('levalbuterol', 'HCPCS', 1192218, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('levamisole hydrochloride', 'HCPCS', 1389464, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('levetiracetam', 'HCPCS', 711584, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('levocarnitine', 'HCPCS', 1553610, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('levofloxacin', 'HCPCS', 1742253, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('levoleucovorin calcium', 'HCPCS', 40168303, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('levonorgestrel-releasing intrauterine contraceptive system', 'HCPCS', 1589505, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('levorphanol tartrate', 'HCPCS', 1189766, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('lidocaine hcl for intravenous infusion', 'HCPCS', 989878, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('lincomycin hcl', 'HCPCS', 1790692, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('linezolid', 'HCPCS', 1736887, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('liquid)', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('lomustine', 'HCPCS', 1391846, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('lorazepam', 'HCPCS', 791967, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('loxapine', 'HCPCS', 792263, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('lymphocyte immune globulin, antithymocyte globulin, equine', 'HCPCS', 19003476, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('lymphocyte immune globulin, antithymocyte globulin, rabbit', 'HCPCS', 19136207, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('magnesium sulfate', 'HCPCS', 19093848, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('mannitol', 'HCPCS', 994058, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('mecasermin', 'HCPCS', 1502877, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('mechlorethamine hydrochloride', 'HCPCS', 1394337, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('medroxyprogesterone acetate', 'HCPCS', 1500211, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('medroxyprogesterone acetate for contraceptive use', 'HCPCS', 1500211, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('megestrol acetate', 'HCPCS', 1300978, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('melphalan', 'HCPCS', 1301267, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('melphalan hydrochloride', 'HCPCS', 1301267, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('menotropins', 'HCPCS', 19125388, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('meperidine hydrochloride', 'HCPCS', 1102527, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('mepivacaine hydrochloride', 'HCPCS', 702774, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('mercaptopurine', 'HCPCS', 1436650, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('meropenem', 'HCPCS', 1709170, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('mesna', 'HCPCS', 1354698, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('metaproterenol sulfate', 'HCPCS', 1123995, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('metaraminol bitartrate', 'HCPCS', 19003303, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('methacholine chloride', 'HCPCS', 19024227, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('methadone', 'HCPCS', 1103640, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('methadone hcl', 'HCPCS', 1103640, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('methocarbamol', 'HCPCS', 704943, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('methotrexate', 'HCPCS', 1305058, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('methotrexate sodium', 'HCPCS', 1305058, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('methyl aminolevulinate (mal)', 'HCPCS', 924120, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('methyldopate hcl', 'HCPCS', 1305496, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('methylene blue', 'HCPCS', 905518, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('methylergonovine maleate', 'HCPCS', 1305637, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('methylnaltrexone', 'HCPCS', 909841, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('methylprednisolone', 'HCPCS', 1506270, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('methylprednisolone acetate', 'HCPCS', 1506270, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('methylprednisolone sodium succinate', 'HCPCS', 1506270, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('metoclopramide hcl', 'HCPCS', 906780, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('metronidazole', 'HCPCS', 1707164, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('micafungin sodium', 'HCPCS', 19018013, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('midazolam hydrochloride', 'HCPCS', 708298, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('mifepristone', 'HCPCS', 1508439, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('milrinone lactate', 'HCPCS', 1368671, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('minocycline hydrochloride', 'HCPCS', 1708880, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('minoxidil', 'HCPCS', 1309068, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('misoprostol', 'HCPCS', 1150871, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('mitomycin', 'HCPCS', 1389036, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('mitoxantrone hydrochloride', 'HCPCS', 1309188, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('mometasone furoate ', 'HCPCS', 905233, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('morphine sulfate', 'HCPCS', 1110410, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('morphine sulfate (preservative-free sterile solution)', 'HCPCS', 1110410, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('moxifloxacin', 'HCPCS', 1716903, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('multiple vitamins', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('muromonab-cd3', 'HCPCS', 19051865, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('mycophenolate mofetil', 'HCPCS', 19003999, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('mycophenolic acid', 'HCPCS', 19012565, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('nabilone', 'HCPCS', 913440, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('nafcillin sodium', 'HCPCS', 1713930, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('nalbuphine hydrochloride', 'HCPCS', 1114122, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('naloxone hydrochloride', 'HCPCS', 1114220, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('naltrexone', 'HCPCS', 1714319, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('nandrolone decanoate', 'HCPCS', 1514412, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('nasal vaccine inhalation', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('natalizumab', 'HCPCS', 735843, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('nelarabine', 'HCPCS', 19002912, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('neostigmine methylsulfate', 'HCPCS', 717136, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('neoxflo or clarixflo', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('nesiritide', 'HCPCS', 1338985, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('nicotine', 'HCPCS', 718583, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('nivolumab', 'HCPCS', 45892628, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('noc drugs', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('non-radioactive', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('normal saline solution', 'HCPCS', 967823, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('obinutuzumab', 'HCPCS', 44507676, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ocriplasmin', 'HCPCS', 42904298, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('octafluoropropane microspheres', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('octreotide', 'HCPCS', 1522957, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ofatumumab', 'HCPCS', 40167582, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ofloxacin', 'HCPCS', 923081, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('olanzapine', 'HCPCS', 785788, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('omacetaxine mepesuccinate', 'HCPCS', 19069046, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('omalizumab', 'HCPCS', 1110942, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('onabotulinumtoxina', 'HCPCS', 40165651, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ondansetron', 'HCPCS', 1000560, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ondansetron 1 mg', 'HCPCS', 1000560, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ondansetron hydrochloride', 'HCPCS', 1000560, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ondansetron hydrochloride 8  mg', 'HCPCS', 1000560, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('oprelvekin', 'HCPCS', 1318030, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('oritavancin', 'HCPCS', 45776147, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('orphenadrine citrate', 'HCPCS', 724394, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('oseltamivir phosphate', 'HCPCS', 1799139, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('oxacillin sodium', 'HCPCS', 1724703, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('oxaliplatin', 'HCPCS', 1318011, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('oxygen contents', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('oxymorphone hcl', 'HCPCS', 1125765, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('oxytetracycline hcl', 'HCPCS', 925952, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('oxytocin', 'HCPCS', 1326115, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('paclitaxel', 'HCPCS', 1378382, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('paclitaxel protein-bound particles', 'HCPCS', 1378382, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('palifermin', 'HCPCS', 19038562, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('paliperidone palmitate', 'HCPCS', 703244, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('paliperidone palmitate extended release', 'HCPCS', 703244, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('palivizumab-rsv-igm', 'HCPCS', 537647, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('palonosetron hcl', 'HCPCS', 911354, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pamidronate disodium', 'HCPCS', 1511646, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('panitumumab', 'HCPCS', 19100985, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pantoprazole sodium', 'HCPCS', 948078, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('papaverine hcl', 'HCPCS', 1326901, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('peramivir', 'HCPCS', 40167569, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('paricalcitol', 'HCPCS', 1517740, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pasireotide long acting', 'HCPCS', 43012417, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pegademase bovine', 'HCPCS', 581480, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pegaptanib sodium', 'HCPCS', 19063605, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pegaspargase', 'HCPCS', 1326481, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pegfilgrastim', 'HCPCS', 1325608, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('peginesatide', 'HCPCS', 42709327, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pegloticase', 'HCPCS', 40226208, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pembrolizumab', 'HCPCS', 45775965, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pemetrexed', 'HCPCS', 1304919, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('penicillin g benzathine', 'HCPCS', 1728416, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('penicillin g benzathine and penicillin g procaine', 'HCPCS', 1728416, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('penicillin g potassium', 'HCPCS', 1728416, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('penicillin g procaine', 'HCPCS', 1728416, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pentamidine isethionate', 'HCPCS', 1730370, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pentastarch', 'HCPCS', 40161354, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pentazocine', 'HCPCS', 1130585, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pentobarbital sodium', 'HCPCS', 730729, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pentostatin', 'HCPCS', 19031224, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('perflexane lipid microspheres', 'HCPCS', 45775689, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('perflutren lipid microspheres', 'HCPCS', 19071160, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('perphenazine', 'HCPCS', 733008, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pertuzumab', 'HCPCS', 42801287, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('phenobarbital sodium', 'HCPCS', 734275, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('phentolamine mesylate', 'HCPCS', 1335539, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('phenylephrine hcl', 'HCPCS', 1135766, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('phenytoin sodium', 'HCPCS', 740910, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('phytonadione (vitamin k)', 'HCPCS', 19044727, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('piperacillin sodium', 'HCPCS', 1746114, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('plasma protein fraction (human)', 'HCPCS', 19025693, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('platelet rich plasma', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('plerixafor', 'HCPCS', 19017581, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('plicamycin', 'HCPCS', 19009165, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pneumococcal conjugate vaccine', 'HCPCS', 513909, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pneumococcal vaccine', 'HCPCS', 513909, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('porfimer sodium', 'HCPCS', 19087871, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('potassium chloride', 'HCPCS', 19049105, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pralatrexate', 'HCPCS', 40166461, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pralidoxime chloride', 'HCPCS', 1727468, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('prednisolone', 'HCPCS', 1550557, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('prednisolone acetate', 'HCPCS', 1550557, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('prednisone', 'HCPCS', 1551099, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('prescription drug', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('procainamide hcl', 'HCPCS', 1351461, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('procarbazine hydrochloride', 'HCPCS', 1351779, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('prochlorperazine', 'HCPCS', 752061, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('prochlorperazine maleate', 'HCPCS', 752061, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('progesterone', 'HCPCS', 1552310, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('promazine hcl', 'HCPCS', 19052903, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('promethazine hcl', 'HCPCS', 1153013, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('promethazine hydrochloride', 'HCPCS', 1153013, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('propofol', 'HCPCS', 753626, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('propranolol hcl', 'HCPCS', 1353766, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('protamine sulfate', 'HCPCS', 19054242, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('protein c concentrate', 'HCPCS', 42801108, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('prothrombin complex concentrate (human), kcentra', 'HCPCS', 44507865, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('protirelin', 'HCPCS', 19001701, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('pyridoxine hcl', 'HCPCS', 42903728, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('radiesse', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ramucirumab', 'HCPCS', 44818489, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ranibizumab', 'HCPCS', 19080982, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ranitidine hydrochloride', 'HCPCS', 961047, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('rasburicase', 'HCPCS', 1304565, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('regadenoson', 'HCPCS', 19090761, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('respiratory syncytial virus immune globulin', 'HCPCS', 19013765, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('reteplase', 'HCPCS', 19024191, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('rho d immune globulin', 'HCPCS', 535714, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('rho(d) immune globulin (human)', 'HCPCS', 535714, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('rilonacept', 'HCPCS', 19023450, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('rimabotulinumtoxinb', 'HCPCS', 40166020, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('rimantadine hydrochloride', 'HCPCS', 1763339, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('risperidone', 'HCPCS', 735979, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('rituximab', 'HCPCS', 1314273, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('romidepsin', 'HCPCS', 40168385, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('romiplostim', 'HCPCS', 19032407, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ropivacaine hydrochloride', 'HCPCS', 1136487, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('saquinavir', 'HCPCS', 1746244, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sargramostim (gm-csf)', 'HCPCS', 1308432, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sculptra', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('secretin', 'HCPCS', 19066188, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sermorelin acetate', 'HCPCS', 19077457, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sildenafil citrate', 'HCPCS', 1316262, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sincalide', 'HCPCS', 19067803, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('single vitamin/mineral/trace element', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sipuleucel-t', 'HCPCS', 40224095, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sirolimus', 'HCPCS', 19034726, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('siltuximab', 'HCPCS', 44818461, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sodium chloride', 'HCPCS', 967823, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sodium ferric gluconate complex in sucrose injection', 'HCPCS', 1399177, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sodium hyaluronate', 'HCPCS', 787787, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('somatrem', 'HCPCS', 1578181, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('somatropin', 'HCPCS', 1584910, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('spectinomycin dihydrochloride', 'HCPCS', 1701651, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('state supplied vaccine', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sterile cefuroxime sodium', 'HCPCS', 1778162, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sterile dilutant', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sterile saline or water', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sterile water', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sterile water/saline', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('streptokinase', 'HCPCS', 19136187, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('streptomycin', 'HCPCS', 1836191, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('streptozocin', 'HCPCS', 19136210, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('succinylcholine chloride', 'HCPCS', 836208, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sulfur hexafluoride lipid microsphere', 'HCPCS', 45892833, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sumatriptan succinate', 'HCPCS', 1140643, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('syringe', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('syringe with needle', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tacrine hydrochloride', 'HCPCS', 836654, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tacrolimus', 'HCPCS', 950637, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('taliglucerase alfa', 'HCPCS', 42800246, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('taliglucerace alfa', 'HCPCS', 42800246, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tamoxifen citrate', 'HCPCS', 1436678, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tbo-filgrastim', 'HCPCS', 43560301, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tedizolid phosphate', 'HCPCS', 45775686, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('telavancin', 'HCPCS', 40166675, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('temozolomide', 'HCPCS', 1341149, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('temsirolimus', 'HCPCS', 19092845, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tenecteplase', 'HCPCS', 19098548, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('teniposide', 'HCPCS', 19136750, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('terbutaline sulfate', 'HCPCS', 1236744, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('teriparatide', 'HCPCS', 1521987, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('testosterone cypionate', 'HCPCS', 1636780, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('testosterone enanthate', 'HCPCS', 1636780, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('testosterone pellet', 'HCPCS', 1636780, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('testosterone propionate', 'HCPCS', 1636780, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('testosterone suspension', 'HCPCS', 1636780, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('testosterone undecanoate', 'HCPCS', 1636780, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tetanus immune globulin', 'HCPCS', 561401, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tetracycline', 'HCPCS', 1836948, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('theophylline', 'HCPCS', 1237049, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('thiamine hcl', 'HCPCS', 19137312, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('thiethylperazine maleate', 'HCPCS', 1037358, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('thiotepa', 'HCPCS', 19137385, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('thyrotropin alpha', 'HCPCS', 19007721, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tigecycline', 'HCPCS', 1742432, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tinzaparin sodium', 'HCPCS', 1308473, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tirofiban hcl', 'HCPCS', 19017067, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tissue marker', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tobramycin', 'HCPCS', 902722, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tobramycin sulfate', 'HCPCS', 902722, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tocilizumab', 'HCPCS', 40171288, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tolazoline hcl', 'HCPCS', 19002829, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('topotecan', 'HCPCS', 1378509, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('torsemide', 'HCPCS', 942350, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tositumomab', 'HCPCS', 19068894, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('trastuzumab', 'HCPCS', 1387104, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('treprostinil', 'HCPCS', 1327256, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tretinoin', 'HCPCS', 903643, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('triamcinolone', 'HCPCS', 903963, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('triamcinolone acetonide', 'HCPCS', 903963, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('triamcinolone diacetate', 'HCPCS', 903963, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('triamcinolone hexacetonide', 'HCPCS', 903963, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('triflupromazine hcl', 'HCPCS', 19005104, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('trimethobenzamide hcl', 'HCPCS', 942799, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('trimethobenzamide hydrochloride', 'HCPCS', 942799, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('trimetrexate glucuronate', 'HCPCS', 1750928, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('triptorelin pamoate', 'HCPCS', 1343039, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('urea', 'HCPCS', 906914, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('urofollitropin', 'HCPCS', 1515417, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('urokinase', 'HCPCS', 1307515, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ustekinumab', 'HCPCS', 40161532, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('vaccine for part d drug', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('valrubicin', 'HCPCS', 19012543, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('vancomycin hcl', 'HCPCS', 1707687, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('vascular graft material, synthetic', 'HCPCS', 0, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('vedolizumab', 'HCPCS', 45774639, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('velaglucerase alfa', 'HCPCS', 40174604, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('verteporfin', 'HCPCS', 912803, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('vinblastine sulfate', 'HCPCS', 19008264, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('vincristine sulfate', 'HCPCS', 1308290, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('vincristine sulfate liposome', 'HCPCS', 1308290, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('vinorelbine tartrate', 'HCPCS', 1343346, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('vitamin b-12 cyanocobalamin', 'HCPCS', 1308738, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('von willebrand factor complex', 'HCPCS', 44785885, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('von willebrand factor complex (human)', 'HCPCS', 44785885, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('von willebrand factor complex (humate-p)', 'HCPCS', 44785885, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('voriconazole', 'HCPCS', 1714277, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('water', 'HCPCS', null, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('zalcitabine (ddc)', 'HCPCS', 1724827, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ziconotide', 'HCPCS', 19005061, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('zidovudine', 'HCPCS', 1710612, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ziprasidone mesylate', 'HCPCS', 712615, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ziv-aflibercept', 'HCPCS', 42874262, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('zoledronic acid', 'HCPCS', 1524674, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('zoledronic acid (reclast)', 'HCPCS', 1524674, null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('zoledronic acid (zometa)', 'HCPCS', 1524674, null);
end;
commit;

-- Add ingredients and their mappings that are not automatically generated
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('calcium chloride', 'HCPCS', 19036781, null); -- Ringer
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('calcium chloride', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sodium lactate', 'HCPCS', 19011035, null); -- Ringer. Lactate is precise ingredient
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('sodium lactate', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dextrose', 'HCPCS', 1560524, null); -- Dextrose
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('dextrose', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sodium bicarbonate', 'HCPCS', 939506, null); -- Elliot's
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('sodium bicarbonate', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sodium phosphate', 'HCPCS', 939871, null); -- Elliot's
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('sodium phosphate', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sulbactam', 'HCPCS', 1836241, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('sulbactam', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tazobactam', 'HCPCS', 1741122, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('tazobactam', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('tetracaine', 'HCPCS', 1036884, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('tetracaine', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('quinupristin', 'HCPCS', 1789515, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('quinupristin', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('dalfopristin', 'HCPCS', 1789517, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('dalfopristin', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('calcium glycerophosphate', 'HCPCS', 1337159, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('calcium glycerophosphate', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('calcium lactate', 'HCPCS', 19058896, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('calcium lactate', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('avibactam', 'HCPCS', 46221507, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('avibactam', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ceftolozane', 'HCPCS', 45892599, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('ceftolozane', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('netupitant', 'HCPCS', 45774966, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('netupitant', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('sulfamethoxazole', 'HCPCS', 1836430, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('sulfamethoxazole', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('trimethoprim', 'HCPCS', 1705674, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('trimethoprim', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('ticarcillin', 'HCPCS', 1759842, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('ticarcillin', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('clavulanate', 'HCPCS', 1702364, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('clavulanate', 'HCPCS', 'Ingredient');

-- Add ingredients for combination products
-- 5% dextrose and 0.45% normal saline
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'dextrose' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose and 0.45% normal saline';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'normal saline solution' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose and 0.45% normal saline';
delete from internal_relationship_stage where concept_code_2='5% dextrose and 0.45% normal saline';
-- 5% dextrose in lactated ringer's
-- Calcium Chloride 0.001 MEQ/ML / Glucose 50 MG/ML / Potassium Chloride 0.004 MEQ/ML / Sodium Chloride 0.103 MEQ/ML / Sodium Lactate 0.028 MEQ/ML Injectable Solution
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'dextrose' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringer''s';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'calcium chloride' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringer''s';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'potassium chloride' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringer''s';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'normal saline solution' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringer''s';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'sodium lactate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringer''s';
delete from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringer''s';
-- 5% dextrose in lactated ringers infusion
-- Calcium Chloride 0.001 MEQ/ML / Glucose 50 MG/ML / Potassium Chloride 0.004 MEQ/ML / Sodium Chloride 0.103 MEQ/ML / Sodium Lactate 0.028 MEQ/ML Injectable Solution
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'dextrose' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringers infusion';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'calcium chloride' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringers infusion';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'potassium chloride' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringers infusion';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'normal saline solution' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringers infusion';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'sodium lactate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringers infusion';
delete from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringers infusion';
-- 5% dextrose with potassium chloride
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'dextrose' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose with potassium chloride';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'potassium chloride' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose with potassium chloride';
delete from internal_relationship_stage where concept_code_2='5% dextrose with potassium chloride';
-- both ingredients already defined 
-- 5% dextrose/0.45% normal saline with potassium chloride and magnesium sulfate
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'dextrose' as concept_code_2, 'HCPCS' as vocabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose/0.45% normal saline with potassium chloride and magnesium sulfate';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'normal saline solution' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose/0.45% normal saline with potassium chloride and magnesium sulfate';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'potassium chloride' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose/0.45% normal saline with potassium chloride and magnesium sulfate';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'magnesium sulfate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose/0.45% normal saline with potassium chloride and magnesium sulfate';
delete from internal_relationship_stage where concept_code_2='5% dextrose/0.45% normal saline with potassium chloride and magnesium sulfate';
-- all ingredients already defined
-- 5% dextrose/normal saline (500 ml = 1 unit)
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'dextrose' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose/normal saline (500 ml = 1 unit)';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'normal saline solution' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='5% dextrose/normal saline (500 ml = 1 unit)';
delete from internal_relationship_stage where concept_code_2='5% dextrose/normal saline (500 ml = 1 unit)';
-- both ingredients already defined
-- albuterol/ipratropium bromide up to 0.5 mg
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'albuterol' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='albuterol/ipratropium bromide up to 0.5 mg';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'ipratropium bromide' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='albuterol/ipratropium bromide up to 0.5 mg';
delete from internal_relationship_stage where concept_code_2='albuterol/ipratropium bromide up to 0.5 mg';
-- both ingredients already defined
-- ampicillin sodium/sulbactam sodium
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'ampicillin sodium' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='ampicillin sodium/sulbactam sodium';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'sulbactam' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='ampicillin sodium/sulbactam sodium';
delete from internal_relationship_stage where concept_code_2='ampicillin sodium/sulbactam sodium';
-- antihemophilic factor viii/von willebrand factor complex (human)
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'factor viii' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='antihemophilic factor viii/von willebrand factor complex (human)';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'von willebrand factor complex' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='antihemophilic factor viii/von willebrand factor complex (human)';
delete from internal_relationship_stage where concept_code_2='antihemophilic factor viii/von willebrand factor complex (human)';
-- both ingredients already defined
-- buprenorphine/naloxone
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'buprenorphine hydrochloride' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='buprenorphine/naloxone';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'naloxone hydrochloride' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='buprenorphine/naloxone';
delete from internal_relationship_stage where concept_code_2='buprenorphine/naloxone';
-- both ingredients defined already
-- elliot b solution
-- Calcium Chloride 0.00136 MEQ/ML / Glucose 0.8 MG/ML / Magnesium Sulfate 0.00122 MEQ/ML / Potassium Chloride 0.00403 MEQ/ML / Sodium Bicarbonate 0.0226 MEQ/ML / Sodium Chloride 0.125 MEQ/ML / sodium phosphate 0.000746 MEQ/ML Injectable Solution [Elliotts B
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'sodium bicarbonate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='elliotts'' b solution';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'sodium phosphate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='elliotts'' b solution';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'normal saline solution' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='elliotts'' b solution';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'dextrose' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='elliotts'' b solution';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'calcium chloride' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='elliotts'' b solution';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'potassiuim chloride' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='elliotts'' b solution';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'magnesium sulfate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='elliotts'' b solution';
delete from internal_relationship_stage where concept_code_2='elliotts'' b solution';
-- some of the ingredients are already defined
-- immune globulin/hyaluronidase
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'immune globulin' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='immune globulin/hyaluronidase';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'hyaluronidase' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='immune globulin/hyaluronidase';
delete from internal_relationship_stage where concept_code_2='immune globulin/hyaluronidase';
-- both ingredients definded already
-- lidocaine /tetracaine 
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'lidocaine hcl for intravenous infusion' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='lidocaine /tetracaine ';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'tetracaine' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='lidocaine /tetracaine ';
delete from internal_relationship_stage where concept_code_2='lidocaine /tetracaine ';
-- lidocaine already defined
-- medroxyprogesterone acetate / estradiol cypionate
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'medroxyprogesterone acetate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='medroxyprogesterone acetate / estradiol cypionate';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'depo-estradiol cypionate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='medroxyprogesterone acetate / estradiol cypionate';
delete from internal_relationship_stage where concept_code_2='medroxyprogesterone acetate / estradiol cypionate';
-- both ingredients already defined
-- piperacillin sodium/tazobactam sodium
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'piperacillin sodium' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='piperacillin sodium/tazobactam sodium';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'tazobactam' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='piperacillin sodium/tazobactam sodium';
delete from internal_relationship_stage where concept_code_2='piperacillin sodium/tazobactam sodium';
-- piperacillin already defined
-- quinupristin/dalfopristin
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'quinupristin' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='quinupristin/dalfopristin';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'dalfopristin' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='quinupristin/dalfopristin';
delete from internal_relationship_stage where concept_code_2='quinupristin/dalfopristin';
-- calcium glycerophosphate and calcium lactate
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'calcium glycerophosphate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='calcium glycerophosphate and calcium lactate';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'calcium lactate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='calcium glycerophosphate and calcium lactate';
delete from internal_relationship_stage where concept_code_2='calcium glycerophosphate and calcium lactate';
--- ceftazidime and avibactam
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'ceftazidime' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='ceftazidime and avibactam';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'avibactam' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='ceftazidime and avibactam';
delete from internal_relationship_stage where concept_code_2='ceftazidime and avibactam';
-- ceftazidime already defined
-- ceftolozane 50 mg and tazobactam 25 mg
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'ceftolozane' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='ceftolozane 50 mg and tazobactam 25 mg';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'tazobactam' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='ceftolozane 50 mg and tazobactam 25 mg';
delete from internal_relationship_stage where concept_code_2='ceftolozane 50 mg and tazobactam 25 mg';
-- tazobactam already defined
-- droperidol and fentanyl citrate
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'droperidol' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='droperidol and fentanyl citrate';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'fentanyl citrate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='droperidol and fentanyl citrate';
delete from internal_relationship_stage where concept_code_2='droperidol and fentanyl citrate';
-- both ingredients already defined
-- meperidine and promethazine hcl
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'meperidine hydrochloride' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='meperidine and promethazine hcl';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'promethazine hcl' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='meperidine and promethazine hcl';
delete from internal_relationship_stage where concept_code_2='meperidine and promethazine hcl';
-- Both ingredients already defined
-- netupitant 300 mg and palonosetron 0.5 mg
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'netupitant' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='netupitant 300 mg and palonosetron 0.5 mg';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'palonosetron hcl' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='netupitant 300 mg and palonosetron 0.5 mg';
delete from internal_relationship_stage where concept_code_2='netupitant 300 mg and palonosetron 0.5 mg';
-- palonosetron already defined
-- phenylephrine and ketorolac
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'phenylephrine hcl' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='phenylephrine and ketorolac';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'ketorolac tromethamine' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='phenylephrine and ketorolac';
delete from internal_relationship_stage where concept_code_2='phenylephrine and ketorolac';
-- both ingredients already defined
-- ringers lactate infusion
-- Calcium Chloride 0.0014 MEQ/ML / Potassium Chloride 0.004 MEQ/ML / Sodium Chloride 0.103 MEQ/ML / Sodium Lactate 0.028 MEQ/ML Injectable Solution
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'calcium chloride' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='ringers lactate infusion';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'potassium chloride' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='ringers lactate infusion';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'normal saline solution' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='ringers lactate infusion';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'sodium lactate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='ringers lactate infusion';
delete from internal_relationship_stage where concept_code_2='ringers lactate infusion';
-- sulfamethoxazole and trimethoprim
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'sulfamethoxazole' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='sulfamethoxazole and trimethoprim';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'trimethoprim' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='sulfamethoxazole and trimethoprim';
delete from internal_relationship_stage where concept_code_2='sulfamethoxazole and trimethoprim';
-- testosterone cypionate and estradiol cypionate
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'testosterone cypionate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='testosterone cypionate and estradiol cypionate';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'depo-estradiol cypionate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='testosterone cypionate and estradiol cypionate';
delete from internal_relationship_stage where concept_code_2='testosterone cypionate and estradiol cypionate';
-- both ingredients already defined
-- testosterone enanthate and estradiol valerate
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'testosterone enanthate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='testosterone enanthate and estradiol valerate';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'estradiol valerate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='testosterone enanthate and estradiol valerate';
delete from internal_relationship_stage where concept_code_2='testosterone enanthate and estradiol valerate';
-- both ingredients already defined
-- ticarcillin disodium and clavulanate potassium
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'ticarcillin' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='ticarcillin disodium and clavulanate potassium';
insert into internal_relationship_stage
select concept_code_1, 'HCPCS' as vocabulary_id_1, 'clavulanate' as concept_code_2, 'HCPCS' as voabulary_id_2 from internal_relationship_stage where concept_code_2='ticarcillin disodium and clavulanate potassium';
delete from internal_relationship_stage where concept_code_2='ticarcillin disodium and clavulanate potassium';

-- Add and remove ingredients
delete from drug_concept_stage where concept_class_id='Ingredient' and concept_code not in (select concept_code_2 from internal_relationship_stage);
commit;

/*********************************************
* 3. Create Dose Forms and links to products *
*********************************************/
insert /*+ APPEND */ into drug_concept_stage
select distinct dose_form as concept_name, 'HCPCS' as vocabulary_id, 'Dose Form' as concept_class_id, cast(null as varchar2(1)) as standard_concept, 
  dose_form as concept_code, null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason,
  dose_form
from drug_concept_stage where concept_class_id='Procedure Drug'
;
commit;

insert /*+ APPEND */ into internal_relationship_stage 
select d.concept_code as concept_code_1, 'HCPCS' as vocabulary_id_1,
  df.concept_code as concept_code_2, 'HCPCS' as vocabulary_id_2
from drug_concept_stage d
join drug_concept_stage df on df.concept_code=d.dose_form and df.concept_class_id='Dose Form'
where d.concept_class_id='Procedure Drug'
;
commit;

-- Manually create Dose Form mapping to RxNorm
begin
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Infusion', 'HCPCS', 19082103, 1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Infusion', 'HCPCS', 19082104, 2);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Infusion', 'HCPCS', 46234469, 3);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'HCPCS', 19082259, 2);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'HCPCS', 19095898, 1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'HCPCS', 19126918, 3);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'HCPCS', 19082162, 4);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'HCPCS', 19126919, 5);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'HCPCS', 19127579, 6);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'HCPCS', 19082258, 7);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Inhalant', 'HCPCS', 19018195, 8);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injection', 'HCPCS', 19082103, 1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injection', 'HCPCS', 19126920, 2);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injection', 'HCPCS', 19082104, 3);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injection', 'HCPCS', 46234469, 4);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injection', 'HCPCS', 46234468, 5);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injection', 'HCPCS', 19095913, 6);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injection', 'HCPCS', 19095914, 7);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injection', 'HCPCS', 19082105, 8);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injection', 'HCPCS', 44784844, 9);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injection', 'HCPCS', 46234466, 10);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injection', 'HCPCS', 46234467, 11);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injection', 'HCPCS', 46275062, 12);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injection', 'HCPCS', 19095915, 13);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Injection', 'HCPCS', 19082260, 14);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082573, 1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082168, 2);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082191, 3);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082170, 4);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082251, 5);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19001144, 6);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082652, 7);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19095976, 8);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082651, 9);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082253, 10);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082101, 11);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19111148, 12);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082169, 13);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19001943, 14);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19135868, 15);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19021887, 16);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082223, 17);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082077, 18);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082079, 19);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082080, 20);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 44817840, 21);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082255, 22);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19001949, 23);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082076, 24);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19103220, 25);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082048, 26);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082256, 27);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082050, 28);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 40164192, 29);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 40175589, 30);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082222, 31);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082075, 32);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19135866, 33);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19102296, 34);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19018708, 35);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19135790, 36);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 45775489, 37);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 45775490, 38);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 45775491, 39);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 45775492, 40);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19111155, 41);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19126316, 42);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Oral', 'HCPCS', 19082285, 43);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Patch', 'HCPCS', 19082229, 1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Patch', 'HCPCS', 19082701, 2);
-- insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Patch', 'HCPCS', 19082224, 3); -- Topical cream
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Patch', 'HCPCS', 19082049, 4);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Patch', 'HCPCS', 19082071, 5);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Patch', 'HCPCS', 19082072, 6);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Patch', 'HCPCS', 19082252, 7);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Patch', 'HCPCS', 19082073, 8);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082228, 1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082224, 2);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19095912, 3);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 46234410, 4);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082227, 5);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082226, 6);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082225, 7);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19095972, 8);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19095973, 9);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19095912, 10);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082628, 11);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19135438, 12);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19135446, 13);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19135439, 14);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19135440, 15);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19129401, 16);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082287, 17);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19135925, 18);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082194, 19);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19095975, 20);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082164, 21);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19110977, 22);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082161, 23);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082576, 24);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082169, 25);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082193, 26);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082197, 27);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19010878, 28);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19112544, 29);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082163, 30);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082166, 31);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19095916, 32);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19095917, 33);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19095973, 34);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19095974, 35);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19010880, 36);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19011932, 37);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 40228565, 38);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19095900, 39);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19011167, 40);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19095911, 41);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082281, 42);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082199, 43);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19095899, 44);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19112649, 45);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082110, 46);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082165, 47);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082195, 48);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 45775488, 49);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19095977, 50);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082167, 51);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082196, 52);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19082102, 53);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Topical', 'HCPCS', 19010879, 54);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Spray', 'HCPCS', 19095899, 1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Spray', 'HCPCS', 19095911, 2);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Spray', 'HCPCS', 19011167, 3);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Spray', 'HCPCS', 19082199, 4);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Spray', 'HCPCS', 19082281, 5);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Spray', 'HCPCS', 19095912, 6);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Spray', 'HCPCS', 19112649, 7);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Spray', 'HCPCS', 19095900, 8);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Vaccine', 'HCPCS', 19082104, 1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Vaccine', 'HCPCS', 19126920, 2);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Vaccine', 'HCPCS', 19082103, 3);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Vaccine', 'HCPCS', 46234469, 4);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Vaccine', 'HCPCS', 19011167, 5);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Vaccine', 'HCPCS', 19082191, 6);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Vaccine', 'HCPCS', 19001949, 7);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Vaccine', 'HCPCS', 19082255, 8);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Suppository', 'HCPCS', 19082200, 1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Suppository', 'HCPCS', 19093368, 2);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Suppository', 'HCPCS', 19082575, 3);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082573, 1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082103, 2);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082168, 3);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082170, 4);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082079, 5);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082224, 6);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082191, 7);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082227, 8);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082228, 9);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19135866, 10);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082077, 11);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19095973, 12);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082225, 13);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19129634, 14);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19126920, 15);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082200, 16);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082253, 17);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19095912, 18);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082104, 19);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19001949, 20);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082229, 21);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19008697, 22);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 46234469, 23);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19095898, 24);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082076, 25);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19130307, 26);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082258, 27);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082255, 28);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082109, 29);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19135925, 30);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19095916, 31);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082080, 32);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082285, 33);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082286, 34);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19095972, 35);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19011167, 36);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19126590, 37);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19093368, 38);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082195, 39);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082165, 40);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19009068, 41);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082167, 42);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19016586, 43);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19095976, 44);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082108, 45);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082226, 46);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19102295, 47);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19010878, 48);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082627, 49);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082259, 50);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082110, 51);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082651, 52);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 44817840, 53);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19126918, 54);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19124968, 55);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082251, 56);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19129139, 57);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19095900, 58);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082197, 59);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19102296, 60);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082282, 61);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19095911, 62);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 46234468, 63);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19010880, 64);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19126316, 65);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 46234466, 66);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19010962, 67);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082166, 68);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19126919, 69);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19095918, 70);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19127579, 71);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 46234467, 72);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 40175589, 73);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082281, 74);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19059413, 75);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082196, 76);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082163, 77);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082169, 78);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19112648, 79);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19095917, 80);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19095971, 81);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082162, 82);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 40164192, 83);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082574, 84);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082105, 85);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082222, 86);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082575, 87);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082652, 88);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 45775489, 89);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 45775491, 90);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082164, 91);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 40167393, 92);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082287, 93);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082194, 94);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082576, 95);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19095975, 96);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082628, 97);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 46275062, 98);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19010879, 99);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 46234410, 100);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19135439, 101);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19095977, 102);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082199, 103);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082283, 104);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19095974, 105);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19135446, 106);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19130329, 107);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 45775490, 108);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 45775492, 109);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19082101, 110);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19135440, 111);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 19135438, 112);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 45775488, 113);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Unknown', 'HCPCS', 44784844, 114);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Instillation', 'HCPCS', 19016586, 1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Instillation', 'HCPCS', 46234410, 2);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Instillation', 'HCPCS', 19082104, 3);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Instillation', 'HCPCS', 19082103, 4);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Instillation', 'HCPCS', 46234469, 5);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Implant', 'HCPCS', 19124968, 1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Implant', 'HCPCS', 19082103, 2);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence) values ('Implant', 'HCPCS', 19082104, 3);
end;
commit;

/*********************************
* 4. Create and link Drug Strength
*********************************/
-- Write units
insert /*+ APPEND */ into drug_concept_stage
select distinct 
  u as concept_name, 'HCPCS' as vocabulary_id, 'Unit' as concept_class_id, null as standard_concept, u as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from (
  select case
      when snd is null then null
      when trd is null then 'weird'
      else substr(dose, snd+1, trd-snd-1)
    end as u
  from (
    select d.*, instr(dose, '|', 1, 1) as fst, instr(dose, '|', 1, 2) as snd, instr(dose, '|', 1, 3) as trd
    from (
      select regexp_replace(lower(concept_name), '([^0-9]+)([0-9][0-9\.,]*|per) *(mg|ml|micrograms?|units?|i\.?u\.?|grams?|gm|cc|mcg|milligrams?|million units)(.*)', '\1|\2|\3|\4') as dose, concept_code from drug_concept_stage
    ) d
  )
) 
where u is not null;
commit;

-- write mappings to real units
begin
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('i.u.', 'HCPCS', 8718, 1, 1); -- to international unit
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('i.u.', 'HCPCS', 8510, 2, 1); -- to unit
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('iu', 'HCPCS', 8718, 1, 1); -- to international unit
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('iu', 'HCPCS', 8510, 2, 1); -- to unit
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('unit', 'HCPCS', 8510, 1, 1); -- to unit
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('unit', 'HCPCS', 8718, 2, 1); -- to international unit
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('units', 'HCPCS', 8510, 1, 1); -- to unit
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('units', 'HCPCS', 8718, 2, 1); -- to international unit
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('million units', 'HCPCS', 8510, 1, 1000000); -- to unit
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('million units', 'HCPCS', 8718, 2, 1000000); -- to international unit
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('gm', 'HCPCS', 8576, 1, 1000); -- to milligram
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('gm', 'HCPCS', 8587, 2, 1); -- to milliliter
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('gram', 'HCPCS', 8576, 1, 1000); -- to milligram
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('gram', 'HCPCS', 8587, 2, 1); -- to milliliter
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('grams', 'HCPCS', 8576, 1, 1000); -- to milligram
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('grams', 'HCPCS', 8587, 2, 1); -- to milliliter
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('mg', 'HCPCS', 8576, 1, 1); -- to milligram
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('milligram', 'HCPCS', 8576, 1, 1); -- to milligram
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('milligrams', 'HCPCS', 8576, 1, 1); -- to milligram
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('mcg', 'HCPCS', 8576, 1, 0.001); -- to milligram
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('meq', 'HCPCS', 9551, 1, 1); 
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('microgram', 'HCPCS', 8576, 1, 0.001); -- to milligram
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('micrograms', 'HCPCS', 8576, 1, 0.001); -- to milligram
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ml', 'HCPCS', 8587, 1, 1); -- to milliliter
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ml', 'HCPCS', 8576, 2, 1000); -- to milligram
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('cc', 'HCPCS', 8587, 1, 1); -- to milliliter
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('cc', 'HCPCS', 8576, 2, 1000); -- to milligram
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('%', 'HCPCS', 8554, 2, 1);
end;
commit;

-- write drug_strength
insert /*+ APPEND */ into ds_stage
select distinct
  d.concept_code as drug_concept_code,
  i.concept_code_2 as ingredient_concept_code,
  case u when '%' then null else d.v end as amount_value, -- only percent goes into liquid drug_strength
  case u when '%' then null else d.u end as amount_unit,
  case u when '%' then d.v else null end as numerator_value,
  case u when '%' then d.u else null end as numerator_unit,
  null as denominator_value,
  null as denominator_unit,
  null as box_size
from (
  select concept_code, 
    case v when 'per' then 1 else cast(translate(v, 'a,', 'a') as float) end as v,
    u
  from (
    select concept_code, -- dose,
      case
        when fst is null then null
        when snd is null then 'weird'
        else substr(dose, fst+1, snd-fst-1)
      end as v,
      case
        when snd is null then null
        when trd is null then 'weird'
        else substr(dose, snd+1, trd-snd-1)
      end as u
    from (
      select d.*, instr(dose, '|', 1, 1) as fst, instr(dose, '|', 1, 2) as snd, instr(dose, '|', 1, 3) as trd
      from (
        select 
          regexp_replace(lower(concept_name), '([^0-9]+)([0-9][0-9\.,]*|per) *(mg|ml|micrograms?|units?|i\.?u\.?|grams?|gm|cc|mcg|milligrams?|million units|%)(.*)', '\1|\2|\3|\4') as dose, 
          concept_code 
        from drug_concept_stage
      ) d
    )
  ) 
) d
left join (
  select r.concept_code_1, r.concept_code_2 from internal_relationship_stage r join drug_concept_stage i on i.concept_code=r.concept_code_2 and i.concept_class_id='Ingredient' -- join the ingredient
) i on i.concept_code_1=d.concept_code
where d.v is not null
;
commit;

-- Manually fix the combination products
-- C9285 defined and correct
-- C9447 not defined, will pass only as form or ingredient
-- C9448 defined:
update ds_stage set amount_value=0.5 where drug_concept_code='C9448' and ingredient_concept_code='palonosetron hcl';
-- C9452 defined:
update ds_stage set amount_value=25 where drug_concept_code='C9452' and ingredient_concept_code='tazobactam';
-- J0295 only defined for ampicillin
delete from ds_stage where drug_concept_code='J0295' and ingredient_concept_code='sulbactam';
-- J0571 - J0575 only defined for buprenorphine, will pass only as form or ingredient
delete from ds_stage where drug_concept_code='J0571' and ingredient_concept_code='naloxone hydrochloride';
delete from ds_stage where drug_concept_code='J0572' and ingredient_concept_code='naloxone hydrochloride';
delete from ds_stage where drug_concept_code='J0573' and ingredient_concept_code='naloxone hydrochloride';
delete from ds_stage where drug_concept_code='J0574' and ingredient_concept_code='naloxone hydrochloride';
delete from ds_stage where drug_concept_code='J0575' and ingredient_concept_code='naloxone hydrochloride';
-- J0620 not defined, will pass only as form or ingredient
-- J0695 defined:
update ds_stage set amount_value=25 where drug_concept_code='J0695' and ingredient_concept_code='tazobactam';
-- J0900 not defined, will pass only as form or ingredient
-- J1056 defined:
update ds_stage set amount_value=25 where drug_concept_code='J1056' and ingredient_concept_code='depo-estradiol cypionate';
-- J1060 not defined, will pass only as form or ingredient
-- J1575 not defined, will pass only as form or ingredient
-- J1810 not defined, will pass only as form or ingredient
-- J2180 defined:
update ds_stage set amount_value=25 where drug_concept_code='J2180' and ingredient_concept_code='promethazine hcl';
-- J2543 defined:
update ds_stage set amount_value=125, amount_unit='mg' where drug_concept_code='J2543' and ingredient_concept_code='tazobactam';
-- J2770 defined:
update ds_stage set amount_value=350 where drug_concept_code='J2770' and ingredient_concept_code='quinupristin';
update ds_stage set amount_value=150 where drug_concept_code='J2770' and ingredient_concept_code='dalfopristin';
-- J7042 defined:
update ds_stage set amount_value=null, amount_unit=null, numerator_value=50, numerator_unit='mg', denominator_unit='ml' where drug_concept_code='J7042' and ingredient_concept_code='dextrose';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.154, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='J7042' and ingredient_concept_code='normal saline solution';
-- J7060 defined:
update ds_stage set amount_value=null, amount_unit=null, numerator_value=50, numerator_unit='mg', denominator_unit='ml' where drug_concept_code='J7060' and ingredient_concept_code='dextrose';
-- J7120 defined:
-- Calcium Chloride 0.0014 MEQ/ML / Potassium Chloride 0.004 MEQ/ML / Sodium Chloride 0.103 MEQ/ML / Sodium Lactate 0.028 MEQ/ML Injectable Solution
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.0014, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='J7120' and ingredient_concept_code='calcium chloride';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.004, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='J7120' and ingredient_concept_code='potassium chloride';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.103, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='J7120' and ingredient_concept_code='normal saline solution';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.028, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='J7120' and ingredient_concept_code='sodium lactate';
-- J7121 defined:
-- Calcium Chloride 0.001 MEQ/ML / Glucose 50 MG/ML / Potassium Chloride 0.004 MEQ/ML / Sodium Chloride 0.103 MEQ/ML / Sodium Lactate 0.028 MEQ/ML Injectable Solution
update ds_stage set amount_value=null, amount_unit=null, numerator_value=50, numerator_unit='mg', denominator_unit='ml' where drug_concept_code='J7121' and ingredient_concept_code='dextrose';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.001, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='J7121' and ingredient_concept_code='calcium chloride';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.004, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='J7121' and ingredient_concept_code='potassium chloride';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.103, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='J7121' and ingredient_concept_code='normal saline solution';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.028, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='J7121' and ingredient_concept_code='sodium lactate';
-- J7620 defined:
update ds_stage set amount_value=2.5 where drug_concept_code='J7620' and ingredient_concept_code='albuterol';
-- J9175 defined:
-- Calcium Chloride 0.00136 MEQ/ML / Glucose 0.8 MG/ML / Magnesium Sulfate 0.00122 MEQ/ML / Potassium Chloride 0.00403 MEQ/ML / Sodium Bicarbonate 0.0226 MEQ/ML / Sodium Chloride 0.125 MEQ/ML / sodium phosphate 0.000746 MEQ/ML Injectable Solution [Elliotts B
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.0226, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='J9175' and ingredient_concept_code='sodium bicarbonate';
update ds_stage set amount_value=null, amount_unit=null, numerator_value= 0.000746, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='J9175' and ingredient_concept_code='sodium phosphate';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.125, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='J9175' and ingredient_concept_code='normal saline solution';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.8, numerator_unit='mg', denominator_unit='ml' where drug_concept_code='J9175' and ingredient_concept_code='dextrose';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.00136, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='J9175' and ingredient_concept_code='calcium chloride';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.00403, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='J9175' and ingredient_concept_code='potassium chloride';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.00122, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='J9175' and ingredient_concept_code='magnesium sulfate';
-- S0039: not defined, will pass only as form or ingredient
-- S0040 somewhat defined. the 31 mg are in one milliliter andn are a sum of both ingredients:
update ds_stage set amount_value=null, amount_unit=null, numerator_value=30, numerator_unit='mg', denominator_unit='ml' where drug_concept_code='S0040' and ingredient_concept_code='ticarcillin';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=1, numerator_unit='mg', denominator_unit='ml' where drug_concept_code='S0040' and ingredient_concept_code='clavulanate';
-- S5010: defined:
update ds_stage set amount_value=null, amount_unit=null, numerator_value=50, numerator_unit='mg', denominator_unit='ml' where drug_concept_code='S5010' and ingredient_concept_code='dextrose';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.0769, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='S5010' and ingredient_concept_code='normal saline solution';
-- S5011
-- Calcium Chloride 0.001 MEQ/ML / Glucose 50 MG/ML / Potassium Chloride 0.004 MEQ/ML / Sodium Chloride 0.103 MEQ/ML / Sodium Lactate 0.028 MEQ/ML Injectable Solution
update ds_stage set amount_value=null, amount_unit=null, numerator_value=50, numerator_unit='mg', denominator_unit='ml' where drug_concept_code='S5011' and ingredient_concept_code='dextrose';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.001, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='S5011' and ingredient_concept_code='calcium chloride';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.004, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='S5011' and ingredient_concept_code='potassium chloride';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.103, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='S5011' and ingredient_concept_code='normal saline solution';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.028, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='S5011' and ingredient_concept_code='sodium lactate';
-- S5012: undefined, including the ingredients. Still:
update ds_stage set amount_value=null, amount_unit=null, numerator_value=50, numerator_unit='mg', denominator_unit='ml' where drug_concept_code='S5012' and ingredient_concept_code='dextrose';
delete from ds_stage where drug_concept_code='S5012' and ingredient_concept_code='potassium chloride';
-- S5013: undefined, but this we know:
update ds_stage set amount_value=null, amount_unit=null, numerator_value=50, numerator_unit='mg', denominator_unit='ml' where drug_concept_code='S5013' and ingredient_concept_code='dextrose';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.0769, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='S5013' and ingredient_concept_code='normal saline solution';
delete from ds_stage where drug_concept_code='S5013' and ingredient_concept_code='potassium chloride';
delete from ds_stage where drug_concept_code='S5013' and ingredient_concept_code='magnesium sulfate';
-- S5014: undefined, but this we know:
update ds_stage set amount_value=null, amount_unit=null, numerator_value=50, numerator_unit='mg', denominator_unit='ml' where drug_concept_code='S5014' and ingredient_concept_code='dextrose';
update ds_stage set amount_value=null, amount_unit=null, numerator_value=0.0769, numerator_unit='meq', denominator_unit='ml' where drug_concept_code='S5014' and ingredient_concept_code='normal saline solution';
delete from ds_stage where drug_concept_code='S5014' and ingredient_concept_code='potassium chloride';
delete from ds_stage where drug_concept_code='S5014' and ingredient_concept_code='magnesium sulfate';

/******************************
* 5. Create and link Brand Names *
******************************/
-- create relationship from drug to brand (direct, need to change to stage-type brandsd
create table brandname nologging as
with bn as (
  select d.concept_code, b.concept_id, b.brandname
  from drug_concept_stage d
  join (
    select concept_id, lower(concept_name) as brandname from concept where vocabulary_id='RxNorm' and concept_class_id='Brand Name' 
  ) b on instr(lower(d.concept_name), b.brandname)>0
  where d.concept_class_id='Procedure Drug'
  and regexp_like(lower(d.concept_name), '[^a-z]'||b.brandname||'[^a-z]') -- regexp very slow compared to instr (2 lines above), therefore pre-filter with instr and then regexp
)
select b.*
from drug_concept_stage d
join ( -- only select those brandnames that appear uniquely in hte concept_name. If there are more than one brand_name we can't identify it 
  select concept_code from bn group by concept_code having count(8)<2
) db on db.concept_code=d.concept_code
join bn b on b.concept_code=d.concept_code
;

insert /*+ APPEND */ into drug_concept_stage
select distinct brandname as concept_name, 'HCPCS' as vocabulary_id, 'Brand Name' as concept_class_id, null as standard_concept, brandname as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from brandname;
commit;

insert /*+ APPEND */ into relationship_to_concept
select distinct brandname as concept_code_1, 'HCPCS' as vocabulary_id_1, concept_id as concept_id_2, 1 as precedence, null as conversion_factor
from brandname;
commit;

insert /*+ APPEND */ into internal_relationship_stage 
select distinct concept_code as concept_code_1, 'HCPCS' as vocabulary_id_1,
  brandname as concept_code_2, 'HCPCS' as vocabulary_id_2
from brandname;
commit;

/****************************
* 6. Clean up
*****************************/
-- remove dose forms from concept_stage table
alter table drug_concept_stage drop column dose_form;
drop table drug_concept_stage_tmp purge;
drop table brandname purge;
drop table ds_stage;