/*----------------------------------------------------------------------------------------
 * (c) 2016 Observational Health Data Science and Informatics
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://ohdsi.org/publiclicense.
 * 
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. Any redistributions of this work or any derivative work or modification based on this work should be accompanied by the following source attribution: "This work is based on work by the Observational Medical Outcomes Partnership (OMOP) and used under license from the FNIH at
 * http://ohdsi.org/publiclicense.
 * 
 * Any scientific publication that is based on this work should include a reference to
 * http://ohdsi.org.
 * --------------------------------------------------------------------------------------- */

/*******************************************************************************
 * This program creates for each drug and ingredient a record with the strength.
 * For drugs with absolute amount strength information, the value and unit are provided as
 * amount_value and amount_unit. For drugs with relative strength (concentration), the 
 * strength is provided as numerator_value, numerator_unit_concept_id and 
 * denominator_unit_concept_id. For Quantified Drugs the denominator_value is also set
 *
 * Version 2.0
 * Author Christian Reich, Timur Vakhitov
********************************************************************************/

/* 1. Prepare components that will set off parser */

--GATHER_TABLE_STATS
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_stage', estimate_percent  => null, cascade  => true);
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_relationship_stage', estimate_percent  => null, cascade  => true);

--drop table component_replace;
create table component_replace (
component_name varchar(250),
replace_with varchar(250)
);

-- load replacement component names so that they match ingredient names and unit names and number conventions
insert into component_replace (component_name, replace_with) values ('aspergillus fumigatus fumigatus 1:500', 'Aspergillus fumigatus extract 20 MG/ML');
insert into component_replace (component_name, replace_with) values ('benzalkonium 1:5000', 'benzalkonium 2 mg/ml');
insert into component_replace (component_name, replace_with) values ('candida albicans albicans 1:500', 'candida albicans extract 20 MG/ML');
insert into component_replace (component_name, replace_with) values ('ginkgo biloba leaf leaf 1:2', 'ginkgo biloba leaf 0.5 ');
insert into component_replace (component_name, replace_with) values ('histoplasmin 1:100', 'Histoplasmin 10 MG/ML');
insert into component_replace (component_name, replace_with) values ('trichophyton preparation 1 :500', 'Trichophyton 2 MG/ML');
insert into component_replace (component_name, replace_with) values ('interferon alfa-2b million unt/ml', 'Interferon Alfa-2b 10000000 UNT/ML');
insert into component_replace (component_name, replace_with) values ('papain million unt', 'Papain 1000000 UNT');
insert into component_replace (component_name, replace_with) values ('penicillin g million unt', 'Penicillin G 1000000 UNT');
insert into component_replace (component_name, replace_with) values ('poliovirus vaccine, inactivated antigen u/ml', '');
insert into component_replace (component_name, replace_with) values ('pseudoephedrine', 'Pseudoephedrine 120 MG');
insert into component_replace (component_name, replace_with) values ('strontium-89 148mbq-4mci', 'strontium-89 4 MCI');
insert into component_replace (component_name, replace_with) values ('technetium 99m 99m ns', '');
insert into component_replace (component_name, replace_with) values ('trichopyton mentagrophytes mentagrophytes 1:500', 'Trichophyton 2 MG/ML');
insert into component_replace (component_name, replace_with) values ('samarium sm 153 lexidronam 1850 mbq/ml', 'samarium-153 lexidronam 1850 mbq/ml');
insert into component_replace (component_name, replace_with) values ('saw palmetto extract extract 1:5', 'Saw palmetto extract 0.5 ');
insert into component_replace (component_name, replace_with) values ('sodium phosphate, dibasic 88-30 mg/ml', 'Sodium Phosphate, Dibasic 88 MG/ML');
insert into component_replace (component_name, replace_with) values ('monobasic potassium phosphate 63-30 mg/ml', 'Monobasic potassium phosphate 63 mg/ml');
insert into component_replace (component_name, replace_with) values ('short ragweed pollen extract 12 amb a 1-u', 'short ragweed pollen extract 12 UNT');
insert into component_replace (component_name, replace_with) values ('secretin 75 cu/vial', 'Secretin 10 CU/ML'); -- the vial is supposed to be reconsituted in 7.5 mL of saline

