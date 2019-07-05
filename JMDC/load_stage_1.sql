
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
* Authors: Christian Reich, Anna Ostropolets
* Date: 06-05-2019
**************************************************************************/

/*************************************************
* Create sequence for entities that do not have source codes *
*************************************************/
truncate table non_drug;
truncate table drug_concept_stage;
truncate table ds_stage;
truncate table internal_relationship_stage;
truncate table pc_stage;

DROP SEQUENCE IF EXISTS new_vocab ;
CREATE SEQUENCE new_vocab INCREMENT BY 1 START WITH 1 CACHE 20;

/*************************************************
* 0. Clean the data and extract non drugs *
*************************************************/
-- Preliminary work: manually identify new packs and add them to aut_pc_stage table (ingredients,dose forms and dosages; brand names and suplliers if applicable)

-- Radiopharmaceuticals, scintigraphic material and blood products
insert into non_drug
select distinct
  case when brand_name is not null then replace(substr(general_name||' '||concat(standardized_unit,null)||' ['||brand_name||']', 1, 255),'  ',' ')
       else trim(substr(general_name||' '||concat(standardized_unit,null), 1, 255))  end as concept_name,
  'JMDC', 'Device', 'S', jmdc_drug_code, null, 'Device', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null
  from jmdc
  where
  general_name ~* '(99mTc)|(131I)|(89Sr)|capsule|iodixanol|iohexol|ioxilan|ioxaglate|iopamidol|iothalamate|(123I)|(9 Cl)|(111In)|(13C)|(123I)|(51Cr)|(201Tl)|(133Xe)|(90Y)|(81mKr)|(90Y)|(67Ga)|gadoter|gadopent|manganese chloride tetrahydrate|amino acid|barium sulfate|cellulose,oxidized|purified tuberculin|blood|plasma|diagnostic|nutrition|patch test|free milk|vitamin/|white ointment|simple syrup|electrolyte|allergen extract(therapeutic)|simple ointment' -- cellulose = Surgicel Absorbable Hemostat
  and not general_name ~* 'coagulation|an extract from hemolysed blood' -- coagulation factors

insert into non_drug
select distinct
  case when brand_name is not null then replace(substr(general_name||' '||concat(standardized_unit,null)||' ['||brand_name||']', 1, 255),'  ',' ')
       else trim(substr(general_name||' '||concat(standardized_unit,null), 1, 255))  end as concept_name,
  'JMDC', 'Device', 'S', jmdc_drug_code, null, 'Device', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null
  from jmdc
  where who_atc_code like 'V08%' or formulation_medium_classification_name in ('Diagnostic Use');

insert into non_drug
select distinct
 case when brand_name is not null then replace(substr(general_name||' '||concat(standardized_unit,null)||' ['||brand_name||']', 1, 255),'  ',' ')
       else trim(substr(general_name||' '||concat(standardized_unit,null), 1, 255))  end as concept_name,
  'JMDC', 'Device', 'S', jmdc_drug_code, null, 'Device', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null
  from jmdc
  where lower(general_name) in
  ('maintenance solution','maintenance solution with acetic acid','maintenance solution with acetic acid(with glucose)','maintenance solution(with glucose)','artificial kidney dialysis preparation',
  'benzoylmercaptoacetylglycylglycylglycine','diethylenetriamine pentaacetate','ethyelenebiscysteinediethylester dichloride','hydroxymethylene diphosphonate','postoperative recovery solution',
  'tetrakis(methoxyisobutylisonitrile)cu(i)tetrafluoroborate','witepsol','peritoneal dialysis solution','intravenous hyperalimentative basic solution','macroaggregated human serum albumin');

-- Create copy of input data
drop table if exists j;
create table j as
select * from jmdc
where jmdc_drug_code not in (
  select concept_code from non_drug
);

delete from j
where lower(general_name) in ('allergen extract(therapeutic)','therapeutic allergen extract','allergen disk','initiating solution','white soft sugar');

drop table if exists supplier;
create table supplier
as
select trim(substring(brand_name,' \w+$')) as concept_name,jmdc_drug_code from j -- upper case suppliers in the end of the line
where substring(brand_name,' \w+$')=upper(substring(brand_name,' \w+$'))
and length(substring(brand_name,' \w+$'))>4 and trim(substring(brand_name,' \w+$')) not in ('A240','VIII')
UNION
select trim(substring(brand_name,'^\w+ ')) as concept_name,jmdc_drug_code from j -- upper case suppliers in the beginning of the line
where substring(brand_name,'^\w+ ')=upper(substring(brand_name,'^\w+ '))
and length(substring(brand_name,'^\w+ '))>4 and trim(substring(brand_name,'^\w+ ')) not in ('A240','VIII')
UNION
select distinct replace(replace(substring(brand_name,'\[\w+\]'),'[',''),']','') as concept_name,jmdc_drug_code -- the position doesn't matter since it's in brackets
from j
where length(replace(replace(substring(brand_name,'\[\w+\]'),'[',''),']',''))>1 -- something like [F] that we do not need
;

--ingredient
delete from supplier
where jmdc_drug_code='100000049525'
and concept_name = 'GHRP';

delete from supplier
where concept_name = 'WATER';

