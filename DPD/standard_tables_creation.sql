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
* Authors: Anna Ostropolets, Dmitry Dimschitz, Christian Reich
* Date: April 2016
**************************************************************************/
--CREATING UNITED TABLES OUT 3 BATCHES THAT WE WERE GIVEN. AS DRUG_IDENTIFICATION_NUMBER IS UNIQUE WE USED IT INSTEAD OF DRUG CODE
create table drug_product as (
select drug_CODE as old_code,PRODUCT_CATEGORIZATION,CLASS,ltrim(DRUG_IDENTIFICATION_NUMBER,'0') as DRUG_CODE,BRAND_NAME,DESCRIPTOR,PEDIATRIC_FLAG,ACCESSION_NUMBER,NUMBER_OF_AIS,AI_GROUP_NO,
case when DRUG_IDENTIFICATION_NUMBER in (select DRUG_IDENTIFICATION_NUMBER from drug_product_ap) then 'A'
when DRUG_IDENTIFICATION_NUMBER in (select DRUG_IDENTIFICATION_NUMBER from drug_product_ia) then 'D' 
else null end as INVALID_REASON  
from (
select * from drug_product_ia 
union 
select * from drug_product_act
union 
select * from drug_product_ap)
)
;
insert into drug_product (drug_code, BRAND_NAME)
select ltrim(DIN_STD,'0'),PROD_DESC from additional_list 
WHERE ltrim(DIN_STD,'0') not in (
select drug_code from drug_product);
delete drug_product where drug_code in (
select concept_code from non_drug);
delete drug_product where rowid not in (
select min(rowid) from drug_product group by drug_code
)
;
CREATE TABLE ACTIVE_INGREDIENTS
(
   DRUG_CODE               VARCHAR2(200 Byte),
   ACTIVE_INGREDIENT_CODE  VARCHAR2(200 Byte),
   INGREDIENT              VARCHAR2(240 Byte),
   STRENGTH                VARCHAR2(20 Byte),
   STRENGTH_UNIT           VARCHAR2(40 Byte),
   STRENGTH_TYPE           VARCHAR2(40 Byte),
   DOSAGE_VALUE            VARCHAR2(20 Byte),
   DOSAGE_UNIT             VARCHAR2(40 Byte),
   NOTES                   VARCHAR2(2000 Byte)
)
TABLESPACE USERS;

insert into active_ingredients
 select b.drug_code, ACTIVE_INGREDIENT_CODE,INGREDIENT,STRENGTH,STRENGTH_UNIT,STRENGTH_TYPE,DOSAGE_VALUE,DOSAGE_UNIT,NOTES
 from (
 select * from active_ingredients_ap 
 union 
 select * from active_ingredients_ia 
 union 
 select * from active_ingredients_act) a 
 join drug_product b on old_code=a.drug_Code
;
delete  active_ingredients where drug_code in (
select concept_code from non_drug);

create table ingr_add_list as ( --just created this
SELECT ingredient, ltrim(DIN_STD,'0') as drug_code, 'A'||rownum as AIC, regexp_replace (strength,'(/)+(AMP|TAB|BLISTER|SPRAY|CAP|VIAL|SUP|SRT|SRC|LOZ|PCK|KIT|DOSE)') as strength from (
select distinct
trim(regexp_substr(t.MLCL_DESC, '[^\&\;]+', 1, levels.column_value))  as ingredient, DIN_STD,trim(regexp_substr(t.STRNT_DESC, '[^\&]+', 1, levels.column_value))  as strength,rownum
from additional_list t,
table(cast(multiset(select level from dual connect by  level <= length (regexp_replace(t.MLCL_DESC, '[^\&\;]+'))  + 1) as sys.OdciNumberList)) levels where t.DIN_STD not in (select drug_code from active_ingredients)) );
delete ingr_add_list where drug_code in (select drug_code from active_ingredients);