-- Create Unit mappingselect * from source_to_concept_map;
-- drop table unit_to_concept_map;
create table unit_to_concept_map as
select * from source_to_concept_map where 1=0;

begin
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
values ('min', 0, 'minim', 9367, 11, '1-Jan-1970', '31-Dec-2099', null);
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
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('ir', 0, 'index of reactivity', 9693, 11, '14-Dec-2014', '31-Dec-2099', null);
insert into unit_to_concept_map (source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason)
values ('vector-genomes', 0, 'vector-genomes', 32018, 11, '1-Jan-1970', '31-Dec-2099', null);
end;

commit;

/* 2. Make sure that invalid concepts are standard_concept = NULL */
update concept_stage c set c.standard_concept = null
where c.valid_end_date != to_date ('20991231', 'yyyymmdd') and c.standard_concept is not null;

commit;

/* 3. Create RxNorm's concept code ancestor */
create table rxnorm_ancestor nologging as
select ancestor_concept_code, ancestor_vocabulary_id, descendant_concept_code, descendant_vocabulary_id From (
    select ca.* From (    
        select ancestor_concept_code, ancestor_vocabulary_id, descendant_concept_code, descendant_vocabulary_id From (
            SELECT
            CONNECT_BY_ROOT ancestor_concept_code as ancestor_concept_code, 
            CONNECT_BY_ROOT ancestor_vocabulary_id as ancestor_vocabulary_id,
            descendant_concept_code,
            descendant_vocabulary_id
            FROM (
                select 
                crs.concept_code_1 as ancestor_concept_code,
                crs.vocabulary_id_1 as ancestor_vocabulary_id,
                crs.concept_code_2 as descendant_concept_code,
                crs.vocabulary_id_2 as descendant_vocabulary_id
                from concept_relationship_stage crs 
                join relationship s on s.relationship_id=crs.relationship_id and s.defines_ancestry=1 
                join concept_stage c1 on c1.concept_code=crs.concept_code_1 and c1.vocabulary_id=crs.vocabulary_id_1 and c1.invalid_reason is null and c1.vocabulary_id='RxNorm'
                join concept_stage c2 on c2.concept_code=crs.concept_code_2 and c1.vocabulary_id=crs.vocabulary_id_2 and c2.invalid_reason is null and c2.vocabulary_id='RxNorm'
                where crs.invalid_reason is null
            )
            CONNECT BY PRIOR descendant_concept_code=ancestor_concept_code and descendant_vocabulary_id=ancestor_vocabulary_id
        )
        group by ancestor_concept_code, ancestor_vocabulary_id, descendant_concept_code, descendant_vocabulary_id

    ) ca
    join concept_stage c1 on c1.concept_code=ca.ancestor_concept_code and c1.vocabulary_id=ca.ancestor_vocabulary_id
    join concept_stage c2 on c2.concept_code=ca.descendant_concept_code and c2.vocabulary_id=ca.descendant_vocabulary_id
    where c1.standard_concept is not null and c2.standard_concept is not null
)
union all
select c.concept_code as ancestor_concept_code, c.vocabulary_id as ancestor_vocabulary_id, c.concept_code as descendant_concept_code, c.vocabulary_id as descendant_vocabulary_id
from concept_stage c 
where c.vocabulary_id = 'RxNorm' and c.invalid_reason is null and c.standard_concept is not null;

exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'rxnorm_ancestor', estimate_percent  => null, cascade  => true);


/* 4. Return proper valid_start_date from concept*/
merge into concept_stage cs
using (
    select c.concept_code, c.valid_start_date from concept c
    where c.vocabulary_id='RxNorm'
) i on (cs.concept_code=i.concept_code)
when matched then
update set cs.valid_start_date=i.valid_start_date where cs.vocabulary_id='RxNorm';

commit;

/* 5. Fix valid_start_date for incorrect concepts (bad data in sources) */
update concept_stage c set c.valid_start_date = c.valid_end_date - 1 
where c.valid_end_date < c.valid_start_date and c.vocabulary_id='RxNorm';

commit;
 
/* 6. Build drug_strength_stage table for '* Drugs' */
truncate table drug_strength_stage;

