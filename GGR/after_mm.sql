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
**************************************************************************/

insert into relationship_to_concept --Measurement Units
select distinct 
  concept_code as CONCEPT_CODE_1,
  'BCFI' as VOCABULARY_ID_1,
  concept_ID as CONCEPT_ID_2,
  1 as PRECEDENCE,
  nvl (CONVERSION_FACTOR, 1) as CONVERSION_FACTOR
from tomap_unit;

insert into relationship_to_concept --Dose Forms
select distinct 
  concept_code as CONCEPT_CODE_1,
  'BCFI' as VOCABULARY_ID_1,
  mapped_id as CONCEPT_ID_2,
  nvl (precedence, 1) as PRECEDENCE,
  null as CONVERSION_FACTOR
from tomap_form;

insert into relationship_to_concept -- Suppliers
select distinct 
  concept_code as CONCEPT_CODE_1,
  'BCFI' as VOCABULARY_ID_1,
  mapped_id as CONCEPT_ID_2,
  1 as PRECEDENCE,
  null as CONVERSION_FACTOR
from tomap_supplier
  where mapped_id is not null;
  
insert into relationship_to_concept -- Brand names
select distinct 
  concept_code as CONCEPT_CODE_1,
  'BCFI' as VOCABULARY_ID_1,
  mapped_id as CONCEPT_ID_2,
  1 as PRECEDENCE,
  null as CONVERSION_FACTOR
from tomap_bn
  where mapped_id is not null;
  
-- will contain only duplicate replacements for clean creation of internal_relationship_stage and ds_stage  
create table dupe_fix as 
select
  rm.concept_code as concept_code_1,
  mb.concept_code as concept_code_2  
from drug_concept_stage rm
join tomap_bn mb
on rm.concept_name = mb.concept_name and rm.concept_code != mb.concept_code;

delete from drug_concept_stage where concept_class_id = 'Dose Form'; -- Rename Dose Forms
insert into drug_concept_stage
select distinct
  concept_name_en as concept_name,
  'BCFI' as vocabulary_ID,
  'Dose Form' as concept_class_id,
  null as source_concept_class_id,
  null as standard_concept,
  concept_code,
  null as possible_excipient,
  'Drug' as domain_id,
  trunc(sysdate) as valid_start_date,
  TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
  null as invalid_reason
from tomap_form;


delete from drug_concept_stage where concept_class_id = 'Brand Name' and concept_code not in (select concept_code from tomap_bn); -- delete manually removed dupes
  
  --Reaction to 'n' and 'g' marks and renaming:
  update drug_concept_stage
    set invalid_reason = 'T' where concept_code in (select distinct  concept_code from tomap_bn where mapped_name != 'n'); -- Mark as *T*emporary concepts that must be changed or deleted
    
  insert into drug_concept_stage -- Create corrected copies of temporary BN concepts
  select distinct  
    case 
      when tm.mapped_id is not null then c.concept_name
      else tm.mapped_name 
    end as concept_name,
    'BCFI' as vocabulary_ID,
    'Brand Name' as concept_class_id,
    'Medicinal Product' as source_concept_class_id,
    null as standard_concept,
    tm.concept_code as concept_code,
    null as possible_excipient,
    'Drug' as domain_id,
    trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
  
  from tomap_bn tm 
  left join concept c on c.concept_id = tm.mapped_id
    where mapped_name not in ('n','d'); -- n are correct names, g are for deletion

insert into relationship_to_concept -- Ingredients
select distinct 
  concept_code as CONCEPT_CODE_1,
  'BCFI' as VOCABULARY_ID_1,
  mapped_id as CONCEPT_ID_2,
  nvl (precedence, 1) as PRECEDENCE,
  null as CONVERSION_FACTOR
from tomap_ingred
  where mapped_id is not null;
  
  --Reaction to 'n' and 'g' marks and renaming:
  update drug_concept_stage
    set invalid_reason = 'T' where concept_code in (select concept_code from tomap_ingred where mapped_name != 'n'); --  Mark as *T*emporary concepts that must be changed or deleted 
  insert into drug_concept_stage -- Create corrected copies of temporary ingred concepts
  select distinct  
    
     case 
      when tm.mapped_id is not null then c.concept_name
      else tm.mapped_name 
    end as concept_name,
    
    'BCFI' as vocabulary_ID,
    'Ingredient' as concept_class_id,
    'Stof' as source_concept_class_id,
    null as standard_concept,
    tm.concept_code as concept_code,
    null as possible_excipient,
    'Drug' as domain_id,
    trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
    
  from tomap_ingred tm 
  left join concept c on c.concept_id = tm.mapped_id
    where mapped_name not in ('n','d') -- n are correct names, g are for deletion
    and (tm.precedence = 1 or tm.precedence is null);
    