create table ingr_add_list_2 as(select case when  strength like '%/%' then regexp_substr (STRENGTH, '[[:digit:]]*(\.[[:digit:]]+)?') else null end as numerator_value  ,
case when  strength like '%/%' then regexp_substr (STRENGTH, '(MG|UNIT|X|GM|GM|ML|L|X|G|ACT|MCG|CM)',1,1)  else null end as numerator_unit,
case when  strength like '%/%' then regexp_substr (strength, '(MG|ML|ACT(s)*|GM|G|Kg|L|X|MCG|CM)$') else null end as denominator_unit,
case when  strength like '%/%' then  replace (regexp_substr (strength,'/[[:digit:]\.]*'), '/') else null end as denominator_value, 
case when  strength not like '%/%' then regexp_substr (STRENGTH, '[[:digit:]]*(\.[[:digit:]]+)?') else null end as amount_value, 
case when  strength not like '%/%' then regexp_replace (STRENGTH, '[[:digit:]]*(\.[[:digit:]]+)?') else null end as amount_unit, 
drug_code, ingredient,AIC,strength
from ingr_add_list); 
insert into active_ingredients (DRUG_CODE,ACTIVE_INGREDIENT_CODE,INGREDIENT,STRENGTH,STRENGTH_UNIT)
select DRUG_CODE,AIC,INGREDIENT,AMOUNT_VALUE,AMOUNT_UNIT from ingr_add_list_2 where amount_value is not null;
insert into active_ingredients (DRUG_CODE,ACTIVE_INGREDIENT_CODE,INGREDIENT,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
select DRUG_CODE,AIC,INGREDIENT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT from ingr_add_list_2 where amount_value is null;
delete active_ingredients where ingredient='x';
update active_ingredients set ingredient='SENNOSIDES B' where ingredient='B';

--UPDATING ACTIVE_INGREDIENTS TO REMOVE ORIGINAL TABLES INACCURACY
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH_UNIT = 'CH' WHERE DRUG_CODE = '876321' AND   INGREDIENT = 'ACETIC ACID';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH_UNIT = '%',       DOSAGE_VALUE = '' WHERE DRUG_CODE = '813613' AND   INGREDIENT = 'LIDOCAINE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '2.5',       STRENGTH_UNIT = '%' WHERE DRUG_CODE = '813613' AND   INGREDIENT = 'PRILOCAINE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH_UNIT = 'DH' WHERE DRUG_CODE = '672823' AND   INGREDIENT = 'ACONITE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH_UNIT = '%',      DOSAGE_VALUE = '' WHERE DRUG_CODE = '2243569' AND   INGREDIENT = 'CAMPHOR';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '5.71',       STRENGTH_UNIT = '%'WHERE DRUG_CODE = '2243569' AND   INGREDIENT = 'PHENOL'; 
UPDATE ACTIVE_INGREDIENTS  SET STRENGTH = '1.24',        STRENGTH_UNIT = '%' WHERE DRUG_CODE = '2243569' AND   INGREDIENT = 'MENTHOL';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '400',       STRENGTH_UNIT = 'MG',       DOSAGE_VALUE = '5',      DOSAGE_UNIT = 'ML' WHERE DRUG_CODE = '649643' AND   INGREDIENT = 'MAGNESIUM';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '400',       STRENGTH_UNIT = 'MG',      DOSAGE_VALUE = '5',     DOSAGE_UNIT = 'ML' WHERE DRUG_CODE = '649643' AND   INGREDIENT = 'SIMETHICONE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '200',       STRENGTH_UNIT = 'MG',       DOSAGE_VALUE = '5',       DOSAGE_UNIT = 'ML' WHERE DRUG_CODE = '2084732';
UPDATE ACTIVE_INGREDIENTS   SET DOSAGE_UNIT = 'G' WHERE DRUG_CODE = '2237089';
UPDATE ACTIVE_INGREDIENTS   SET DOSAGE_VALUE = '0.5',       DOSAGE_UNIT = 'ML' WHERE DRUG_CODE = '2239208';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '25',       STRENGTH_UNIT = 'MG',      DOSAGE_VALUE = '5',       DOSAGE_UNIT = 'ML' WHERE DRUG_CODE = '649643' AND   ACTIVE_INGREDIENT_CODE = 'A32477';
UPDATE ACTIVE_INGREDIENTS  SET STRENGTH = '400',      STRENGTH_UNIT = 'MG',       DOSAGE_VALUE = '5',       DOSAGE_UNIT = 'ML' WHERE DRUG_CODE = '649643' AND   ACTIVE_INGREDIENT_CODE = 'A6204';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '10.5' WHERE DRUG_CODE = '62812' AND INGREDIENT = 'CAPSICUM';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '5.95' WHERE DRUG_CODE = '190462' AND INGREDIENT = 'VERBASCUM THAPSUS';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '22' WHERE DRUG_CODE = '248207' AND INGREDIENT = 'SENNA';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '6410' WHERE DRUG_CODE = '464988' AND INGREDIENT = 'MODIFIED RAGWEED TYROSINE ADSORBATE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '1000' WHERE DRUG_CODE = '894400' AND INGREDIENT = 'VITAMIN C (CALCIUM ASCORBATE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '2.26' WHERE DRUG_CODE = '1900722' AND INGREDIENT = 'VITAMIN C (CALCIUM ASCORBATE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '1.25' WHERE DRUG_CODE = '2003856' AND INGREDIENT = 'LIDOCAINE HYDROCHLORIDE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '1.25' WHERE DRUG_CODE = '2003864' AND INGREDIENT = 'LIDOCAINE HYDROCHLORIDE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '2.23' WHERE DRUG_CODE = '634050' AND INGREDIENT = 'VITAMIN C (CALCIUM ASCORBATE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '40' WHERE DRUG_CODE = '695335' AND INGREDIENT = 'BICARBONATE (SODIUM BICARBONATE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '120' WHERE DRUG_CODE = '695335' AND INGREDIENT = 'SULFATE (SODIUM SULFATE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '20' WHERE DRUG_CODE = '695335' AND INGREDIENT = 'CHLORIDE (POTASSIUM CHLORIDE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '50' WHERE DRUG_CODE = '695335' AND INGREDIENT = 'CHLORIDE (SODIUM CHLORIDE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '2.26' WHERE DRUG_CODE = '662992' AND INGREDIENT = 'VITAMIN C (CALCIUM ASCORBATE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '1000' WHERE DRUG_CODE = '658707' AND INGREDIENT = 'VITAMIN C (CALCIUM ASCORBATE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '850' WHERE DRUG_CODE = '1983954' AND INGREDIENT = 'POTASSIUM (POTASSIUM PHOSPHATE DIBASIC)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '950' WHERE DRUG_CODE = '2014149' AND INGREDIENT = 'POTASSIUM (POTASSIUM PHOSPHATE DIBASIC)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '950' WHERE DRUG_CODE = '1991094' AND INGREDIENT = 'POTASSIUM (POTASSIUM PHOSPHATE DIBASIC)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '2.5' WHERE DRUG_CODE = '2023326' AND INGREDIENT = 'LIDOCAINE HYDROCHLORIDE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '242' WHERE DRUG_CODE = '2029731' AND INGREDIENT = 'BARBERRY ROOT';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '243' WHERE DRUG_CODE = '2029731' AND INGREDIENT = 'CITRULLUS COLOCYNTHIS';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '42' WHERE DRUG_CODE = '2030675' AND INGREDIENT = 'ALOE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '40' WHERE DRUG_CODE = '2030675' AND INGREDIENT = 'TORMENTILLA';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '41' WHERE DRUG_CODE = '2030675' AND INGREDIENT = 'RHUBARB';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '310' WHERE DRUG_CODE = '2035901' AND INGREDIENT = 'POTASSIUM (POTASSIUM PHOSPHATE DIBASIC)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '240' WHERE DRUG_CODE = '2065983' AND INGREDIENT = 'EUPHORBIA CYPARISSIAS';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '4.5' WHERE DRUG_CODE = '2009137' AND INGREDIENT = 'LIDOCAINE HYDROCHLORIDE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '160' WHERE DRUG_CODE = '2200724' AND INGREDIENT = 'POTASSIUM (POTASSIUM IODIDE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '650' WHERE DRUG_CODE = '2230209' AND INGREDIENT = 'POTASSIUM (POTASSIUM CHLORIDE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '160' WHERE DRUG_CODE = '2230429' AND INGREDIENT = 'IODINE (POTASSIUM IODIDE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '773' WHERE DRUG_CODE = '2231927' AND INGREDIENT = 'VITAMIN C (CALCIUM ASCORBATE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '0.635' WHERE DRUG_CODE = '2231064' AND INGREDIENT = 'TITANIUM DIOXIDE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '0.85' WHERE DRUG_CODE = '2231065' AND INGREDIENT = 'TITANIUM DIOXIDE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '4.15' WHERE DRUG_CODE = '2231065' AND INGREDIENT = 'OCTINOXATE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '1.05' WHERE DRUG_CODE = '2231066' AND INGREDIENT = 'TITANIUM DIOXIDE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '1.55' WHERE DRUG_CODE = '2231068' AND INGREDIENT = 'TITANIUM DIOXIDE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '21.3125' WHERE DRUG_CODE = '2276569' AND INGREDIENT = 'METHACHOLINE CHLORIDE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '31.0625' WHERE DRUG_CODE = '2276577' AND INGREDIENT = 'METHACHOLINE CHLORIDE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '52' WHERE DRUG_CODE = '2266121' AND INGREDIENT = 'DELTA-9-TETRAHYDROCANNABINOL (CANNABIS SATIVA EXTRACT)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '745' WHERE DRUG_CODE = '2242013' AND INGREDIENT = 'VITAMIN C (CALCIUM ASCORBATE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '950' WHERE DRUG_CODE = '2240814' AND INGREDIENT = 'CALCIUM (CALCIUM PHOSPHATE MONOBASIC)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '3100' WHERE DRUG_CODE = '2241327' AND INGREDIENT = 'MODIFIED GRASS TYROSINE ADSORBATE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '1440' WHERE DRUG_CODE = '2241328' AND INGREDIENT = 'MODIFIED TREE TYROSINE ADSORBATE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '5.75' WHERE DRUG_CODE = '2406365' AND INGREDIENT = 'OCTINOXATE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '10.39' WHERE DRUG_CODE = '2373793' AND INGREDIENT = 'SODIUM CHLORIDE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '100',       STRENGTH_UNIT = 'ML',       DOSAGE_VALUE = '100',       DOSAGE_UNIT = 'ML' WHERE DRUG_CODE = '2239576' AND   INGREDIENT = 'WATER';
UPDATE ACTIVE_INGREDIENTS   SET DOSAGE_VALUE = '0.5',       DOSAGE_UNIT = 'ML' WHERE DRUG_CODE = '2241047' AND   INGREDIENT = 'WATER';
UPDATE ACTIVE_INGREDIENTS   SET DOSAGE_VALUE = '14',       DOSAGE_UNIT = 'ML' WHERE DRUG_CODE = '2405024' AND   INGREDIENT = 'TRASTUZUMAB';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '200',       STRENGTH_UNIT = 'MG',       DOSAGE_VALUE = '5',       DOSAGE_UNIT = 'ML' WHERE DRUG_CODE = '569801' AND   INGREDIENT = 'MAGNESIUM';
UPDATE ACTIVE_INGREDIENTS   SET INGREDIENT = 'salicylic acid' WHERE DRUG_CODE = '2158671';
UPDATE ACTIVE_INGREDIENTS  SET STRENGTH = '263' WHERE DRUG_CODE = '776300' AND   INGREDIENT = 'VITAMIN C (POTASSIUM ASCORBATE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '4.26' WHERE DRUG_CODE = '776300' AND   INGREDIENT = 'VITAMIN C (ZINC ASCORBATE)';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '242' WHERE DRUG_CODE = '2073226' AND   INGREDIENT = 'PAPAVERINE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '13.25' WHERE DRUG_CODE = '2023326' AND   INGREDIENT = 'DEXTROSE';
UPDATE ACTIVE_INGREDIENTS   SET STRENGTH = '0.1',       STRENGTH_UNIT = '%' WHERE DRUG_CODE = '2023326' AND   INGREDIENT = 'EPINEPHRINE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '776300' AND   INGREDIENT = 'POTASSIUM (POTASSIUM ASCORBATE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '776300' AND   INGREDIENT = 'ZINC (ZINC ASCORBATE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2073226' AND   INGREDIENT = 'PAPAVERINE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2073226' AND   INGREDIENT = 'PAPAVERINE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2023326' AND   INGREDIENT = 'DEXTROSE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '62812' AND   INGREDIENT = 'CAPSICUM';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '190462' AND INGREDIENT = 'VERBASCUM THAPSUS';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '248207' AND INGREDIENT = 'SENNA';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '464988' AND INGREDIENT = 'MODIFIED RAGWEED TYROSINE ADSORBATE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '464988' AND INGREDIENT = 'MODIFIED RAGWEED TYROSINE ADSORBATE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '464988' AND INGREDIENT = 'MODIFIED RAGWEED TYROSINE ADSORBATE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '894400' AND INGREDIENT = 'CALCIUM (CALCIUM ASCORBATE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '1900722' AND INGREDIENT = 'CALCIUM (CALCIUM ASCORBATE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2003856' AND INGREDIENT = 'LIDOCAINE HYDROCHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2003864' AND INGREDIENT = 'LIDOCAINE HYDROCHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2003864' AND INGREDIENT = 'LIDOCAINE HYDROCHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '634050' AND INGREDIENT = 'CALCIUM (CALCIUM ASCORBATE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '695335' AND INGREDIENT = 'POTASSIUM (POTASSIUM CHLORIDE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '695335' AND INGREDIENT = 'SODIUM (SODIUM SULFATE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '695335' AND INGREDIENT = 'SODIUM (SODIUM BICARBONATE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '695335' AND INGREDIENT = 'SODIUM (SODIUM CHLORIDE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '711470' AND INGREDIENT = 'CALCIUM (CALCIUM ASCORBATE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '662992' AND INGREDIENT = 'CALCIUM (CALCIUM ASCORBATE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '658707' AND INGREDIENT = 'CALCIUM (CALCIUM ASCORBATE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '1983954' AND INGREDIENT = 'PHOSPHORUS (POTASSIUM PHOSPHATE DIBASIC)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2014149' AND INGREDIENT = 'PHOSPHORUS (POTASSIUM PHOSPHATE DIBASIC)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '1991094' AND INGREDIENT = 'PHOSPHORUS (POTASSIUM PHOSPHATE DIBASIC)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2023326' AND INGREDIENT = 'LIDOCAINE HYDROCHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2029731' AND INGREDIENT = 'BARBERRY ROOT';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2029731' AND INGREDIENT = 'BARBERRY ROOT';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2029731' AND INGREDIENT = 'BARBERRY ROOT';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2029731' AND INGREDIENT = 'CITRULLUS COLOCYNTHIS';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2029731' AND INGREDIENT = 'CITRULLUS COLOCYNTHIS';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2029731' AND INGREDIENT = 'CITRULLUS COLOCYNTHIS';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2030675' AND INGREDIENT = 'ALOE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2030675' AND INGREDIENT = 'ALOE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2030675' AND INGREDIENT = 'TORMENTILLA';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2030675' AND INGREDIENT = 'RHUBARB';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2030675' AND INGREDIENT = 'RHUBARB';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2035901' AND INGREDIENT = 'PHOSPHORUS (POTASSIUM PHOSPHATE DIBASIC)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2065983' AND INGREDIENT = 'EUPHORBIA CYPARISSIAS';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2065983' AND INGREDIENT = 'EUPHORBIA CYPARISSIAS';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2009137' AND INGREDIENT = 'LIDOCAINE HYDROCHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2009137' AND INGREDIENT = 'LIDOCAINE HYDROCHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2200724' AND INGREDIENT = 'IODINE (POTASSIUM IODIDE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2230209' AND INGREDIENT = 'CHLORINE (POTASSIUM CHLORIDE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2230429' AND INGREDIENT = 'POTASSIUM (POTASSIUM IODIDE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2231927' AND INGREDIENT = 'CALCIUM (CALCIUM ASCORBATE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2231064' AND INGREDIENT = 'TITANIUM DIOXIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2231065' AND INGREDIENT = 'TITANIUM DIOXIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2231066' AND INGREDIENT = 'OXYBENZONE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2231066' AND INGREDIENT = 'TITANIUM DIOXIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2231068' AND INGREDIENT = 'TITANIUM DIOXIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2276569' AND INGREDIENT = 'METHACHOLINE CHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2276569' AND INGREDIENT = 'METHACHOLINE CHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2276569' AND INGREDIENT = 'METHACHOLINE CHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2276569' AND INGREDIENT = 'METHACHOLINE CHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2276577' AND INGREDIENT = 'METHACHOLINE CHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2276577' AND INGREDIENT = 'METHACHOLINE CHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2276577' AND INGREDIENT = 'METHACHOLINE CHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2276577' AND INGREDIENT = 'METHACHOLINE CHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2276577' AND INGREDIENT = 'METHACHOLINE CHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2276577' AND INGREDIENT = 'METHACHOLINE CHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2276577' AND INGREDIENT = 'METHACHOLINE CHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2276577' AND INGREDIENT = 'METHACHOLINE CHLORIDE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2266121' AND INGREDIENT = 'CANNABIDIOL (CANNABIS SATIVA EXTRACT)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2242013' AND INGREDIENT = 'CALCIUM (CALCIUM ASCORBATE)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2240814' AND INGREDIENT = 'PHOSPHORUS (CALCIUM PHOSPHATE MONOBASIC)';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2241327' AND INGREDIENT = 'MODIFIED GRASS TYROSINE ADSORBATE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2241327' AND INGREDIENT = 'MODIFIED GRASS TYROSINE ADSORBATE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2241328' AND INGREDIENT = 'MODIFIED TREE TYROSINE ADSORBATE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2241328' AND INGREDIENT = 'MODIFIED TREE TYROSINE ADSORBATE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2406365' AND INGREDIENT = 'AVOBENZONE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2406365' AND INGREDIENT = 'OCTOCRYLENE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2406365' AND INGREDIENT = 'OCTINOXATE';
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2373793' AND INGREDIENT = 'SODIUM CHLORIDE';

--DELETING DUPLICATES
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2439042' AND   ACTIVE_INGREDIENT_CODE = 11564;
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2246512' AND   ACTIVE_INGREDIENT_CODE = 6487;
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2210614' AND   ACTIVE_INGREDIENT_CODE = 331;
DELETE FROM ACTIVE_INGREDIENTS WHERE DRUG_CODE = '2210622' AND   ACTIVE_INGREDIENT_CODE = 331;

create table route as(
select b.drug_code, ROUTE_OF_ADMINISTRATION from (
select * from route_ap 
union 
select * from route_ia 
union 
select * from route_act
) a join drug_product b on old_code=a.drug_Code);
delete route where drug_code in (select concept_code from non_drug)
;
create table form as(
select b.drug_code, PHARMACEUTICAL_FORM from (
select * from form_ap 
union 
select * from form_ia 
union 
select * from form_act
) a join drug_product b on old_code=a.drug_Code);
delete form where drug_code in (select concept_code from non_drug);
insert into form (drug_code, PHARMACEUTICAL_FORM)
select ltrim(DIN_STD,'0'),FORM_NM from additional_list WHERE ltrim(DIN_STD,'0') not in (select drug_code from drug_product)
;
create table packaging as( 
select b.DRUG_CODE,PACKAGE_SIZE_UNIT,PACKAGE_TYPE,PACKAGE_SIZE,PRODUCT_INFORMATION from (
select * from packaging_ap 
union 
select * from packaging_ia 
union 
select * from packaging_act
)a join drug_product b on old_code=a.drug_Code);
delete packaging  where drug_code in (select concept_code from non_drug);
insert into packaging (drug_code, PRODUCT_INFORMATION)
select ltrim(DIN_STD,'0'), PACK_DESC from additional_list WHERE ltrim(DIN_STD,'0') not in (select drug_code from drug_product)
;
create table status as( 
select b.drug_Code, STATUS,HISTORY_DATE,CURRENT_STATUS_FLAG from (
select * from status_ap 
union 
select * from status_ia 
union 
select * from status_act
)a join drug_product b on old_code=a.drug_Code);
delete status  where drug_code in (select concept_code from non_drug)
;
create table companies as( 
select b.drug_Code, MFR_CODE,COMPANY_CODE,COMPANY_NAME,COMPANY_TYPE,ADDRESS_MAILING_FLAG,ADDRESS_BILLING_FLAG,ADDRESS_NOTIFICATION_FLAG,ADDRESS_OTHER,SUITE_NUMBER,STREET_NAME,CITY_NAME,PROVINCE,COUNTRY,POSTAL_CODE,POST_OFFICE_BOX from (
select * from companies_ap 
union 
select * from companies_ia 
union 
select * from companies_act
)a join drug_product b on old_code=a.drug_Code);
delete companies  where drug_code in (select concept_code from non_drug)
;
create table therapeutic_class as(
select b.drug_Code, TC_ATC_NUMBER,TC_ATC,TC_AHFS_NUMBER,TC_AHFS  from(
select * from therapeutic_class_act
union
select * from therapeutic_class_ap
union
select * from therapeutic_class_ia
)a join drug_product b on old_code=a.drug_Code);
insert into therapeutic_class (DRUG_CODE,TC_ATC_NUMBER,TC_ATC)
select ltrim(DIN_STD,'0'),ATC4_CD,ATC4_DESC from additional_list  WHERE ltrim(DIN_STD,'0') not in (select drug_code from drug_product);

--INGREDIENTS
create table ingr as (select drug_CODE as concept_code, active_ingredient_Code as AIC, ingredient as concept_name, 
'Ingredient' as concept_class_id from active_ingredients);

--UPDATING INGREDIENTS IN ORDER TO DELETE ALL UNNECESSARY INFORMATION
update ingr
set  concept_name=regexp_replace (concept_name,' \(.*\)')
WHEre regexp_LIKE (concept_name,'\(.*\)$') 
and upper(concept_name) not like '%(%HUMAN)%'
and upper(concept_name) not like '%(%RABBIT)%'
and upper(concept_name) not like '%(%RECOMBINANT%)%'
and upper(concept_name) not like '%(%SYNTHETIC)%'
and upper(concept_name) not like '%(%ACTIVATED)%'
and upper(concept_name) not like '%(%OVINE)%'
and upper(concept_name) not like '%(%ANHYDROUS)%'
and upper(concept_name) not like '%VICTORIA%'
and upper(concept_name) not like '%YAMAGATA%' 
and upper(concept_name) not like '%(PMSG)%'
and upper(concept_name) not like '%(%H3N2)%'
and upper(concept_name) not like '%(%H1N1)%'
and upper(concept_name) not like '%(NPH)'
and upper(concept_name) not like '%(8)%'
and upper(concept_name) not like '%(V.C.O%)%'
and upper(concept_name) not like '%(D.C.O%)%'
and upper(concept_name) not like '%(FIM)%'
and upper(concept_name) not like '%(PRP-T)%'
and upper(concept_name) not like '%(FSH)%'
and upper(concept_name) not like '%(BCG)%'
and upper(concept_name) not like '%(R-METHUG-CSF)%'
and upper(concept_name) not like '%(MCT)%'
and upper(concept_name) not like '%(JERYL LYNN STRAIN)%'
and upper(concept_name) not like '%(EQUINE)%'
and upper(concept_name) not like '%(DILUENT)%'
and upper(concept_name) not like '%(WISTAR RA27/3 STRAIN)%'
and upper(concept_name) not like '%(EDMONSTON B STRAIN)%'
and upper(concept_name) not like '%(HAEMAGGLUTININ-STRAIN B%)%'
and concept_name not like '%(Neisseria meningitidis group B NZ98/254 strain)%'
and concept_name not like '%(2)%'
and concept_name not like '%(%DOLOMITE%)%'
and concept_name not like  '%(TUBERCULIN TINE TEST)%'
and concept_name not like '%(LEAVES)%'
and concept_name not like '%(ACETATE)'
and concept_name not like '%(KELP, POTASSIUM IODIDE)%'
and concept_name not like '%(TI 201)%'
and concept_name not like  '%[CU(MIB)4]BF4'
and concept_name not like  '%(ETHYLENEOXY)%'
and concept_name not like '%(CALCIFEROL)%'
and concept_name not like '%(MA HUANG)%'
and concept_name not like  '%(%BASIC)'
and concept_name not like '%(EXT.)%'
and concept_name not like '%(CALF)%'
and concept_name not like  '%(LIVER)%'
and concept_name not like  '%(PAW%'
and concept_name not like  '%(PORK)%';
update ingr
set  concept_name=regexp_replace (concept_name,' \(.*\)')
WHEre concept_name like '%(%BASIC%)' and concept_name not like '%(DIBASIC)' and concept_name not like '%(TRIBASIC)';
update ingr
set  concept_name=regexp_replace (concept_name,' \(.*\)') where concept_name like '%(%,%)%' and concept_code in (select concept_code from ingr_OMOP);

--CREATE TABLE WITH PRECISE NAME TAKEN FROM ORIGINAL TABLE TO USE LATER
create table ingr_OMOP as (select distinct  drug_CODE as concept_code, active_ingredient_Code as AIC, ingredient as concept_name, 
'Ingredient' as concept_class_id from active_ingredients);
update ingr_OMOP
set  concept_name=regexp_SUBSTR (concept_name,'\(.*\)')
WHEre  upper(concept_name) not like '%(%HUMAN)'
and upper(concept_name) not like '%(%RABBIT)'
and upper(concept_name) not like '%(%RECOMBINANT%)'
and upper(concept_name) not like '%(%SYNTHETIC)'
and upper(concept_name) not like '%(%ACTIVATED)'
and upper(concept_name) not like '%(%OVINE)'
and upper(concept_name) not like '%(%ANHYDROUS)'
and upper(concept_name) not like '%(%BASIC%)'
and upper(concept_name) not like '%VICTORIA%'
and upper(concept_name) not like '%YAMAGATA%'
and upper(concept_name) not like '%(PMSG)'
and upper(concept_name) not like '%(%H3N2)'
and upper(concept_name) not like '%(%H1N1)'
and upper(concept_name) not like '%(NPH)'
and upper(concept_name) not like '%(8)'
and upper(concept_name) not like '%(V.C.O%)%'
and upper(concept_name) not like '%(D.C.O%)%'
and upper(concept_name) not like '%(FIM)'
and upper(concept_name) not like '%(PRP-T)'
and upper(concept_name) not like '%(FSH)'
and upper(concept_name) not like '%(BCG)'
and upper(concept_name) not like '%(R-METHUG-CSF)'
and upper(concept_name) not like '%(MCT)'
and upper(concept_name) not like '%(JERYL LYNN STRAIN)'
and upper(concept_name) not like '%(EQUINE)'
and upper(concept_name) not like '%(DILUENT)'
and upper(concept_name) not like '%(WISTAR RA27/3 STRAIN)'
and upper(concept_name) not like '%(SACUBITRIL VALSARTAN SODIUM HYDRATE COMPLEX)'
and upper(concept_name) not like '%(EDMONSTON B STRAIN)'
and upper(concept_name) not like '%(HAEMAGGLUTININ-STRAIN B%)'
and concept_name not like '%(Neisseria meningitidis group B NZ98/254 strain)'
and concept_name not like '%(2)%'
and concept_name not like '%(%DOLOMITE%)%'
and concept_name not like  '%(TUBERCULIN TINE TEST)%'
and concept_name not like '%(%BONE MEAL%)%'
and concept_name not like '%(FISH OIL)%'
and concept_name not like '%(LEMON GRASS)%'
and concept_name not like '%(LEAVES)%'
and concept_name not like '%(ACETATE)'
and concept_name not like '%(%YEAST%)%'
and concept_name not like '%(KELP%)%'
and concept_name not like '%(TI 201)%'
and concept_name not like '%(COD LIVER OIL)%'
and concept_name not like  '%[CU(MIB)4]BF4'
and concept_name not like  '%(ETHYLENEOXY)%'
and concept_name not like  '%(PAPAYA)%'
and concept_name not like '%(CALCIFEROL)%'
and concept_name not like '%(MA HUANG)%'
and concept_name not like  '%(HORSETAIL)%'
and concept_name not like  '%(FLAXSEED)%'
and concept_name not like '%(EXT.)%'
and concept_name not like '%(ROTH)%'
and concept_name not like '%(CALF)%'
and concept_name not like '%(PINEAPPLE)%'
and concept_name not like  '%(LIVER)%'
and concept_name not like  '%(PAW%'
and concept_name not like  '%(PORK)%';
update ingr_OMOP
set  concept_name=regexp_SUBSTR (concept_name,'\(.*\)')  
where concept_name like '%(%BASIC%)' and concept_name not like '%(DIBASIC)' and concept_name not like '%(TRIBASIC)';
delete ingr_OMOP where concept_name is null;
delete ingr_OMOP where upper(concept_name) like '%(MCT)'
or upper(concept_name)  like '%(%HUMAN)'
or upper(concept_name)  like '%(%RABBIT)'
or upper(concept_name)  like '%(%RECOMBINANT%)'
or upper(concept_name)  like '%(%SYNTHETIC)'
or upper(concept_name)  like '%(%ACTIVATED)'
or upper(concept_name)  like '%(%OVINE)'
or upper(concept_name) like '%(%ANHYDROUS)'
or upper(concept_name)  like '%VICTORIA%'
or upper(concept_name)  like '%YAMAGATA%'
or upper(concept_name)  like '%(PMSG)'
or upper(concept_name)  like '%(%H3N2)'
or upper(concept_name)  like '%(%H1N1)'
or upper(concept_name)  like '%(NPH)'
or upper(concept_name)  like '%(8)'
or upper(concept_name) like '%(V.C.O%)%'
or upper(concept_name) like '%(D.C.O%)%'
or upper(concept_name) like '%(FIM)'
or upper(concept_name) like '%(PRP-T)'
or upper(concept_name) like '%(FSH)'
or upper(concept_name) like '%(BCG)'
or upper(concept_name) like '%(R-METHUG-CSF)'
or upper(concept_name) like '%(JERYL LYNN STRAIN)'
or upper(concept_name) like '%(EQUINE)'
or upper(concept_name) like '%(DILUENT)'
or upper(concept_name) like '%(WISTAR RA27/3 STRAIN)'
or upper(concept_name) like '%(SACUBITRIL VALSARTAN SODIUM HYDRATE COMPLEX)'
or upper(concept_name) like '%(EDMONSTON B STRAIN)'
or upper(concept_name) like '%(HAEMAGGLUTININ-STRAIN B%)'
or concept_name like '%(Neisseria meningitidis group B NZ98/254 strain)'
or concept_name like '%(2)%'
or concept_name like '%(%DOLOMITE%)%'
or concept_name like  '%(TUBERCULIN TINE TEST)%'
or concept_name like '%(BONE%'
or concept_name like '%(%OIL)%'
or concept_name like '%(LEMON GRASS)%'
or concept_name like '%(LEAVES)%'
or concept_name like '%(ACETATE)'
or concept_name like '%(%YEAST%)%'
or concept_name like '%(KELP%)%'
or concept_name like '%(TI 201)%'
or concept_name like '%(COD LIVER OIL)%'
or concept_name like  '%[CU(MIB)4]BF4'
or concept_name like  '%(ETHYLENEOXY)%'
or concept_name like  '%(PAPAYA)%'
or concept_name like '%(CALCIFEROL)%'
or concept_name like '%(MA HUANG)%'
or concept_name like  '%(HORSETAIL)%'
or concept_name like  '%(FLAXSEED)%'
or concept_name like '%(EXT.)%'
or concept_name like '%(ROTH)%'
or concept_name like '%(CALF)%'
or concept_name like '%(PINEAPPLE)%'
or concept_name like  '%(LIVER)%'
or concept_name like  '%(PAW%'
or concept_name like  '%(PORK)%';
update ingr_OMOP
set concept_name=regexp_replace (concept_name,'\(');
update ingr_OMOP
set concept_name=regexp_replace (concept_name,'\)');
delete ingr_OMOP where concept_name like '%OIL%';
delete ingr_OMOP where concept_name like '%EGG%';
delete ingr_OMOP where concept_name like '%BONE%';
delete ingr_OMOP where concept_name like '%CRYSTALS%';
delete ingr_OMOP where concept_name like '%,%' and concept_name not like '%KELP%';
delete ingr_OMOP where concept_name like '%ACEROLA%';
delete ingr_OMOP where concept_name like '%ROSE HIPS%';
delete ingr_OMOP where concept_name like '%BUCKWHEAT%';
delete ingr_OMOP where concept_name like '%1-PIPERIDYLTHIOCARBONYL%';
delete ingr_OMOP where concept_name like '%ALOE%';
delete ingr_OMOP where concept_name='D.C.O.';
delete ingr_OMOP where concept_name like '%VITAMIN%';
delete ingr_OMOP where concept_name='BCG';
delete ingr_OMOP where concept_name like '%SENNA%';
delete ingr_OMOP where concept_name like '%OYSTER%';
delete ingr_OMOP where concept_name like '%WHEAT%';
delete ingr_OMOP where concept_name='DEXTROSE';
delete ingr_OMOP where concept_name='EPHEDRA';
delete ingr_OMOP where concept_name='CIG';
delete ingr_OMOP where concept_name='BLACK CURRANT';
delete ingr_OMOP where concept_name='ATTENUAT. STRAIN SA14-14-2 PRODUCED IN VERO CELLS';
delete ingr_OMOP where concept_name='FEVERFEW';
delete ingr_OMOP where concept_name='EXTRACT';
delete ingr_OMOP where concept_name='H1N1V-LIKE STRAIN X-179A';
delete ingr_OMOP where concept_name='H5N1';
delete ingr_OMOP where concept_name='HOMEO';
delete ingr_OMOP where concept_name='III';
delete ingr_OMOP where concept_name='INS';
delete ingr_OMOP where concept_name='LIVER EXTRACT';
delete ingr_OMOP where concept_name='PRP';
delete ingr_OMOP where concept_name='NUTMEG';
delete ingr_OMOP where concept_name='RHPDGF-BB';
delete ingr_OMOP where concept_name='SAGO PALM';
delete ingr_OMOP where concept_name='SEA PROTEINATE';
delete ingr_OMOP where concept_name='SOYBEAN';
delete ingr_OMOP where concept_name='VIRIDANS AND NON-HEMOLYTIC';
delete ingr_OMOP where concept_name='PURIFIED CHICK EMBRYO CELL CULTURE';
delete ingr_OMOP where concept_name='DURAPATITE';
delete ingr_OMOP where concept_name='OXYCARBONATE';
delete ingr_OMOP where concept_name='BENZOTHIAZOLE' ;
delete ingr_OMOP where concept_name='BENZOTHIAZOLE' ;
delete ingr_OMOP where concept_name like '%ASPERGILLUS%';
delete ingr_OMOP where concept_name like '%ANANAS%';
delete ingr_OMOP where concept_name like '%BARLEY%';
delete ingr_OMOP where concept_name like '%BORAGO%';
delete ingr_OMOP where concept_name='MORPHOLINOTHIO';
delete ingr_OMOP where concept_name='OKA/MERCK STRAIN';
delete ingr_OMOP where concept_name like '%RHIZOPUS%';
delete ingr_OMOP where concept_name like '%DRIED%';
delete ingr_OMOP where concept_name='S';
DELETE FROM INGR_OMOP WHERE CONCEPT_CODE = '782971' AND   AIC = '10225' AND   CONCEPT_NAME = 'POVIDONE-IODINE';
DELETE FROM INGR_OMOP WHERE CONCEPT_CODE = '593710' AND   AIC = '105' AND   CONCEPT_NAME = 'MAGNESIUM OXIDE';
DELETE FROM INGR_OMOP WHERE CONCEPT_CODE = '94498' AND   AIC = '778' AND   CONCEPT_NAME = 'MAGNESIUM CITRATE';

--CREATING TABLE WITH FINAL INGREDIENT NAMES, ALSO WILL BE USED IN DRUG_STRENGTH_STAGE.PICN STANDS FOR PRECISE INGREDIENT CONCEPT NAME
create table ingr_2 as
select distinct a.concept_name as PICN,c.CONCEPT_CODE,c.AIC,c.CONCEPT_NAME,STRENGTH,STRENGTH_UNIT,
STRENGTH_TYPE,DOSAGE_VALUE,DOSAGE_UNIT,NOTES from ingr c join active_ingredients b on c.AIC=b.active_ingredient_code and b.drug_Code=c.concept_code 
left join ingr_OMOP a on a.AIC=c.AIC and a.concept_code=c.concept_code and  regexp_like(INGREDIENT,a.concept_name)
;
update ingr_2
set concept_name=PICN where PICN is not null;
update ingr_2
set  concept_name=regexp_replace (concept_name,' \(.*\)')
WHEre upper(concept_name) like '%(%,%)%' or upper(concept_name) like '%(DOLOMITE)%' or upper(concept_name) like '%(LIVER)%' or upper(concept_name) like '%(CALCIFEROL)%' or upper(concept_name) like '%(ACETATE)%';
update ingr_2 set dosage_unit='%' where strength_unit='%' and dosage_unit is null
;
--PARCING INGREDIENT 'ALUMINUM HYDROXIDE-MAGNESIUM CARBONATE-CO DRIED GEL' INTO TWO PARTS WITH RELATIVE DOSAGE
delete ingr_2 where aic='3980'; 
insert into ingr_2 (concept_code, AIC, concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (116882,3980,'ALUMINUM HYDROXIDE',184,'MG',10,'ML');
insert into ingr_2 (concept_code,AIC,concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (116882,3980,'MAGNESIUM CARBONATE',116,'MG',10,'ML');
insert into ingr_2 (concept_code, AIC, concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (13838,3980,'ALUMINUM HYDROXIDE',184,'MG',10,'ML');
insert into ingr_2 (concept_code,AIC,concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (13838,3980,'MAGNESIUM CARBONATE',116,'MG',10,'ML');
insert into ingr_2 (concept_code, AIC, concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (1988786	,3980,'ALUMINUM HYDROXIDE',184,'MG',10,'ML');
insert into ingr_2 (concept_code,AIC,concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (1988786	,3980,'MAGNESIUM CARBONATE',116,'MG',10,'ML');
insert into ingr_2 (concept_code, AIC, concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (2004046,3980,'ALUMINUM HYDROXIDE',184,'MG',10,'ML');
insert into ingr_2 (concept_code,AIC,concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (2004046,3980,'MAGNESIUM CARBONATE',116,'MG',10,'ML');
insert into ingr_2 (concept_code, AIC, concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (2124998,3980,'ALUMINUM HYDROXIDE',184,'MG',10,'ML');
insert into ingr_2 (concept_code,AIC,concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (2124998,3980,'MAGNESIUM CARBONATE',116,'MG',10,'ML');
insert into ingr_2 (concept_code, AIC, concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (2162318,3980,'ALUMINUM HYDROXIDE',184,'MG',10,'ML');
insert into ingr_2 (concept_code,AIC,concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (2162318,3980,'MAGNESIUM CARBONATE',116,'MG',10,'ML');
insert into ingr_2 (concept_code, AIC, concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (2162326,3980,'ALUMINUM HYDROXIDE',184,'MG',10,'ML');
insert into ingr_2 (concept_code,AIC,concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (2162326,3980,'MAGNESIUM CARBONATE',116,'MG',10,'ML');
insert into ingr_2 (concept_code, AIC, concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (407453,3980,'ALUMINUM HYDROXIDE',184,'MG',10,'ML');
insert into ingr_2 (concept_code,AIC,concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (407453,3980,'MAGNESIUM CARBONATE',116,'MG',10,'ML');
insert into ingr_2 (concept_code, AIC, concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (457310,3980,'ALUMINUM HYDROXIDE',184,'MG',10,'ML');
insert into ingr_2 (concept_code,AIC,concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (457310,3980,'MAGNESIUM CARBONATE',116,'MG',10,'ML');
insert into ingr_2 (concept_code, AIC, concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (649651,3980,'ALUMINUM HYDROXIDE',184,'MG',10,'ML');
insert into ingr_2 (concept_code,AIC,concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (649651,3980,'MAGNESIUM CARBONATE',116,'MG',10,'ML');
insert into ingr_2 (concept_code, AIC, concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (540846,3980,'ALUMINUM HYDROXIDE',184,'MG',10,'ML');
insert into ingr_2 (concept_code,AIC,concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (540846,3980,'MAGNESIUM CARBONATE',116,'MG',10,'ML');
insert into ingr_2 (concept_code, AIC, concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (478865,3980,'ALUMINUM HYDROXIDE',184,'MG',10,'ML');
insert into ingr_2 (concept_code,AIC,concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (478865,3980,'MAGNESIUM CARBONATE',116,'MG',10,'ML');
insert into ingr_2 (concept_code, AIC, concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (608521,3980,'ALUMINUM HYDROXIDE',184,'MG',10,'ML');
insert into ingr_2 (concept_code,AIC,concept_name,STRENGTH,STRENGTH_UNIT,DOSAGE_VALUE,DOSAGE_UNIT)
values (608521,3980,'MAGNESIUM CARBONATE',116,'MG',10,'ML');
UPDATE ingr_2    SET STRENGTH = '10' WHERE STRENGTH = ' 10' AND   STRENGTH_UNIT = '%' AND   DOSAGE_VALUE IS NULL AND   DOSAGE_UNIT = '%' AND   concept_CODE = '2229776';
UPDATE ingr_2    SET concept_name='SENNOSIDES B' where concept_name='B'; 
delete ingr_2 where concept_name='x';

--DELETING ALL PSEUDO-UNITS
update ingr_2
set strength_unit=null 
where STRENGTH_UNIT='NIL';
update ingr_2
set strength=null 
where STRENGTH='0';

update ingr_2
set dosage_unit=null where dosage_unit in ('TAB', 'CAP','BLISTER','LOZ','PCK','PIECE', 'SUP', 'ECT','NS','EVT','TSP','GUM','SRC','WAF','SRT','SUT','SLT','SRD','DOSE','DROP','SPRAY','VIAL', 'CARTRIDGE','INSERT',
'CARTRIDGE','INSERT','GUM','PAD' ,'PATCH' ,'PCK' ,'PEN' ,'SUT' ,'SYR' ,'TBS' ,'W/W','W/V','V/V','V/W','CYLR','ECT','IMP','SUP','JAR','SYR','SRT','PAIL','VTAB',
'CH','CAN','D','DH','EVT','ECC','ECT','XMK','X','CAP','LOZ','BLISTER','PIECE','WAF','SRC','TSP','SLT','NS','PAD','AMP','BOTTLE','TEA','KIT','STRIP','NIL','GM')
;
--TABLE WITH INGREDIENTS FOR DRUG_CONCEPT_STAGE
create table ingr_all as(
select distinct concept_name, 'Ingredient' as concept_class_id from ingr_2)
;
--FORMS
create table forms as (
select distinct ROUTE_OF_ADMINISTRATION||' '||PHARMACEUTICAL_FORM as concept_name, 
'Dose Form' as concept_class_id, drug_Code
from (
select a.DRUG_CODE,PHARMACEUTICAL_FORM,ROUTE_OF_ADMINISTRATION from form a 
left join route b on a.drug_code=b.drug_code 
where a.drug_code in (
select drug_Code from drug_product
)));
UPDATE FORMS SET CONCEPT_NAME = 'SOLUTION' WHERE CONCEPT_NAME = '0-UNASSIGNED SOLUTION' AND   CONCEPT_CLASS_ID = 'Dose Form';

--CREATING TABLES CONTAINING PAIRS OF DRUGS WITH THE SAME DRUG_CODE BUT DIFFERENT FORM. THESE DRUGS AREN'T REAL KITS SO WE ARE MAKING THEM OF ONE FORM
create table temp1 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='DROPS' and b.PHARMACEUTICAL_FORM='SUSPENSION');
create table temp2 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='DROPS' and b.PHARMACEUTICAL_FORM='LIQUID');
create table temp3 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='LOTION' and b.PHARMACEUTICAL_FORM='LIQUID');
create table temp4 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='SPRAY' and b.PHARMACEUTICAL_FORM='LIQUID');
create table temp5 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='METERED-DOSE AEROSOL' and b.PHARMACEUTICAL_FORM='LIQUID');
create table temp6 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='OINTMENT' and b.PHARMACEUTICAL_FORM='PAD');
create table temp8 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='SPRAY' and b.PHARMACEUTICAL_FORM='SUSPENSION');
create table temp9 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='ENEMA' and b.PHARMACEUTICAL_FORM='LIQUID');
create table temp11 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='LIQUID' and b.PHARMACEUTICAL_FORM='SOLUTION');
create table temp12 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='SUSPENSION' and b.PHARMACEUTICAL_FORM='SOLUTION');
create table temp13 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='METERED-DOSE AEROSOL' and b.PHARMACEUTICAL_FORM='POWDER');
create table temp14 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='KIT' and b.PHARMACEUTICAL_FORM='POWDER FOR SOLUTION');
create table temp15 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='KIT' and b.PHARMACEUTICAL_FORM='SOLUTION');
create table temp16 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='LIQUID' and b.PHARMACEUTICAL_FORM='POWDER FOR SOLUTION');
create table temp17 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='KIT' and b.PHARMACEUTICAL_FORM='LIQUID');
create table temp18 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='PACKAGE' and b.PHARMACEUTICAL_FORM='POWDER');
create table temp19 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='AEROSOL' and b.PHARMACEUTICAL_FORM='POWDER');
create table temp20 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='POWDER FOR SOLUTION' and b.PHARMACEUTICAL_FORM='PACKAGE');
create table temp21 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='LIQUID' and b.PHARMACEUTICAL_FORM='MOUTHWASH/GARGLE');
create table temp22 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='SOLUTION' and b.PHARMACEUTICAL_FORM='POWDER FOR SOLUTION');
create table temp23 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='LOTION' and b.PHARMACEUTICAL_FORM='KIT');
create table temp24 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='POWDER FOR SUSPENSION,SUSTAINED-RELEASE' and b.PHARMACEUTICAL_FORM='KIT');
create table temp25 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='SOLUTION' and b.PHARMACEUTICAL_FORM='MOUTHWASH/GARGLE');
create table temp26 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='KIT' and b.PHARMACEUTICAL_FORM='POWDER FOR SUSPENSION');
create table temp27 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='METERED-DOSE AEROSOL' and b.PHARMACEUTICAL_FORM='SUSPENSION');
create table temp29 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='METERED-DOSE AEROSOL' and b.PHARMACEUTICAL_FORM='SPRAY');
create table temp10 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='MOUTHWASH/GARGLE' and b.PHARMACEUTICAL_FORM='SOLUTION');
create table temp7 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='POWDER FOR SOLUTION' and b.PHARMACEUTICAL_FORM='AEROSOL');
create table temp30 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='POWDER' and b.PHARMACEUTICAL_FORM='LIQUID');
create table temp31 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='CREAM' and b.PHARMACEUTICAL_FORM='EMULSION');
create table temp32 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='CREAM' and b.PHARMACEUTICAL_FORM='JELLY');
create table temp33 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='TABLET (ENTERIC-COATED)' and b.PHARMACEUTICAL_FORM='TABLET (EXTENDED-RELEASE)');
create table temp34 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='TABLET' and b.PHARMACEUTICAL_FORM='TABLET (EXTENDED-RELEASE)');
create table temp35 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='SHAMPOO' and b.PHARMACEUTICAL_FORM='LIQUID');
create table temp36 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='OINTMENT' and b.PHARMACEUTICAL_FORM='LIQUID');
create table temp37 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='GEL' and b.PHARMACEUTICAL_FORM='TOOTHPASTE');
create table temp38 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='KIT' and b.PHARMACEUTICAL_FORM='POWDER');
create table temp39 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='PAD' and b.PHARMACEUTICAL_FORM='PLASTER');
create table temp40 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='GLOBULES' and b.PHARMACEUTICAL_FORM='TABLET');
create table temp41 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='GRANULES' and b.PHARMACEUTICAL_FORM='LIQUID');
create table temp42 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='GRANULES' and b.PHARMACEUTICAL_FORM='DROPS');
create table temp43 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='KIT' and b.PHARMACEUTICAL_FORM='CAPSULE');
create table temp44 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='KIT' and b.PHARMACEUTICAL_FORM='TABLET');
create table temp45 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='SUSPENSION' and b.PHARMACEUTICAL_FORM='POWDER');
create table temp46 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='TOOTHPASTE' and b.PHARMACEUTICAL_FORM='PASTE');
create table temp47 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='CREAM' and b.PHARMACEUTICAL_FORM='LIQUID');
create table temp48 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='CREAM' and b.PHARMACEUTICAL_FORM='LOTION');
create table temp50 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='CREAM' and b.PHARMACEUTICAL_FORM='OINTMENT');
create table temp49 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='GEL' and b.PHARMACEUTICAL_FORM='SHAMPOO');
create table temp51 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='GLOBULES' and b.PHARMACEUTICAL_FORM='GRANULES');
create table temp52 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='CAPSULE (IMMEDIATE RELEASE)' and b.PHARMACEUTICAL_FORM='CAPSULE (EXTENDED RELEASE)');
create table temp53 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='SUSPENSION' and b.PHARMACEUTICAL_FORM='CREAM');
create table temp54 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='TABLET (EXTENDED-RELEASE)' and b.PHARMACEUTICAL_FORM='TABLET (DELAYED-RELEASE)');
create table temp55 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='DROPS' and b.PHARMACEUTICAL_FORM='POWDER');
create table temp56 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='KIT' and b.PHARMACEUTICAL_FORM='POWDER FOR SUSPENSION, SUSTAINED-RELEASE');
create table temp57 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='ENEMA' and b.PHARMACEUTICAL_FORM='SUSPENSION');
create table temp58 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='WIPE' and b.PHARMACEUTICAL_FORM='CREAM');
create table temp59 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='METERED-DOSE AEROSOL' and b.PHARMACEUTICAL_FORM='SOLUTION');
create table temp60 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='TABLET (IMMEDIATE RELEASE)' and b.PHARMACEUTICAL_FORM='TABLET (EXTENDED-RELEASE)');
create table temp61 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='AEROSOL' and b.PHARMACEUTICAL_FORM='LOTION');
create table temp62 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='CREAM' and b.PHARMACEUTICAL_FORM='TOOTHPASTE');
create table temp63 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='SPRAY' and b.PHARMACEUTICAL_FORM='SOLUTION');
create table temp64 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='LIQUID' and b.PHARMACEUTICAL_FORM='SOAP BAR');
create table temp65 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='LOTION' and b.PHARMACEUTICAL_FORM='SOAP BAR');
create table temp66 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='GLOBULES' and b.PHARMACEUTICAL_FORM='DROPS');
create table temp67 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='SPRAY' and b.PHARMACEUTICAL_FORM='LOTION');
create table temp68 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='PACKAGE' and b.PHARMACEUTICAL_FORM='TEA (HERBAL)');
create table temp69 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='LIQUID' and b.PHARMACEUTICAL_FORM='GAS');
create table temp70 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='TINCTURE' and b.PHARMACEUTICAL_FORM='SPRAY');
create table temp71 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='SHAMPOO' and b.PHARMACEUTICAL_FORM='LOTION');
create table temp72 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='SPRAY' and b.PHARMACEUTICAL_FORM='DROPS');
create table temp73 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='SOLUTION' and b.PHARMACEUTICAL_FORM='SPONGE');
create table temp74 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='LIQUID' and b.PHARMACEUTICAL_FORM='SPONGE');
create table temp75 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='LIQUID' and b.PHARMACEUTICAL_FORM='PELLET');
create table temp76 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code where b.PHARMACEUTICAL_FORM='STICK');
create table temp77 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='IMPLANT' and b.PHARMACEUTICAL_FORM='KIT');
create table temp78 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='CREAM' and b.PHARMACEUTICAL_FORM='KIT');
create table temp79 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='GEL' and b.PHARMACEUTICAL_FORM='KIT');
create table temp80 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='LIQUID' and b.PHARMACEUTICAL_FORM='PAD');
create table temp81 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='SPRAY' and b.PHARMACEUTICAL_FORM='EMULSION');
create table temp82 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='SOAP BAR' and b.PHARMACEUTICAL_FORM='GEL');
create table temp83 (drug_code varchar (255) ); INSERT INTO TEMP83(  DRUG_CODE)VALUES(  '2231806'); INSERT INTO TEMP83(  DRUG_CODE)VALUES(  '2231807'); INSERT INTO TEMP83(  DRUG_CODE)VALUES(  '2231816'); INSERT INTO TEMP83(  DRUG_CODE)VALUES(  '2231817'); INSERT INTO TEMP83(  DRUG_CODE)VALUES(  '2231820');
INSERT INTO TEMP83(  DRUG_CODE)VALUES(  '2231822'); INSERT INTO TEMP83(  DRUG_CODE)VALUES(  '2231823'); INSERT INTO TEMP83(  DRUG_CODE)VALUES(  '2231826'); INSERT INTO TEMP83(  DRUG_CODE)VALUES(  '2231827'); INSERT INTO TEMP83(  DRUG_CODE)VALUES(  '2232001'); INSERT INTO TEMP83(  DRUG_CODE)VALUES(  '2232004');
create table temp84 (drug_code varchar (255) ); INSERT INTO TEMP84(  DRUG_CODE)VALUES(  '415820'); INSERT INTO TEMP84(  DRUG_CODE)VALUES(  '419087'); INSERT INTO TEMP84(  DRUG_CODE)VALUES(  '432172'); INSERT INTO TEMP84(  DRUG_CODE)VALUES(  '724491');
INSERT INTO TEMP84(  DRUG_CODE)VALUES(  '505900'); INSERT INTO TEMP84(  DRUG_CODE)VALUES(  '509159'); INSERT INTO TEMP84(  DRUG_CODE)VALUES(  '510874'); INSERT INTO TEMP84(  DRUG_CODE)VALUES(  '724041'); 
create table temp85 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='AEROSOL' and b.PHARMACEUTICAL_FORM='SHAMPOO');
create table temp86 as (select c.drug_code from drug_product c join form b on c.drug_code=b.drug_code join form a on c.drug_code=a.drug_code where a.PHARMACEUTICAL_FORM='LOTION' and b.PHARMACEUTICAL_FORM='GEL'); 