update j
set brand_name = replace(brand_name,substring(brand_name,' \w+$'),'')
where substring(brand_name,' \w+$')=upper(substring(brand_name,' \w+$'))
and length(substring(brand_name,' \w+$'))>4 and trim(substring(brand_name,' \w+$')) not in ('A240','VIII')
;
update j
set brand_name = replace(brand_name,substring(brand_name,'^\w+ '),'')
where substring(brand_name,'^\w+ ')=upper(substring(brand_name,'^\w+ '))
and length(substring(brand_name,'^\w+ '))>4 and trim(substring(brand_name,'^\w+ ')) not in ('A240','VIII')
;
-- all new items with [] are generics by their nature
update j
set brand_name = null
where brand_name like '%[%]%'
;

-- Remove pseudo brands
update j
set brand_name = null
where brand_name in (
  'Acrinol and Zinc Oxide Oil',
  'Caffeine and Sodium Benzoate',
  'Compound Oxycodone and Atropine',
  'Crude Drugs',
  'Nor-Adrenalin',
  'Wasser',
  'Gel',
  'Horizon',
  'Biogen',
   'Vega',
  'Calcium L-Aspartate',
  'Deleted NHI price',
   'Unknown Brand Name in English',
  'Glycerin and Potash',
  'Morphine and Atropine',
  'Opium Alkaloids and Atropine',
  'Opium Alkaloids and Scopolamine',
  'Phenol and Zinc Oxide Liniment',
  'Scopolia Extract and Tannic Acid',
  'Sulfur and Camphor',
  'Sulfur,Salicylic Acid and Thianthol',
  'Swertia and Sodium Bicarbonate',
  'Weak Opium Alkaloids and Scopolamine',
  '5-FU'
)
or lower(brand_name)=lower(general_name)
or brand_name ~* 'Sulfate|Nitrate|Acetat|Oxide|Saponated|Salicylat|Chloride|/|Acid|Sodium|Aluminum|Potassium|Ammonia|Ringer|Invert Soap|Dried Yeast|Fluidextract|Kakko| RTU|Infusion Solution| KO$|Globulin|Absorptive Ointment|Allergen|Water'
;
update j
set brand_name = null
where brand_name in (
select brand_name
from j
join devv5.concept c on lower(j.brand_name)=lower(c.concept_name)
where c.concept_class_id like '%Ingredient' );

update j
set brand_name = null
where lower(brand_name) in (
select lower(concept_name)
from supplier);

update j
set brand_name = null
where lower(brand_name)||' extract' in (
select lower(general_name)
from j);

update j
set brand_name = null
where length(brand_name)<3;

update j
set brand_name = null
where brand_name like '% %' and brand_name ~* 'NIPPON-ZOKI|KANADA|BIKEN|Antivenom|KITASATO|NICHIIKO|JPS | Equine|Otsujito|Bitter Tincture|Syrup| SW|Concentrate| MED| DSP$| DK$| KN$| KY$| YP$| UJI$| TTS$| MDP$| JG$| KN$|SEIKA|KYOWA|SHOWA|NikP| JCR| NK$| HK$|Japanese Strain| CH$| TCK| FM| Na | Na$| AFP|Gargle|Injection| Ca | Ca$|KOBAYASI| TYK| NIKKO| YD| KOG| FFP| NP| NS| TSU| KOG| SN| TS| NP| YD';

update j
set brand_name = null
where  brand_name ~* 'Tosufloxacin Tosilate|Succinate|OTSUKA|Kenketsu|Ethanol|Powder|JANSSEN|Disinfection|Oral|Gluconate| TN$|FUSO|Sugar| TOA$|Prednisolone Acetate T|I''ROM| BMD$|^KTS |Taunus Aqua|Cefamezin alfa|Bromide|Vaccine';

update j
set brand_name = null
where  brand_name ~* 'ASAHI| CMX|Lawter Leaf|Kakkontokasenkyushin| HMT|Saikokeishito|Dibasic Calcium Phosphate| Hp$| F$| HT$| TC$| AA$| MP$|Freeze-dried| AY$| KTB| CEO|Ethyl Aminobenzoate| QQ$|Viscous|Tartrate|NIPPON| EE$|Tincture';

-- multi-ingredients fixes
update j
set general_name = 'ampicillin sodium/sulbactam sodium'
where lower(general_name) = 'sultamicillin tosilate hydrate';

update j
set general_name = 'follicle stimulating hormone/luteinizing hormone'
where lower(general_name) = 'human menopausal gonadotrophin';

update j
set general_name = 'human normal immunoglobulin/histamine'
where lower(general_name) = 'immunoglobulin with histamine';

