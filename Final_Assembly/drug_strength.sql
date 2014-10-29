/*----------------------------------------------------------------------------------------
 * (c) 2013 Observational Medical Outcomes Partnership.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://omop.org/publiclicense.
 * 
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. Any redistributions of this work or any derivative work or modification based on this work should be accompanied by the following source attribution: "This work is based on work by the Observational Medical Outcomes Partnership (OMOP) and used under license from the FNIH at
 * http://omop.org/publiclicense.
 * 
 * Any scientific publication that is based on this work should include a reference to
 * http://omop.org.
 * --------------------------------------------------------------------------------------- */

/*******************************************************************************
 * This program creates for each drug and ingredient a record with the strength.
 * For drugs with absolute amount strength information, the value and unit are provided as
 * amount_value and amount_unit. For drugs with relative strength (concentration), the 
 * strength is provided as c_value, c_enum_unit and c_denom_unit.
 *
 * Version 1.0
********************************************************************************/


-- fix some components that will set off parser
-- drop table component_replace;
create table component_replace (
component_name varchar(250),
replace_with varchar(250)
);

-- load replacement component names
insert into component_replace (component_name, replace_with) values ('aspergillus fumigatus fumigatus 1:500', 'Aspergillus fumigatus extract 20 MG/ML');
insert into component_replace (component_name, replace_with) values ('benzalkonium 1:5000', 'benzalkonium 2 mg/ml');
insert into component_replace (component_name, replace_with) values ('candida albicans albicans 1:500', 'candida albicans extract 20 MG/ML');
insert into component_replace (component_name, replace_with) values ('ginkgo biloba leaf leaf 1:2', 'ginkgo biloba leaf 0.5 ');
insert into component_replace (component_name, replace_with) values ('histoplasmin 1:100', 'Histoplasmin 10 MG/ML');
insert into component_replace (component_name, replace_with) values ('trichophyton preparation 1 :500', 'Trichophyton 2 MG/ML');
insert into component_replace (component_name, replace_with) values ('interferon alfa-2b million unt/ml', 'Interferon Alfa-2b 10000000 UNT/ML');
insert into component_replace (component_name, replace_with) values ('monobasic potassium phosphate 63-30 mg/ml', '');
insert into component_replace (component_name, replace_with) values ('papain million unt', 'Papain 1000000 UNT');
insert into component_replace (component_name, replace_with) values ('penicillin g million unt', 'Penicillin G 1000000 UNT');
insert into component_replace (component_name, replace_with) values ('poliovirus vaccine, inactivated antigen u/ml', '');
insert into component_replace (component_name, replace_with) values ('pseudoephedrine', 'Pseudoephedrine 120 MG');
insert into component_replace (component_name, replace_with) values ('sodium phosphate,dibasic 88-30 mg/ml', '');
insert into component_replace (component_name, replace_with) values ('strontium-89 148mbq-4mci', 'strontium-89 4 MCI');
insert into component_replace (component_name, replace_with) values ('technetium 99m 99m ns', '');
insert into component_replace (component_name, replace_with) values ('trichopyton mentagrophytes mentagrophytes 1:500', 'Trichophyton 2 MG/ML');
insert into component_replace (component_name, replace_with) values ('samarium sm 153 lexidronam 1850 mbq/ml', 'samarium-153 lexidronam 1850 mbq/ml');
insert into component_replace (component_name, replace_with) values ('saw palmetto extract extract 1:5', 'Saw palmetto extract 0.5 ');

-- Create Unit mappingselect * from source_to_concept_map;
-- drop table unit_to_concept_map;
create table unit_to_concept_map as
select * from source_to_concept_map where 1=1;

insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('%', 0, 'percent', 8554, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('actuat', 0, '{actuat}', 45744809, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('au', 0, 'allergenic unit', 45744811, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('bau', 0, 'bioequivalent allergenic unit', 45744810, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('cells', 0, 'cells', 45744812, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('cfu', 0, 'colony forming unit', 9278, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('cu', 0, 'clinical unit', 45744813, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('hr', 0, 'hour', 8505, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('iu', 0, 'international unit', 8718, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('lfu', 0, 'limit of flocculation unit', 45744814, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('mci', 0, 'millicurie', 44819154, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('meq', 0, 'milliequivalent', 9551, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('mg', 0, 'milligram', 8576, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('mil', 0, 'milliliter', 8587, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('min', 0, 'minute', 8550, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('ml', 0, 'milliliter', 8587, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('mmol', 0, 'millimole', 9573, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('mmole', 0, 'millimole', 9573, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('mu', 0, 'mega-international unit', 9439, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('ns', 0, 'unmapped', 0, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('org', 0, 'unmapped', 0, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('organisms', 0, 'bacteria', 45744815, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('pfu', 0, 'plaque forming unit', 9379, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('pnu', 0, 'protein nitrogen unit', 45744816, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('sqcm', 0, 'square centimeter', 9483, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('tcid', 0, '50% tissue culture infectious dose', 9414, 11, '1-Jan-1970', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('unt', 0, 'unit', 8510, 11, '1-Jan-1970', '31-Dec-2099', null);
 

-- Build drug_strength table;
-- truncate table drug_strength;
insert into drug_strength (
  drug_concept_id, ingredient_concept_id, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason
)
select
  v4.drug_id,
  v4.ingredient_id,
  amount_value,
  au.target_concept_id, 
  numerator_value,
  nu.target_concept_id as numerator_unit_concept_id, 
  du.target_concept_id as denominator_unit_concept_id,
  v4.valid_start_date, v4.valid_end_date,
  null as invalid_reason
from (
  select distinct
    drug_id, ingredient_id, 
    sum(amount) over (partition by drug_id, ingredient_id) as amount_value,
    amount_unit, 
    sum(numerator) over (partition by drug_id, ingredient_id) as numerator_value,
    numerator_unit, denominator_unit, valid_start_date, valid_end_date
  from (
    select
      drug_id, ingredient_id, 
      case 
        when regexp_like(component_name, '\/[^-]') then null
        else to_number(regexp_substr(component_name, ' [0-9]+(\.[0-9]+)? ', position)) 
      end as amount,
      case
        when regexp_like(component_name, '\/[^-]') then null
        else lower(regexp_substr(regexp_substr(component_name, ' [0-9\.]+\s+[^0-9\. ]+', position), '[^0-9\. ]+'))
        end as amount_unit,
      case 
        when not regexp_like(component_name, '\/[^-]') then null
        else to_number(regexp_substr(component_name, ' [0-9]+(\.[0-9]+)? ', position)) 
      end as numerator,
      case
        when not regexp_like(component_name, '\/[^-]') then null
        else lower(regexp_substr(regexp_substr(component_name, ' [0-9]+(\.[0-9]+)?\s+[^0-9\. \/]+', position), '[^0-9\. \/]+'))
        end as numerator_unit,
      case
        when not regexp_like(component_name, '\/[^-]') then null
        else lower(regexp_substr(regexp_substr(component_name, '\/[^0-9\.]+', position), '[^0-9\. \/]+'))
        end as denominator_unit,
      component_start_date as valid_start_date, 
      component_end_date as valid_end_date
    from (
      select -- if ingredient name is not part of component name start from position 1, otherwise start after the ingredient name
        drug_id, component_name, component_start_date, component_end_date, ingredient_id, ingredient_name, len,
        case position when 0 then 1 else position+len end as position
      from (
        select -- get the position of the ingredient inside the component
          drug_id, component_name, component_start_date, component_end_date, ingredient_id, ingredient_name, 
          instr(component_name, ingredient_name) as position,
          length(ingredient_name) as len
        from ( -- provide drugs with cleaned components and ingredients 
          select drug_id, ingredient_id,
            regexp_replace(lower(component_name), 'ic\s+acid', 'ate') as component_name, 
            min(component_start_date) over (partition by ingredient_id) as component_start_date, 
            max(component_end_date) over (partition by ingredient_id) as component_end_date,
            -- pick the latest ingredient
            regexp_replace(lower( first_value (ingredient_name) over (partition by component_id order by valid_end_date desc)), 'ic\s+acid', 'ate') as ingredient_name
          from (
            select distinct -- select for each drug the drug_component(s) and ingredient(s), and replace the component name if necessary
              d.concept_id as drug_id,
              c.concept_id as component_id,
              c.valid_start_date as component_start_date,
              c.valid_end_date as component_end_date,
              nvl(r.replace_with, c.concept_name) as component_name,
              i.concept_id as ingredient_id,
              i.concept_name as ingredient_name,
              i.valid_end_date
            from concept d
            join concept_relationship r1 on d.concept_id=r1.concept_id_1 and r1.relationship_id='Consists of' and r1.invalid_reason is null -- Constitutes (RxNorm)
            join concept c on r1.concept_id_2=c.concept_id and c.concept_class_id='Clinical Drug Comp'
            join concept_relationship r2 on c.concept_id=r2.concept_id_1 and r2.invalid_reason is null -- fetch the ingredient
            join concept i on r2.concept_id_2=i.concept_id and i.concept_class_id='Ingredient' and i.standard_concept='S'
            left join component_replace r on r.component_name=lower(c.concept_name)
            where d.standard_concept='S' and d.concept_class_id in ('Clinical Drug', 'Branded Drug')
          ) 
        )
      )
    )
  )
) v4
left join unit_to_concept_map au on au.source_code=v4.amount_unit
left join unit_to_concept_map nu on nu.source_code=v4.numerator_unit
left join unit_to_concept_map du on du.source_code=v4.denominator_unit
;

-- check unparsed records
select * from drug_strength where amount_unit_concept_id is null and numerator_unit_concept_id is null;

-- check that numbers are all valid
select * from drug_strength where (amount_value=0 or numerator_value=0);

-- check that all units are valid
select distinct amount_unit_concept_id, numerator_unit_concept_id, denominator_unit_concept_id from drug_strength order by 1,2,3;

-- delete unparsable records
delete from drug_strength where coalesce(amount_unit_concept_id, 0)=0 and coalesce(numerator_unit_concept_id, 0)=0;

commit;