CREATE TABLE FORM_1 AS (
select case when drug_code in (select drug_code from temp1) then 'SUSPENSION'
when drug_code in (select drug_code from temp2) then 'SOLUTION'
when drug_code in (select drug_code from temp3) then 'LOTION'
when drug_code in (select drug_code from temp4) then 'SPRAY'
when drug_code in (select drug_code from temp5) then 'METERED-DOSE AEROSOL'
when drug_code in (select drug_code from temp6) then 'OINTMENT'
when drug_code in (select drug_code from temp8) then 'SUSPENSION'
when drug_code in (select drug_code from temp9) then 'ENEMA'
when drug_code in (select drug_code from temp10) then 'SOLUTION'
when drug_code in (select drug_code from temp11) then 'SOLUTION'
when drug_code in (select drug_code from temp12) then 'SUSPENSION'
when drug_code in (select drug_code from temp13) then 'METERED-DOSE AEROSOL'
when drug_code in (select drug_code from temp14) then 'SOLUTION'
when drug_code in (select drug_code from temp15) then 'SOLUTION'
when drug_code in (select drug_code from temp16) then 'SOLUTION'
when drug_code in (select drug_code from temp17) then 'SOLUTION'
when drug_code in (select drug_code from temp18) then 'POWDER'
when drug_code in (select drug_code from temp19) then 'AEROSOL'
when drug_code in (select drug_code from temp20) then 'SOLUTION'
when drug_code in (select drug_code from temp21) then 'SOLUTION'
when drug_code in (select drug_code from temp22) then 'SOLUTION'
when drug_code in (select drug_code from temp23) then 'LOTION'
when drug_code in (select drug_code from temp24) then 'SUSPENSION'
when drug_code in (select drug_code from temp25) then 'SOLUTION'
when drug_code in (select drug_code from temp26) then 'SUSPENSION'
when drug_code in (select drug_code from temp27) then 'METERED-DOSE AEROSOL'
when drug_code in (select drug_code from temp29) then 'METERED-DOSE AEROSOL'
when drug_code in (select drug_code from temp30) then 'SOLUTION'
when drug_code in (select drug_code from temp31) then 'CREAM' 
when drug_code in (select drug_code from temp32) then 'CREAM' 
when drug_code in (select drug_code from temp33) then 'TABLET (EXTENDED-RELEASE)'
when drug_code in (select drug_code from temp34) then 'TABLET (EXTENDED-RELEASE)'
when drug_code in (select drug_code from temp7) then 'AEROSOL'
when drug_code in (select drug_code from temp35) then 'TOPICAL SOLUTION'
when drug_code in (select drug_code from temp36) then 'SOLUTION'
when drug_code in (select drug_code from temp37) then 'GEL'
when drug_code in (select drug_code from temp38) then 'SOLUTION'
when drug_code in (select drug_code from temp41) then 'SOLUTION'
when drug_code in (select drug_code from temp40) then 'TABLET'
when drug_code in (select drug_code from temp39) then 'PATCH'
when drug_code in (select drug_code from temp42) then 'SOLUTION'
when drug_code in (select drug_code from temp43) then 'CAPSULE'
when drug_code in (select drug_code from temp44) then 'TABLET'
when drug_code in (select drug_code from temp45) then 'SUSPENSION'
when drug_code in (select drug_code from temp46) then 'TOOTHPASTE'
when drug_code in (select drug_code from temp47) then 'CREAM' 
when drug_code in (select drug_code from temp48) then 'CREAM'
when drug_code in (select drug_code from temp49) then 'SHAMPOO'  
when drug_code in (select drug_code from temp51) then 'GRANULES' 
when drug_code in (select drug_code from temp50) then 'CREAM' 
when drug_code in (select drug_code from temp52) then 'CAPSULE' 
when drug_code in (select drug_code from temp53) then 'CREAM' 
when drug_code in (select drug_code from temp54) then 'TABLET'
when drug_code in (select drug_code from temp55) then 'SOLUTION'
when drug_code in (select drug_code from temp56) then 'SUSPENSION'
when drug_code in (select drug_code from temp57) then 'SUSPENSION' 
when drug_code in (select drug_code from temp58) then 'CREAM' 
when drug_code in (select drug_code from temp59) then 'METERED-DOSE AEROSOL'
when drug_code in (select drug_code from temp60) then 'TABLET'
when drug_code in (select drug_code from temp61) then 'LOTION'
when drug_code in (select drug_code from temp62) then 'TOOTHPASTE'
when drug_code in (select drug_code from temp63) then 'SPRAY'
when drug_code in (select drug_code from temp64) then 'LIQUID SOAP'
when drug_code in (select drug_code from temp65) then 'LOTION'
when drug_code in (select drug_code from temp66) then 'SOLUTION'
when drug_code in (select drug_code from temp67) then 'SPRAY'
when drug_code in (select drug_code from temp68) then 'TEA'
when drug_code in (select drug_code from temp69) then 'GAS'
when drug_code in (select drug_code from temp70) then 'SPRAY'
when drug_code in (select drug_code from temp71) then 'SHAMPOO'
when drug_code in (select drug_code from temp72) then 'SPRAY'
when drug_code in (select drug_code from temp73) then 'SOLUTION'
when drug_code in (select drug_code from temp74) then 'SOLUTION'
when drug_code in (select drug_code from temp75) then 'SOLUTION'
when drug_code in (select drug_code from temp76) then 'GEL'
when drug_code in (select drug_code from temp77) then 'IMPLANT'
when drug_code in (select drug_code from temp78) then 'CREAM'
when drug_code in (select drug_code from temp79) then 'GEL'
when drug_code in (select drug_code from temp80) then 'SOLUTION'
when drug_code in (select drug_code from temp81) then 'SPRAY'
when drug_code in (select drug_code from temp82) then 'SOAP'
when drug_code in (select drug_code from temp83) then 'TABLET'
when drug_code in (select drug_code from temp84) then 'SOLUTION'
when drug_code in (select drug_code from temp85) then 'SHAMPOO'
when drug_code in (select drug_code from temp86) then 'LOTION'
else PHARMACEUTICAL_FORM end as PHARMACEUTICAL_FORM, drug_code
from form)
;
create table ff2 as (
select new_form, drug_code from (
select distinct listagg (concept_name, '/') WITHIN GROUP (ORDER BY concept_name) OVER (PARTITION BY drug_code ) as form_comb, drug_Code from 
(select distinct r.ROUTE_OF_ADMINISTRATION||' '||a.PHARMACEUTICAL_FORM as concept_name, a.drug_Code from form_1 a
 join route r on r.drug_code=a.drug_Code 
 where a.drug_Code in (
 select r.drug_Code from route group by r.drug_Code having count(1)>1)
 and a.drug_code not in (select drug_code from new_pack)
 )
 ) f 
join new_form n on n.form_Comb=f.form_Comb
)
;
update form_1 a
set PHARMACEUTICAL_FORM=(select new_form from ff2 b where b.drug_code = a.drug_code) where exists (select new_form from ff2 b where b.drug_code = a.drug_code) 
;
create table form_2 as (
select case when drug_code in (select drug_code from additional_list) or drug_code in (select drug_code from ff2) then PHARMACEUTICAL_FORM else ROUTE_OF_ADMINISTRATION||' '||PHARMACEUTICAL_FORM end as PHARMACEUTICAL_FORM, 
drug_code
from (
select  a.DRUG_CODE, ROUTE_OF_ADMINISTRATION, PHARMACEUTICAL_FORM from form_1 a 
left join route b on a.drug_code=b.drug_code
) 
);
UPDATE FORM_2 SET PHARMACEUTICAL_FORM = 'SOLUTION' WHERE PHARMACEUTICAL_FORM = '0-UNASSIGNED SOLUTION';