-- remove junk from standard_unit
update j set standardized_unit = regexp_replace(standardized_unit, '\(forGeneralDiagnosis\)', '') where standardized_unit like '%(forGeneralDiagnosis)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(forGeneralDiagnosis/forOnePerson\)', '') where standardized_unit like '%(forGeneralDiagnosis/forOnePerson)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(forStrongResponsePerson\)', '') where standardized_unit like '%(forStrongResponsePerson)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(MixedPreparedInjection\)', '') where standardized_unit like '%(MixedPreparedInjection)%';
update j set standardized_unit = regexp_replace(standardized_unit, 'w/NS', '') where standardized_unit like '%w/NS%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(w/Soln\)', '') where standardized_unit like '%(w/Soln)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(asSoln\)', '') where standardized_unit like '%(asSoln)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(w/DrainageBag\)', '') where standardized_unit like '%(w/DrainageBag)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(w/Sus\)', '') where standardized_unit like '%(w/Sus)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(asgoserelin\)', '') where standardized_unit like '%(asgoserelin)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(Amountoftegafur\)', '') where standardized_unit like '%(Amountoftegafur)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(as levofloxacin\)', '') where standardized_unit like '%(as levofloxacin)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(as phosphorus\)', '') where standardized_unit like '%(as phosphorus)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(asActivatedform\)', '') where standardized_unit like '%(asActivatedform)%';
update j set standardized_unit = regexp_replace(standardized_unit, 'teriparatideacetate', '') where standardized_unit like '%teriparatideacetate%';
update j set standardized_unit = regexp_replace(standardized_unit, 'Elcatonin', '') where standardized_unit like '%Elcatonin%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(asSuspendedLiquid\)', '') where standardized_unit like '%(asSuspendedLiquid)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(mixedOralLiquid\)', '') where standardized_unit like '%(mixedOralLiquid)%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(w/Soln,Dil\)', '') where standardized_unit like '%(w/Soln,Dil)%';
update j set standardized_unit = regexp_replace(standardized_unit, 'DomesticStandard', '') where standardized_unit like '%DomesticStandard%';
update j set standardized_unit = regexp_replace(standardized_unit, 'million', '000000') where standardized_unit like '%million%';
update j set standardized_unit = regexp_replace(standardized_unit, 'U\.S\.P\.', '') where standardized_unit like '%U.S.P.%';
update j set standardized_unit = regexp_replace(standardized_unit, 'about', '') where standardized_unit like '%about%';
update j set standardized_unit = regexp_replace(standardized_unit, 'iron', '') where standardized_unit like '%iron%';
update j set standardized_unit = regexp_replace(standardized_unit, ':240times', '') where standardized_unit like '%:240times%';
update j set standardized_unit = regexp_replace(standardized_unit, 'low\-molecularheparin', '') where standardized_unit like '%low-molecularheparin%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(asCalculatedamountofD\-arabinose\)', '') where standardized_unit like '%(asCalculatedamountofD-arabinose)%';
update j set standardized_unit = regexp_replace(standardized_unit, 'w/5%GlucoseInjection', '') where standardized_unit like '%w/5\%GlucoseInjection%' escape '\';
update j set standardized_unit = regexp_replace(standardized_unit, 'w/WaterforInjection', '') where standardized_unit like '%w/WaterforInjection%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(w/SodiumBicarbonate\)', '') where standardized_unit like '%(w/SodiumBicarbonate)%';
update j set standardized_unit = regexp_replace(standardized_unit, 'potassium', '') where standardized_unit like '%potassium%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(Amountoftrifluridine\)', '') where standardized_unit like '%(Amountoftrifluridine)%';
update j set standardized_unit = regexp_replace(standardized_unit, 'FRM', '') where standardized_unit like '%FRM%';
update j set standardized_unit = regexp_replace(standardized_unit, 'NormalHumanPlasma', '') where standardized_unit like '%NormalHumanPlasma%';
update j set standardized_unit = regexp_replace(standardized_unit, 'Anti-factorXa', '') where standardized_unit like '%Anti-factorXa%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(w/SodiumBicarbonateSoln\)', '') where standardized_unit like '%(w/SodiumBicarbonateSoln)%';
update j set standardized_unit = regexp_replace(standardized_unit, ',CorSoln', '') where standardized_unit like '%,CorSoln%';
update j set standardized_unit = regexp_replace(standardized_unit, '1Set', '') where standardized_unit like '%1Set%';
update j set standardized_unit = regexp_replace(standardized_unit, 'AmountforOnce', '') where standardized_unit like '%AmountforOnce%';
update j set standardized_unit = regexp_replace(standardized_unit, '\(w/Dil\)', '') where standardized_unit like '%(w/Dil)%';

/*************************************************
* 1. Create parsed Ingredients and relationships *
*************************************************/
drop table if exists PI;
create table pi
as
select jmdc_drug_code, ing_name
from  (
select jmdc_drug_code, lower(general_name) as ing_name
from j
where general_name not like '%/%' and general_name not like '% and %'
union
select jmdc_drug_code, lower(ing_name)
from (select jmdc_drug_code, replace(general_name,' and ','/') as concept_name
      from j) j,
     UNNEST(STRING_TO_ARRAY(j.concept_name,'/')) as ing_name
) a
where jmdc_drug_code not in
      (select jmdc_drug_code from aut_pc_stage);


delete from pi
where lower(ing_name) = 'rhizome'--eliminating wrong parsing
;

update pi
set ing_name = trim(regexp_replace (ing_name,'\(genetical recombination\)',''))
where ing_name ~* 'genetical recombination';
update pi
set ing_name = trim(regexp_replace (ing_name,'adhesive plaster',''))
where ing_name ~* 'adhesive plaster';

insert into pi
select jmdc_drug_code, lower(concept_name)
from pi
join aut_parsed_ingr
using(ing_name);

delete from pi
where ing_name in
  (select ing_name from aut_parsed_ingr);

/************************************
* 2. Populate drug concept stage *
*************************************/

-- Drugs
insert into drug_concept_stage
select distinct
  case when brand_name is not null then replace(substr(general_name||' '||concat(standardized_unit,null)||' ['||brand_name||']', 1, 255),'  ',' ')
       else trim(substr(general_name||' '||concat(standardized_unit,null), 1, 255))  end as concept_name,
  'JMDC' as vocabulary_id,
  'Drug Product' as concept_class_id,
  null as standard_concept,
  jmdc_drug_code as concept_code,
  null as possible_excipient,
   'Drug',
  to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'),
  null as invalid_reason
from j;

-- Drugs from packs
insert into drug_concept_stage
select
  concept_name,
  'JMDC' as vocabulary_id,
  'Drug Product' as concept_class_id,
  null as standard_concept,
  'JMDC'||nextval('new_vocab') as concept_code,
  null as possible_excipient,
   'Drug',
  to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'),
  null as invalid_reason
