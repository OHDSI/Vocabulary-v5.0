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
  domain_id varchar2(20),
  concept_name varchar2(255),
  vocabulary_id varchar2(20),
  concept_class_id varchar2(20),
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
  concept_id_2 integer,
  precedence integer,
  conversion_factor float
)
NOLOGGING;

create table internal_relationship_stage (
  concept_code_1 varchar2(255),
  concept_code_2 varchar2(255)
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
insert /*+ APPEND */ into drug_concept_stage (concept_name, domain_id, vocabulary_id, concept_class_id, concept_code, possible_excipient, 
  valid_start_date, valid_end_date, invalid_reason, dose_form)
select * from (
  select distinct concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Procedure Drug' as concept_class_id, concept_code, null as possible_excipient, 
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
  '' as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, 
  regexp_replace(regexp_replace(lower(concept_name), 'injection,? (iv, )?([^,]+).*', '\1|\2'), '.*?\|(.+)', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Injection' -- and concept_name like '%betamethasone%'
;
commit;
-- Vaccines
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, 
  regexp_replace(regexp_replace(lower(concept_name), '(.+?vaccine)(.+?for intramuscular use \(.+?\))?(.+vaccine)?', '\1\2'), '.+ of ', '') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Vaccine' 
;
commit;
-- Orals
insert /*+ APPEND */into drug_concept_stage_tmp
select 
  '' as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, lower(regexp_substr(c1_cleanname, '[^,]+')) as concept_code, 
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
  '' as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, regexp_replace(lower(concept_name), '(.+?),? ?(per|each) (unit|i.u.).*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Unit' 
;
commit;
-- Instillations
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, regexp_replace(lower(concept_name), '(.+?),? ?per instillation.*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Instillation' 
;
commit;
-- Patches
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, regexp_replace(regexp_replace(lower(concept_name), '(.+?),? ?(per )?patch.*', '\1'), '\d+(%| ?mg)', '') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Patch' 
;
commit;
-- Sprays
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, regexp_replace(lower(concept_name), '(.+?),? ?(nasal )?spray.*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Spray'
;
commit;
-- Infusions
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, 
  regexp_replace(lower(concept_name), 'infusion,? (.+?) ?,.*', '\1') as concept_code, null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Infusion'
;
commit;
-- Guess Topicals
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, regexp_replace(lower(concept_name), '(.+?)(, | for )topical.*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Topical'
;
commit;
-- Implants
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, regexp_replace(lower(concept_name), '(.+?), implant.*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Implant'
;
commit;
-- Parenterals
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, regexp_replace(lower(concept_name), '(.+?), parenteral.*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Parenteral'
;
commit;
-- Suppositories
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, regexp_replace(lower(concept_name), '(.+?),? ?(urethral )?(rectal\/)?suppository.*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Suppository'
;
commit;
-- Inhalant
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, 
  regexp_replace(lower(concept_name), '(.+?),? ?(administered as )?(all formulations including separated isomers, )?inhalation solution.*', '\1') as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from drug_concept_stage where dose_form='Inhalant'
;
commit;
-- Unknown
insert /*+ APPEND */ into drug_concept_stage_tmp
select 
  '' as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Ingredient' as concept_class_id, 
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
  concept_code as concept_code_1, 
  regexp_replace(regexp_replace(lower(concept_name), 'injection,? (iv, )?([^,]+).*', '\1|\2'), '.*?\|(.+)', '\1') as concept_code_2
from drug_concept_stage where dose_form='Injection' -- and length(regexp_substr(concept_name, ' [^,]+'))>3
;
commit;
-- Vaccines
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1,
  regexp_replace(regexp_replace(lower(concept_name), '(.+?vaccine)(.+?for intramuscular use \(.+?\))?(.+vaccine)?', '\1\2'), '.+ of ', '') as concept_code_2
from drug_concept_stage where dose_form='Vaccine' 
;
commit;
-- Orals
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1,lower(regexp_substr(c1_cleanname, '[^,]+')) as concept_code_2
from (
  select concept_code, vocabulary_id, regexp_replace(concept_name, ',?;? ?oral,? ?', ', ') as c1_cleanname
  from drug_concept_stage where dose_form='Oral'
) 
;
commit;
-- Units
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1,regexp_replace(lower(concept_name), '(.+?),? ?(per|each) (unit|i.u.).*', '\1') as concept_code_2
from drug_concept_stage where dose_form='Unit' 
;
commit;
-- Instillations
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1,regexp_replace(lower(concept_name), '(.+?),? ?per instillation.*', '\1') as concept_code_2
from drug_concept_stage where dose_form='Instillation' 
;
commit;
-- Patches
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1,regexp_replace(regexp_replace(lower(concept_name), '(.+?),? ?(per )?patch.*', '\1'), '\d+(%| ?mg)', '') as concept_code_2
from drug_concept_stage where dose_form='Patch' 
;
commit;
-- Sprays
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1,regexp_replace(lower(concept_name), '(.+?),? ?(nasal )?spray.*', '\1') as concept_code_2
from drug_concept_stage where dose_form='Spray'
;
commit;
-- Infusions
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1,regexp_replace(lower(concept_name), 'infusion,? (.+?) ?,.*', '\1') as concept_code_2
from drug_concept_stage where dose_form='Infusion'
;
commit;
-- Guess Topicals
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1,regexp_replace(lower(concept_name), '(.+?)(, | for )topical.*', '\1') as concept_code_2
from drug_concept_stage where dose_form='Topical'
;
commit;
-- Implants
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1,regexp_replace(lower(concept_name), '(.+?), implant.*', '\1') as concept_code_2
from drug_concept_stage where dose_form='Implant'
;
commit;
-- Parenterals
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1,regexp_replace(lower(concept_name), '(.+?), parenteral.*', '\1') as concept_code_2
from drug_concept_stage where dose_form='Parenteral'
;
commit;
-- Suppositories
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1,regexp_replace(lower(concept_name), '(.+?),? ?(urethral )?(rectal\/)?suppository.*', '\1') as concept_code_2
from drug_concept_stage where dose_form='Suppository'
;
commit;
-- Inhalant
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1,
  regexp_replace(lower(concept_name), '(.+?),? ?(administered as )?(all formulations including separated isomers, )?inhalation solution.*', '\1') as concept_code_2
from drug_concept_stage where dose_form='Inhalant'
;
commit;
-- Unknown
insert /*+ APPEND */ into internal_relationship_stage
select 
  concept_code as concept_code_1,
  regexp_replace(regexp_replace(lower(concept_name), '(.+?)(, |; | \(?for | gel |sinus implant| implant| per).*', '\1'), '(administration and supply of )?(.+)', '\2') as concept_code_2
from drug_concept_stage where dose_form='Unknown'
;
commit;

-- Manually create mappings from Ingredients to RxNorm ingredients
begin
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('(e.g. liquid)', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('5% dextrose/water (500 ml = 1 unit)', 1560524, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('abarelix', 19010868, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('abatacept', 1186087, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('abciximab', 19047423, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('abobotulinumtoxina', 40165377, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('acetaminophen', 1125315, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('acetazolamide sodium', 929435, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('acetylcysteine', 1139042, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('acyclovir', 1703687, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('adalimumab', 1119119, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('adenosine', 1309204, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('adenosine for diagnostic use', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('adenosine for therapeutic use', 1309204, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('administration', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ado-trastuzumab emtansine', 43525787, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('adrenalin', 1343916, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('aflibercept', 40244266, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('agalsidase beta', 1525746, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('alatrofloxacin mesylate', 19018154, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('albumin (human)', 1344143, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('albuterol', 1154343, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('aldesleukin', 1309770, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('alefacept', 909959, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('alemtuzumab', 1312706, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('alglucerase', 19057354, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('alglucosidase alfa', 19088328, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('alglucosidase alfa (lumizyme)', 19088328, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('alpha 1 proteinase inhibitor (human)', 40181679, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('alprostadil', 1381504, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('alteplase recombinant', 1347450, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('amantadine hydrochloride', 19087090, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('amifostine', 1350040, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('amikacin sulfate', 1790868, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('aminocaproic acid', 1369939, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('aminolevulinic acid hcl', 19025194, null); -- it's meant methyl 5-aminolevulinate
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('aminophyllin', 1105775, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('amiodarone hydrochloride', 1309944, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('amitriptyline hcl', 710062, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('amobarbital', 712757, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('amphotericin b', 1717240, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('amphotericin b cholesteryl sulfate complex', 1717240, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('amphotericin b lipid complex', 19056402, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('amphotericin b liposome', 19056402, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ampicillin sodium', 1717327, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('anastrozole', 1348265, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('anidulafungin', 19026450, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('anistreplase', 19044890, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('anti-inhibitor', 19080406, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('antiemetic drug', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('antithrombin iii (human)', 1436169, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('antithrombin recombinant', 1436169, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('apomorphine hydrochloride', 837027, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('aprepitant', 936748, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('aprotonin', 19000729, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('arbutamine hcl', 19086330, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('arformoterol', 1111220, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('argatroban', 1322207, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('aripiprazole', 757688, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('arsenic trioxide', 19010961, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('artificial saliva', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('asparaginase', 19012585, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('asparaginase (erwinaze)', 19055717, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('asparaginase erwinia chrysanthemi', 43533115, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('atropine', 914335, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('atropine sulfate', 914335, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('aurothioglucose', 1163570, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('autologous cultured chondrocytes', 40224705, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('azacitidine', 1314865, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('azathioprine', 19014878, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('azithromycin', 1734104, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('azithromycin dihydrate', 1734104, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('aztreonam', 1715117, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('baclofen', 715233, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('basiliximab', 19038440, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('bcg (intravesical)', 19086176, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('becaplermin', 912476, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('beclomethasone', 1115572, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('belatacept', 40239665, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('belimumab', 40236987, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('belinostat', 45776670, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('bendamustine hcl', 19015523, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('benztropine mesylate', 719174, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('betamethasone', 920458, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('betamethasone acetate 3 mg and betamethasone sodium phosphate 3 mg', 920458, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('betamethasone sodium phosphate', 920458, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('bethanechol chloride', 937439, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('bevacizumab', 1397141, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('biperiden lactate', 724908, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('bitolterol mesylate', 1138050, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('bivalirudin', 19084670, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('blinatumomab', 45892531, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('bleomycin sulfate', 1329241, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('bortezomib', 1336825, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('brentuximab vedotin', 40241969, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('brompheniramine maleate', 1130863, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('budesonide', 939259, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('bumetanide', 932745, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('bupivacaine liposome', 40244151, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('bupivicaine hydrochloride', 732893, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('buprenorphine', 1133201, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('buprenorphine hydrochloride', 1133201, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('bupropion hcl sustained release tablet', 750982, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('busulfan', 1333357, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('butorphanol tartrate', 1133732, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('c-1 esterase inhibitor (human)', 45892906, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('c1 esterase inhibitor (human)', 45892906, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('c1 esterase inhibitor (recombinant)', 45892906, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('c-1 esterase inhibitor (recombinant)', 45892906, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cabazitaxel', 40222431, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cabergoline', 1558471, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('caffeine citrate', 1134439, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('calcitonin salmon', 1537655, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('calcitriol', 19035631, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('calcitrol', 19035631, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('calcium gluconate', 19037038, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('canakinumab', 40161669, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cangrelor', 46275677, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('capecitabine', 1337620, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('capsaicin', 939881, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('capsaicin ', 939881, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('carbidopa', 740560, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('carboplatin', 1344905, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('carfilzomib', 42873638, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('carmustine', 1350066, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('caspofungin acetate', 1718054, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cefazolin sodium', 1771162, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cefepime hydrochloride', 1748975, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cefoperazone sodium', 1773402, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cefotaxime sodium', 1774470, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cefotetan disodium', 1774932, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cefoxitin sodium', 1775741, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ceftaroline fosamil', 40230597, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ceftazidime', 1776684, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ceftizoxime sodium', 1777254, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ceftriaxone sodium', 1777806, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('centruroides (scorpion) immune f(ab)2 (equine)', 40241715, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('centruroides immune f(ab)2', 40241715, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cephalothin sodium', 19086759, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cephapirin sodium', 19086790, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('certolizumab pegol', 912263, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cetuximab', 1315411, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('chlorambucil', 1390051, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('chloramphenicol sodium succinate', 990069, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('chlordiazepoxide hcl', 990678, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('chlorhexidine containing antiseptic', 1790812, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('chloroprocaine hydrochloride', 19049410, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('chloroquine hydrochloride', 1792515, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('chlorothiazide sodium', 992590, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('chlorpromazine hcl', 794852, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('chlorpromazine hydrochloride', 794852, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('chorionic gonadotropin', 1563600, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cidofovir', 1745072, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cilastatin sodium; imipenem', 1797258, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cimetidine hydrochloride', 997276, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ciprofloxacin for intravenous infusion', 1797513, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cisplatin', 1397599, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cladribine', 19054825, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('clevidipine butyrate', 19089969, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('clindamycin phosphate', 997881, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('clofarabine', 19054821, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('clonidine hydrochloride', 1398937, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('clozapine', 800878, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('codeine phosphate', 1201620, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('colchicine', 1101554, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('colistimethate sodium', 1701677, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('collagenase', 980311, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('collagenase clostridium histolyticum', 40172153, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('contraceptive supply, hormone containing', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('corticorelin ovine triflutate', 19020789, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('corticotropin', 1541079, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cosyntropin', 19008009, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cosyntropin (cortrosyn)', 19008009, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cromolyn sodium', 1152631, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('crotalidae polyvalent immune fab (ovine)', 19071744, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cryoprecipitate', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cyclophosphamide', 1310317, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cyclosporin', 19010482, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cyclosporine', 19010482, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cymetra', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cytarabine', 1311078, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cytarabine liposome', 40175460, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('cytomegalovirus immune globulin intravenous (human)', 586491, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('d5w', 1560524, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dacarbazine', 1311409, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('daclizumab', 19036892, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dactinomycin', 1311443, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dalbavancin', 45774861, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dalteparin sodium', 1301065, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('daptomycin', 1786617, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('darbepoetin alfa', 1304643, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('daunorubicin', 1311799, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('daunorubicin citrate', 1311799, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('decitabine', 19024728, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('deferoxamine mesylate', 1711947, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('degarelix', 19058410, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('denileukin diftitox', 19051642, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('denosumab', 40222444, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('depo-estradiol cypionate', 1548195, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('desmopressin acetate', 1517070, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dexamethasone', 1518254, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dexamethasone acetate', 1518254, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dexamethasone intravitreal implant', 1518254, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dexamethasone sodium phosphate', 1518254, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dexrazoxane hydrochloride', 1353011, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dextran 40', 19019122, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dextran 75', 19019193, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dextroamphetamine sulfate', 719311, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dialysis/stress vitamin supplement', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('diazepam', 723013, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('diazoxide', 1523280, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dicyclomine hcl', 924724, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('didanosine (ddi)', 1724869, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('diethylstilbestrol diphosphate', 1525866, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('digoxin', 19045317, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('digoxin immune fab (ovine)', 19045317, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dihydroergotamine mesylate', 1126557, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dimenhydrinate', 928744, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dimercaprol', 1728903, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('diphenhydramine hcl', 1129625, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('diphenhydramine hydrochloride', 1129625, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dipyridamole', 1331270, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dmso', 928980, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dobutamine hydrochloride', 1337720, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('docetaxel', 1315942, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dolasetron mesylate', 903459, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dopamine hcl', 1337860, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('doripenem', 1713905, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dornase alfa', 1125443, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('doxercalciferol', 1512446, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('doxorubicin hydrochloride', 1338512, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('doxorubicin hydrochloride liposomal', 19051649, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dronabinol', 40125879, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('droperidol', 739323, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dyphylline', 1140088, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ecallantide', 40168938, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('eculizumab', 19080458, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('edetate calcium disodium', 43013616, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('edetate disodium', 19052936, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('efalizumab', 936429, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('elosulfase alfa', 44814525, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('enfuvirtide', 1717002, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('enoxaparin sodium', 1301025, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('epifix', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('epirubicin hcl', 1344354, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('epoetin alfa', 1301125, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('epoetin beta', 19001311, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('epoprostenol', 1354118, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('eptifibatide', 1322199, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ergonovine maleate', 1345205, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('eribulin mesylate', 40230712, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ertapenem sodium', 1717963, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('erythromycin lactobionate', 1746940, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('estradiol valerate', 1548195, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('estrogen  conjugated', 1549080, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('estrone', 1549254, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('etanercept', 1151789, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ethanolamine oleate', 19095285, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('etidronate disodium', 1552929, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('etoposide', 1350504, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('everolimus', 19011440, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('excellagen', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('exemestane', 1398399, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('factor ix', 1351935, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('factor ix (antihemophilic factor', 1351935, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('factor ix (antihemophilic factor, purified, non-recombinant)', 1351935, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('factor ix (antihemophilic factor, recombinant), alprolix', 1351935, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('factor ix (antihemophilic factor, recombinant), rixubis', 1351935, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('factor ix, complex', 1351935, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('factor viia (antihemophilic factor', 1352141, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('factor viii', 1352213, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('factor viii (antihemophilic factor', 1352213, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('factor viii (antihemophilic factor (porcine))', 1352213, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('factor viii (antihemophilic factor, human)', 1352213, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('factor viii (antihemophilic factor, recombinant)', 1352213, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('factor xiii (antihemophilic factor', 1352213, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('factor xiii a-subunit', 45776421, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('factor viii fc fusion (recombinant)', 45776421, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('famotidine', 953076, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('fentanyl citrate', 1154029, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ferric carboxymaltose', 43560392, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ferric pyrophosphate citrate solution', 46221255, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ferumoxytol', 40163731, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('filgrastim (g-csf)', 1304850, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('finasteride', 996416, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('floxuridine', 1355509, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('fluconazole', 1754994, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('fludarabine phosphate', 1395557, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('flunisolide', 1196514, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('fluocinolone acetonide', 996541, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('fluocinolone acetonide intravitreal implant', 996541, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('fluorouracil', 955632, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('fluphenazine decanoate', 756018, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('flutamide', 1356461, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('follitropin alfa', 1542948, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('follitropin beta', 1597235, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('fomepizole', 19022479, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('fomivirsen sodium', 19048999, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('fondaparinux sodium', 1315865, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('formoterol', 1196677, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('formoterol fumarate', 1196677, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('fosaprepitant', 19022131, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('foscarnet sodium', 1724700, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('fosphenytoin', 713192, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('fosphenytoin sodium', 713192, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('fulvestrant', 1304044, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('furosemide', 956874, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('gadobenate dimeglumine (multihance multipack)', 19097468, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('gadobenate dimeglumine (multihance)', 19097468, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('gadobutrol', 19048493, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('gadofosveset trisodium', 43012718, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('gadoterate meglumine', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('gadoteridol', 19097463, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('gadoxetate disodium', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('gallium nitrate', 42899259, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('galsulfase', 19078649, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('gamma globulin', 19117912, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ganciclovir', 1757803, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ganciclovir sodium', 1757803, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ganirelix acetate', 1536743, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('garamycin', 919345, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('gatifloxacin', 1789276, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('gefitinib', 1319193, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('gemcitabine hydrochloride', 1314924, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('gemtuzumab ozogamicin', 19098566, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('glatiramer acetate', 751889, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('glucagon hydrochloride', 1560278, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('glucarpidase', 42709319, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('glycopyrrolate', 963353, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('gold sodium thiomalate', 1152134, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('golimumab', 19041065, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('gonadorelin hydrochloride', 19089810, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('goserelin acetate', 1366310, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('graftjacket xpress', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('granisetron hydrochloride', 1000772, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('haloperidol', 766529, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('haloperidol decanoate', 766529, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hemin', 19067303, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('heparin sodium', 1367571, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hepatitis b immune globulin (hepagam b)', 501343, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hepatitis b vaccine', 528323, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hexaminolevulinate hydrochloride', 43532423, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('high risk population (use only with codes for immunization)', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('histrelin', 1366773, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('histrelin acetate', 1366773, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('home infusion therapy', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('human fibrinogen concentrate', 19044986, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('human plasma fibrin sealant', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hyaluronan or derivative', 787787, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hyaluronidase', 19073699, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hydralazine hcl', 1373928, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hydrocortisone acetate', 975125, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hydrocortisone sodium  phosphate', 975125, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hydrocortisone sodium succinate', 975125, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hydromorphone', 1126658, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hydromorphone hydrochloride', 1126658, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hydroxyprogesterone caproate', 19077143, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hydroxyurea', 1377141, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hydroxyzine hcl', 777221, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hydroxyzine pamoate', 777221, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hyoscyamine sulfate', 923672, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('hypertonic saline solution', 967823, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ibandronate sodium', 1512480, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ibuprofen', 1177480, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ibutilide fumarate', 19050087, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('icatibant', 40242044, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('idarubicin hydrochloride', 19078097, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('idursulfase', 19091430, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ifosfamide', 19078187, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('iloprost', 1344992, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('imatinib', 1304107, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('imiglucerase', 1348407, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('immune globulin', 19117912, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('immune globulin (bivigam)', 19117912, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('immune globulin (gammaplex)', 19117912, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('immune globulin (hizentra)', 19117912, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('immune globulin (privigen)', 19117912, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('immune globulin (vivaglobin)', 19117912, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('immunizations/vaccinations', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('incobotulinumtoxin a', 40224763, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('infliximab', 937368, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('influenza vaccine, recombinant hemagglutinin antigens, for intramuscular use (flublok)', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('influenza virus vaccine', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('influenza virus vaccine, split virus, for intramuscular use (agriflu)', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('injectable anesthetic', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('injectable bulking agent', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('injectable poly-l-lactic acid', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('insulin', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('insulin intermediate acting (nph or lente)', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('insulin long acting', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('insulin most rapid onset (lispro or aspart)', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('insulin per 5 units', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('insulin rapid onset', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('interferon alfa-2a', 1379969, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('interferon alfa-2b', 1380068, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('interferon alfacon-1', 1781314, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('interferon alfa-n3', 1385645, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('interferon beta-1a', 722424, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('interferon beta-1b', 713196, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('interferon gamma 1-b', 1380191, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pegylated interferon alfa-2a', 1714165, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pegylated interferon alfa-2b', 1797155, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('intravenous', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ipilimumab', 40238188, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ipratropium bromide', 1112921, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('irinotecan', 1367268, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('iron dextran', 1381661, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('iron dextran 165', 1381661, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('iron dextran 267', 1381661, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('iron sucrose', 1395773, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('irrigation solution', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('isavuconazonium', 46221284, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('isavuconazonium sulfate', 46221284, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('isoetharine hcl', 1181809, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('isoproterenol hcl', 1183554, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('itraconazole', 1703653, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ixabepilone', 19025348, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('kanamycin sulfate', 1784749, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ketorolac tromethamine', 1136980, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('lacosamide', 19087394, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('lanreotide', 1503501, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('lanreotide acetate', 1503501, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('laronidase', 1543229, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('lepirudin', 19092139, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('leucovorin calcium', 1388796, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('leuprolide acetate', 1351541, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('leuprolide acetate (for depot suspension)', 1351541, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('levalbuterol', 1192218, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('levodopa', 789578, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('levamisole hydrochloride', 1389464, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('levetiracetam', 711584, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('levocarnitine', 1553610, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('levofloxacin', 1742253, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('levoleucovorin calcium', 40168303, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('levonorgestrel-releasing intrauterine contraceptive system', 1589505, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('levorphanol tartrate', 1189766, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('lidocaine hcl for intravenous infusion', 989878, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('lincomycin hcl', 1790692, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('linezolid', 1736887, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('liquid)', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('lomustine', 1391846, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('lorazepam', 791967, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('loxapine', 792263, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('lymphocyte immune globulin, antithymocyte globulin, equine', 19003476, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('lymphocyte immune globulin, antithymocyte globulin, rabbit', 19136207, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('magnesium sulfate', 19093848, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('mannitol', 994058, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('mecasermin', 1502877, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('mechlorethamine hydrochloride', 1394337, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('medroxyprogesterone acetate', 1500211, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('medroxyprogesterone acetate for contraceptive use', 1500211, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('megestrol acetate', 1300978, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('melphalan', 1301267, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('melphalan hydrochloride', 1301267, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('menotropins', 19125388, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('meperidine hydrochloride', 1102527, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('mepivacaine hydrochloride', 702774, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('mercaptopurine', 1436650, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('meropenem', 1709170, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('mesna', 1354698, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('metaproterenol sulfate', 1123995, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('metaraminol bitartrate', 19003303, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('methacholine chloride', 19024227, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('methadone', 1103640, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('methadone hcl', 1103640, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('methocarbamol', 704943, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('methotrexate', 1305058, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('methotrexate sodium', 1305058, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('methyl aminolevulinate (mal)', 924120, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('methyldopate hcl', 1305496, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('methylene blue', 905518, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('methylergonovine maleate', 1305637, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('methylnaltrexone', 909841, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('methylprednisolone', 1506270, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('methylprednisolone acetate', 1506270, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('methylprednisolone sodium succinate', 1506270, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('metoclopramide hcl', 906780, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('metronidazole', 1707164, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('micafungin sodium', 19018013, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('midazolam hydrochloride', 708298, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('mifepristone', 1508439, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('milrinone lactate', 1368671, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('minocycline hydrochloride', 1708880, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('minoxidil', 1309068, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('misoprostol', 1150871, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('mitomycin', 1389036, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('mitoxantrone hydrochloride', 1309188, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('mometasone furoate ', 905233, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('morphine sulfate', 1110410, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('morphine sulfate (preservative-free sterile solution)', 1110410, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('moxifloxacin', 1716903, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('multiple vitamins', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('muromonab-cd3', 19051865, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('mycophenolate mofetil', 19003999, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('mycophenolic acid', 19012565, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('nabilone', 913440, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('nafcillin sodium', 1713930, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('nalbuphine hydrochloride', 1114122, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('naloxone hydrochloride', 1114220, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('naltrexone', 1714319, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('nandrolone decanoate', 1514412, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('nasal vaccine inhalation', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('natalizumab', 735843, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('nelarabine', 19002912, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('neostigmine methylsulfate', 717136, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('neoxflo or clarixflo', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('nesiritide', 1338985, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('netupitant', 45774966, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('nicotine', 718583, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('nivolumab', 45892628, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('noc drugs', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('non-radioactive', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('normal saline solution', 967823, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('obinutuzumab', 44507676, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ocriplasmin', 42904298, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('octafluoropropane microspheres', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('octreotide', 1522957, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ofatumumab', 40167582, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ofloxacin', 923081, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('olanzapine', 785788, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('omacetaxine mepesuccinate', 19069046, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('omalizumab', 1110942, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('onabotulinumtoxina', 40165651, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ondansetron', 1000560, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ondansetron 1 mg', 1000560, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ondansetron hydrochloride', 1000560, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ondansetron hydrochloride 8  mg', 1000560, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('oprelvekin', 1318030, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('oritavancin', 45776147, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('orphenadrine citrate', 724394, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('oseltamivir phosphate', 1799139, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('oxacillin sodium', 1724703, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('oxaliplatin', 1318011, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('oxygen contents', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('oxymorphone hcl', 1125765, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('oxytetracycline hcl', 925952, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('oxytocin', 1326115, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('paclitaxel', 1378382, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('paclitaxel protein-bound particles', 1378382, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('palifermin', 19038562, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('paliperidone palmitate', 703244, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('paliperidone palmitate extended release', 703244, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('palivizumab-rsv-igm', 537647, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('palonosetron', 911354, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('palonosetron hcl', 911354, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pamidronate disodium', 1511646, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('panitumumab', 19100985, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pantoprazole sodium', 948078, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('papaverine hcl', 1326901, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('peramivir', 40167569, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('paricalcitol', 1517740, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pasireotide long acting', 43012417, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pegademase bovine', 581480, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pegaptanib sodium', 19063605, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pegaspargase', 1326481, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pegfilgrastim', 1325608, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('peginesatide', 42709327, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pegloticase', 40226208, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pembrolizumab', 45775965, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pemetrexed', 1304919, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('penicillin g benzathine', 1728416, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('penicillin g benzathine and penicillin g procaine', 1728416, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('penicillin g potassium', 1728416, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('penicillin g procaine', 1728416, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pentamidine isethionate', 1730370, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pentastarch', 40161354, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pentazocine', 1130585, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pentobarbital sodium', 730729, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pentostatin', 19031224, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('perflexane lipid microspheres', 45775689, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('perflutren lipid microspheres', 19071160, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('perphenazine', 733008, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pertuzumab', 42801287, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('phenobarbital sodium', 734275, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('phentolamine mesylate', 1335539, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('phenylephrine hcl', 1135766, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('phenytoin sodium', 740910, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('phytonadione (vitamin k)', 19044727, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('piperacillin sodium', 1746114, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('plasma protein fraction (human)', 19025693, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('platelet rich plasma', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('plerixafor', 19017581, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('plicamycin', 19009165, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pneumococcal conjugate vaccine', 513909, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pneumococcal vaccine', 513909, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('porfimer sodium', 19090420, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('potassium chloride', 19049105, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pralatrexate', 40166461, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pralidoxime chloride', 1727468, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('prednisolone', 1550557, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('prednisolone acetate', 1550557, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('prednisone', 1551099, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('prescription drug', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('procainamide hcl', 1351461, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('procarbazine hydrochloride', 1351779, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('prochlorperazine', 752061, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('prochlorperazine maleate', 752061, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('progesterone', 1552310, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('promazine hcl', 19052903, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('promethazine hcl', 1153013, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('promethazine hydrochloride', 1153013, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('propofol', 753626, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('propranolol hcl', 1353766, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('protamine sulfate', 19054242, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('protein c concentrate', 42801108, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('prothrombin complex concentrate (human), kcentra', 44507865, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('protirelin', 19001701, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('pyridoxine hcl', 42903728, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('radiesse', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ramucirumab', 44818489, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ranibizumab', 19080982, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ranitidine hydrochloride', 961047, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('rasburicase', 1304565, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('regadenoson', 19090761, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('respiratory syncytial virus immune globulin', 19013765, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('reteplase', 19024191, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('rho d immune globulin', 535714, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('rho(d) immune globulin (human)', 535714, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('rilonacept', 19023450, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('rimabotulinumtoxinb', 40166020, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('rimantadine hydrochloride', 1763339, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('risperidone', 735979, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('rituximab', 1314273, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('romidepsin', 40168385, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('romiplostim', 19032407, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ropivacaine hydrochloride', 1136487, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('saquinavir', 1746244, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sargramostim (gm-csf)', 1308432, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sculptra', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('secretin', 19066188, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sermorelin acetate', 19077457, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sildenafil citrate', 1316262, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sincalide', 19067803, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('single vitamin/mineral/trace element', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sipuleucel-t', 40224095, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sirolimus', 19034726, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('siltuximab', 44818461, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sodium chloride', 967823, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sodium ferric gluconate complex in sucrose injection', 1399177, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sodium hyaluronate', 787787, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('somatrem', 1578181, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('somatropin', 1584910, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('spectinomycin dihydrochloride', 1701651, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('state supplied vaccine', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sterile cefuroxime sodium', 1778162, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sterile dilutant', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sterile saline or water', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sterile water', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sterile water/saline', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('streptokinase', 19136187, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('streptomycin', 1836191, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('streptozocin', 19136210, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('succinylcholine chloride', 836208, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sulfur hexafluoride lipid microsphere', 45892833, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sumatriptan succinate', 1140643, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('syringe', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('syringe with needle', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tacrine hydrochloride', 836654, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tacrolimus', 950637, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('taliglucerase alfa', 42800246, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('taliglucerace alfa', 42800246, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tamoxifen citrate', 1436678, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tbo-filgrastim', 1304850, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tedizolid phosphate', 45775686, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('telavancin', 40166675, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('temozolomide', 1341149, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('temsirolimus', 19092845, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tenecteplase', 19098548, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('teniposide', 19136750, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('terbutaline sulfate', 1236744, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('teriparatide', 1521987, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('testosterone cypionate', 1636780, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('testosterone enanthate', 1636780, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('testosterone pellet', 1636780, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('testosterone propionate', 1636780, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('testosterone suspension', 1636780, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('testosterone undecanoate', 1636780, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tetanus immune globulin', 561401, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tetracycline', 1836948, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('theophylline', 1237049, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('thiamine hcl', 19137312, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('thiethylperazine maleate', 1037358, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('thiotepa', 19137385, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('thyrotropin alpha', 19007721, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tigecycline', 1742432, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tinzaparin sodium', 1308473, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tirofiban hcl', 19017067, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tissue marker', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tobramycin', 902722, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tobramycin sulfate', 902722, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tocilizumab', 40171288, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tolazoline hcl', 19002829, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('topotecan', 1378509, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('torsemide', 942350, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tositumomab', 19068894, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('trastuzumab', 1387104, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('treprostinil', 1327256, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tretinoin', 903643, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('triamcinolone', 903963, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('triamcinolone acetonide', 903963, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('triamcinolone diacetate', 903963, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('triamcinolone hexacetonide', 903963, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('triflupromazine hcl', 19005104, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('trimethobenzamide hcl', 942799, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('trimethobenzamide hydrochloride', 942799, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('trimetrexate glucuronate', 1750928, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('triptorelin pamoate', 1343039, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('urea', 906914, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('urofollitropin', 1515417, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('urokinase', 1307515, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ustekinumab', 40161532, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('vaccine for part d drug', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('valrubicin', 19012543, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('vancomycin hcl', 1707687, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('vascular graft material, synthetic', 0, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('vedolizumab', 45774639, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('velaglucerase alfa', 40174604, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('verteporfin', 912803, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('vinblastine sulfate', 19008264, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('vincristine sulfate', 1308290, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('vincristine sulfate liposome', 1308290, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('vinorelbine tartrate', 1343346, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('vitamin b-12 cyanocobalamin', 1308738, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('von willebrand factor complex', 44785885, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('von willebrand factor complex (human)', 44785885, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('von willebrand factor complex (humate-p)', 44785885, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('voriconazole', 1714277, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('water', null, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('zalcitabine (ddc)', 1724827, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ziconotide', 19005061, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('zidovudine', 1710612, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ziprasidone mesylate', 712615, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ziv-aflibercept', 40244266, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('zoledronic acid', 1524674, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('zoledronic acid (reclast)', 1524674, null);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('zoledronic acid (zometa)', 1524674, null);
end;
commit;

-- Add ingredients and their mappings that are not automatically generated
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('calcium chloride', 19036781, null); -- Ringer
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('calcium chloride', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sodium lactate', 19011035, null); -- Ringer. Lactate is precise ingredient
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('sodium lactate', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dextrose', 1560524, null); -- Dextrose
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('dextrose', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sodium bicarbonate', 939506, null); -- Elliot's
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('sodium bicarbonate', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sodium phosphate', 939871, null); -- Elliot's
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('sodium phosphate', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sulbactam', 1836241, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('sulbactam', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tazobactam', 1741122, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('tazobactam', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('tetracaine', 1036884, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('tetracaine', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('quinupristin', 1789515, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('quinupristin', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('dalfopristin', 1789517, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('dalfopristin', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('calcium glycerophosphate', 1337159, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('calcium glycerophosphate', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('calcium lactate', 19058896, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('calcium lactate', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('avibactam', 46221507, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('avibactam', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ceftolozane', 45892599, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('ceftolozane', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('netupitant', 45774966, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('netupitant', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('sulfamethoxazole', 1836430, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('sulfamethoxazole', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('trimethoprim', 1705674, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('trimethoprim', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('ticarcillin', 1759842, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('ticarcillin', 'HCPCS', 'Ingredient');
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('clavulanate', 1702364, null);
insert into drug_concept_stage (concept_code, vocabulary_id, concept_class_id) values ('clavulanate', 'HCPCS', 'Ingredient');

-- Add ingredients for combination products
-- 5% dextrose and 0.45% normal saline
insert into internal_relationship_stage
select concept_code_1, 'dextrose' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose and 0.45% normal saline';
insert into internal_relationship_stage
select concept_code_1, 'normal saline solution' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose and 0.45% normal saline';
delete from internal_relationship_stage where concept_code_2='5% dextrose and 0.45% normal saline';
-- 5% dextrose in lactated ringer's
-- Calcium Chloride 0.001 MEQ/ML / Glucose 50 MG/ML / Potassium Chloride 0.004 MEQ/ML / Sodium Chloride 0.103 MEQ/ML / Sodium Lactate 0.028 MEQ/ML Injectable Solution
insert into internal_relationship_stage
select concept_code_1, 'dextrose' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringer''s';
insert into internal_relationship_stage
select concept_code_1, 'calcium chloride' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringer''s';
insert into internal_relationship_stage
select concept_code_1, 'potassium chloride' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringer''s';
insert into internal_relationship_stage
select concept_code_1, 'normal saline solution' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringer''s';
insert into internal_relationship_stage
select concept_code_1, 'sodium lactate' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringer''s';
delete from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringer''s';
-- 5% dextrose in lactated ringers infusion
-- Calcium Chloride 0.001 MEQ/ML / Glucose 50 MG/ML / Potassium Chloride 0.004 MEQ/ML / Sodium Chloride 0.103 MEQ/ML / Sodium Lactate 0.028 MEQ/ML Injectable Solution
insert into internal_relationship_stage
select concept_code_1, 'dextrose' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringers infusion';
insert into internal_relationship_stage
select concept_code_1, 'calcium chloride' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringers infusion';
insert into internal_relationship_stage
select concept_code_1, 'potassium chloride' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringers infusion';
insert into internal_relationship_stage
select concept_code_1, 'normal saline solution' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringers infusion';
insert into internal_relationship_stage
select concept_code_1, 'sodium lactate' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringers infusion';
delete from internal_relationship_stage where concept_code_2='5% dextrose in lactated ringers infusion';
-- 5% dextrose with potassium chloride
insert into internal_relationship_stage
select concept_code_1, 'dextrose' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose with potassium chloride';
insert into internal_relationship_stage
select concept_code_1, 'potassium chloride' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose with potassium chloride';
delete from internal_relationship_stage where concept_code_2='5% dextrose with potassium chloride';
-- both ingredients already defined 
-- 5% dextrose/0.45% normal saline with potassium chloride and magnesium sulfate
insert into internal_relationship_stage
select concept_code_1, 'dextrose' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose/0.45% normal saline with potassium chloride and magnesium sulfate';
insert into internal_relationship_stage
select concept_code_1, 'normal saline solution' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose/0.45% normal saline with potassium chloride and magnesium sulfate';
insert into internal_relationship_stage
select concept_code_1, 'potassium chloride' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose/0.45% normal saline with potassium chloride and magnesium sulfate';
insert into internal_relationship_stage
select concept_code_1, 'magnesium sulfate' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose/0.45% normal saline with potassium chloride and magnesium sulfate';
delete from internal_relationship_stage where concept_code_2='5% dextrose/0.45% normal saline with potassium chloride and magnesium sulfate';
-- all ingredients already defined
-- 5% dextrose/normal saline (500 ml = 1 unit)
insert into internal_relationship_stage
select concept_code_1, 'dextrose' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose/normal saline (500 ml = 1 unit)';
insert into internal_relationship_stage
select concept_code_1, 'normal saline solution' as concept_code_2 from internal_relationship_stage where concept_code_2='5% dextrose/normal saline (500 ml = 1 unit)';
delete from internal_relationship_stage where concept_code_2='5% dextrose/normal saline (500 ml = 1 unit)';
-- both ingredients already defined
-- albuterol/ipratropium bromide up to 0.5 mg
insert into internal_relationship_stage
select concept_code_1, 'albuterol' as concept_code_2 from internal_relationship_stage where concept_code_2='albuterol/ipratropium bromide up to 0.5 mg';
insert into internal_relationship_stage
select concept_code_1, 'ipratropium bromide' as concept_code_2 from internal_relationship_stage where concept_code_2='albuterol/ipratropium bromide up to 0.5 mg';
delete from internal_relationship_stage where concept_code_2='albuterol/ipratropium bromide up to 0.5 mg';
-- both ingredients already defined
-- ampicillin sodium/sulbactam sodium
insert into internal_relationship_stage
select concept_code_1, 'ampicillin sodium' as concept_code_2 from internal_relationship_stage where concept_code_2='ampicillin sodium/sulbactam sodium';
insert into internal_relationship_stage
select concept_code_1, 'sulbactam' as concept_code_2 from internal_relationship_stage where concept_code_2='ampicillin sodium/sulbactam sodium';
delete from internal_relationship_stage where concept_code_2='ampicillin sodium/sulbactam sodium';
-- antihemophilic factor viii/von willebrand factor complex (human)
insert into internal_relationship_stage
select concept_code_1, 'factor viii' as concept_code_2 from internal_relationship_stage where concept_code_2='antihemophilic factor viii/von willebrand factor complex (human)';
insert into internal_relationship_stage
select concept_code_1, 'von willebrand factor complex' as concept_code_2 from internal_relationship_stage where concept_code_2='antihemophilic factor viii/von willebrand factor complex (human)';
delete from internal_relationship_stage where concept_code_2='antihemophilic factor viii/von willebrand factor complex (human)';
-- both ingredients already defined
-- buprenorphine/naloxone
insert into internal_relationship_stage
select concept_code_1, 'buprenorphine hydrochloride' as concept_code_2 from internal_relationship_stage where concept_code_2='buprenorphine/naloxone';
insert into internal_relationship_stage
select concept_code_1, 'naloxone hydrochloride' as concept_code_2 from internal_relationship_stage where concept_code_2='buprenorphine/naloxone';
delete from internal_relationship_stage where concept_code_2='buprenorphine/naloxone';
-- both ingredients defined already
-- elliot b solution
-- Calcium Chloride 0.00136 MEQ/ML / Glucose 0.8 MG/ML / Magnesium Sulfate 0.00122 MEQ/ML / Potassium Chloride 0.00403 MEQ/ML / Sodium Bicarbonate 0.0226 MEQ/ML / Sodium Chloride 0.125 MEQ/ML / sodium phosphate 0.000746 MEQ/ML Injectable Solution [Elliotts B
insert into internal_relationship_stage
select concept_code_1, 'sodium bicarbonate' as concept_code_2 from internal_relationship_stage where concept_code_2='elliotts'' b solution';
insert into internal_relationship_stage
select concept_code_1, 'sodium phosphate' as concept_code_2 from internal_relationship_stage where concept_code_2='elliotts'' b solution';
insert into internal_relationship_stage
select concept_code_1, 'normal saline solution' as concept_code_2 from internal_relationship_stage where concept_code_2='elliotts'' b solution';
insert into internal_relationship_stage
select concept_code_1, 'dextrose' as concept_code_2 from internal_relationship_stage where concept_code_2='elliotts'' b solution';
insert into internal_relationship_stage
select concept_code_1, 'calcium chloride' as concept_code_2 from internal_relationship_stage where concept_code_2='elliotts'' b solution';
insert into internal_relationship_stage
select concept_code_1, 'potassiuim chloride' as concept_code_2 from internal_relationship_stage where concept_code_2='elliotts'' b solution';
insert into internal_relationship_stage
select concept_code_1, 'magnesium sulfate' as concept_code_2 from internal_relationship_stage where concept_code_2='elliotts'' b solution';
delete from internal_relationship_stage where concept_code_2='elliotts'' b solution';
-- some of the ingredients are already defined
-- immune globulin/hyaluronidase
insert into internal_relationship_stage
select concept_code_1, 'immune globulin' as concept_code_2 from internal_relationship_stage where concept_code_2='immune globulin/hyaluronidase';
insert into internal_relationship_stage
select concept_code_1, 'hyaluronidase' as concept_code_2 from internal_relationship_stage where concept_code_2='immune globulin/hyaluronidase';
delete from internal_relationship_stage where concept_code_2='immune globulin/hyaluronidase';
-- both ingredients definded already
-- lidocaine /tetracaine 
insert into internal_relationship_stage
select concept_code_1, 'lidocaine hcl for intravenous infusion' as concept_code_2 from internal_relationship_stage where concept_code_2='lidocaine /tetracaine ';
insert into internal_relationship_stage
select concept_code_1, 'tetracaine' as concept_code_2 from internal_relationship_stage where concept_code_2='lidocaine /tetracaine ';
delete from internal_relationship_stage where concept_code_2='lidocaine /tetracaine ';
-- lidocaine already defined
-- medroxyprogesterone acetate / estradiol cypionate
insert into internal_relationship_stage
select concept_code_1, 'medroxyprogesterone acetate' as concept_code_2 from internal_relationship_stage where concept_code_2='medroxyprogesterone acetate / estradiol cypionate';
insert into internal_relationship_stage
select concept_code_1, 'depo-estradiol cypionate' as concept_code_2 from internal_relationship_stage where concept_code_2='medroxyprogesterone acetate / estradiol cypionate';
delete from internal_relationship_stage where concept_code_2='medroxyprogesterone acetate / estradiol cypionate';
-- both ingredients already defined
-- piperacillin sodium/tazobactam sodium
insert into internal_relationship_stage
select concept_code_1, 'piperacillin sodium' as concept_code_2 from internal_relationship_stage where concept_code_2='piperacillin sodium/tazobactam sodium';
insert into internal_relationship_stage
select concept_code_1, 'tazobactam' as concept_code_2 from internal_relationship_stage where concept_code_2='piperacillin sodium/tazobactam sodium';
delete from internal_relationship_stage where concept_code_2='piperacillin sodium/tazobactam sodium';
-- piperacillin already defined
-- quinupristin/dalfopristin
insert into internal_relationship_stage
select concept_code_1, 'quinupristin' as concept_code_2 from internal_relationship_stage where concept_code_2='quinupristin/dalfopristin';
insert into internal_relationship_stage
select concept_code_1, 'dalfopristin' as concept_code_2 from internal_relationship_stage where concept_code_2='quinupristin/dalfopristin';
delete from internal_relationship_stage where concept_code_2='quinupristin/dalfopristin';
-- calcium glycerophosphate and calcium lactate
insert into internal_relationship_stage
select concept_code_1, 'calcium glycerophosphate' as concept_code_2 from internal_relationship_stage where concept_code_2='calcium glycerophosphate and calcium lactate';
insert into internal_relationship_stage
select concept_code_1, 'calcium lactate' as concept_code_2 from internal_relationship_stage where concept_code_2='calcium glycerophosphate and calcium lactate';
delete from internal_relationship_stage where concept_code_2='calcium glycerophosphate and calcium lactate';
--- ceftazidime and avibactam
insert into internal_relationship_stage
select concept_code_1, 'ceftazidime' as concept_code_2 from internal_relationship_stage where concept_code_2='ceftazidime and avibactam';
insert into internal_relationship_stage
select concept_code_1, 'avibactam' as concept_code_2 from internal_relationship_stage where concept_code_2='ceftazidime and avibactam';
delete from internal_relationship_stage where concept_code_2='ceftazidime and avibactam';
-- ceftazidime already defined
-- ceftolozane 50 mg and tazobactam 25 mg
insert into internal_relationship_stage
select concept_code_1, 'ceftolozane' as concept_code_2 from internal_relationship_stage where concept_code_2='ceftolozane 50 mg and tazobactam 25 mg';
insert into internal_relationship_stage
select concept_code_1, 'tazobactam' as concept_code_2 from internal_relationship_stage where concept_code_2='ceftolozane 50 mg and tazobactam 25 mg';
delete from internal_relationship_stage where concept_code_2='ceftolozane 50 mg and tazobactam 25 mg';
-- tazobactam already defined
-- droperidol and fentanyl citrate
insert into internal_relationship_stage
select concept_code_1, 'droperidol' as concept_code_2 from internal_relationship_stage where concept_code_2='droperidol and fentanyl citrate';
insert into internal_relationship_stage
select concept_code_1, 'fentanyl citrate' as concept_code_2 from internal_relationship_stage where concept_code_2='droperidol and fentanyl citrate';
delete from internal_relationship_stage where concept_code_2='droperidol and fentanyl citrate';
-- both ingredients already defined
-- meperidine and promethazine hcl
insert into internal_relationship_stage
select concept_code_1, 'meperidine hydrochloride' as concept_code_2 from internal_relationship_stage where concept_code_2='meperidine and promethazine hcl';
insert into internal_relationship_stage
select concept_code_1, 'promethazine hcl' as concept_code_2 from internal_relationship_stage where concept_code_2='meperidine and promethazine hcl';
delete from internal_relationship_stage where concept_code_2='meperidine and promethazine hcl';
-- Both ingredients already defined
-- netupitant 300 mg and palonosetron 0.5 mg
insert into internal_relationship_stage
select concept_code_1, 'netupitant' as concept_code_2 from internal_relationship_stage where concept_code_2='netupitant 300 mg and palonosetron 0.5 mg';
insert into internal_relationship_stage
select concept_code_1, 'palonosetron hcl' as concept_code_2 from internal_relationship_stage where concept_code_2='netupitant 300 mg and palonosetron 0.5 mg';
delete from internal_relationship_stage where concept_code_2='netupitant 300 mg and palonosetron 0.5 mg';
-- palonosetron already defined
-- phenylephrine and ketorolac
insert into internal_relationship_stage
select concept_code_1, 'phenylephrine hcl' as concept_code_2 from internal_relationship_stage where concept_code_2='phenylephrine and ketorolac';
insert into internal_relationship_stage
select concept_code_1, 'ketorolac tromethamine' as concept_code_2 from internal_relationship_stage where concept_code_2='phenylephrine and ketorolac';
delete from internal_relationship_stage where concept_code_2='phenylephrine and ketorolac';
-- both ingredients already defined
-- ringers lactate infusion
-- Calcium Chloride 0.0014 MEQ/ML / Potassium Chloride 0.004 MEQ/ML / Sodium Chloride 0.103 MEQ/ML / Sodium Lactate 0.028 MEQ/ML Injectable Solution
insert into internal_relationship_stage
select concept_code_1, 'calcium chloride' as concept_code_2 from internal_relationship_stage where concept_code_2='ringers lactate infusion';
insert into internal_relationship_stage
select concept_code_1, 'potassium chloride' as concept_code_2 from internal_relationship_stage where concept_code_2='ringers lactate infusion';
insert into internal_relationship_stage
select concept_code_1, 'normal saline solution' as concept_code_2 from internal_relationship_stage where concept_code_2='ringers lactate infusion';
insert into internal_relationship_stage
select concept_code_1, 'sodium lactate' as concept_code_2 from internal_relationship_stage where concept_code_2='ringers lactate infusion';
delete from internal_relationship_stage where concept_code_2='ringers lactate infusion';
-- sulfamethoxazole and trimethoprim
insert into internal_relationship_stage
select concept_code_1, 'sulfamethoxazole' as concept_code_2 from internal_relationship_stage where concept_code_2='sulfamethoxazole and trimethoprim';
insert into internal_relationship_stage
select concept_code_1, 'trimethoprim' as concept_code_2 from internal_relationship_stage where concept_code_2='sulfamethoxazole and trimethoprim';
delete from internal_relationship_stage where concept_code_2='sulfamethoxazole and trimethoprim';
-- testosterone cypionate and estradiol cypionate
insert into internal_relationship_stage
select concept_code_1, 'testosterone cypionate' as concept_code_2 from internal_relationship_stage where concept_code_2='testosterone cypionate and estradiol cypionate';
insert into internal_relationship_stage
select concept_code_1, 'depo-estradiol cypionate' as concept_code_2 from internal_relationship_stage where concept_code_2='testosterone cypionate and estradiol cypionate';
delete from internal_relationship_stage where concept_code_2='testosterone cypionate and estradiol cypionate';
-- both ingredients already defined
-- testosterone enanthate and estradiol valerate
insert into internal_relationship_stage
select concept_code_1, 'testosterone enanthate' as concept_code_2 from internal_relationship_stage where concept_code_2='testosterone enanthate and estradiol valerate';
insert into internal_relationship_stage
select concept_code_1, 'estradiol valerate' as concept_code_2 from internal_relationship_stage where concept_code_2='testosterone enanthate and estradiol valerate';
delete from internal_relationship_stage where concept_code_2='testosterone enanthate and estradiol valerate';
-- both ingredients already defined
-- ticarcillin disodium and clavulanate potassium
insert into internal_relationship_stage
select concept_code_1, 'ticarcillin' as concept_code_2 from internal_relationship_stage where concept_code_2='ticarcillin disodium and clavulanate potassium';
insert into internal_relationship_stage
select concept_code_1, 'clavulanate' as concept_code_2 from internal_relationship_stage where concept_code_2='ticarcillin disodium and clavulanate potassium';
delete from internal_relationship_stage where concept_code_2='ticarcillin disodium and clavulanate potassium';

-- Add and remove ingredients
delete from drug_concept_stage where concept_class_id='Ingredient' and concept_code not in (select concept_code_2 from internal_relationship_stage);
commit;

/*********************************************
* 3. Create Dose Forms and links to products *
*********************************************/
insert /*+ APPEND */ into drug_concept_stage
select distinct dose_form as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Dose Form' as concept_class_id, 
  dose_form as concept_code, null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason,
  dose_form
from drug_concept_stage where concept_class_id='Procedure Drug'
;
commit;

insert /*+ APPEND */ into internal_relationship_stage 
select d.concept_code as concept_code_1, df.concept_code as concept_code_2
from drug_concept_stage d
join drug_concept_stage df on df.concept_code=d.dose_form and df.concept_class_id='Dose Form'
where d.concept_class_id='Procedure Drug'
;
commit;

-- Manually create Dose Form mapping to RxNorm
begin
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Infusion', 19082103, 1);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Infusion', 19082104, 2);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Infusion', 46234469, 3);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Inhalant', 19082259, 2);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Inhalant', 19095898, 1);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Inhalant', 19126918, 3);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Inhalant', 19082162, 4);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Inhalant', 19126919, 5);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Inhalant', 19127579, 6);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Inhalant', 19082258, 7);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Inhalant', 19018195, 8);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Injection', 19082103, 1);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Injection', 19126920, 2);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Injection', 19082104, 3);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Injection', 46234469, 4);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Injection', 46234468, 5);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Injection', 19095913, 6);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Injection', 19095914, 7);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Injection', 19082105, 8);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Injection', 44784844, 9);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Injection', 46234466, 10);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Injection', 46234467, 11);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Injection', 46275062, 12);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Injection', 19095915, 13);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Injection', 19082260, 14);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082573, 1);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082168, 2);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082191, 3);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082170, 4);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082251, 5);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19001144, 6);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082652, 7);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19095976, 8);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082651, 9);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082253, 10);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082101, 11);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19111148, 12);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082169, 13);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19001943, 14);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19135868, 15);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19021887, 16);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082223, 17);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082077, 18);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082079, 19);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082080, 20);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 44817840, 21);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082255, 22);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19001949, 23);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082076, 24);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19103220, 25);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082048, 26);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082256, 27);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082050, 28);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 40164192, 29);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 40175589, 30);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082222, 31);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082075, 32);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19135866, 33);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19102296, 34);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19018708, 35);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19135790, 36);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 45775489, 37);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 45775490, 38);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 45775491, 39);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 45775492, 40);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19111155, 41);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19126316, 42);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Oral', 19082285, 43);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Patch', 19082229, 1);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Patch', 19082701, 2);
-- insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Patch', 19082224, 3); -- Topical cream
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Patch', 19082049, 4);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Patch', 19082071, 5);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Patch', 19082072, 6);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Patch', 19082252, 7);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Patch', 19082073, 8);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082228, 1);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082224, 2);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19095912, 3);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 46234410, 4);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082227, 5);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082226, 6);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082225, 7);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19095972, 8);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19095973, 9);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19095912, 10);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082628, 11);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19135438, 12);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19135446, 13);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19135439, 14);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19135440, 15);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19129401, 16);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082287, 17);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19135925, 18);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082194, 19);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19095975, 20);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082164, 21);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19110977, 22);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082161, 23);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082576, 24);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082169, 25);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082193, 26);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082197, 27);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19010878, 28);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19112544, 29);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082163, 30);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082166, 31);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19095916, 32);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19095917, 33);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19095973, 34);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19095974, 35);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19010880, 36);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19011932, 37);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 40228565, 38);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19095900, 39);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19011167, 40);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19095911, 41);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082281, 42);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082199, 43);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19095899, 44);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19112649, 45);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082110, 46);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082165, 47);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082195, 48);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 45775488, 49);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19095977, 50);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082167, 51);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082196, 52);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19082102, 53);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Topical', 19010879, 54);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Spray', 19095899, 1);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Spray', 19095911, 2);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Spray', 19011167, 3);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Spray', 19082199, 4);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Spray', 19082281, 5);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Spray', 19095912, 6);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Spray', 19112649, 7);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Spray', 19095900, 8);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Vaccine', 19082104, 1);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Vaccine', 19126920, 2);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Vaccine', 19082103, 3);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Vaccine', 46234469, 4);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Vaccine', 19011167, 5);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Vaccine', 19082191, 6);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Vaccine', 19001949, 7);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Vaccine', 19082255, 8);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Suppository', 19082200, 1);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Suppository', 19093368, 2);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Suppository', 19082575, 3);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082573, 1);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082103, 2);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082168, 3);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082170, 4);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082079, 5);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082224, 6);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082191, 7);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082227, 8);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082228, 9);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19135866, 10);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082077, 11);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19095973, 12);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082225, 13);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19129634, 14);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19126920, 15);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082200, 16);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082253, 17);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19095912, 18);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082104, 19);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19001949, 20);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082229, 21);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19008697, 22);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 46234469, 23);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19095898, 24);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082076, 25);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19130307, 26);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082258, 27);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082255, 28);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082109, 29);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19135925, 30);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19095916, 31);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082080, 32);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082285, 33);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082286, 34);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19095972, 35);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19011167, 36);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19126590, 37);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19093368, 38);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082195, 39);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082165, 40);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19009068, 41);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082167, 42);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19016586, 43);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19095976, 44);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082108, 45);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082226, 46);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19102295, 47);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19010878, 48);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082627, 49);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082259, 50);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082110, 51);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082651, 52);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 44817840, 53);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19126918, 54);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19124968, 55);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082251, 56);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19129139, 57);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19095900, 58);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082197, 59);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19102296, 60);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082282, 61);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19095911, 62);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 46234468, 63);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19010880, 64);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19126316, 65);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 46234466, 66);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19010962, 67);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082166, 68);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19126919, 69);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19095918, 70);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19127579, 71);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 46234467, 72);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 40175589, 73);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082281, 74);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19059413, 75);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082196, 76);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082163, 77);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082169, 78);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19112648, 79);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19095917, 80);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19095971, 81);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082162, 82);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 40164192, 83);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082574, 84);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082105, 85);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082222, 86);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082575, 87);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082652, 88);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 45775489, 89);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 45775491, 90);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082164, 91);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 40167393, 92);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082287, 93);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082194, 94);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082576, 95);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19095975, 96);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082628, 97);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 46275062, 98);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19010879, 99);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 46234410, 100);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19135439, 101);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19095977, 102);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082199, 103);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082283, 104);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19095974, 105);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19135446, 106);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19130329, 107);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 45775490, 108);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 45775492, 109);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19082101, 110);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19135440, 111);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 19135438, 112);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 45775488, 113);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Unknown', 44784844, 114);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Instillation', 19016586, 1);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Instillation', 46234410, 2);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Instillation', 19082104, 3);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Instillation', 19082103, 4);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Instillation', 46234469, 5);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Implant', 19124968, 1);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Implant', 19082103, 2);
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence) values ('Implant', 19082104, 3);
end;
commit;

/*********************************
* 4. Create and link Drug Strength
*********************************/
-- Write units
insert /*+ APPEND */ into drug_concept_stage
select distinct 
  u as concept_name, 'Drug', 'HCPCS' as vocabulary_id, 'Unit' as concept_class_id, u as concept_code, 
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
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('i.u.', 8718, 1, 1); -- to international unit
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('i.u.', 8510, 2, 1); -- to unit
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('iu', 8718, 1, 1); -- to international unit
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('iu', 8510, 2, 1); -- to unit
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('unit', 8510, 1, 1); -- to unit
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('unit', 8718, 2, 1); -- to international unit
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('units', 8510, 1, 1); -- to unit
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('units', 8718, 2, 1); -- to international unit
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('million units', 8510, 1, 1000000); -- to unit
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('million units', 8718, 2, 1000000); -- to international unit
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('gm', 8576, 1, 1000); -- to milligram
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('gm', 8587, 2, 1); -- to milliliter
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('gram', 8576, 1, 1000); -- to milligram
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('gram', 8587, 2, 1); -- to milliliter
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('grams', 8576, 1, 1000); -- to milligram
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('grams', 8587, 2, 1); -- to milliliter
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('mg', 8576, 1, 1); -- to milligram
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('milligram', 8576, 1, 1); -- to milligram
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('milligrams', 8576, 1, 1); -- to milligram
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('mcg', 8576, 1, 0.001); -- to milligram
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('meq', 9551, 1, 1); 
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('microgram', 8576, 1, 0.001); -- to milligram
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('micrograms', 8576, 1, 0.001); -- to milligram
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('ml', 8587, 1, 1); -- to milliliter
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('ml', 8576, 2, 1000); -- to milligram
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('cc', 8587, 1, 1); -- to milliliter
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('cc', 8576, 2, 1000); -- to milligram
insert into relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) values ('%', 8554, 2, 1);
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
select distinct brandname as concept_name, 'Drug' as domain_id, 'HCPCS' as vocabulary_id, 'Brand Name' as concept_class_id, brandname as concept_code, 
  null as possible_excipient, null as valid_start_date, null as valid_end_date, null as invalid_reason, null as dose_form
from brandname;
commit;

insert /*+ APPEND */ into relationship_to_concept
select distinct brandname as concept_code_1, concept_id as concept_id_2, 1 as precedence, null as conversion_factor
from brandname;
commit;

insert /*+ APPEND */ into internal_relationship_stage 
select distinct concept_code as concept_code_1, brandname as concept_code_2
from brandname;
commit;

/****************************
* 6. Clean up
*****************************/
-- remove dose forms from concept_stage table
alter table drug_concept_stage drop column dose_form;
drop table drug_concept_stage_tmp purge;
drop table brandname purge;