insert /*+ APPEND */ into drug_strength_stage (
  drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason
)
select drug_concept_code, 'RxNorm' as vocabulary_id_1, ingredient_concept_code, 'RxNorm' as vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
denominator_unit_concept_id, valid_start_date, valid_end_date, null as invalid_reason From (
select 
  ds.drug_concept_code,
  ds.ingredient_concept_code,
  denominator_value,
  first_value(amount_value) over (partition by drug_concept_code, ingredient_concept_code order by component_concept_code rows between unbounded preceding and unbounded following) as amount_value,
  first_value(au.target_concept_id) over (partition by drug_concept_code, ingredient_concept_code order by component_concept_code rows between unbounded preceding and unbounded following) as amount_unit_concept_id, 
  first_value(numerator_value) over (partition by drug_concept_code, ingredient_concept_code order by component_concept_code rows between unbounded preceding and unbounded following) as numerator_value,
  first_value(nu.target_concept_id) over (partition by drug_concept_code, ingredient_concept_code order by component_concept_code rows between unbounded preceding and unbounded following) as numerator_unit_concept_id, 
  first_value(du.target_concept_id) over (partition by drug_concept_code, ingredient_concept_code order by component_concept_code rows between unbounded preceding and unbounded following) as denominator_unit_concept_id,
  ds.valid_start_date, ds.valid_end_date
from (
  select distinct
    drug_concept_code, ingredient_concept_code, 
    component_concept_code,
    sum(amount) over (partition by drug_concept_code, ingredient_concept_code, numerator_unit) as amount_value,
    amount_unit, 
    sum(numerator) over (partition by drug_concept_code, ingredient_concept_code, numerator_unit) as numerator_value,
    numerator_unit, 
    null as denominator_value, -- in Clinical/Branded Drugs always normalized to 1
    denominator_unit, valid_start_date, valid_end_date
  from (
    select
      drug_concept_code, ingredient_concept_code, component_concept_code,
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
        else lower(regexp_substr(regexp_substr(component_name, '\/[^0-9\.]+\Z', position), '[^0-9\. \/]+'))
        end as denominator_unit,
      component_start_date as valid_start_date, 
      component_end_date as valid_end_date
    from (
      select -- if ingredient name is not part of component name start from position 1, otherwise start after the ingredient name
        drug_concept_code, component_name, component_start_date, component_end_date, ingredient_concept_code, ingredient_name, len,
        case position when 0 then 1 else position+len end as position,
        component_concept_code
      from (
        select -- get the position of the ingredient inside the component
          drug_concept_code, component_name, component_start_date, component_end_date, ingredient_concept_code, ingredient_name, 
          instr(component_name, ingredient_name) as position,
          length(ingredient_name) as len,
          component_concept_code
        from ( -- provide drugs with cleaned components and ingredients 
          select drug_concept_code, ingredient_concept_code, component_concept_code,
            regexp_replace(lower(component_name), 'ic\s+acid', 'ate') as component_name, 
            min(component_start_date) over (partition by ingredient_concept_code) as component_start_date, 
            max(component_end_date) over (partition by ingredient_concept_code) as component_end_date,
            -- pick the latest ingredient
            regexp_replace(lower( first_value (ingredient_name) over (partition by component_concept_code order by valid_end_date desc)), 'ic\s+acid', 'ate') as ingredient_name
          from (
            select distinct -- select for each drug the drug_component(s) and ingredient(s), and replace the component name if necessary
              d.concept_code as drug_concept_code,
              c.concept_code as component_concept_code,
              c.valid_start_date as component_start_date,
              c.valid_end_date as component_end_date,
              nvl(r.replace_with, c.concept_name) as component_name,
              i.concept_code as ingredient_concept_code,
              i.concept_name as ingredient_name,
              i.valid_end_date
            from concept_stage d
            join rxnorm_ancestor a1 on a1.descendant_concept_code=d.concept_code and a1.descendant_vocabulary_id=d.vocabulary_id
            join concept_stage c on c.concept_code=a1.ancestor_concept_code and c.vocabulary_id=a1.ancestor_vocabulary_id and c.concept_class_id='Clinical Drug Comp' and c.vocabulary_id='RxNorm'
            join rxnorm_ancestor a2 on a2.descendant_concept_code=c.concept_code and a2.descendant_vocabulary_id=c.vocabulary_id
            join concept_stage i on i.concept_code=a2.ancestor_concept_code and i.vocabulary_id=a2.ancestor_vocabulary_id and i.concept_class_id='Ingredient' and i.vocabulary_id='RxNorm'
            left join component_replace r on r.component_name=lower(c.concept_name)
            where d.standard_concept='S' and d.concept_class_id in ('Clinical Drug', 'Branded Drug', 'Branded Drug Comp')
            and d.vocabulary_id='RxNorm'
          ) 
        )
      )
    )
  )
) ds
left join unit_to_concept_map au on au.source_code=ds.amount_unit
left join unit_to_concept_map nu on nu.source_code=ds.numerator_unit
left join unit_to_concept_map du on du.source_code=ds.denominator_unit
) group by drug_concept_code, ingredient_concept_code, denominator_value,
  amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_unit_concept_id,
  valid_start_date, valid_end_date;

