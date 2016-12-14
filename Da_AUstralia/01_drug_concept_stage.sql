drop sequence nv;
declare
 ex number;
begin
  select max(cast(substr(concept_code, 5) as integer))+1 into ex from devv5.concept where concept_code like 'OMOP%' and concept_code not like '% %'; -- Last valid value of the OMOP123-type codes
  begin
    execute immediate 'create sequence nv increment by 1 start with ' || ex || ' nocycle cache 20 noorder';
  end;
end;


update drugs set unit = 'MCG' where unit like 'µg';
update drugs set unit2 = 'MCG' where unit2 like 'µg';
update drugs
set MOL_NAME = 'DIPHTHERIA VACCINE/PERTUSSIS VACCINE/POLIOMYELITIS VACCINE - INACTIVATED/TETANUS VACCINE' where fo_prd_id in('590079','595524','590082','587459','587464');
update drugs
set MOL_NAME = 'CITRIC ACID/MACROGOL/MAGNESIUM OXIDE/PICOSULFATE/POTASSIUM CHLORIDE/SODIUM CHLORIDE/SODIUM SULFATE' where fo_prd_id = 586468;
update drugs
set MOL_NAME = 'MENINGOCOCCAL VACCINE' where fo_prd_id = 586227;
update drugs
set MOL_NAME = 'AVENA SATIVA/CAFFEINE/CAMELLIA SINENSIS/CARNITINE/CHROMIUM/GARCINIA QUAESITA/GYMNEMA SYLVESTRE/THIOCTIC ACID' where fo_prd_id = 59136 ;
update drugs
set MOL_NAME = 'CALCIUM/COPPER/ELEUTHEROCOCCUS SENTICOSUS/GINKGO BILOBA/IODINE/MANGANESE/NICOTINIC ACID/PANTOTHENATE/PYRIDOXINE/RIBOFLAVIN/SELENIUM/THIAMINE/ZINC' where fo_prd_id = 24024 ;
update drugs
set MOL_NAME = 'ALLIUM SATIVUM/ASCORBATE/BETACAROTENE/BIOFLAVONOIDS/CYSTEINE/MANGANESE/NICOTINAMIDE/PANTOTHENATE/PYRIDOXINE/RETINOL/RIBOFLAVIN/SELENIUM/THIOCTIC ACID/TOCOPHEROL/ZINC' where fo_prd_id = 33708 ;
update DRUGS SET FO_PRD_ID= TRIM(FO_PRD_ID),PRD_NAME=TRIM(PRD_NAME),MAST_PRD_NAME=TRIM(MAST_PRD_NAME),DOSAGE=TRIM(DOSAGE),UNIT=TRIM(UNIT),DOSAGE2=TRIM(DOSAGE2),MOL_NAME=TRIM(MOL_NAME),ATCCODE=TRIM(ATCCODE),
ATC_NAME=TRIM(ATC_NAME),NFC_CODE=TRIM(NFC_CODE),MANUFACTURER=TRIM(MANUFACTURER);
update drugs set prd_name = 'SALICYLIC ACID & SULFUR AQUEOUS CREAM APF' where mast_prd_name = 'SALICYLIC ACID & SULFUR AQUEOUS CREAM APF';


--ingredients
drop table ingredients;
create table ingredients as ( 
SELECT ingredient, FO_PRD_ID from (
select distinct
trim(regexp_substr(t.MOL_NAME, '[^/]+', 1, levels.column_value))  as ingredient, FO_PRD_ID
from drugs t,
table(cast(multiset(select level from dual connect by  level <= length (regexp_replace(t.MOL_NAME, '[^/]+'))  + 1) as sys.OdciNumberList)) levels) );