--TABLE WITH FORMS FOR DRUG_CONCEPT_STAGE
create table forms_v2 as (
select distinct PHARMACEUTICAL_FORM as concept_name, 'Dose Form' as concept_class_id from form_2 where PHARMACEUTICAL_FORM is not null
)
;
--TABLE WITH UNITS FOR DRUG_CONCEPT_STAGE
CREATE TABLE UNIT AS (
SELECT distinct upper(strength_unit) AS concept_name, upper(strength_unit)  as concept_CODE, 'Unit' as concept_class_id
FROM ACTIVE_INGREDIENTS where strength_unit is not null);
insert into unit (concept_name,concept_CODE, concept_class_id)
values ('SQ CM','SQ CM', 'Unit');
insert into unit (concept_name,concept_CODE, concept_class_id)
values ('L','L', 'Unit');
insert into unit (concept_name,concept_CODE, concept_class_id)
values ('HOUR','HOUR', 'Unit');
insert into unit (concept_name,concept_CODE, concept_class_id)
values ('CC','CC', 'Unit');
insert into unit (concept_name,concept_CODE, concept_class_id)
values ('CM','CM', 'Unit');
insert into unit (concept_name,concept_CODE, concept_class_id)
values ('GM','GM', 'Unit');
insert into unit (concept_name,concept_CODE, concept_class_id)
values ('ACT','ACT', 'Unit');