delete from drug_concept_stage where invalid_reason = 'T' or (concept_name = 'd' and concept_class_id in ('Brand Name','Ingredient')); -- Clear temporary BN and Ingredients

;
  
  
truncate table INTERNAL_RELATIONSHIP_STAGE;

--Mark one of the each duplicate group as *S*tandard
update drug_concept_stage
set standard_concept = 'S' where
  concept_code in (
    select 
      min (concept_code)
    from
      drug_concept_stage group by concept_name)
  and concept_class_id in ('Ingredient','Brand Name');
  
--insert mappings to standard from dupes in internal_relationship_stage
insert into internal_relationship_stage
select distinct c1.concept_code, c2.concept_code 
  from drug_concept_stage c1
  join drug_concept_stage c2
    on c1.concept_code != c2.concept_code and
    lower (c1.concept_name)= lower (c2.concept_name) and
    c1.concept_class_id = c2.concept_class_id and
    c2.standard_concept = 'S';

update drug_concept_stage
set standard_concept = NULL
where concept_class_id = 'Brand Name';

insert into dupe_fix
select * from internal_relationship_stage;


;
insert into INTERNAL_RELATIONSHIP_STAGE --Product to Ingredient
select distinct
  case  
    when mpp.OUC != 'C' then 'mpp' || mpp.mppcv
    else 'mpp' || sam.mppcv || '-' || sam.ppid
  end,
  nvl (d2.concept_code_2, 'stof' || sam.stofcv)
  from mpp
join sam on mpp.mppcv = sam.mppcv
and mpp.mppcv not in (select mppcv from devices_to_filter)
left join dupe_fix d2 on 'stof' || sam.stofcv = d2.concept_code_1
;

insert into INTERNAL_RELATIONSHIP_STAGE --Product to Dose Forms
select distinct
  case
    when mpp.OUC != 'C' then 'mpp' || sam.mppcv
    else 'mpp' || sam.mppcv || '-' || sam.ppid
  end,
  'gal' || mpp.galcv
from mpp
left join sam on sam.mppcv = mpp.mppcv
where mpp.mppcv not in (select mppcv from devices_to_filter)
and sam.mppcv != 0
;

insert into INTERNAL_RELATIONSHIP_STAGE --Product to Suppliers
select distinct
  case
    when mpp.OUC != 'C' then 'mpp' || mpp.mppcv
    else 'mpp' || sam.mppcv || '-' || sam.ppid
  end,
 'ir' || mp.ircv 
from mpp
join sam on sam.mppcv = mpp.mppcv
join mp on mp.mpcv = mpp.mpcv
and 'mp' || mpp.mpcv in
  (select concept_code from drug_concept_stage where concept_class_id = 'Brand Name');


insert into INTERNAL_RELATIONSHIP_STAGE --Product to Brand Names
select distinct
  case
    when mpp.OUC != 'C' then 'mpp' || mpp.mppcv
    else 'mpp' || sam.mppcv || '-' || sam.ppid
  end,
  nvl (du.concept_code_2, 'mp' || mpp.mpcv)
from mpp
left join dupe_fix du on 'mp' || mpp.mpcv = du.concept_code_1
left join sam on sam.mppcv = mpp.mppcv
where 'mp' || mpp.mpcv in
  (select concept_code from drug_concept_stage where concept_class_id = 'Brand Name');

delete from internal_relationship_stage where concept_code_1 in (select concept_code from drug_concept_stage where concept_class_id = 'Device');
/*delete from internal_relationship_stage 
  where concept_code_2 like 'stof%'
  and concept_code_2 not in (select concept_code from drug_concept_stage where concept_class_id = 'Ingredient')*/;
  
insert into ds_stage  --devices and duplicates are out of the way and packs are neatly organized, so it's best time to do it

