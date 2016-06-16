--BN from drug_concept_stage

create table brand_name as(
select distinct initcap( brand_name) as brand_name,'Brand Name' as concept_class_id
from source_table
where upper(brand_name) 
not in (select upper(ingredient) from ingredient_translation_all) and domain_id='Drug');
delete brand_name where brand_name in ('Zink','Xylometazolin','Isopropylalkohol','Isopropanol','Vitamin E','Vitamin C','Citalopram','Vitamin B6','Vitamin B2','Vitamin B12','Vitamin B 12','Vitamin A',
'Trospium','Tramadol','Somatostatin','Metformin','Mianserin','Mesalmin','Gentamicin','Belladonna','Amlodipin','2- Propanol','5-Fluorouracil','Amiodaron','Apomorphin','Atorvastatin',
'Buprenorphine','Amitriptylin','Ambroxol','Benalapril','Faktor VIII','Epoprostenol','Meronem','Magnesium','Magnesiumsulfat','Leucovorin','Levocetirizin','Levofloxacin','Lactose');
delete brand_name where brand_name like '%Abnobaviscum%' or brand_name like '%/%' or brand_name like '%Glycerol%' or brand_name like '%Comp.%' or brand_name like '% Cum%' or brand_name='Mg'
and brand_name not like '%Pharma%' and brand_name not like '%Hexal%' and brand_name not like '%Mylan%' and brand_name not like '%Ratiopharm%' and brand_name not like '%Stada%'
and brand_name not like '%Jubilant%' and brand_name not like '%Zentiva%' and brand_name not like '%Sandoz%' and brand_name not like '% Heumann%' and brand_name not like '%Healthcare%' and brand_name not like '% Abz%' and brand_name not like '%Axcount%'
and brand_name not like '%Aristo%' and brand_name not like '%Krugmann%' and brand_name not like '%Eberth%' and brand_name not like '%Liconsa%' and brand_name not like '%Aurobindo%' and brand_name not like '%Basics%';

--drop table dsc_bn;
create table dcs_bn as (
select brand_name as concept_name,concept_class_id,'OMOP'||new_voc.nextval as concept_code
from brand_name);


--drugs for drug_concept_stage
create table dcs_drug as
(SELECT distinct a.drug_code as concept_code, 'Quant Drug' as concept_class_id, b.drug_name as concept_name from strength_tmp a
left join st_5 b on b.new_code=a.drug_code
WHERE b.new_code IS NOT NULL and b.box_size is null 
union
SELECT distinct a.drug_code as concept_code, 'Drug Box' as concept_class_id, b.drug_name as concept_name from strength_tmp a
left join st_5 b on b.new_code=a.drug_code
WHERE b.new_code IS NOT NULL and b.box_size is NOT null 
union
SELECT distinct enr as concept_code, 'Drug Pack' as concept_class_id, am||' [Drug Pack]' from source_table_pack
union
SELECT distinct a.drug_code as concept_code, 'Drug' as concept_class_id, st.am||' [Drug]' as concept_name from strength_tmp a
left join st_5 b on b.new_code=a.drug_code
left join source_table st on st.enr=a.drug_code
WHERE b.new_code IS NULL AND st.enr IS NOT NULL
union
SELECT distinct a.drug_code as concept_code, 'Drug' as concept_class_id, stp.am||' [Drug]' as concept_name from strength_tmp a
left join st_5 b on b.new_code=a.drug_code
left join source_table_pack stp on stp.drug_code=a.drug_code
WHERE b.new_code IS NULL AND stp.enr IS NOT NULL
);

--form for drug_concept_stage
create table forms as (
select distinct initcap(concept_name_1) as concept_name, 'Dose Form' as concept_class_id
from form_translation_all);
--drop table dcs_form;
create table dcs_form as (
select concept_name, concept_class_id,'OMOP'||new_voc.nextval as concept_code
from forms);


--unit for drug_concept_stage
create table unit as (
select distinct amount_unit from strength_tmp where amount_unit is not null union
select distinct numerator_unit from strength_tmp where numerator_unit  is not null union
select distinct denominator_unit from strength_tmp where denominator_unit is not null);

create table dcs_unit as(
select distinct amount_unit as concept_name, amount_unit as concept_code,'Unit' as concept_class_id
from unit where amount_unit is not null);

-- manufacturer for drug_concept_stage
--drop table dcs_manuf;
create table manuf as
(select  distinct 
TRIM(REGEXP_SUBSTR(ADRANTL , '[^,]+', 1, 2)) as concept_name, 
'Manufacturer' as concept_class_id
 from source_table) ;
 
 create table dcs_manuf as
(select  'OMOP'||new_voc.nextval as concept_code, 
 concept_name, 
 concept_class_id
 from manuf) ;
 
 
create table dcs_ingr as
(select distinct INGREDIENT_CODE as concept_code ,lower(TRANSLATION) as concept_name,'Ingredient' as concept_class_id from INGREDIENT_TRANSLATION_ALL);
 
--CONCEPT-STAGE CREATION
truncate table DRUG_concept_STAGE;
insert into DRUG_concept_STAGE (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,pack_size,domain_id,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct CONCEPT_NAME, 'AMIS', CONCEPT_CLASS_ID, '', CONCEPT_CODE, '', '','Drug', TO_DATE('2016/06/01', 'yyyy/mm/dd') as valid_start_date,
TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date, ''
 from 
(
select distinct CONCEPT_NAME,CONCEPT_CLASS_ID,cast (CONCEPT_CODE as varchar(255)) as concept_code from  dcs_unit
union 
select distinct CONCEPT_NAME,CONCEPT_CLASS_ID,cast (CONCEPT_CODE as varchar(255)) as concept_code from  dcs_form
union
select distinct CONCEPT_NAME,CONCEPT_CLASS_ID,CONCEPT_CODE from dcs_bn
union
select distinct CONCEPT_NAME,CONCEPT_CLASS_ID,CONCEPT_CODE from dcs_manuf
union
select distinct CONCEPT_NAME, CONCEPT_CLASS_ID, CONCEPT_CODE from dcs_drug
union
select distinct CONCEPT_NAME, CONCEPT_CLASS_ID, CONCEPT_CODE from dcs_ingr
union
select am||' [Drug Pack]' as concept_name, 'Drug Pack' as concept_class_id, concept_code from stp_2 JOIN source_table st ON st.enr=stp_2.enr
 );

MERGE
INTO    drug_concept_stage dcs
USING   (
select concept_name, concept_code from drug_concept_stage WHERE concept_class_id NOT IN ('Brand Name', 'Dose Form', 'Unit', 'Ingredient', 'Manufacturer') 
) d ON (d.concept_code=dcs.concept_code)
WHEN MATCHED THEN UPDATE
    SET dcs.standard_concept = 'S'
;
MERGE
INTO    drug_concept_stage dcs
USING   (
select concept_name, MIN(concept_code) m from drug_concept_stage WHERE concept_class_id='Ingredient' group by concept_name having count(concept_code) > 1
) d ON (d.m=dcs.concept_code)
WHEN MATCHED THEN UPDATE
    SET dcs.standard_concept = 'S'
;