--TABLE WITH BRAND NAMES FOR DRUG_CONCEPT_STAGE
create table brand_v3 as (
select distinct concept_name, concept_class_id from brand_v2
)
;
--BRANDED DRUGS
create table Branded_Drug_p1 as (select distinct
a.brand_name as concept_name, case when  a.drug_code in (select drug_code from new_pack)  then 'Branded Pack' 
when d.dosage_value is not null then 'Quant Branded Drug'  else 'Branded Drug'  end as concept_class_id, a.drug_code as concept_code 
from drug_product a
join  active_ingredients d on d.drug_code = a.drug_Code
left join  form c on a.drug_code = c.drug_code 
where a.drug_code in (select drug_code from brand_v2))
;
--ADDING FORM TO BRANDED DRUG NAME TO AVOID SAME BRAND NAME - BRANDED DRUG NAME PAIRS
UPDATE BRANDED_DRUG_P1    SET CONCEPT_NAME = 'TARO-CARBAMAZEPINE SUSPENSION' WHERE CONCEPT_NAME = 'TARO-CARBAMAZEPINE' AND   CONCEPT_CLASS_ID = 'Quant Branded Drug' AND   CONCEPT_CODE = '2367394';
UPDATE BRANDED_DRUG_P1   SET CONCEPT_NAME = 'TARO-CARBAMAZEPINE TABLET' WHERE CONCEPT_NAME = 'TARO-CARBAMAZEPINE' AND   CONCEPT_CLASS_ID = 'Branded Drug' AND   CONCEPT_CODE = '2407515';
UPDATE BRANDED_DRUG_P1   SET CONCEPT_NAME = 'CYSTADANE POWDER FOR SOLUTION' WHERE CONCEPT_NAME = 'CYSTADANE' AND   CONCEPT_CLASS_ID = 'Quant Branded Drug' AND   CONCEPT_CODE = '2238526';