select distinct

  case
    when OUC = 'C' then 'mpp' || sam.mppcv || '-' || sam.ppid -- Pack contents have two defining keys, we combine them
    else 'mpp' || mpp.mppcv
  end as DRUG_CONCEPT_CODE,
  
  nvl (du.concept_code_2, 'stof' || sam.stofcv) AS INGREDIENT_CONCEPT_CODE,
  
  case
    when 
      sam.inq != 0 and
      mpp.afu is null and -- not a soluble powder
      sam.inbasu is null and -- has no denominator
      (mpp.cfu is null or mpp.cfu in ('x', 'parels')) -- CFU may refer to both box size and amount of drug
    then sam.inq 
    when
      sam.stofcv = 01422
    then 0
    else null
  end as AMOUNT_VALUE,
  
  case
    when
      sam.inq != 0 and
      mpp.afu is null and
      sam.inbasu is null and
      (mpp.cfu is null or mpp.cfu in ('x', 'parels'))
    then sam.inu
    when
      sam.stofcv = 01422
    then 'mg'
    else null
  end as AMOUNT_UNIT,
  
  case
    when --defined like numerator/denominator, 
      sam.inq != '0' and
      sam.inbasu is not null
      then 
      
        case --liter filter
          when mpp.cfu = 'l' then sam.INQ * nvl ((mpp.cfq * 1000 / sam.inbasq), 1)
          else sam.INQ * nvl ((mpp.cfq / sam.inbasq), 1)
        end
        
    when --defined like powder/solvent
      sam.inq != '0' and
      mpp.afu is not null and
      sam.inbasu is null
      then sam.INQ
      
    else null
  end as NUMERATOR_VALUE,
  
  case
    when --defined like numerator/denominator
      sam.inq != '0' and
      sam.inbasu is not null
      then sam.INU

    when --defined like powder/solvent
      sam.inq != '0' and
      mpp.afu is not null and
      sam.inbasu is null
      then sam.INU
      
    else null
  end as NUMERATOR_UNIT,
  
  case
    when --defined like numerator/denominator
      sam.inq != '0' and
      sam.inbasu is not null
      then nvl (mpp.CFQ, sam.inbasq)

    when --defined like powder/solvent
      sam.inq != '0' and
      mpp.afu is not null and
      sam.inbasu is null
      then mpp.afq
      
    else null
  end as DENOMINATOR_VALUE,

  case
    when mpp.cfq = 'l' then 'l'
    
    when --defined like numerator/denominator
      sam.inq != '0' and
      sam.inbasu is not null
      then sam.inbasu

    when --defined like powder/solvent
      sam.inq != '0' and
      mpp.afu is not null and
      sam.inbasu is null
      then mpp.afu
      
    else null
  end as DENOMINATOR_UNIT,
  
  case
    /* when mpp.OUC = 'C' and sam.ppq != 0 then sam.ppq 
    when mpp.OUC != 'C' and mpp.cfu in ('x', 'parels') then mpp.cfq 
    when mpp.OUC != 'C' and mpp.afu is not null and sam.inbasu is not null then mpp.afq / sam.inbasq */
    when mpp.OUC != 'C' and mpp.cq != 1 then mpp.cq
    else NULL
  end as BOX_SIZE

from mpp
left join sam on
mpp.mppcv = sam.mppcv
left join dupe_fix du on du.concept_code_1 = 'stof' || sam.stofcv
;

delete from ds_stage where --delete devices and dataless rows
drug_concept_code in (select 'mpp' || mppcv from DEVICES_TO_FILTER) or
ingredient_concept_code is NULL or
(amount_value is null and numerator_value is null and ingredient_concept_code != 'stof01422') or
AMOUNT_UNIT in 'ml' --vaccines without otherwise set doses, exclusively
;

update ds_stage
set NUMERATOR_UNIT = 'g' where NUMERATOR_UNIT = 'ml' -- tinctures/liquid extracts, herbal
;
delete from ds_stage where INGREDIENT_CONCEPT_CODE not in (select concept_code from drug_concept_stage where concept_class_id = 'Ingredient'); -- filter deprecated ingreds
/*
delete from ds_stage where drug_concept_code in ( --deletes incomplete entries
 SELECT concept_code_1
      FROM (SELECT DISTINCT concept_code_1, COUNT(concept_code_2) OVER (PARTITION BY concept_code_1) AS irs_cnt
            FROM internal_relationship_stage
              JOIN drug_concept_stage ON concept_code = concept_code_2 AND concept_class_id = 'Ingredient') irs
        JOIN (SELECT DISTINCT drug_concept_code, COUNT(ingredient_concept_code) OVER (PARTITION BY drug_concept_code) AS ds_cnt
              FROM ds_stage) ds
          ON drug_concept_code = concept_code_1   AND irs_cnt != ds_cnt); */
          
insert into concept_synonym_stage --English translations
select 
  NULL as synonym_concept_id,
  concept_name as synonym_concept_name,
  concept_code as synonym_concept_code,
  'BCFI' as vocabulary_ID,
  4180186 as language_concept_id --English
from drug_concept_stage where concept_class_id in ('Ingredient');

/* Ingredients */
insert into concept_synonym_stage --French Ingredients
select 
  NULL as synonym_concept_id,
  finnm as synonym_concept_name,
  'stof' || stofcv as synonym_concept_code,
  'BCFI' as vocabulary_ID,
  4180190 as language_concept_id --French