commit;

/* 7. Write 'Clinical Drug Components' */
insert /*+ APPEND */ into drug_strength_stage (
  drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason
)
select drug_concept_code, 'RxNorm' as vocabulary_id_1, ingredient_concept_code, 'RxNorm' as vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason From (
select
  ds.drug_concept_code,
  ds.ingredient_concept_code,
  denominator_value,
  first_value(amount_value) over (partition by drug_concept_code, ingredient_concept_code order by component_concept_code rows between unbounded preceding and unbounded following) as amount_value,
  first_value(au.target_concept_id) over (partition by drug_concept_code, ingredient_concept_code order by component_concept_code rows between unbounded preceding and unbounded following) as amount_unit_concept_id, 
  first_value(numerator_value) over (partition by drug_concept_code, ingredient_concept_code order by component_concept_code rows between unbounded preceding and unbounded following) as numerator_value,
  first_value(nu.target_concept_id) over (partition by drug_concept_code, ingredient_concept_code order by component_concept_code rows between unbounded preceding and unbounded following) as numerator_unit_concept_id,
  first_value(du.target_concept_id) over (partition by drug_concept_code, ingredient_concept_code order by component_concept_code rows between unbounded preceding and unbounded following) as denominator_unit_concept_id,
  ds.valid_start_date, ds.valid_end_date, null as invalid_reason
from (
  select distinct
    drug_concept_code, ingredient_concept_code, 
    component_concept_code,
    sum(amount) over (partition by drug_concept_code, ingredient_concept_code, numerator_unit) as amount_value,
    amount_unit, 
    sum(numerator) over (partition by drug_concept_code, ingredient_concept_code, numerator_unit) as numerator_value,
    numerator_unit, 
    null as denominator_value, -- denominator_value, in Clinical/Branded Drugs always normalized to 1
    denominator_unit, valid_start_date, valid_end_date
  from (
    select
      drug_concept_code, ingredient_concept_code, component_concept_code,
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
        else lower(regexp_substr(regexp_substr(component_name, '\/[^0-9\.]+\Z', position), '[^0-9\. \/]+'))
        end as denominator_unit,
      component_start_date as valid_start_date, 
      component_end_date as valid_end_date
    from (
      select -- if ingredient name is not part of component name start from position 1, otherwise start after the ingredient name
        drug_concept_code, component_name, component_start_date, component_end_date, ingredient_concept_code, ingredient_name, len,
        case position when 0 then 1 else position+len end as position,
        component_concept_code
      from (
        select -- get the position of the ingredient inside the component
          drug_concept_code, component_name, component_start_date, component_end_date, ingredient_concept_code, ingredient_name, 
          instr(component_name, ingredient_name) as position,
          length(ingredient_name) as len,
          component_concept_code
        from ( -- provide drugs with cleaned components and ingredients 
          select drug_concept_code, ingredient_concept_code, component_concept_code,
            regexp_replace(lower(component_name), 'ic\s+acid', 'ate') as component_name, 
            min(component_start_date) over (partition by ingredient_concept_code) as component_start_date, 
            max(component_end_date) over (partition by ingredient_concept_code) as component_end_date,
            -- pick the latest ingredient
            regexp_replace(lower( first_value (ingredient_name) over (partition by component_concept_code order by valid_end_date desc)), 'ic\s+acid', 'ate') as ingredient_name
          from (
            select distinct -- select for each drug the drug_component(s) and ingredient(s), and replace the component name if necessary
              c.concept_code as drug_concept_code,
              c.concept_code as component_concept_code,
              c.valid_start_date as component_start_date,
              c.valid_end_date as component_end_date,
              nvl(r.replace_with, c.concept_name) as component_name,
              i.concept_code as ingredient_concept_code,
              i.concept_name as ingredient_name,
              i.valid_end_date
            from concept_stage c
            join rxnorm_ancestor a2 on a2.descendant_concept_code=c.concept_code and a2.descendant_vocabulary_id=c.vocabulary_id
            join concept_stage i on i.concept_code=a2.ancestor_concept_code and i.vocabulary_id=a2.ancestor_vocabulary_id and i.concept_class_id='Ingredient' and i.vocabulary_id='RxNorm'
            left join component_replace r on r.component_name=lower(c.concept_name)
            where c.standard_concept='S' and c.concept_class_id = 'Clinical Drug Comp' and c.vocabulary_id='RxNorm'
          ) 
        )
      )
    )
  )
) ds
left join unit_to_concept_map au on au.source_code=ds.amount_unit
left join unit_to_concept_map nu on nu.source_code=ds.numerator_unit
left join unit_to_concept_map du on du.source_code=ds.denominator_unit
) group by drug_concept_code, ingredient_concept_code,  denominator_value,
  amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_unit_concept_id,
  valid_start_date, valid_end_date, invalid_reason;