from
  (select distinct
   substr(ingredient||' '||dosage||' '||lower(form), 1, 255) as concept_name
   from aut_pc_stage) a
;

-- Devices
insert into drug_concept_stage
select distinct * from non_drug;

-- Ingredients
insert into drug_concept_stage
select
  ing_name as concept_name,
  'JMDC' as vocabulary_id,
  'Ingredient' as concept_class_id,
  null as standard_concept,
  'JMDC'||nextval('new_vocab') as concept_code,
  null as possible_excipient,
  'Drug',
  to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'),
  null as invalid_reason
  from ( select distinct ing_name
from pi) a;

-- Brand Name
insert into drug_concept_stage
select
  brand_name as concept_name,
  'JMDC' as vocabulary_id,
  'Brand Name' as concept_class_id,
  null as standard_concept,
  'JMDC'||nextval('new_vocab') as concept_code,
  null as possible_excipient,
  'Drug',
  to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'),
  null as invalid_reason
from
(select distinct brand_name from j where brand_name is not null) a
;

-- Dose Forms
-- is populated based on manual tables
insert into drug_concept_stage
select
   concept_name,
  'JMDC' as vocabulary_id,
  'Dose Form' as concept_class_id,
  null as standard_concept,
  'JMDC'||nextval('new_vocab') as concept_code,
  null as possible_excipient,
  'Drug',
  to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'),
  null as invalid_reason
from
(select distinct coalesce(new_name, concept_name) as concept_name from aut_form_mapped) a
;