--CREATE BRANDED DRUGS THAT ARE PRESENTED IN ORIGINAL TABLES IN PACKS
create table branded_drug_p2 as 
(select distinct a.concept_name, case when DENOMINATOR_VALUE is not null then 'Quant Branded Drug' else 'Branded Drug' end 
as concept_class_id, concept_code from new_pack a join brand_v2 b on a.concept_code=b.drug_code )
;
--CLINICAL DRUG
create table CLINICal_Drug as (
select distinct a.brand_name||' '||c.PHARMACEUTICAL_FORM as concept_name, a.drug_code as concept_code, 
case when dosage_value is not null then 'Quant Clinical Drug'  else  'Clinical Drug'  end as concept_class_id
from drug_product a
join  active_ingredients d on d.drug_code = a.drug_Code
left join  form_2 c on a.drug_code = c.drug_code 
where a.drug_code not in (
select concept_Code from branded_drug_p1 
union 
select concept_code from branded_drug_p2)
)
;
--DRUG MANUFACTURER
drop table manufacturer;
create table manufacturer as (
select distinct COMPANY_NAME  as concept_name,'Manufacturer' as concept_class_id from companies
)
;
create table DRUG_concept_STAGE (
concept_name	varchar(255),
vocabulary_id	varchar(20),
concept_class_id	varchar(25),
standard_concept	varchar(1),
concept_code	varchar(50),
possible_excipient	varchar(1),
pack_size varchar (25),
domain_id  varchar (25),
valid_start_date	date,
valid_end_date	date,
invalid_reason	varchar(1)
)
;
--SEQUENCE FOR OMOP-GENERATED CODES STARTING WITH THE LAST CODE USED IN PREVIOUS VOCABULARY
create sequence conc_stage_seq 
  MINVALUE 97124
  MAXVALUE 1000000
  START WITH 97124
  INCREMENT BY 1
  CACHE 20;
  ;