commit;

/* 8. Write 'Quantified * Drugs from Clinical Drugs */
-- Quantity provided in "ACTUAT": They only exist for concentrations of ingredients
insert /*+ APPEND */ into drug_strength_stage (
  drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason
)
select drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason from (
    select
      drug_concept_code, -- of the quantified
      vocabulary_id_1,
      ingredient_concept_code, -- of the original non-quantified
      vocabulary_id_2,
      null as amount_value,
      null as amount_unit_concept_id,
      v*numerator_value as numerator_value,
      numerator_unit_concept_id, 
      v as denominator_value, -- newly added amount
      denominator_unit_concept_id,
      valid_start_date, 
      valid_end_date,
      null as invalid_reason
    from (
      select 
        q.concept_code as drug_concept_code, ds.vocabulary_id_1, ds.ingredient_concept_code,  ds.vocabulary_id_2,
        ds.numerator_value, ds.numerator_unit_concept_id, ds.denominator_unit_concept_id, -- Actuations never have values in the amount section
        ds.valid_start_date, ds.valid_end_date,
        regexp_substr(q.concept_name, '^[0-9\.]+')as v,  regexp_substr(q.concept_name, '[^ 0-9\.]+') as u -- parsing out the quantity
      from drug_strength_stage ds
      join concept_stage d on d.concept_code=ds.drug_concept_code and d.vocabulary_id=ds.vocabulary_id_1 and d.concept_class_id in ('Clinical Drug', 'Branded Drug') and d.vocabulary_id='RxNorm'
      join concept_relationship_stage r on r.concept_code_1=ds.drug_concept_code and r.vocabulary_id_1=ds.vocabulary_id_1 and r.invalid_reason is null
      join concept_stage q on q.concept_code=r.concept_code_2 and q.vocabulary_id=r.vocabulary_id_2 and q.concept_class_id like 'Quant%' and q.standard_concept = 'S' and q.vocabulary_id='RxNorm'
    )
    where u='ACTUAT'
) group by drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason;

commit;