-- Units
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('u', 'JMDC', 'Unit', null, 'u', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('iu', 'JMDC', 'Unit', null, 'iu', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('g', 'JMDC', 'Unit', null, 'g', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('mg', 'JMDC', 'Unit', null, 'mg', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('mlv', 'JMDC', 'Unit', null, 'mlv', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('ml', 'JMDC', 'Unit', null, 'ml', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('%', 'JMDC', 'Unit', null, '%', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('ug', 'JMDC', 'Unit', null, 'ug', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('actuat', 'JMDC', 'Unit', null, 'actuat', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('mol', 'JMDC', 'Unit', null, 'mol', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('mEq', 'JMDC', 'Unit', null, 'mEq', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('ku', 'JMDC', 'Unit', null, 'ku', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
 values ('ul', 'JMDC', 'Unit', null, 'ul', 'Drug', to_date('19700101','YYYYMMDD'), to_date('20991231','YYYYMMDD'), null);

--Supplier
insert into drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code, domain_id, valid_start_date, valid_end_date, invalid_reason)
select
  concept_name,
  'JMDC' as vocabulary_id,
  'Supplier' as concept_class_id,
  null as standard_concept,
   'JMDC'||nextval('new_vocab') as concept_code,
   'Drug',
  to_date('19700101','YYYYMMDD'),
  to_date('20991231','YYYYMMDD'),
  null as invalid_reason
from (
  select distinct coalesce(name,concept_name) as concept_name
  from supplier
  left join aut_suppliers_mapped on upper(source_name) = upper(concept_name)) s;

/*************************************************
* 3. Populate IRS *
*************************************************/

-- 3.1 create relationship between products and ingredients
insert into internal_relationship_stage
select distinct
  pi.jmdc_drug_code as concept_code_1,
  dcs.concept_code as concept_code_2
from pi
  join drug_concept_stage dcs
    on dcs.concept_name=pi.ing_name and dcs.concept_class_id='Ingredient'
;

-- 3.1.1 drugs from packs
insert into internal_relationship_stage
select distinct
  dcs2.concept_code as concept_code_1,
  dcs.concept_code as concept_code_2
from aut_pc_stage
  join drug_concept_stage dcs
   on dcs.concept_name=ingredient and dcs.concept_class_id='Ingredient'
  join drug_concept_stage dcs2
   on dcs2.concept_name = substr(ingredient||' '||dosage||' '||lower(form), 1, 255)
;

-- 3.2 create relationship between products and BN
insert into internal_relationship_stage
select distinct
  j.jmdc_drug_code as concept_code_1,
  dcs.concept_code as concept_code_2
from j
  join drug_concept_stage dcs on dcs.concept_name=j.brand_name and dcs.concept_class_id='Brand Name'
;

-- 3.3 create relationship between products and DF
insert into internal_relationship_stage
select distinct jmdc_drug_code,dc.concept_code
from aut_form_mapped a
join j on trim(formulation_small_classification_name) = a.concept_name
join drug_concept_stage dc on dc.concept_name = coalesce (a.new_name, a.concept_name)
where dc.concept_class_id = 'Dose Form'
;
-- 3.3.1 drugs from packs
insert into internal_relationship_stage
select distinct
  dcs2.concept_code as concept_code_1,
  dcs.concept_code as concept_code_2
from aut_pc_stage
  join drug_concept_stage dcs
   on dcs.concept_name=form and dcs.concept_class_id='Dose Form'
  join drug_concept_stage dcs2
   on dcs2.concept_name = substr(ingredient||' '||dosage||' '||lower(form), 1, 255)
;

-- 3.4 Suppliers
insert into internal_relationship_stage (concept_code_1, concept_code_2)
    select distinct jmdc_drug_code,concept_code
    from supplier s
    left join aut_suppliers_mapped a on upper(a.source_name) = upper(s.concept_name)
    join drug_concept_stage dc on dc.concept_name = coalesce(a.name,s.concept_name)
where concept_class_id = 'Supplier';

/*********************************
* 4. Create and link Drug Strength
*********************************/

-- 4.1 g|mg|ug|mEq|MBq|IU|KU|U
INSERT into ds_stage
SELECT DISTINCT j.jmdc_drug_code,
                dcs.concept_code,
                CAST(substring(regexp_replace(standardized_unit, '[,()]', '', 'g') from '^(\d+\.*\d*)(?=(g|mg|ug|mEq|MBq|IU|KU|U)(|1T|1Syg|1A|1V|1Bag|each/V|1C|1Pack|1Pc|1Kit|1Sheet|1Bot|1Bls|1P|(\d+\.*\d*)(cm|mm)(2|\*(\d+\.*\d*)(cm|mm)))(|1Sheet)($))') as double precision),
                substring(regexp_replace(standardized_unit, '[,()]', '', 'g') from '(?<=^(\d+\.*\d*))(g|mg|ug|mEq|MBq|IU|KU|U)(?=(|1T|1Syg|1A|1V|1Bag|each/V|1C|1Pack|1Pc|1Kit|1Sheet|1Bot|1Bls|1P|(\d+\.*\d*)(cm|mm)(2|\*(\d+\.*\d*)(cm|mm)))(|1Sheet)($))')
FROM j
         JOIN pi ON j.jmdc_drug_code = pi.jmdc_drug_code
         JOIN drug_concept_stage dcs ON pi.ing_name = dcs.concept_name
WHERE general_name !~ '\/'
  AND regexp_replace(standardized_unit, '[,()]', '', 'g') ~ '^(\d+\.*\d*)(g|mg|ug|mEq|MBq|IU|KU|U)(|1T|1Syg|1A|1V|1Bag|each/V|1C|1Pack|1Pc|1Kit|1Sheet|1Bot|1Bls|1P|(\d+\.*\d*)(cm|mm)(2|\*(\d+\.*\d*)(cm|mm)))(|1Sheet)($)'
  AND dcs.concept_class_id = 'Ingredient';

--4.2 liquid % / ml|l
INSERT into ds_stage
SELECT DISTINCT j.jmdc_drug_code,
                dcs.concept_code,
                CAST(null as double precision),
                null,
                CAST(substring(standardized_unit from '^(\d+\.*\d*)(?=(%)(\d+\.*\d*)(mL|L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($))') as double precision)
                    * CAST(substring(standardized_unit from '(?<=^(\d+\.*\d*)(%))(\d+\.*\d*)(?=(mL|L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($))') as double precision)
                    * CASE  WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mL)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($)' THEN 10
                            WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($)'  THEN 10000 END,
                'mg',
                CAST(substring(standardized_unit from '(?<=^(\d+\.*\d*)(%))(\d+\.*\d*)(?=(mL|L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($))') as double precision)
                    * CASE  WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mL)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($)' THEN 1
                            WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($)'  THEN 1000 END,
                'ml'
FROM j
         JOIN pi ON j.jmdc_drug_code = pi.jmdc_drug_code
         JOIN drug_concept_stage dcs ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mL|L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($)'
  AND dcs.concept_class_id = 'Ingredient';

--4.3 solid % / g|mg
INSERT into ds_stage
SELECT DISTINCT j.jmdc_drug_code,
                dcs.concept_code,
                CAST(null as double precision),
                null,
                CAST(substring(standardized_unit from '^(\d+\.*\d*)(?=(%)(\d+\.*\d*)(mg|g)(|1Pack|1Bot|1can|1V|1Pc)($))') as double precision)
                    * CAST(substring(standardized_unit from '(?<=^(\d+\.*\d*)(%))(\d+\.*\d*)(?=(mg|g)(|1Pack|1Bot|1can|1V|1Pc)($))') as double precision)
                    * CASE  WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(g)(|1Pack|1Bot|1can|1V|1Pc)($)' THEN 10
                            WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mg)(|1Pack|1Bot|1can|1V|1Pc)($)'  THEN 0.01 END,
                'mg',
                CAST(substring(standardized_unit from '(?<=^(\d+\.*\d*)(%))(\d+\.*\d*)(?=(mg|g)(|1Pack|1Bot|1can|1V|1Pc)($))') as double precision)
                    * CASE  WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(g)(|1Pack|1Bot|1can|1V|1Pc)($)' THEN 1000
                            WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mg)(|1Pack|1Bot|1can|1V|1Pc)($)'  THEN 1 END,
                'mg'
FROM j
         JOIN pi ON j.jmdc_drug_code = pi.jmdc_drug_code
         JOIN drug_concept_stage dcs ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mg|g)(|1Pack|1Bot|1can|1V|1Pc)($)'
  AND dcs.concept_class_id = 'Ingredient';

--4.4 mg|mol|ug|g|IU|U|mEq / mL|uL|g
INSERT into ds_stage
SELECT DISTINCT j.jmdc_drug_code,
                dcs.concept_code,
                CAST(null as double precision),
                null,
                CAST(substring(regexp_replace(standardized_unit, ',', '', 'g') from '^(\d+\.*\d*)(?=(mg|mol|ug|g|IU|U|mEq)(\d+\.*\d*)(mL|uL|g)(|1A|1Pc|1Syg|1Kit|1Bot|V|1V|1Bag|1Pack)($))') as double precision),
                substring(regexp_replace(standardized_unit, ',', '', 'g') from '(?<=^(\d+\.*\d*))(mg|mol|ug|g|IU|U|mEq)(?=(\d+\.*\d*)(mL|uL|g)(|1A|1Pc|1Syg|1Kit|1Bot|V|1V|1Bag|1Pack)($))'),
                CAST(substring(regexp_replace(standardized_unit, ',', '', 'g') from '(?<=^(\d+\.*\d*)(mg|mol|ug|g|IU|U|mEq))(\d+\.*\d*)(?=(mL|uL|g)(|1A|1Pc|1Syg|1Kit|1Bot|V|1V|1Bag|1Pack)($))') as double precision),
                substring(regexp_replace(standardized_unit, ',', '', 'g') from '(?<=^(\d+\.*\d*)(mg|mol|ug|g|IU|U|mEq)(\d+\.*\d*))(mL|uL|g)(?=(|1A|1Pc|1Syg|1Kit|1Bot|V|1V|1Bag|1Pack)($))')
FROM j
         JOIN pi ON j.jmdc_drug_code = pi.jmdc_drug_code
         JOIN drug_concept_stage dcs ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND regexp_replace(standardized_unit, ',', '', 'g') ~ '^(\d+\.*\d*)(mg|mol|ug|g|IU|U|mEq)(\d+\.*\d*)(mL|uL|g)(|1A|1Pc|1Syg|1Kit|1Bot|V|1V|1Bag|1Pack)($)'
  AND dcs.concept_class_id = 'Ingredient';

-- 4.5 ug/actuat1
INSERT into ds_stage
SELECT DISTINCT j.jmdc_drug_code,
                dcs.concept_code,
                CAST(null as double precision),
                null,
                CAST(substring(standardized_unit from '^(\d+\.*\d*)(?=(ug)(\d+\.*\d*)(Bls)(1Pc|1Kit)($))') as double precision)
                    * CAST(substring(standardized_unit from '(?<=^(\d+\.*\d*)(ug))(\d+\.*\d*)(?=(Bls)(1Pc|1Kit)($))') as double precision),
                substring(standardized_unit from '(?<=^(\d+\.*\d*))(ug)(?=(\d+\.*\d*)(Bls)(1Pc|1Kit)($))'),
                CAST(substring(standardized_unit from '(?<=^(\d+\.*\d*)(ug))(\d+\.*\d*)(?=(Bls)(1Pc|1Kit)($))') as double precision),
                'actuat'
FROM j
         JOIN pi ON j.jmdc_drug_code = pi.jmdc_drug_code
         JOIN drug_concept_stage dcs ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND standardized_unit ~ '^(\d+\.*\d*)(ug)(\d+\.*\d*)(Bls)(1Pc|1Kit)($)'
  AND dcs.concept_class_id = 'Ingredient';

-- 4.6 ug/actuat2
INSERT into ds_stage
SELECT DISTINCT j.jmdc_drug_code,
                dcs.concept_code,
                CAST(null as double precision),
                null,
                CAST(substring(regexp_replace(standardized_unit, '[()]', '', 'g') from '^(\d+\.*\d*)(?=(mg|ug)(1Bot|1Kit)(\d+\.*\d*)(ug)($))') as double precision),
                substring(regexp_replace(standardized_unit, '[()]', '', 'g') from '(?<=^(\d+\.*\d*))(mg|ug)(?=(1Bot|1Kit)(\d+\.*\d*)(ug)($))'),
                CAST(substring(regexp_replace(standardized_unit, '[()]', '', 'g') from '^(\d+\.*\d*)(?=(mg|ug)(1Bot|1Kit)(\d+\.*\d*)(ug)($))') as double precision)
                    * CASE  WHEN regexp_replace(standardized_unit, '[()]', '', 'g') ~ '^(\d+\.*\d*)(ug)(1Bot|1Kit)(\d+\.*\d*)(ug)($)' THEN 1
                            WHEN regexp_replace(standardized_unit, '[()]', '', 'g') ~ '^(\d+\.*\d*)(mg)(1Bot|1Kit)(\d+\.*\d*)(ug)($)'  THEN 1000 END
                    / CAST(substring(regexp_replace(standardized_unit, '[()]', '', 'g') from '(?<=^(\d+\.*\d*)(mg|ug)(1Bot|1Kit))(\d+\.*\d*)(?=(ug)($))') as double precision),
                'actuat'
FROM j
         JOIN pi ON j.jmdc_drug_code = pi.jmdc_drug_code
         JOIN drug_concept_stage dcs ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND regexp_replace(standardized_unit, '[()]', '', 'g') ~ '^(\d+\.*\d*)(mg|ug)(1Bot|1Kit)(\d+\.*\d*)(ug)($)'
  AND dcs.concept_class_id = 'Ingredient';

-- 4.7 g|mg from kits
INSERT into ds_stage
SELECT DISTINCT j.jmdc_drug_code,
                dcs.concept_code,
                CAST(substring(regexp_replace(standardized_unit, '[()]', '', 'g') from '^(\d+\.*\d*)(?=(g|mg)(1Kit)(\d+\.*\d*)(mL))') as double precision),
                substring(regexp_replace(standardized_unit, '[()]', '', 'g') from '(?<=^(\d+\.*\d*))(g|mg)(?=(1Kit)(\d+\.*\d*)(mL))')
FROM j
         JOIN pi ON j.jmdc_drug_code = pi.jmdc_drug_code
         JOIN drug_concept_stage dcs ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND regexp_replace(standardized_unit, '[()]', '', 'g') ~ '^(\d+\.*\d*)(g|mg)(1Kit)(\d+\.*\d*)(mL)'
  AND dcs.concept_class_id = 'Ingredient';

-- 4.8 drugs from packs
insert into ds_stage
select distinct dcs2.concept_code,
                dcs.concept_code,
                cast(substring(dosage,'\d+') as double precision),
                substring(dosage,'mg')
from aut_pc_stage
  join drug_concept_stage dcs
   on dcs.concept_name=ingredient and dcs.concept_class_id='Ingredient'
  join drug_concept_stage dcs2
   on dcs2.concept_name = substr(ingredient||' '||dosage||' '||lower(form), 1, 255)
;

-- 4.9
update ds_stage
set amount_unit = lower(amount_unit),
    numerator_unit = lower(numerator_unit),
    denominator_unit = lower(denominator_unit);

-- 4.10 convert meq to mmol
update ds_stage
set amount_value = '595', amount_unit = 'mg'
where ingredient_concept_code in (select concept_code from drug_concept_stage where concept_name='potassium gluconate')
and amount_value='2.5' and amount_unit='meq';
update ds_stage
set denominator_unit='ml'
where ingredient_concept_code in (select concept_code from drug_concept_stage where concept_name='potassium gluconate')
and numerator_unit='meq';

-- 4.11 fixing inhalers

update ds_stage
set numerator_unit = amount_unit, numerator_value = amount_value, amount_unit = null, amount_value = null, denominator_unit = 'actuat'
where (drug_concept_code, ingredient_concept_code) in
      (select drug_concept_code, ingredient_concept_code from j
join ds_stage ds
on jmdc_drug_code = drug_concept_code
where who_atc_code ~'R01|R03' and formulation_small_classification_name ~'Inhal'
and formulation_small_classification_name !~'Sol|Aeros'
and amount_unit = 'ug');

update ds_stage
set numerator_unit = amount_unit, numerator_value = amount_value, amount_unit = null, amount_value = null, denominator_value = amount_value*100, denominator_unit = 'actuat'
where (drug_concept_code, ingredient_concept_code) in
      (select drug_concept_code, ingredient_concept_code from j
join ds_stage ds
on jmdc_drug_code = drug_concept_code
where who_atc_code ~'R01|R03' and formulation_small_classification_name ~'Inhal'
and formulation_small_classification_name !~'Sol|Aeros'
and brand_name = 'Meptin');

update ds_stage
set numerator_unit = 'ug', numerator_value = '200', amount_unit = null, amount_value = null, denominator_value = '28', denominator_unit = 'actuat'
where (drug_concept_code, ingredient_concept_code) in
      (select drug_concept_code, ingredient_concept_code from j
join ds_stage ds
on jmdc_drug_code = drug_concept_code
where who_atc_code ~'R01|R03' and formulation_small_classification_name ~'Inhal'
and formulation_small_classification_name !~'Sol|Aeros'
and brand_name = 'Erizas');

update ds_stage
set numerator_unit = 'ug', numerator_value = '32', denominator_value = null, denominator_unit = 'actuat'
where (drug_concept_code, ingredient_concept_code) in
      (select drug_concept_code, ingredient_concept_code from j
join ds_stage ds
on jmdc_drug_code = drug_concept_code
where who_atc_code ~'R01|R03' and formulation_small_classification_name ~'Inhal'
and formulation_small_classification_name !~'Sol|Aeros'
and standardized_unit = '1.50mg0.9087g1Bot');

/************************************************
* 5. Mappings for RTC *
************************************************/

-- create rtc for future releases
create table relationship_to_concept_bckp_@date
as
  select * from relationship_to_concept;
truncate table relationship_to_concept;

-- 5.1 Write mappings to RxNorm Dose Forms
-- delete invalid forms
delete from aut_form_mapped
where concept_id_2 in
      (select concept_id from concept where invalid_reason is not null)
;
-- get the list of forms to map
create temp table aut_form_to_map
as
  select * from drug_concept_stage
where concept_name not in
      (select coalesce (new_name,concept_name)
        from aut_form_mapped)
and concept_class_id = 'Dose Form';

-- 5.2 Write mappings to real units
-- get list of units
create temp table aut_unit_to_map
as
  select * from drug_concept_stage
where concept_name not in
      (select concept_code_1
        from aut_unit_mapped)
and concept_class_id = 'Unit';

-- 5.3 Ingredients
-- for ingredients the ATC codes provided by the source jmdc table can be used

insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',c2.concept_id, rank() over (partition by dc.concept_code order by c2.concept_id)
from drug_concept_stage dc
left join relationship_to_concept r on concept_code = concept_code_1
join concept c2 on lower(C2.concept_name) = lower(dc.concept_name)
where dc.concept_class_id = 'Ingredient' and concept_id_2 is  null
and c2.standard_concept = 'S' and c2.concept_class_id = 'Ingredient' and c2.vocabulary_id like 'RxNorm%'
;
--precise ingredients
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code, 'JMDC',c3.concept_id, 1
from drug_concept_stage dc
left join relationship_to_concept r on concept_code = concept_code_1
join devv5.concept c2 on lower(C2.concept_name) = lower(dc.concept_name)
join devv5.concept_relationship cr on cr.concept_id_1 = c2.concept_id
join devv5.concept c3 on c3.concept_id = cr.concept_id_2
where dc.concept_class_id = 'Ingredient' and r.concept_id_2 is  null
and c2.concept_class_id = 'Precise Ingredient' and c3.concept_class_id = 'Ingredient'
and cr.invalid_reason is null and c3.standard_concept = 'S' and c3.vocabulary_id like 'RxNorm%'
;

-- delete/update invalid ingredients

delete from aut_ingredient_mapped
where cast(concept_id_2 as int)
in (select concept_id from concept where invalid_reason = 'D');

update aut_ingredient_mapped aim
set concept_id_2 = c.concept_id_2
from (select concept_id_2,concept_id_1 
      from concept_relationship cr
      join concept c on c.concept_id = concept_id_1 and c.invalid_reason = 'U' and relationship_id = 'Maps to' and cr.invalid_reason is null) c
where (cast(aim.concept_id_2 as int) = c.concept_id_1);

-- get the list of ingredients to map
create temp table aut_ingredient_to_map
as
  select *
  from drug_concept_stage
where lower(concept_name) not in
      (select lower(concept_name)
        from aut_ingredient_mapped
        union
       select lower(ing_name)
        from aut_parsed_ingr
        union
       select lower(concept_name)
        from aut_parsed_ingr
        )
and concept_code not in
    (select concept_code_1 from relationship_to_concept)
and concept_class_id = 'Ingredient';

-- 5.4 Brand Names
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',c.concept_id, rank() over (partition by dc.concept_code order by c.concept_id)
from drug_concept_stage dc
join devv5.concept c on regexp_replace(lower (trim(dc.concept_name)), '(\s|\W)', '', 'g') = regexp_replace(lower (trim(c.concept_name)), '(\s|\W)', '', 'g')
where dc.concept_class_id = 'Brand Name'
and c.concept_class_id = 'Brand Name' and c.vocabulary_id like 'Rx%' and c.invalid_reason is null
and c.concept_id not in (42912198, 44022957, 21018872, 40819872)
;

insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',c2.concept_id, rank() over (partition by dc.concept_code order by c2.concept_id)
from drug_concept_stage dc
join devv5.concept c on lower(c.concept_name) = lower(dc.concept_name) and c.invalid_reason = 'U' and c.concept_class_id = 'Brand Name'
join devv5.concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.invalid_reason is null
join devv5.concept  c2 on cr.concept_id_2 = c2.concept_id and relationship_id = 'Concept replaced by'
where dc.concept_class_id = 'Brand Name'
and dc.concept_code not in (select concept_code_1 from relationship_to_concept);
;

-- delete/update invalid BN
delete from aut_bn_mapped
where cast(concept_id_2 as int)
in (select concept_id from concept where invalid_reason = 'D');

update aut_bn_mapped aim
set concept_id_2 = c.concept_id_2
from (select concept_id_2,concept_id_1 
      from concept_relationship cr
      join concept c on c.concept_id = concept_id_1 and c.invalid_reason = 'U' and relationship_id = 'Concept replaced by' and cr.invalid_reason is null) c
where (cast(aim.concept_id_2 as int) = c.concept_id_1);

-- get the list of BN to map 
create temp table aut_bn_to_map
as
  select *
  from drug_concept_stage
where concept_code not in
    (select concept_code_1 from relationship_to_concept)
and concept_class_id = 'Brand Name';

 -- 5.5 Supplier
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',c.concept_id, rank() over (partition by dc.concept_code order by c.concept_id)
from drug_concept_stage dc
join devv5.concept c on lower(c.concept_name) = lower(dc.concept_name)and c.concept_class_id = 'Supplier'
and c.invalid_reason is null and c.vocabulary_id = 'RxNorm Extension'
where dc.concept_class_id = 'Supplier'
and dc.concept_code not in (select concept_code_1 from relationship_to_concept);

-- delete/update invalid suppliers
delete from aut_suppliers_mapped
where cast(concept_id_2 as int)
in (select concept_id from concept where invalid_reason = 'D');

update aut_suppliers_mapped aim
set concept_id_2 = c.concept_id_2
from (select concept_id_2,concept_id_1 
      from concept_relationship cr
      join concept c on c.concept_id = concept_id_1 and c.invalid_reason = 'U' and relationship_id = 'Concept replaced by' and cr.invalid_reason is null) c
where (cast(aim.concept_id_2 as int) = c.concept_id_1);

-- get the list of suppliers to map
create temp table aut_suppliers_to_map
as
  select *
  from drug_concept_stage
where lower(concept_name) not in
      (select lower(concept_name)
        from aut_suppliers_mapped
        )
and concept_code not in
    (select concept_code_1 from relationship_to_concept)
and concept_class_id = 'Supplier';

/****************************
*     7. POPULATE PC_STAGE   *
*****************************/

insert into pc_stage
select jmdc_drug_code, dcs.concept_code, quantity,null
from aut_pc_stage
  join drug_concept_stage dcs
   on dcs.concept_name = substr(ingredient||' '||dosage||' '||lower(form), 1, 255)
;

/****************************
*     8. POST-PROCESSING.   *
*****************************/

-- 7.1 Delete Suppliers where DF or strength doesn't exist
DELETE
	FROM internal_relationship_stage
			where concept_code_1 in
	 (
		SELECT concept_code_1
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Supplier'
		LEFT JOIN ds_stage ON drug_concept_code = concept_code_1
		WHERE drug_concept_code IS NULL

		UNION

		SELECT concept_code_1
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Supplier'
		WHERE concept_code_1 NOT IN (
				SELECT concept_code_1
				FROM internal_relationship_stage
				JOIN drug_concept_stage ON concept_code_2 = concept_code
					AND concept_class_id = 'Dose Form'
				)
		)
and concept_code_2 in
			(select concept_code from drug_concept_stage where concept_class_id = 'Supplier')
;