--TABLE WITH OMOP-GENERATED CODES
create table list_temp as (
select a.*, conc_stage_seq.NEXTVAL as concept_code from ( select * from 
(select concept_name,concept_class_id from ingr_all where concept_name is not null
union 
select concept_name,concept_class_id from brand_v3 where concept_name is not null
union 
select concept_name,concept_class_id from forms_v2 where concept_name is not null
union
select concept_name,concept_class_id from branded_drug_p2 where concept_name is not null
union
select concept_name,concept_class_id from manufacturer where concept_name is not null)) a)
;
--CONCEPT-STAGE CREATION
insert into DRUG_concept_STAGE (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,pack_size,domain_id,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct CONCEPT_NAME, 'DPD', CONCEPT_CLASS_ID, '', CONCEPT_CODE, '', '','Drug', TO_DATE('2015/12/12', 'yyyy/mm/dd') as valid_start_date,
TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date, ''
 from 
(
select distinct CONCEPT_NAME,CONCEPT_CLASS_ID,cast (CONCEPT_CODE as varchar(255)) as concept_code from  Branded_drug_p1
union 
select distinct CONCEPT_NAME,CONCEPT_CLASS_ID,cast (CONCEPT_CODE as varchar(255)) as concept_code from  CLINICAL_drug
union
select distinct CONCEPT_NAME,CONCEPT_CLASS_ID,CONCEPT_CODE from unit
union
select distinct CONCEPT_NAME, CONCEPT_CLASS_ID, 'OMOP'||CONCEPT_CODE from list_temp --ADD 'OMOP' to all OMOP-generated concepts
 );
 --FLAG INDICATING INERT INGREDIENTS 
update drug_Concept_stage
set POSSIBLE_EXCIPIENT=1 where upper(concept_name)='WATER' or upper(concept_name)='NEON';

--UPDATING VALID DATES USING INFO IN ORIGINAL TABLES
create table dates as (
select distinct d.DRUG_CODE, valid_date  from drug_product d join 
(
select min(HISTORY_DATE) as valid_date , drug_code from status group by drug_code
) a on a.drug_code = d.old_code
)
;
update drug_concept_stage a 
set VALID_START_DATE=(select valid_date from dates b where a.concept_code = b.drug_code);
update drug_concept_stage 
set VALID_START_DATE= TO_DATE('1970/01/01', 'yyyy/mm/dd') where valid_start_date is null;
update drug_concept_stage 
set concept_class_id = replace (concept_class_id , 'Quant ') 
WHERe  CONCEPT_CODE IN (
select A.CONCEPT_CODE from drug_concept_stage a 
join  drug_strength_stage s on a.concept_code = s.drug_concept_code and a.concept_class_id like '%Quant%' and (s.DENOMINATOR_VALUE is null or NUMERATOR_VALUE is null)
);
delete drug_concept_stage where concept_name='NIL';

create table DTB1 as (
select distinct a.concept_code, a.concept_name  from dRUG_concept_stage a 
where concept_class_id='Branded Drug' or concept_class_id='Quant Branded Drug' or concept_class_id='Branded Pack');
create table DTB2 as (
select distinct a.concept_code, a.concept_name, b.drug_code from dRUG_concept_stage a 
join brand_v2 b on b.concept_name = a.concept_name
where a.concept_class_id = 'Brand Name' )
;
create table drug_to_brnd_name as (
select distinct
a.concept_code as CONCEPT_CODE_1,  b.concept_code as  CONCEPT_CODE_2
from DTB1 a join
DTB2 b
on b.drug_Code=a.concept_code)
;
create table pack_to_brnd_name as (select distinct a.concept_code as concept_code_1, d.concept_code as concept_code_2 from dRUG_concept_stage a 
join branded_drug_p2 b on b.concept_name=a.concept_name 
join brand_v2 c on c.drug_code=b.concept_code 
join drug_concept_stage d on d.concept_name=c.concept_name 
where a.concept_class_id like '%Branded Drug' and d.concept_class_id='Brand Name');

--drug_to_form
create table drug_to_form as (select 
distinct  a.concept_code as drug_code,  b.concept_code as Form_code 
from drug_concept_stage a --drugs
join  form_2 r on a.concept_Code=cast (r.drug_code as varchar (255))
join drug_concept_stage b on r.pharmaceutical_form= b.concept_name
where a.concept_class_id like '%Drug%'
and b.concept_class_id = 'Dose Form')
;
create table DP_to_form as (
select distinct b.concept_code as concept_code_1, a.concept_code as concept_code_2
from pack_form f
join drug_concept_stage a on f.form_name=a.concept_name 
join drug_concept_stage b on b.concept_name=f.concept_name
where a.concept_class_id='Dose Form'
and b.concept_class_id like '%Branded Drug'
)
;
create table Drug_to_ingr_temp as(
select distinct a.concept_code, a.concept_name, b.concept_code as drug_code 
from DRUG_concept_STAGE a 
join ingr_2 b on a.concept_name=b.concept_name
where a.concept_class_id='Ingredient'
)
;
create table drug_to_ingr as(
select distinct 
a.concept_code as CONCEPT_CODE_2,  b.drug_code as  CONCEPT_CODE_1
from Drug_to_ingr_temp a
join active_ingredients b on b.drug_Code=a.drug_code  
where b.drug_code not in (select drug_code from new_pack)
)
;
CREATE TABLE pack_for_DSS as (
select distinct a.*, b.concept_Code as  DRUG_CONCEPT_CODE , c.concept_Code as  INGREDIENT_CONCEPT_CODE from new_pack a 
join drug_concept_stage b on b.concept_name=a.concept_name 
join drug_concept_stage c on c.concept_name=a.ingredient
where b.concept_class_id like '%Drug' 
and c.concept_class_id='Ingredient'
)
;
create table pack_to_ingr as (
select distinct drug_concept_code as concept_code_1,INGREDIENT_CONCEPT_CODE as concept_code_2 from pack_for_DSS
)
;
create table quant_to_drg_1 as (
select distinct a.concept_code AS concept_code_1, b.concept_code as concept_code_2
from drug_concept_stage a join
drug_concept_stage b
on a.concept_class_id LIKE '%Quant Clin%' and b.concept_class_id LIKE  'Clinical Drug%' 
join ACTIVE_INGREDIENTS c on a.concept_code = cast(c.drug_code as varchar(255))
join ACTIVE_INGREDIENTS d on b.concept_code = cast(d.drug_code as varchar(255))
and d.ACTIVE_INGREDIENT_CODE = c.ACTIVE_INGREDIENT_CODE
and d.STRENGTH = c.STRENGTH
and d.STRENGTH_UNIT = c.STRENGTH_UNIT
join form_2 f on a.concept_code = cast(f.drug_code as varchar(255))
join form_2 e on b.concept_code = cast(e.drug_code as varchar(255))
and e.PHARMACEUTICAL_FORM=f.PHARMACEUTICAL_FORM
)
;
create table quant_to_drg_2 as (
select  distinct a.concept_code AS concept_code_1, b.concept_code as concept_code_2
from drug_concept_stage a join
drug_concept_stage b
on a.concept_class_id LIKE '%Quant Brand%' and b.concept_class_id LIKE  'Branded Drug%' 
join ACTIVE_INGREDIENTS c on a.concept_code = cast(c.drug_code as varchar(255))
join ACTIVE_INGREDIENTS d on b.concept_code = cast(d.drug_code as varchar(255))
and d.ACTIVE_INGREDIENT_CODE = c.ACTIVE_INGREDIENT_CODE
and d.STRENGTH = c.STRENGTH
and d.STRENGTH_UNIT = c.STRENGTH_UNIT
join form_2 f on a.concept_code = cast(f.drug_code as varchar(255))
join form_2 e on b.concept_code = cast(e.drug_code as varchar(255))
and e.PHARMACEUTICAL_FORM=f.PHARMACEUTICAL_FORM
join drug_to_brnd_name z on a.concept_code=z.concept_code_1 
join drug_to_brnd_name y  on b.concept_code=y.concept_code_1 
where z.concept_code_2=y.concept_code_2
)
;
create table quant_to_drg as (
select  * from quant_to_drg_1
union
select  * from quant_to_drg_2)
;
drop table comp_to_drug ;
create table comp_to_drug as(
select distinct a.concept_code as concept_code_2, n.drug_code as concept_code_1
from drug_concept_stage a 
join companies n on n.COMPANY_NAME=a.concept_name 
where a.concept_class_id='Manufacturer'
)
;
--INTERNAL RELATIONSHIP
create table internal_relationship_stage
(
CONCEPT_CODE_1		VARCHAR2 (255 Byte),
VOCABULARY_ID_1		VARCHAR2 (20 Byte),
CONCEPT_CODE_2	   	VARCHAR2 (255 Byte),
VOCABULARY_ID_2   VARCHAR2 (20 Byte)
)
;
insert into  internal_relationship_stage 
(CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_CODE_2,VOCABULARY_ID_2)
select concept_code_1, 'DPD' as VOCABULARY_ID_1, CONCEPT_CODE_2,'DPD' as VOCABULARY_ID_2
from 
(select distinct * from quant_to_drg union
select distinct cast(concept_code_1 as varchar (255)) as concept_code_1,cast(concept_code_2 as varchar (255)) as concept_code_2 from drug_to_ingr union
select distinct  drug_code as concept_code_1,form_code as concept_Code_2 from drug_to_form union
select  distinct * from drug_to_brnd_name union
select  distinct * from pack_to_ingr union
select  distinct * from pack_to_brnd_name union
select  distinct concept_code_1,concept_code_2 from DP_to_form union
select   distinct  concept_code_1,cast(concept_code_2 as varchar (255)) as concept_code_2 from comp_to_drug )
;
delete drug_concept_stage where concept_code in (select distinct concept_code from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2 where a.concept_class_id= 'Dose Form' and b.concept_code_1 is null)
;
update drug_concept_stage
set CONCEPT_CLASS_ID = CONCEPT_CLASS_ID||' Comp' 
where concept_code in (select distinct concept_code  from drug_concept_stage where concept_class_id like '%Drug%' and concept_class_id not like '%Comp%' and concept_code not in(
select a.concept_code from  drug_concept_stage a 
join internal_relationship_stage s on s.concept_code_1= a.concept_code  
join drug_concept_stage b on b.concept_code = s.concept_code_2
 and  a.concept_class_id like '%Drug%' and a.concept_class_id not like '%Comp%' and b.concept_class_id ='Dose Form'
))
;
--DRUG_STRENGTH
CREATE TABLE DRUG_STRENGTH_stage
(
   DRUG_CONCEPT_CODE        VARCHAR2(255 Byte),
   INGREDIENT_CONCEPT_CODE  VARCHAR2(255 Byte),
   BOX_SIZE                 INTEGER,
   AMOUNT_VALUE             FLOAT(126),
   AMOUNT_UNIT              VARCHAR2(255 Byte),
   NUMERATOR_VALUE          FLOAT(126),
   NUMERATOR_UNIT           VARCHAR2(255 Byte),
   DENOMINATOR_VALUE        FLOAT(126),
   DENOMINATOR_UNIT         VARCHAR2(255 Byte)
)
;
create table DS_0 as (
select distinct STRENGTH, STRENGTH_unit,dosage_value, DOSAGE_UNIT, d.concept_code as drug_Code, e.concept_code from ingr_2 d 
join drug_concept_stage e on d.concept_name=e.concept_name 
where e.concept_class_id='Ingredient')
;
insert into drug_strength_stage (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
select distinct drug_code, concept_code, case when dosage_unit is null and strength_unit!='%' then cast(strength as float (126)) else null end as AMOUNT_VALUE,
case when dosage_unit is null and strength_unit!='%' then strength_unit else null end as AMOUNT_unit,
case when dosage_unit is not null or strength_unit='%'  then cast(strength as float (126)) else null end as NUMERATOR_VALUE,
case when dosage_unit  is not null or strength_unit='%' then strength_unit else null end as NUMERATOR_unit,
case when dosage_unit  is not null then cast(dosage_value as float (126))  else null end as DENOMINATOR_VALUE, 
case when dosage_unit  is not null then dosage_unit else null end as DENOMINATOR_UNIT
from  ds_0
;
update DRUG_STRENGTH_STAGE 
set denominator_unit=null where denominator_unit='%';
--deleting pack codes that we will insert as OMOP-codes
delete drug_strength_stage where drug_concept_code in (
select concept_code from branded_drug_p2)
;
insert into drug_strength_stage (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
select distinct DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,cast( AMOUNT_VALUE as float (126)),AMOUNT_UNIT,cast( NUMERATOR_VALUE as float (126)),NUMERATOR_UNIT,cast( DENOMINATOR_VALUE as float (126)),DENOMINATOR_UNIT from pack_for_DSS;

create table pack_content_0 as(
select distinct a.concept_code as  pack_concept_code, b.concept_code as component_concept_code, b.concept_name,PRODUCT_INFORMATION as amount
from branded_drug_p2  p join  drug_concept_stage b on p.concept_name=b.concept_name
join drug_concept_stage a on a.concept_code=cast (p.concept_code as varchar (255))
left join packaging g on g.drug_code=a.concept_code
where a.concept_class_id='Branded Pack' and b.concept_class_id like '%Branded Drug%')
;
alter table pack_content_0
add box_size integer;
update pack_content_0 set amount=null where amount='28' or amount='21' or amount='24' or amount='30' or amount='21-PACK';
update pack_content_0 set amount='1' where amount='0.5ML' or amount='0.5 ML'  or amount='2.0ML'  or amount='2.0 ML'  or amount='1.0ML'  or amount='1.0 ML' or amount='1 EA' or amount='1 CAPSULE - 10G CREAM' or amount='1 INSERT'
 or amount='1 OVULE/9G TUBE' or amount='10 GM +1 APPLICATOR' or amount='10G' or amount='10GM + 1 OVULE' or amount='1TAB-10G CREAM' or amount='13.5ML - 3G' or amount='1X500MG INSRT,1X10G TOPCR' or amount='21500UNIT/VIAL' or amount='2ML/4ML/10ML (TOTAL VOLUME)'
 or amount='0.5ML SYRINGE OR PEN AND 0.5 ML SYRINGE OR PEN' or amount='3ML' or amount='300MG/10G CREAM' or amount='4.6G OINT/10G CREAM' or amount='5.0 ML' or amount='5.0ML' or amount='5G/10G';
update pack_content_0 set amount='10' where amount='10/12/20' or amount='10 X 1/28';
update pack_content_0 set amount='12' where amount='12 X 1/21' or amount='12X1/28';
update pack_content_0 set amount='7' where  amount='7/14/30';
UPDATE PACK_CONTENT_0   SET AMOUNT = '84'WHERE CONCEPT_NAME = 'RIBAVIRIN CAPSULE[VICTRELIS TRIPLE] VICTRELIS TRIPLE'AND   AMOUNT = '168 BOC CAPS 84/98 RBV CAPS AND 2 REDIPEN';
UPDATE PACK_CONTENT_0   SET AMOUNT = '84'WHERE CONCEPT_NAME = 'RIBAVIRIN CAPSULE[PEGETRON] PEGETRON'AND   AMOUNT = '2X0.675ML-84 CAPS/2X0.675ML-98 CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '84'WHERE CONCEPT_NAME = 'RIBAVIRIN CAPSULE[PEGETRON] PEGETRON'AND   AMOUNT = '2X0.7ML-84CAPS/2X0.7ML-98CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '70'WHERE CONCEPT_NAME = 'RIBAVIRIN CAPSULE[VICTRELIS TRIPLE] VICTRELIS TRIPLE'AND   AMOUNT = '168 BOC CAPS 70 RBV CAPS AND 2 REDIPEN';
UPDATE PACK_CONTENT_0   SET AMOUNT = '70'WHERE CONCEPT_NAME = 'RIBAVIRIN CAPSULE[PEGETRON] PEGETRON'AND   AMOUNT = '2X0.675ML-70 CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '7'WHERE CONCEPT_NAME = 'MICONAZOLE NITRATE OVULE 100MG [MONISTAT] MONISTAT 7 DUAL-PAK'AND   AMOUNT = '7 SUP/9G TUBE';
UPDATE PACK_CONTENT_0   SET AMOUNT = '7'WHERE CONCEPT_NAME = 'VILAZODONE HYDROCHLORIDE 20MG VIIBRYD'AND   AMOUNT = '7X10MG-7X20MG-16X40MG';
UPDATE PACK_CONTENT_0   SET AMOUNT = '7'WHERE CONCEPT_NAME = 'VILAZODONE HYDROCHLORIDE 10MG VIIBRYD'AND   AMOUNT = '7X10MG-7X20MG-16X40MG';
UPDATE PACK_CONTENT_0   SET AMOUNT = '7'WHERE CONCEPT_NAME = 'VILAZODONE HYDROCHLORIDE 20MG VIIBRYD'AND   AMOUNT = '7X10MG-7X20MG-16X40MG';
UPDATE PACK_CONTENT_0   SET AMOUNT = '7'WHERE CONCEPT_NAME = 'VILAZODONE HYDROCHLORIDE 10MG VIIBRYD'AND   AMOUNT = '7X10MG-7X20MG-16X40MG';
UPDATE PACK_CONTENT_0   SET AMOUNT = '60'WHERE CONCEPT_NAME = 'ALCOHOL ANHYDROUS PAD[T-STAT] T-STAT PAD-LOT'AND   AMOUNT = '60 PADS/10PADS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '6'WHERE CONCEPT_NAME = 'INTERFERON BETA-1A 22MCG/0.5ML SUBCUTANEOUS SOLUTION REBIF'AND   AMOUNT = '6X0.2ML/6X0.5ML';
UPDATE PACK_CONTENT_0   SET AMOUNT = '6'WHERE CONCEPT_NAME = 'INTERFERON BETA-1A 8.8MCG/0.2ML SUBCUTANEOUS SOLUTION REBIF'AND   AMOUNT = '6X0.2ML/6X0.5ML';
UPDATE PACK_CONTENT_0   SET AMOUNT = '56'WHERE CONCEPT_NAME = 'RIBAVIRIN CAPSULE[VICTRELIS TRIPLE] VICTRELIS TRIPLE'AND   AMOUNT = '168 BOC CAPS 56 RBV CAPS AND 2 REDIPEN';
UPDATE PACK_CONTENT_0   SET AMOUNT = '56'WHERE CONCEPT_NAME = 'RIBAVIRIN CAPSULE[VICTRELIS TRIPLE] VICTRELIS TRIPLE'AND   AMOUNT = '168 BOC CAPS 56 RBV CAPS AND 2 REDIPEN';
UPDATE PACK_CONTENT_0   SET AMOUNT = '56'WHERE CONCEPT_NAME = 'RIBAVIRIN CAPSULE[PEGETRON] PEGETRON'AND   AMOUNT = '2X0.675ML-56 CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '56'WHERE CONCEPT_NAME = 'RIBAVIRIN CAPSULE[PEGETRON] PEGETRON'AND   AMOUNT = '2X0.675ML-56CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '56'WHERE CONCEPT_NAME = 'RIBAVIRIN CAPSULE PEGETRON'AND   AMOUNT = '2X0.7ML-56CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '5'WHERE CONCEPT_NAME = 'ACETAMINOPHEN/CHLORPHENIRAMINE MALEATE/DEXTROMETHORPHAN HYDROBROMIDE/PSEUDOEPHEDRINE HYDROCHLORIDE ORAL POWDER FOR SOLUTION'AND   AMOUNT = '10X4.6G(DAY)-5X5G(NIGHT)';
UPDATE PACK_CONTENT_0   SET AMOUNT = '4'WHERE CONCEPT_NAME = 'CHLORPHENIRAMINE MALEATE TABLET[ANA-KIT] ANAKIT INSECT STING TREATMENT KIT'AND   AMOUNT = '1ML/4TAB';
UPDATE PACK_CONTENT_0   SET AMOUNT = '4'WHERE CONCEPT_NAME = 'CHLORPHENIRAMINE MALEATE TABLET[ANA-KIT] ANA-KIT (2MG/TAB ORL, 1MG/ML LIQ SC IM)'AND   AMOUNT = '4 TAB/2-DOSE SYRINGE';
UPDATE PACK_CONTENT_0   SET AMOUNT = '4'WHERE CONCEPT_NAME = 'APREMILAST 10MG OTEZLA'AND   AMOUNT = '4X10MG/4X20MG/5X30MG/14X30MG';
UPDATE PACK_CONTENT_0   SET AMOUNT = '4'WHERE CONCEPT_NAME = 'APREMILAST 20MG OTEZLA'AND   AMOUNT = '4X10MG/4X20MG/5X30MG/14X30MG';
UPDATE PACK_CONTENT_0   SET AMOUNT = '35'WHERE CONCEPT_NAME = 'RIBAVIRIN CAPSULE[PEGETRON] PEGETRON'AND   AMOUNT = '2X0.7ML-35CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '35'WHERE CONCEPT_NAME = 'RIBAVIRIN CAPSULE[PEGETRON] PEGETRON'AND   AMOUNT = '2X0.7ML-35CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '30'WHERE CONCEPT_NAME = 'PROGESTERONE CAPSULE[ESTROGEL PROPAK] ESTROGEL PROPAK'AND   AMOUNT = '80G GEL-30 CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '3'WHERE CONCEPT_NAME = 'CLOTRIMAZOLE SUPPOSITORY[CANESTEN 3 COMBI-PAK] CANESTEN 3 VAGINAL TABLET COMBI-PAK'AND   AMOUNT = '3 INSERTS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '3'WHERE CONCEPT_NAME = 'CLOTRIMAZOLE CREAM[CANESTEN 3 COMBI-PAK] CANESTEN 3 VAGINAL TABLET COMBI-PAK'AND   AMOUNT = '3 INSERTS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '3'WHERE CONCEPT_NAME = 'MICONAZOLE NITRATE OVULE 400MG [MONISTAT] MONISTAT 3 DUAL-PAK'AND   AMOUNT = '3 OVULES/9G TUBE';
UPDATE PACK_CONTENT_0   SET AMOUNT = '3'WHERE CONCEPT_NAME = 'CLOTRIMAZOLE VAGINAL TABLET[CANESTEN COMFORTAB] CANESTEN COMBI-PAK COMFORTAB 3'AND   AMOUNT = '3TAB-10G CREAM';
UPDATE PACK_CONTENT_0   SET AMOUNT = '3'WHERE CONCEPT_NAME = 'TERCONAZOLE OVULE[TERAZOL 3 DUAL PAK] TERAZOL 3 DUAL PAK'AND   AMOUNT = '80MG/3 OVULES, 9GM TUBE(0.8%)';
UPDATE PACK_CONTENT_0   SET AMOUNT = '28'WHERE CONCEPT_NAME = 'RIBAVIRIN TABLET[PEGASYS RBV] PEGASYS RBV'AND   AMOUNT = '28/35/42 TABLETS, 0.5ML SYRINGE OR AUT0-INJECTOR';
UPDATE PACK_CONTENT_0   SET AMOUNT = '28'WHERE CONCEPT_NAME = 'RIBAVIRIN TABLET[PEGASYS RBV] PEGASYS RBV'AND   AMOUNT = '28/35/42 TABLETS, 1ML';
UPDATE PACK_CONTENT_0   SET AMOUNT = '28'WHERE CONCEPT_NAME = 'RIBAVIRIN CAPSULE[PEGETRON] PEGETRON'AND   AMOUNT = '2X0.7ML-28CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '2'WHERE CONCEPT_NAME = 'PEGINTERFERON ALFA-2B SOLUTION 100MCG/0.5ML [VICTRELIS TRIPLE] VICTRELIS TRIPLE'AND   AMOUNT = '168 BOC CAPS 56 RBV CAPS AND 2 REDIPEN';
UPDATE PACK_CONTENT_0   SET AMOUNT = '2'WHERE CONCEPT_NAME = 'PEGINTERFERON ALFA-2B SOLUTION 80MCG/0.5ML [VICTRELIS TRIPLE] VICTRELIS TRIPLE'AND   AMOUNT = '168 BOC CAPS 56 RBV CAPS AND 2 REDIPEN';
UPDATE PACK_CONTENT_0   SET AMOUNT = '2'WHERE CONCEPT_NAME = 'PEGINTERFERON ALFA-2B SOLUTION 120MCG/0.5ML [VICTRELIS TRIPLE] VICTRELIS TRIPLE'AND   AMOUNT = '168 BOC CAPS 70 RBV CAPS AND 2 REDIPEN';
UPDATE PACK_CONTENT_0   SET AMOUNT = '2'WHERE CONCEPT_NAME = 'PEGINTERFERON ALFA-2B SOLUTION 150MCG/0.5ML [VICTRELIS TRIPLE] VICTRELIS TRIPLE'AND   AMOUNT = '168 BOC CAPS 84/98 RBV CAPS AND 2 REDIPEN';
UPDATE PACK_CONTENT_0   SET AMOUNT = '2'WHERE CONCEPT_NAME = 'APREPITANT 80MG ORAL CAPSULE EMEND TRI-PACK'AND   AMOUNT = '1X125MG + 2X80MG';
UPDATE PACK_CONTENT_0   SET AMOUNT = '2'WHERE CONCEPT_NAME = 'PEGINTERFERON ALFA-2B SOLUTION 80MCG/0.5ML [PEGETRON] PEGETRON'AND   AMOUNT = '2X0.675ML-56 CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '2'WHERE CONCEPT_NAME = 'PEGINTERFERON ALFA-2B SOLUTION 100MCG/0.5ML [PEGETRON] PEGETRON'AND   AMOUNT = '2X0.675ML-56CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '2'WHERE CONCEPT_NAME = 'PEGINTERFERON ALFA-2B SOLUTION 120MCG/0.5ML [PEGETRON] PEGETRON'AND   AMOUNT = '2X0.675ML-70 CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '2'WHERE CONCEPT_NAME = 'PEGINTERFERON ALFA-2B SOLUTION 150MCG/0.5ML [PEGETRON] PEGETRON'AND   AMOUNT = '2X0.675ML-84 CAPS/2X0.675ML-98 CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '2'WHERE CONCEPT_NAME = 'PEGINTERFERON ALFA-2B SOLUTION 80MCG/0.5ML [PEGETRON] PEGETRON'AND   AMOUNT = '2X0.7ML-28CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '2'WHERE CONCEPT_NAME = 'PEGINTERFERON ALFA-2B SOLUTION 100MCG/0.5ML [PEGETRON] PEGETRON'AND   AMOUNT = '2X0.7ML-35CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '2'WHERE CONCEPT_NAME = 'PEGINTERFERON ALFA-2B SOLUTION 120MCG/0.5ML [PEGETRON] PEGETRON'AND   AMOUNT = '2X0.7ML-35CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '2'WHERE CONCEPT_NAME = 'PEGINTERFERON ALFA-2B SOLUTION 50MCG/0.5ML [PEGETRON] PEGETRON'AND   AMOUNT = '2X0.7ML-56CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '2'WHERE CONCEPT_NAME = 'PEGINTERFERON ALFA-2B SOLUTION 150MCG/0.5ML [PEGETRON] PEGETRON'AND   AMOUNT = '2X0.7ML-84CAPS/2X0.7ML-98CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '19'WHERE CONCEPT_NAME = 'APREMILAST 30MG OTEZLA'AND   AMOUNT = '4X10MG/4X20MG/5X30MG/14X30MG';
UPDATE PACK_CONTENT_0   SET AMOUNT = '168'WHERE CONCEPT_NAME = 'BOCEPREVIR CAPSULE[VICTRELIS TRIPLE] VICTRELIS TRIPLE'AND   AMOUNT = '168 BOC CAPS 56 RBV CAPS AND 2 REDIPEN';
UPDATE PACK_CONTENT_0   SET AMOUNT = '168'WHERE CONCEPT_NAME = 'BOCEPREVIR CAPSULE[VICTRELIS TRIPLE] VICTRELIS TRIPLE'AND   AMOUNT = '168 BOC CAPS 56 RBV CAPS AND 2 REDIPEN';
UPDATE PACK_CONTENT_0   SET AMOUNT = '168'WHERE CONCEPT_NAME = 'BOCEPREVIR CAPSULE[VICTRELIS TRIPLE] VICTRELIS TRIPLE'AND   AMOUNT = '168 BOC CAPS 70 RBV CAPS AND 2 REDIPEN';
UPDATE PACK_CONTENT_0   SET AMOUNT = '168'WHERE CONCEPT_NAME = 'BOCEPREVIR CAPSULE[VICTRELIS TRIPLE] VICTRELIS TRIPLE'AND   AMOUNT = '168 BOC CAPS 84/98 RBV CAPS AND 2 REDIPEN';
UPDATE PACK_CONTENT_0   SET AMOUNT = '16'WHERE CONCEPT_NAME = 'VILAZODONE HYDROCHLORIDE 40MG VIIBRYD'AND   AMOUNT = '7X10MG-7X20MG-16X40MG';
UPDATE PACK_CONTENT_0   SET AMOUNT = '11'WHERE CONCEPT_NAME = 'VARENICLINE TARTRATE 0.5MG GD-VARENICLINE'AND   AMOUNT = '11/14/28/56';
UPDATE PACK_CONTENT_0   SET AMOUNT = '11'WHERE CONCEPT_NAME = 'VARENICLINE TARTRATE 1MG GD-VARENICLINE'AND   AMOUNT = '11/14/28/56';
UPDATE PACK_CONTENT_0   SET AMOUNT = '10'WHERE CONCEPT_NAME = 'PHENYLEPHRINE HYDROCHLORIDE DAYTIME ORAL POWDER FOR SOLUTION'AND   AMOUNT = '10X4.6G(DAY)-5X5G(NIGHT)';
UPDATE PACK_CONTENT_0   SET AMOUNT = '10'WHERE CONCEPT_NAME = 'ERYTHROMYCIN PAD[T-STAT] T-STAT PAD-LOT'AND   AMOUNT = '60 PADS/10PADS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '1'WHERE CONCEPT_NAME = 'EPINEPHRINE POWDER FOR SOLUTION[ANA-KIT] ANAKIT INSECT STING TREATMENT KIT'AND   AMOUNT = '1ML/4TAB';
UPDATE PACK_CONTENT_0   SET AMOUNT = '1'WHERE CONCEPT_NAME = 'APREPITANT 125MG ORAL CAPSULE EMEND TRI-PACK'AND   AMOUNT = '1X125MG + 2X80MG';
UPDATE PACK_CONTENT_0   SET AMOUNT = '1'WHERE CONCEPT_NAME = 'PEGINTERFERON ALFA-2A SOLUTION[PEGASYS RBV] PEGASYS RBV'AND   AMOUNT = '28/35/42 TABLETS, 0.5ML SYRINGE OR AUT0-INJECTOR';
UPDATE PACK_CONTENT_0   SET AMOUNT = '1'WHERE CONCEPT_NAME = 'PEGINTERFERON ALFA-2A SOLUTION[PEGASYS RBV] PEGASYS RBV'AND   AMOUNT = '28/35/42 TABLETS, 1ML';
UPDATE PACK_CONTENT_0   SET AMOUNT = '1'WHERE CONCEPT_NAME = 'MICONAZOLE NITRATE CREAM[MONISTAT] MONISTAT 3 DUAL-PAK'AND   AMOUNT = '3 OVULES/9G TUBE';
UPDATE PACK_CONTENT_0   SET AMOUNT = '1'WHERE CONCEPT_NAME = 'CLOTRIMAZOLE CREAM[CANESTEN COMFORTAB] CANESTEN COMBI-PAK COMFORTAB 3'AND   AMOUNT = '3TAB-10G CREAM';
UPDATE PACK_CONTENT_0   SET AMOUNT = '1'WHERE CONCEPT_NAME = 'EPINEPHRINE SOLUTION[ANA-KIT] ANA-KIT (2MG/TAB ORL, 1MG/ML LIQ SC IM)'AND   AMOUNT = '4 TAB/2-DOSE SYRINGE';
UPDATE PACK_CONTENT_0   SET AMOUNT = '1'WHERE CONCEPT_NAME = 'MICONAZOLE NITRATE CREAM[MONISTAT] MONISTAT 7 DUAL-PAK'AND   AMOUNT = '7 SUP/9G TUBE';
UPDATE PACK_CONTENT_0   SET AMOUNT = '1'WHERE CONCEPT_NAME = 'ESTRADIOL HEMIHYDRATE PUMP[ESTROGEL PROPAK] ESTROGEL PROPAK'AND   AMOUNT = '80G GEL-30 CAPS';
UPDATE PACK_CONTENT_0   SET AMOUNT = '1'WHERE CONCEPT_NAME = 'TERCONAZOLE CREAM[TERAZOL 3 DUAL PAK] TERAZOL 3 DUAL PAK'AND   AMOUNT = '80MG/3 OVULES, 9GM TUBE(0.8%)';

create table pack_content as ( 
select distinct PACK_CONCEPT_code,COMPONENT_CONCEPT_code,AMOUNT,BOX_SIZE from pack_content_0
)
;
create table RELATIONSHIP_TO_CONCEPT ( 
 concept_code_1		varchar(255)	, 
 vocabulary_id_1	varchar(20)	, 
 concept_id_2		integer	, 
 precedence		integer	 , 
 conversion_factor		float	 
 ) 
;
insert into  RELATIONSHIP_TO_CONCEPT ( concept_code_1,  vocabulary_id_1	, concept_id_2	, precedence) 
select concept_code,'DPD',CONCEPT_id_2,precedence from aut_ingr_all_mapped 
join drug_concept_stage on concept_name_1=concept_name 
where concept_class_id='Ingredient'
;
insert into  RELATIONSHIP_TO_CONCEPT ( concept_code_1,  vocabulary_id_1	, concept_id_2	, precedence) 
select concept_code,'DPD',CONCEPT_code_2,precedence from AUT_FORM_ALL_MAPPED 
join drug_concept_stage on concept_name_1=concept_name and concept_class_id='Dose Form'
;
insert into  RELATIONSHIP_TO_CONCEPT ( concept_code_1,  vocabulary_id_1	, concept_id_2, precedence) 
select concept_code,'DPD',CONCEPT_id_2, precedence from aut_brand_all_mapped 
join drug_concept_stage on concept_name_1=concept_name and concept_class_id='Brand Name'
;
insert into relationship_to_concept 
select b.concept_code, 'DPD', c.concept_id,1, ''  from THERAPEUTIC_CLASS a join drug_concept_stage b on a.DRUG_CODE = b.concept_code
 left join devv5.concept c on c.concept_code = a.TC_ATC_NUMBER and c.vocabulary_id = 'ATC' 
where c.concept_Code is not null
;
insert into relationship_to_concept (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select CONCEPT_CODE_1,'DPD',CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR from aut_units_mapped;