-- Quantity provided in "DAY". Treat equivalent to 24 hours
insert /*+ APPEND */ into drug_strength_stage (
  drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason
)
select drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason from (
    select 
      drug_concept_code, -- of the quantified
      vocabulary_id_1,
      ingredient_concept_code, -- of the original non-quantified
      vocabulary_id_2,
      null as amount_value,
      null as amount_unit_concept_id,
      v*numerator_value*24 as numerator_value,
      numerator_unit_concept_id, 
      v*24 as denominator_value, -- newly added amount
      denominator_unit_concept_id,
      valid_start_date, valid_end_date,
      null as invalid_reason
    from (
      select 
        q.concept_code as drug_concept_code, ds.vocabulary_id_1, ds.ingredient_concept_code,  ds.vocabulary_id_2, 
        ds.numerator_value, ds.numerator_unit_concept_id, ds.denominator_unit_concept_id, -- Actuations never have values in the amount section
        ds.valid_start_date, ds.valid_end_date,
        regexp_substr(q.concept_name, '^[0-9\.]+')as v,  regexp_substr(q.concept_name, '[^ 0-9\.]+') as u -- parsing out the quantity
      from drug_strength_stage ds
      join concept_stage d on d.concept_code=ds.drug_concept_code and d.vocabulary_id=ds.vocabulary_id_1 and d.concept_class_id in ('Clinical Drug', 'Branded Drug') and d.vocabulary_id='RxNorm'
      join concept_relationship_stage r on r.concept_code_1=ds.drug_concept_code and r.vocabulary_id_1=ds.vocabulary_id_1 and r.invalid_reason is null
      join concept_stage q on q.concept_code=r.concept_code_2 and q.vocabulary_id=r.vocabulary_id_2 and q.concept_class_id like 'Quant%' and q.standard_concept = 'S' and q.vocabulary_id='RxNorm'
    )
    where u='DAY'
) group by drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason;

commit;

-- Quantity provided in "Unit": the amount is the total dose, not the total volume
insert /*+ APPEND */ into drug_strength_stage (
  drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason
)
select drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason from (
    select
      drug_concept_code, -- of the quantified
      vocabulary_id_1,
      ingredient_concept_code, -- of the original non-quantified
      vocabulary_id_2,
      null as amount_value,
      null as amount_unit_concept_id,
      v as numerator_value,
      numerator_unit_concept_id, 
      v/numerator_value as denominator_value, -- newly added amount
      denominator_unit_concept_id,
      valid_start_date, valid_end_date,
      null as invalid_reason
    from (
      select 
        q.concept_code as drug_concept_code, ds.vocabulary_id_1, ds.ingredient_concept_code,  ds.vocabulary_id_2, 
        ds.numerator_value, ds.numerator_unit_concept_id, ds.denominator_unit_concept_id, -- Actuations never have values in the amount section
        ds.valid_start_date, ds.valid_end_date,
        regexp_substr(q.concept_name, '^[0-9\.]+')as v,  regexp_substr(q.concept_name, '[^ 0-9\.]+') as u -- parsing out the quantity
      from drug_strength_stage ds
      join concept_stage d on d.concept_code=ds.drug_concept_code and d.vocabulary_id=ds.vocabulary_id_1 and d.concept_class_id in ('Clinical Drug', 'Branded Drug') and d.vocabulary_id='RxNorm'
      join concept_relationship_stage r on r.concept_code_1=ds.drug_concept_code and r.vocabulary_id_1=ds.vocabulary_id_1 and r.invalid_reason is null
      join concept_stage q on q.concept_code=r.concept_code_2 and q.vocabulary_id=r.vocabulary_id_2 and q.concept_class_id like 'Quant%' and q.standard_concept = 'S' and q.vocabulary_id='RxNorm'
    )
    where u='UNT'
) group by drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason;

commit;