/*
create table ingr_2 as (select prd_name, regexp_replace(trim(regexp_replace(regexp_replace(regexp_replace(prd_name,'(CAPSULE|DEVICE|VOLUME|NEBUHALER|SPRAY|CREAM|LOZENGE|MENT|TABLET|NASAL|ROTAHALER|ELEXIR|DROP|INHALER|DAILY|AQ. SUS|EXTRA|OINT|SHAMPOO|BABY|GEL|POWDER|FACE|WASH|SYRUP|AMPOULE|OILY|LIQUI|POWDE|CLEAR SKIN ACNE CONTROL|KIT|ALLERGEN EXTRACTS|BAR|SOAP|CAPSU|SOLUTION|EYE|ORAL|LIQUID|SUPPOS.|AQUEOUS|BP|BPC|APF|LOTION|OINTMENT|SPINHALER)?'),'\s-.*'),'[0-9].*')),'\(.*')
as ingredient,fo_prd_id
from drugs where mol_name is null and fo_prd_id not in (select fo_prd_id from non_drug));
delete ingr_2 where ingredient like '%MULTI%' or ingredient like '%DERM%' or ingredient like '%NEILMED%' or ingredient like '%PAIN%' or ingredient like '%PANADOL%' or ingredient like '%/%' or ingredient like '%RELIEF%'  or ingredient like '%PREGNANCY%'  or ingredient like '%STRESS%'
;
--ingredeients3-manual table from ingr_2
*/
INSERT INTO INGREDIENT_3 (PRD_NAME,NEW_NAME,FO_PRD_ID)
VALUES('','PHENETHYL','16863');
insert into ingredients (INGREDIENT,FO_PRD_ID)
select NEW_NAME,FO_PRD_ID from ingredient_3;
insert into ingredients (ingredient) values ('INACTIVE');
update ingredients 
set INGREDIENT = 'COAL TAR' where INGREDIENT like '%LINOTAR%';
delete from ingredients where regexp_like(ingredient,'ARABLOC|TRIAMCINOLONE\sAND\sANTIBIOTICS|3,');
delete from ingredients where fo_prd_id in(select concept_code from non_drug);
--form
drop table dose_form_test;
create table dose_form_test as (
select fo_prd_id as fo_prd_id, prd_name as prd_name ,nfc_code as nfc_code, regexp_substr(prd_name,'CFC-free inhaler|Capsule|IV dressings|Rectube|adhesive plaster|alcoholic lotion|ampoule|applicator|bandage|bath emulsion|bath oil',1,1,'i') as dose_form   from drugs
union 
select fo_prd_id, prd_name,nfc_code, regexp_substr(prd_name,'bath solution|buccal tablet|caplet|capsule|chesty cough linctus|chewable tablet|chewing gum|collodion BP|colourless cream|cream|crystal',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name,'dental lacquer|diabetic linctus|disks plus disk inhaler|disks refill|dispersible tablet|douche plus fitting|dropper|dry powder spray|dusting powder',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code, regexp_substr(prd_name,'ear drop|ear spray|effervescent granule|effervescent tablet|emollient cream|eye drop|eye irrigation solution|eye/ear ointment|film|foam|gastro-resistant capsule',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name,'gastro-resistant tablet|gauze|gauze swab|gel kit|gel plus dressing|gel-forming eye drop|granule|granule.* for suspension|implant|infant suppositorie',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code ,regexp_substr(prd_name, 'infusion .*powder for reconstitution|infusion plus diluent|inhalation|inhalation capsule|inhalator|inhaler|inhaler plus spacer|inhaler refill|inhaler solution',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name,'injection|injection powder|injection .*powder for reconstitution|injection cartridge|injection plus diluent|injection refills|injection solution|injection vial',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name,'insufflator|intra articular/ intradermal injection|intra articular/intramuscular injection|intra-muscular injection|intramuscular injection .*pdr for recon.*|intranasal solution',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name,'intrathecal injection|intravenous infusion|intravenous infusion concentrate|intravenous infusion plus buffer|intravenous solution|irrigation solution|junior capsule|junior lozenge',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name,'linctus|lip protector|lipocream|liquid|lotio-gel|lozenge|maintenance set|matrigel capsule|melt tablet|modified release granule|modified release tablet|mouthwash and gargle',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name, 'multi-dose vial|nail lacquer|nasal gel|nasal ointment|nebuliser solution|nose drop|nose gel|ocular insert|oil|oily cream|oily injection|ointment|ointment & suppositorie|ophthalmic solution',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name,'oral drop|oral emulsion|oral liquid|oral paint|oral powder|oral syringe|oro-dispersible film|pad|paediatric capsule|paediatric drop|paediatric mixture|paediatric solution',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name,'paediatric sugar free suspension|paediatric suspension|paediatric syrup|paint|paper|patche|pellet|periodontal gel|pessary plus cream|plaster|poultice|powder|powder for reconstitution',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name,'prefilled pen|rectal foam|rectal solution|retention enema|sachet|scalp and skin cleanser solution|scalp application|scalp lotion|scalp solution|semi-solid|single dose injection vial',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name,'single dose unit eye drop|single dose unit eye gel|skin cleanser solution|soluble tablet|spincap|spray|spray application|spray solution|sterile solution|sterile suspension',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name,'sterile swab|stocking|subcutaneous injection|sublingual tablet|sugar free chewable tablet|sugar free dispersible tablet|sugar free granule|sugar free linctus|sugar free lozenge',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name,'sugar free mixture|sugar free paediatric linctus|sugar free paediatric syrup|sugar free suspension|supposit|surgical scrub|swab|tablet|tablet pack|tablet .* pessaries|tablet.* plus granule',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name,'\stampon|throat spray|toothpaste|topical gel|topical liquid|tube|unit dose blister|unit dose vial|vaginal capsule|vaginal cleansing kit|vaginal cream|vaginal ring|vial|vitrellae',1,1,'i') from drugs
union 
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name,'volatile liquid|vortex metered dose inhaler|wax|PENFILL.*INJECTION',1,1,'i') from drugs);
insert into dose_form_test
select fo_prd_id,prd_name, nfc_code ,regexp_substr(prd_name,'SUPP\s|SUPPO|CAPSULE|SYRUP|SYRINGE|ORALDISTAB|AMPOULE|AUTOHALER|INHALER|HALER|CHEW.*GUM|CHEW.*TAB|DISP.*TAB|TABSULE|AUTOINJ|\sPENFILL|PRE-FILLED|SUSPEN|REPETAB|LOTION|VAG.*GEL|GEL.*ORAL|ORAL.*GEL|EYE.*GEL',1,1,'i') FROM DRUGS; 
insert into dose_form_test
select fo_prd_id,prd_name, nfc_code ,regexp_substr(prd_name,'EYE.*OINT|ANAL.*\sOINT|EAR/*\sOINT|\sOINT|\sORAL.*SOL|\sSOL.*ORAL|\sMICROENEMA|\sENEMA|\sNASAL.*DROP|\sDROP|EYE.*DRO|s\EAR.*DRO|\sMOUTHWASH|\sMOUTHWASH.*SOL|\sELIXI|PATCH|\sTABL|\sSHAMPOO|CAPSEAL|\sINJ') from drugs;
insert into dose_form_test
select fo_prd_id,prd_name, nfc_code ,regexp_substr(PRD_NAME, 'NEB.*SOL|PESSARY|INFUSION|WAFER|LINIMENT|MIXTURE|CAPSU|TAB-\d+|\s.*ABLE.*TAB|SOLUTION|PASTE|\sPEN\s|GEL|\sSOLUT\s|\sPOWDE|\sCAP\s|\sPASTILE|\sLOZE\s|EMULSION|MOUTHRINSE|NASAL SPRAY|EYE/EAR DROP|SOFTGELCAP') FROM DRUGS;
delete from dose_form_test where dose_form is null;
delete from dose_form_test where fo_prd_id in (select concept_code from non_drug);
update dose_form_test set dose_form = TRIM(upper(dose_form));
UPDATE dose_form_test SET dose_form= 'TABLET' WHERE dose_form LIKE 'TAB-%' OR dose_form LIKE 'TABSULE' OR  dose_form LIKE 'TABLET%' OR DOSE_FORM LIKE '%REPETAB%' OR DOSE_FORM LIKE '%TABL';
UPDATE dose_form_test SET dose_form= 'EFFERVESCENT TABLET' WHERE dose_form LIKE '%EFFERVESCENT%TABLET%';
UPDATE dose_form_test SET dose_form= 'CHEWABLE TABLET' WHERE dose_form LIKE '%CHEW%TAB%' OR DOSE_FORM LIKE '%ABLE%TAB%';
UPDATE dose_form_test SET dose_form= 'DISPERSIBLE TABLET' WHERE dose_form LIKE '%DISP%TAB%' OR DOSE_FORM LIKE '%ORALDISTAB%';
UPDATE dose_form_test SET dose_form= 'SUPPOSITORY' WHERE dose_form LIKE '%SUPP%';
UPDATE dose_form_test SET dose_form= 'NASAL DROP' WHERE dose_form LIKE '%NASAL RELIEF SALINE NASAL DROP%';
UPDATE dose_form_test SET dose_form= 'ORAL GEL' WHERE dose_form LIKE '%ORAL %GEL%';
UPDATE dose_form_test SET dose_form= 'CAPSULE' WHERE dose_form LIKE '%CAPS%' OR dose_form LIKE 'CAP' OR DOSE_FORM LIKE 'SOFTGELCAP';
UPDATE dose_form_test SET dose_form= 'INJECTION' WHERE dose_form LIKE 'INJ';
UPDATE dose_form_test SET dose_form= 'EYE DROP' WHERE dose_form LIKE '%EYE%DRO';
UPDATE dose_form_test SET dose_form= 'EYE OINTMENT' WHERE dose_form LIKE '%EYE%OINT';
UPDATE dose_form_test SET dose_form= 'VAGINAL GEL' WHERE dose_form LIKE '%VAG%GEL%';
UPDATE dose_form_test SET dose_form= 'LOTION' WHERE dose_form LIKE '%LOT%';
UPDATE dose_form_test SET dose_form= 'ELIXIR' WHERE dose_form LIKE '%ELIXI%';
UPDATE dose_form_test SET dose_form= 'SOLUTION' WHERE dose_form LIKE 'SOLUTION' OR dose_form LIKE 'SOLUT';
UPDATE dose_form_test SET dose_form= 'ORAL SOLUTION' WHERE dose_form LIKE '%SOLUTION%ORAL%' or dose_form like 'ORAL SOL';
UPDATE dose_form_test SET dose_form= 'ORAL GEL' WHERE dose_form LIKE 'GEL ORAL' OR dose_form LIKE 'GEL-ORAL';
UPDATE dose_form_test SET dose_form= 'INHALATION' WHERE dose_form LIKE 'INHALATOR' OR dose_form LIKE 'INHALER' OR dose_form LIKE 'HALER';
UPDATE dose_form_test SET dose_form= 'ENEMA' WHERE dose_form LIKE '%ENEMA%';
UPDATE dose_form_test SET dose_form= 'INHALATION SOLUTION' WHERE dose_form LIKE '%NEB%SOL%';
UPDATE dose_form_test SET dose_form= 'PENFILL INJECTION' WHERE dose_form LIKE '%PENFILL%INJECTION%';
UPDATE dose_form_test SET dose_form= 'OINTMENT' WHERE dose_form LIKE 'OINT';
UPDATE dose_form_test SET dose_form= 'LOZENGE' WHERE dose_form LIKE 'LOZE';
UPDATE dose_form_test SET dose_form= 'ORAL DROP' WHERE dose_form LIKE 'ORAL DROPS ORAL SOL';
UPDATE dose_form_test SET dose_form= 'PATCH' WHERE dose_form LIKE 'PATCHE';
UPDATE dose_form_test SET dose_form= 'POWDER' WHERE dose_form LIKE 'POWDE';
UPDATE dose_form_test SET dose_form= 'ORAL GEL' WHERE dose_form LIKE 'ORALBALANCE DRY MOUTH MOISTURISING GEL';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '11899' AND   DOSE_FORM = 'SACHET';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '11898' AND   DOSE_FORM = 'SACHET';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '11897' AND   DOSE_FORM = 'SACHET';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '13542' AND   DOSE_FORM = 'SACHET';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '17923' AND   DOSE_FORM = 'SACHET';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '17915' AND   DOSE_FORM = 'SACHET';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '603129' AND   DOSE_FORM = 'CAPLET';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '36452' AND   DOSE_FORM = 'SACHET';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '32915' AND   DOSE_FORM = 'SACHET';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '25543' AND   DOSE_FORM = 'LIQUID';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '24931' AND   DOSE_FORM = 'POWDER';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '22528' AND   DOSE_FORM = 'SACHET';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '2143' AND   DOSE_FORM = 'LIQUID';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '19938' AND   DOSE_FORM = 'LIQUID';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '19937' AND   DOSE_FORM = 'LIQUID';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '604426' AND   DOSE_FORM = 'SACHET';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '6286' AND   DOSE_FORM = 'LIQUID';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '17982' AND   DOSE_FORM = 'POWDER';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '15975' AND   DOSE_FORM = 'POWDER';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '29539' AND   DOSE_FORM = 'OIL';

delete from dose_form_test
where rowid not in (select min(rowid)from dose_form_test
group by FO_PRD_ID,PRD_NAME,NFC_CODE,DOSE_FORM);
DROP TABLE dose_form_test_2;
CREATE TABLE dose_form_test_2 AS 
SELECT  DISTINCT A.FO_PRD_ID,A.PRD_NAME,A.NFC_CODE,A.DOSE_FORM  FROM dose_form_test A
INNER JOIN dose_form_test B ON A.FO_PRD_ID=B.FO_PRD_ID 
INNER JOIN dose_form_test C ON A.FO_PRD_ID=C.FO_PRD_ID
WHERE LENGTH(A.DOSE_FORM)>LENGTH(B.DOSE_FORM) AND  LENGTH(A.DOSE_FORM)>LENGTH(C.DOSE_FORM)
AND B.DOSE_FORM!=C.DOSE_FORM AND A.FO_PRD_ID IN (SELECT FO_PRD_ID FROM dose_form_test GROUP BY FO_PRD_ID HAVING COUNT(FO_PRD_ID)>2)
UNION
SELECT  DISTINCT A.FO_PRD_ID,A.PRD_NAME,A.NFC_CODE,A.DOSE_FORM  FROM dose_form_test A
INNER JOIN dose_form_test B ON A.FO_PRD_ID=B.FO_PRD_ID 
WHERE LENGTH(A.DOSE_FORM)>LENGTH(B.DOSE_FORM) AND A.FO_PRD_ID IN (SELECT FO_PRD_ID FROM dose_form_test GROUP BY FO_PRD_ID HAVING COUNT(FO_PRD_ID)=2);
DELETE FROM dose_form_test WHERE FO_PRD_ID IN (SELECT FO_PRD_ID FROM dose_form_test_2);
INSERT INTO dose_form_test SELECT * FROM dose_form_test_2;
;

--bn
drop table bn;
create table bn as
select distinct FO_PRD_ID,MAST_PRD_NAME,MAST_PRD_NAME as new_name from drugs
where  not regexp_like  (MAST_PRD_NAME, '(\D)+/(\D)+')
and FO_PRD_ID not in (select concept_code from non_drug)
and MAST_PRD_NAME is not null
;
update bn
set new_name=regexp_replace (new_name,'\(.*\)')
where regexp_like (new_name,'\(.*\)')
;
UPDATE bn SET new_name = regexp_replace(new_name, '[ ,]+(Eye drops|solution|Injection|syrup|SURGICAL SCRUBSWABSTICKS|ANTISEPTIC||VAGINAL|CHEWABLE|TINCTURE|ointment|FILM-COATED TABLETS|spray|nasal|inhaler|dressing|sterile|sachet|lotion|oily|Tablet|vial|Suspension|Cream|Suppository|capsule).*$', '', 1,0, 'i') WHERE 
regexp_like(new_name, '[ ,]+(Eye drops|solution|Injection|syrup|SURGICAL SCRUBSWABSTICKS|ANTISEPTIC|ointment|FILM-COATED TABLETS|VAGINAL|spray|TINCTURE|CHEWABLE|nasal|inhaler|dressing|sterile|sachet|lotion|oily|Tablet|vial|Suspension|Cream|Suppository|capsule).*$','i')
AND NOT regexp_like(new_name, '[ ,]+(Eye drops|solution|Injection|syrup|SURGICAL SCRUBSWABSTICKS|CHEWABLE|ANTISEPTIC|ointment|VAGINAL|TINCTURE|FILM-COATED TABLETS|spray|nasal|inhaler|dressing|sterile|sachet|lotion|oily|Tablet|vial|Suspension|Cream|Suppository|capsule).*(1[ \-]{0,3}A[ \-]{0,3}BLACKMORES|GENERICHEALTH|JENAPHARM|Actavis|Pharma|Berlin-Chemie|Braun|Baxter|Rotexmedica|EGO|Ratiopharm|Hexal|medica M|APOTEX|ANTEMET-EBS|ASTRAZENECA|SANODOZ|ZENITH|SUSTAIN|PFIZER|ASCENT PHARMA|EGO|VALEANT|MAYNE PHARMA).*$', 'i')
;
delete bn where new_name like '%IRRIGATION%' or new_name like '%+%' and  not regexp_like (new_name,'FESS|VITAPLEX|APTAMIL|HAMILTON|DIMETAPP|AQUASUN|FESS|BIO-|TUSSIN|CODRAL|CITRACAL|CENTRUM|SUDAFED|PANADOL|PRONOSAN|STREPSILS|PENT|NYAL|NUROFEN|OSTEVIT-D|SALINE|CALSOURCE|BEROCCA')
;
delete bn where (new_name like '%ZINC %' or new_name like '% BP%' or new_name like '% APF'  or new_name like '%VACCINE%') and new_name not like '%[%' and new_name not like '%NATURE%'
;
update bn 
set new_name= regexp_replace (new_name,'-\s.*')
where new_name like '%- %' and new_name not like '%[%';

update bn
set new_name=regexp_replace(new_name, '\s*\(*\d+[,./]*\d*[,./]*\d*[,./]*\d*\s*(UA|IR|Anti-Xa|Heparin-Antidot I\.U\.|Million IU|IU|Mio.? I.U.|Mega I.U.|SU|dpp|GBq|SQ-E|SE|ppm|mg|ml|g|%|I.U.|microg|mcg|Microgram|mmol|ug|u).*','',1,0,'i')
where new_name not like '%[%'
;

delete bn where upper(trim(new_name)) in (select upper(trim(concept_name)) from devv5.concept where concept_class_id='Ingredient');
delete bn where upper(trim(new_name)) in (select trim(INGREDIENT) from INGREDIENTs)
;

delete  bn where new_name in ('MULTIVITAMIN','VITAMIN','ISOSORBIDE MONONITRATE-BC','D3');
delete  bn where regexp_like (new_name, '(HYDROCHLORIDE|ACETATE|SULFATE|HYDROXIDE)');

update bn set new_name=regexp_replace (new_name, '(MOUTHWASH|PESSARY|\sENEMA|\[.*\])')
where regexp_like (new_name, '(MOUTHWASH|PESSARY|\sENEMA|\[.*\])');
update bn set new_name = 'MS CONTIN' where new_name='MS';
update bn set new_name = 'IN A WINK' where new_name='IN';


--manufacturer
drop table manufacturer;
create table manufacturer as (
select FO_PRD_ID, trim(manufacturer) manufacturer
from drugs
where manufacturer!='UNBRANDED' and manufacturer is not null and fo_prd_id not in(select concept_code from non_drug)
);

Drop table list;
create table list as (
select distinct trim(manufacturer) as concept_name,'Supplier' as concept_class_id from manufacturer
union
select distinct trim(INGREDIENT) as concept_name,'Ingredient' as concept_class_id from INGREDIENTS where INGREDIENT is not null
union
select distinct trim(NEW_NAME), 'Brand Name' as concept_class_id from bn
union
select distinct trim(PRD_NAME) as concept_name,'Drug Product' as concept_class_id from pack_drug_product)
union 
select distinct trim(dose_form) as concept_name, 'Dose Form' as concept_class_id from dose_form_test
;

alter table list
add concept_code varchar(255);
update list
set concept_code='OMOP'||nv.nextval;

truncate table DRUG_concept_STAGE;
insert into DRUG_concept_STAGE (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,pack_size,domain_id,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct CONCEPT_NAME, 'DA_Australia', CONCEPT_CLASS_ID, '', CONCEPT_CODE, '', '','Drug', TO_DATE('2016/10/01', 'yyyy/mm/dd') as valid_start_date,
TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date, ''
 from 
(
select concept_name,concept_class_id, concept_code from list
union
select distinct unit as concept_name,'Unit' as concept_class_id, unit as concept_code  from drugs where unit is not null and  not regexp_like(unit, 'KCAL|\?G|\d|\?g%')
union
select distinct unit2 as concept_name,'Unit' as concept_class_id, unit2 as concept_code from  drugs where unit2 is not null and not regexp_like(unit2, 'KCAL|\?G|\d|\?g|%')
UNION 
select distinct PRD_NAME,'Drug Product' as CONCEPT_CLASS_ID,fo_prd_id from drugs where fo_prd_id not in (select concept_code from non_drug)
 )
 ;
 insert into DRUG_concept_STAGE (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,pack_size,domain_id,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct CONCEPT_NAME, 'DA_Australia', CONCEPT_CLASS_ID, 's', CONCEPT_CODE, '', '','Device', TO_DATE('2016/10/01', 'yyyy/mm/dd') as valid_start_date,
TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date, ''
 from 
(
select distinct PRD_NAME as concept_name,'Device' as CONCEPT_CLASS_ID,concept_code as concept_code from non_drug
 );
update DRUG_concept_STAGE
set STANDARD_CONCEPT = 's' where CONCEPT_CLASS_ID = 'Ingredient';