from innm
  where 'stof' || stofcv in (select concept_code from drug_concept_stage where concept_class_id = 'Ingredient');
  
insert into concept_synonym_stage --Dutch Ingredients
select 
  NULL as synonym_concept_id,
  ninnm as synonym_concept_name,
  'stof' || stofcv as synonym_concept_code,
  'BCFI' as vocabulary_ID,
  4182503 as language_concept_id --Dutch
from innm
  where 'stof' || stofcv in (select concept_code from drug_concept_stage where concept_class_id = 'Ingredient');
  
/* Dose Forms */
insert into concept_synonym_stage
select distinct
  NULL as synonym_concept_id,
  concept_name_en as synonym_concept_name,
  concept_code as synonym_concept_code,
  'BCFI' as vocabulary_ID,
  4180186 as language_concept_id --English
from tomap_form
union
select distinct
  NULL as synonym_concept_id,
  concept_name_fr as synonym_concept_name,
  concept_code as synonym_concept_code,
  'BCFI' as vocabulary_ID,
  4180190 as language_concept_id --French
from tomap_form
union
select 
  NULL as synonym_concept_id,
  concept_name_nl as synonym_concept_name,
  concept_code as synonym_concept_code,
  'BCFI' as vocabulary_ID,
  4182503 as language_concept_id --Dutch
from tomap_form;


/* create table for manual fixes */
 -- fix duplicates with ingreds
create table dsfix as
select
  DRUG_CONCEPT_CODE,
  a.concept_name as drug_concept_name,
  INGREDIENT_CONCEPT_CODE,
  b.concept_name as ingredient_concept_name,
  AMOUNT_VALUE,AMOUNT_UNIT,
  NUMERATOR_VALUE,
  NUMERATOR_UNIT,
  DENOMINATOR_VALUE,
  DENOMINATOR_UNIT,
  BOX_SIZE
from ds_stage d
join drug_concept_stage a on d.drug_concept_code = a.concept_code
join drug_concept_stage b on b.concept_code = d.ingredient_concept_code
where drug_concept_code in
(SELECT drug_concept_code
            FROM ds_stage
            GROUP BY drug_concept_code, ingredient_concept_code  HAVING COUNT(1) > 1
 union
SELECT concept_code_1
      FROM (SELECT DISTINCT concept_code_1, COUNT(concept_code_2) OVER (PARTITION BY concept_code_1) AS irs_cnt
            FROM internal_relationship_stage
              JOIN drug_concept_stage ON concept_code = concept_code_2 AND concept_class_id = 'Ingredient') irs
        JOIN (SELECT DISTINCT drug_concept_code, COUNT(ingredient_concept_code) OVER (PARTITION BY drug_concept_code) AS ds_cnt
              FROM ds_stage) ds
          ON drug_concept_code = concept_code_1   AND irs_cnt != ds_cnt)
union
select concept_code as drug_concept_code, concept_name as drug_concept_name, null,null,null,null, null,null,null,null,null from
drug_concept_stage
      WHERE concept_code NOT IN (SELECT concept_code_1
                                 FROM internal_relationship_stage
                                   JOIN drug_concept_stage ON concept_code_2 = concept_code  AND concept_class_id = 'Ingredient')
      AND   concept_code NOT IN (SELECT pack_concept_code FROM pc_stage)
      AND   concept_class_id = 'Drug Product'
union
select concept_code as drug_concept_code, concept_name as drug_concept_name, null,null,null,null, null,null,null,null,null from drug_concept_stage  dcs
join (
SELECT concept_code_1
FROM internal_relationship_stage
JOIN drug_concept_stage  ON concept_code_2 = concept_code  AND concept_class_id = 'Supplier'
left join ds_stage on drug_concept_code = concept_code_1 
where drug_concept_code is null
union 
SELECT concept_code_1
FROM internal_relationship_stage
JOIN drug_concept_stage  ON concept_code_2 = concept_code  AND concept_class_id = 'Supplier'
where concept_code_1 not in (SELECT concept_code_1
                                  FROM internal_relationship_stage
                                    JOIN drug_concept_stage   ON concept_code_2 = concept_code  AND concept_class_id = 'Dose Form')
) s on s.concept_code_1 = dcs.concept_code
where dcs.concept_class_id = 'Drug Product' and invalid_reason is null
;
alter table dsfix add DEVICE varchar (255);
alter table dsfix add MAPPED_ID number;
      
delete from ds_stage where drug_concept_code in (select drug_concept_code from dsfix);
delete from INTERNAL_RELATIONSHIP_STAGE where concept_code_1 in (select drug_concept_code from dsfix) and concept_code_2 like 'stof%';