-- Quantity provided in "MG": the amount volume of a gel usually, which is given in /mg or /mL concentrations
insert /*+ APPEND */ into drug_strength_stage (
  drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason
)
select drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason from (
    select
      drug_concept_code, -- of the quantified
      vocabulary_id_1,
      ingredient_concept_code, -- of the original non-quantified
      vocabulary_id_2,
      null as amount_value,
      null as amount_unit_concept_id,
      case denominator_unit_concept_id
        when 8587 then v*numerator_value/1000 -- ml, convert to mg
        else v*numerator_value
      end as numerator_value,
      numerator_unit_concept_id, 
      case denominator_unit_concept_id
        when 8587 then v/1000 -- ml, convert to mg
        else cast(v as number)
      end as denominator_value,
      denominator_unit_concept_id,
      valid_start_date, valid_end_date,
      null as invalid_reason
    from (
      select 
        q.concept_code as drug_concept_code, ds.vocabulary_id_1, ds.ingredient_concept_code,  ds.vocabulary_id_2, 
        ds.numerator_value, ds.numerator_unit_concept_id, ds.denominator_unit_concept_id, -- Actuations never have values in the amount section
        ds.valid_start_date, ds.valid_end_date,
        regexp_substr(q.concept_name, '^[0-9\.]+')as v,  regexp_substr(q.concept_name, '[^ 0-9\.]+') as u -- parsing out the quantity
      from drug_strength_stage ds
      join concept_stage d on d.concept_code=ds.drug_concept_code and d.vocabulary_id=ds.vocabulary_id_1 and d.concept_class_id in ('Clinical Drug', 'Branded Drug') and d.vocabulary_id='RxNorm'
      join concept_relationship_stage r on r.concept_code_1=ds.drug_concept_code and r.vocabulary_id_1=ds.vocabulary_id_1 and r.invalid_reason is null
      join concept_stage q on q.concept_code=r.concept_code_2 and q.vocabulary_id=r.vocabulary_id_2 and q.concept_class_id like 'Quant%' and q.standard_concept = 'S' and q.vocabulary_id='RxNorm'
    )
    where u='MG'
) group by drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason;

commit;

-- Quantity provided in "HR": The situation is complex. 
-- If the drug a solids, in that case the entire amounts becomes the numerator, the hours the denominator
-- If the drug is given as concentration and the denominator is hours, both the numerator and denominator is multiplied with the hours
-- If the drug is given as concentration, it is assumed that the total amount is a unit of 1 (mg or ml) and all of that gets released in the given amount of hours. This is probabl not true
insert /*+ APPEND */ into drug_strength_stage (
  drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason
)
select drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason from (
    select
      drug_concept_code, -- of the quantified
      vocabulary_id_1,
      ingredient_concept_code, -- of the original non-quantified
      vocabulary_id_2,
      null as amount_value,
      null as amount_unit_concept_id,
      case 
        when amount_unit_concept_id=8510 then amount_value -- unit in numerator
        when amount_unit_concept_id=8576 then amount_value -- mg in numerator
        when denominator_unit_concept_id=8505 then numerator_value*v -- hour in denominator
        else numerator_value -- if concentration given assume entire concent will release over the given hours
      end as numerator_value,
      nvl(amount_unit_concept_id, numerator_unit_concept_id) as numerator_unit_concept_id, 
      cast(v as number) as denominator_value,
      8505 as denominator_unit_concept_id, -- everything is going to be unit/hour
      valid_start_date, valid_end_date,
      null as invalid_reason
    from (
      select 
        q.concept_code as drug_concept_code, ds.vocabulary_id_1, ds.ingredient_concept_code,  ds.vocabulary_id_2,
        ds.amount_value, ds.amount_unit_concept_id,
        ds.numerator_value, ds.numerator_unit_concept_id, ds.denominator_unit_concept_id, -- Actuations never have values in the amount section
        ds.valid_start_date, ds.valid_end_date,
        regexp_substr(q.concept_name, '^[0-9\.]+')as v,  regexp_substr(q.concept_name, '[^ 0-9\.]+') as u -- parsing out the quantity
      from drug_strength_stage ds
      join concept_stage d on d.concept_code=ds.drug_concept_code and d.vocabulary_id=ds.vocabulary_id_1 and d.concept_class_id in ('Clinical Drug', 'Branded Drug') and d.vocabulary_id='RxNorm'
      join concept_relationship_stage r on r.concept_code_1=ds.drug_concept_code and r.vocabulary_id_1=ds.vocabulary_id_1 and r.invalid_reason is null
      join concept_stage q on q.concept_code=r.concept_code_2 and q.vocabulary_id=r.vocabulary_id_2 and q.concept_class_id like 'Quant%' and q.standard_concept = 'S' and q.vocabulary_id='RxNorm'
    ) 
    where u='HR'
) group by drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason;

commit;

-- Quantity provided in "ML": The situation is complex. 
-- If the drug a solids, in that case the entire amounts becomes the numerator, the mL the denominator
-- If the drug is given as concentration and the denominator is milligram instead of milliliter, both values are multiplied by 1000
-- Otherwise, the concentration is multiplied with the mL
insert /*+ APPEND */ into drug_strength_stage (
  drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason
)
select drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason from (
    select
      drug_concept_code, -- of the quantified
      vocabulary_id_1,
      ingredient_concept_code, -- of the original non-quantified
      vocabulary_id_2,
      null as amount_value,
      null as amount_unit_concept_id,
      case 
        when amount_unit_concept_id=8510 then amount_value -- unit (doesn't happen yet)
        when amount_unit_concept_id=8576 then amount_value -- mg 
        when denominator_unit_concept_id=8576 then numerator_value*v*1000 -- if mg in denominator
        else numerator_value*v -- if concentration given assume entire concent will release over the given hours
      end as numerator_value,
      nvl(amount_unit_concept_id, numerator_unit_concept_id) as numerator_unit_concept_id, 
      case 
        when denominator_unit_concept_id=8576 then v*1000 -- milliliter to milligram
        else cast(v as number) 
      end as denominator_value,
      case 
        when amount_unit_concept_id is not null then 8587 -- ml
        else denominator_unit_concept_id
      end as denominator_unit_concept_id,
      valid_start_date, valid_end_date,
      null as invalid_reason
    from (
      select 
        q.concept_code as drug_concept_code, ds.vocabulary_id_1, ds.ingredient_concept_code,  ds.vocabulary_id_2, 
        ds.amount_value, ds.amount_unit_concept_id,
        ds.numerator_value, ds.numerator_unit_concept_id, ds.denominator_unit_concept_id, 
        ds.valid_start_date, ds.valid_end_date,
        regexp_substr(q.concept_name, '^[0-9\.]+')as v,  regexp_substr(q.concept_name, '[^ 0-9\.]+') as u -- parsing out the quantity
      from drug_strength_stage ds
      join concept_stage d on d.concept_code=ds.drug_concept_code and d.vocabulary_id=ds.vocabulary_id_1 and d.concept_class_id in ('Clinical Drug', 'Branded Drug') and d.vocabulary_id='RxNorm'
      join concept_relationship_stage r on r.concept_code_1=ds.drug_concept_code and r.vocabulary_id_1=ds.vocabulary_id_1 and r.invalid_reason is null
      join concept_stage q on q.concept_code=r.concept_code_2 and q.vocabulary_id=r.vocabulary_id_2 and q.concept_class_id like 'Quant%' and q.standard_concept = 'S' and q.vocabulary_id='RxNorm'
    ) 
    where u='ML'
) group by drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,  
  denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason;

commit;

/* 9. Shift percent from amount to numerator */
update drug_strength_stage set 
  numerator_value=amount_value,
  numerator_unit_concept_id=8554,
  amount_value=null,
  amount_unit_concept_id=null
where amount_unit_concept_id=8554;

commit;


/* 10. Final diagnostic and clean up */
-- check unparsed records
--select * from drug_strength_stage where amount_unit_concept_id is null and numerator_unit_concept_id is null;
alter table drug_strength_stage add constraint check_units check(coalesce(amount_unit_concept_id,numerator_unit_concept_id,-1)<>-1);
alter table drug_strength_stage drop constraint check_units;

-- check that numbers are all valid
--select * from drug_strength_stage where (amount_value=0 or numerator_value=0);
alter table drug_strength_stage add constraint check_values check(coalesce(amount_value,1)>0 and coalesce(numerator_value,1)>0);
alter table drug_strength_stage drop constraint check_values;

/*
-- check that all units are valid
select a.concept_name as amount_unit, n.concept_name as numerator_unit, d.concept_name as denominator_unit, count(8) as cnt
from drug_strength_stage 
left join concept a on a.concept_id=amount_unit_concept_id
left join concept n on n.concept_id=numerator_unit_concept_id
left join concept d on d.concept_id=denominator_unit_concept_id
group by a.concept_name, n.concept_name, d.concept_name
order by 4 desc;
*/

-- clean up
drop table component_replace purge;
drop table unit_to_concept_map purge;

-- delete unparsable records
delete from drug_strength_stage where coalesce(amount_unit_concept_id, 0)=0 and coalesce(numerator_unit_concept_id, 0)=0;

commit;