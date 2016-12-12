create table drugs as
select distinct fo_prd_id,a.PRD_NAME,a.MAST_PRD_NAME,a.DOSAGE,a.UNIT,a.DOSAGE2,a.UNIT2,a.MOL_EID,a.MOL_NAME,b.MOL_NAME as MOL_NAME_2, ATCCODE,ATC_NAME,NFC_CODE,MANUFACTURER
from fo_product_1_vs_2 a full outer join drug_mapping_1_vs_2 b on a.prd_eid=b.prd_eid;

--next manipulation requires correct numbers--
update drugs 
set PRD_NAME=regexp_replace(PRD_NAME,',','.') where PRD_NAME is not null;


create table drugs_3 as 
select a.fo_prd_id, a.prd_name,a.mast_prd_name, DOSAGE_AS_TEXT as dosage, b.unit, DOSAGE2_AS_TEXT as dosage2, unit_id2 as unit2, a.mol_eid,a.mol_name, b.manufacturer,b.nfc_code,a.atccode, atc_name
from fo_product_3 a  left join drug_mapping_3 b on
a.prd_eid= b.prd_eid
;
UPDATE  DRUGS
SET MANUFACTURER = (SELECT MANUFACTURER FROM DRUGS_3 WHERE DRUGS_3.FO_PRD_ID = DRUGS.FO_PRD_ID)
;
UPDATE  DRUGS
SET ATCCODE = (SELECT ATCCODE FROM DRUGS_3 WHERE DRUGS_3.FO_PRD_ID = DRUGS.FO_PRD_ID AND DRUGS_3.ATCCODE NOT IN ('%IMIQUIMOD%','-1','??'))
;
INSERT INTO DRUGS (FO_PRD_ID,PRD_NAME,MAST_PRD_NAME,DOSAGE,UNIT,DOSAGE2,UNIT2,MOL_EID,MOL_NAME,ATCCODE,ATC_NAME,NFC_CODE,MANUFACTURER)
select  FO_PRD_ID, PRD_NAME,MAST_PRD_NAME,DOSAGE,UNIT,DOSAGE2,UNIT2,MOL_EID,MOL_NAME,ATCCODE,ATC_NAME,nfc_code,MANUFACTURER 
from drugs_3 where fo_prd_id not in (select fo_prd_id from drugs)
;

update drugs 
set PRD_NAME=regexp_replace(PRD_NAME,',','.') where PRD_NAME is not null;
update drugs
SET PRD_NAME=REGEXP_REPLACE(PRD_NAME,'"')
;

create table non_drug as (select  distinct * from drugs where ATCCODE in('V01AA07','V03AK','V04B','V04CL','V04CX','V20','D02A','D02AD','D09A','D02AX','D02BA','D02AC')
or ATCCODE like 'V06%' or ATCCODE like 'V07%');

insert into non_drug
select * from drugs where regexp_like (PRD_NAME,'STOCKING|STRIPS|REMOVER|KCAL|NUTRISION|BREATH-ALERT|CHAMBER|REMOVAL|GAUZE|SUPPLY|PROTECTORS|SOUP|DRESSING|CLEANSER|BANDAGE|BEVERAGE|RESOURCE|WEIGHT|[^IN]TEST[^O]')
and fo_prd_id not in (select fo_prd_id from non_drug);

insert into non_drug  
select * from drugs where (MAST_PRD_NAME like '%SUN%' or   MAST_PRD_NAME like '%ACCU-CHEK%' or MAST_PRD_NAME like '%ACCUTREND%')  and  MAST_PRD_NAME not like '%SELSUN%'
and fo_prd_id not in (select fo_prd_id from non_drug);

insert into non_drug
select * from drugs where regexp_like(mol_name, 'IUD|LEUCOCYTES|AMIDOTRIZOATE|BANDAGE');

insert into non_drug
select * from drugs where regexp_like(nfc_code,'VZT|VGB|VGA|VZY|VEA|VED|VEK|VZV') and fo_prd_id not in (select fo_prd_id from non_drug);

ALTER TABLE non_drug
 RENAME COLUMN fo_prd_id to concept_code;
 

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

create table manufacturer as (
select FO_PRD_ID, trim(manufacturer) manufacturer
from drugs
where manufacturer!='UNBRANDED' and manufacturer is not null and fo_prd_id not in(select concept_code from non_drug)
);

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
select distinct CONCEPT_NAME, 'AMT', CONCEPT_CLASS_ID, '', CONCEPT_CODE, '', '','Drug', TO_DATE('2016/10/01', 'yyyy/mm/dd') as valid_start_date,
TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date, ''
 from 
(
select concept_name,concept_class_id, concept_code from list
union
select distinct unit as concept_name,'Unit' as concept_class_id, unit as concept_code  from drugs where unit is not null and  not regexp_like(unit, 'KCAL|\?G|\d|%')
union
select distinct unit2 as concept_name,'Unit' as concept_class_id, unit2 as concept_code from  drugs where unit2 is not null and not regexp_like(unit2, 'KCAL|\?G|\d|%')
UNION 
select distinct PRD_NAME,'Drug Product' as CONCEPT_CLASS_ID,fo_prd_id from drugs where fo_prd_id not in (select concept_code from non_drug)
 )
 ;
 insert into DRUG_concept_STAGE (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,pack_size,domain_id,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct CONCEPT_NAME, 'AMT', CONCEPT_CLASS_ID, 's', CONCEPT_CODE, '', '','Device', TO_DATE('2016/10/01', 'yyyy/mm/dd') as valid_start_date,
TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date, ''
 from 
(
select distinct PRD_NAME as concept_name,'Device' as CONCEPT_CLASS_ID,concept_code as concept_code from non_drug
 );
update DRUG_concept_STAGE
set STANDARD_CONCEPT = 's' where CONCEPT_CLASS_ID = 'Ingredient';


create table drugs_for_strentgh as
select fo_prd_id , prd_name, dosage,unit,dosage2, unit2, mol_name from fo_product where fo_prd_id not in (select concept_code from non_drug) and fo_prd_id not in (select fo_prd_id from PACK_DRUG_PRODUCT)
union select distinct concept_code,prd_name,dosage,unit, dosage_2,unit_2, mol_name from PACK_DRUG_PRODUCT join drug_concept_stage on prd_name= concept_name;
update drugs_for_strentgh 
set PRD_NAME=regexp_replace(PRD_NAME,',','.') where PRD_NAME is not null;
update drugs_for_strentgh 
set PRD_NAME = 'DEXSAL ANTACID LIQUID 1.25G-20MG/15' where prd_name = 'DEXSAL ANTACID LIQUID 1.25G-20MG/1';

create table ds_strength_trainee (DRUG_CONCEPT_CODE VARCHAR2(255 Byte),INGREDIENT_NAME VARCHAR2(255 Byte),BOX_SIZE NUMBER,AMOUNT_VALUE FLOAT(126),AMOUNT_UNIT VARCHAR2(255 Byte),NUMERATOR_VALUE FLOAT(126),NUMERATOR_UNIT VARCHAR2(255 Byte),DENOMINATOR_VALUE FLOAT(126), 
DENOMINATOR_UNIT VARCHAR2(255 Byte));
update drugs_for_strentgh set unit = 'MCG' where unit like 'µg';
update drugs_for_strentgh set unit2 = 'MCG' where unit2 like 'µg';

--1 molecule denominator in Hours--
insert into ds_strength_trainee (DRUG_CONCEPT_CODE,INGREDIENT_NAME,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
select FO_PRD_ID,mol_name,DOSAGE AS NUMERATOR_VALUE,UNIT AS NUMERATOR_UNIT,regexp_replace(regexp_substr(regexp_substr(PRD_NAME,'/.{0,2}(H|HRS|HOUR|HIURS)$'),'/\d*'), '/') as denominator_value,
regexp_substr(regexp_substr(PRD_NAME,'/.{0,2}(H|HRS|HOUR|HOURS)$'),'H|HRS|HOUR|HOURS')
from drugs_for_strentgh where regexp_like(prd_name, '/.{0,2}(H|HRS|HOUR|HOURS)$') and mol_name not like '%/%'
;

--1 molecule where %--
insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,NUMERATOR_VALUE ,NUMERATOR_UNIT ,DENOMINATOR_UNIT )
SELECT fo_prd_id AS DRUG_CONCEPT_CODE, MOL_NAME AS INGREDIENT_NAME, cast(dosage as number)*10 AS NUMERATOR_VALUE, 'mg' as NUMERATOR_UNIT, 'ml' as DENOMINATOR_UNIT
FROM drugs_for_strentgh
WHERE mol_name not like '%/%' and unit2 is null and unit like '%!%%' escape '!' and fo_prd_id not in (select drug_concept_code from ds_strength_trainee)
;
--1 molecule not %--
insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,AMOUNT_VALUE,AMOUNT_UNIT)
SELECT fo_prd_id, MOL_NAME,DOSAGE,UNIT
from drugs_for_strentgh
WHERE mol_name not like '%/%' and unit2 is null and unit not like '%!%%' escape '!' and dosage2 is null and fo_prd_id not in (select drug_concept_code from ds_strength_trainee)
;


--1 molecule not % where dosage 2 not null--
insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,AMOUNT_VALUE,AMOUNT_UNIT)
SELECT fo_prd_id, MOL_NAME, DOSAGE,UNIT
from drugs_for_strentgh
where mol_name not like '%/%' and unit2 is null and unit not like '%!%%' escape '!' and dosage2 is not null and (prd_name like '%/__H%' or prd_name like '%(%MG)' or dosage2 = '-1') and fo_prd_id not in (select drug_concept_code from ds_strength_trainee)
;
--NEED MANUAL PROCEDURE( NEARLY 20 ROWS) WHERE CONCEPT_CLASS_ID = 'Drug Product' and mol_name not like '%/%' and unit2 is null and unit not like '%!%%' escape '!' and dosage2 is not null and NOT NULL  (prd_name like '%/__H%' or prd_name like '%(%MG)' or dosage2 = '-1')--



--liquid ingr with 1 molecule and no % anywhere--
insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,NUMERATOR_VALUE,NUMERATOR_UNIT, DENOMINATOR_VALUE,DENOMINATOR_UNIT )
SELECT fo_prd_id, MOL_NAME, DOSAGE, UNIT, DOSAGE2,UNIT2
FROM drugs_for_strentgh
where MOL_NAME  not like '%/%' and unit2 is not null and unit not like '%!%%' escape '!' and unit2 not like '%!%%' escape '!' and fo_prd_id not in (select drug_concept_code from ds_strength_trainee)
;


--NEED MANUAL PROCEDURE( NEARLY 40 ROWS) WHERE CONCEPT_CLASS_ID = 'Drug Product' and FO_PRODUCT.MOL_NAME  not like '%/%' and unit2 is not null and (unit like '%!%%' escape '!' or unit2  like '%!%%' escape '!')--

--multiple ingr--
--multiple with pattern ' -%-%-/'--
create or replace view multiple_liquid as
select FO_PRD_ID, PRD_NAME,regexp_replace(regexp_substr( prd_name, '(\d+(\.\d+)?\D*-)+\d+(\.\d+)?\D*'), '/.*') as AA,
regexp_substr(regexp_substr(regexp_substr(prd_name, '(\d+(\.\d+)?\D*-)+\d+(\.\d+)?\D*/.*'),'/\d+.*\s?'), '(\d+(\.\d)?)' ) as DENOMINATOR_VALUE ,
regexp_substr(regexp_substr(regexp_substr( prd_name, '(\d+(\.\d+)?\D*-)+\d+(\.\d+)?\D*/.*'),'/.*'), '(MG|IU|%|G|ML|MCG|MMOL|BILLION.*|MILLION.*|\D*UNITS.|L|LOZ|LOZENGE|µg|U){1}')  as DENOMINATOR_UNIT, mol_name
from
(select * from drugs_for_strentgh where regexp_like(prd_name, '(\d+(\.\d+)?\D*-)+\d+(\.\d+)?\D*/{1}\d?(\.\d+)?\D*') and MOL_NAME like '%/%')
;

create or replace view ds_multiple_liquid as
select FO_PRD_ID,PRD_NAME,G,
regexp_substr(W,'\d+(\.\d+)?') as numerator_value, 
regexp_substr(W,'MG|IU|%|G|ML|MCG|MMOL.*|BILLION.*|MILLION.*|\D*UNITS|DOSE|L|LOZ|µg|U') as numerator_unit,
DENOMINATOR_VALUE, DENOMINATOR_UNIT
from
(select FO_PRD_ID,PRD_NAME,DENOMINATOR_VALUE,DENOMINATOR_UNIT,
regexp_substr(AA, '[^-]+',1,level)as w,
regexp_substr(MOL_NAME , '[^/]+',1,level) as g 
from multiple_liquid
connect by FO_PRD_ID=prior FO_PRD_ID and prior dbms_random.value is not null 
and ( regexp_substr(AA, '[^-]+',1,level) is not null 
or regexp_substr(MOL_NAME , '[^/]+',1,level) is not null))
;
--multiple with pattern '/' --
create or replace view ds_multiple1 as
select FO_PRD_ID,PRD_NAME,A, mol_name from (
select regexp_substr(prd_name,'\d+.?\d*(MG|IU|%|G|ML|MCG|MMOL|BILLION.*|MILLION.*| \D*UNITS|L|LOZ|µg|U){1}/\d+.*') as A, PRD_NAME,FO_PRD_ID, mol_name
from drugs_for_strentgh 
where mol_name like '%/%' and FO_PRD_ID not in (select distinct FO_PRD_ID from ds_multiple_liquid)) where A is not null
;

--multiple with pattern '-'--
create or replace view ds_multiple2 as
select FO_PRD_ID, PRD_NAME, b, mol_name from (
select regexp_substr(prd_name,'\d.?\d*(MG|IU|%|G|ML|MCG|MMOL|BILLION.*|MILLION.*|\D*UNITS|L|LOZ|µg|U){1}-\d.*') as b, PRD_NAME,fo_prd_id, mol_name
from drugs_for_strentgh 
where mol_name like '%/%' and FO_PRD_ID not in (select distinct FO_PRD_ID from ds_multiple_liquid)) where b is not null
;
--connecticng ingredient to comp. dosage--

create table MULTIPLE_INGREDIENTS as
select FO_PRD_ID, PRD_NAME,
regexp_substr(A, '[^/]+',1,level)as w, 
regexp_substr(MOL_NAME , '[^/]+',1,level) as g 
from ds_multiple1
connect by FO_PRD_ID=prior FO_PRD_ID and prior dbms_random.value is not null 
and ( regexp_substr( A, '[^/]+',1,level) is not null 
or regexp_substr(MOL_NAME , '[^/]+',1,level) is not null)
union
select FO_PRD_ID, PRD_NAME,
regexp_substr(b, '[^-]+',1,level) w, 
regexp_substr(MOL_NAME , '[^/]+',1,level) 
from ds_multiple2
connect by FO_PRD_ID=prior FO_PRD_ID and prior dbms_random.value is not null 
and ( regexp_substr( b, '[^-]+',1,level) is not null 
or regexp_substr(MOL_NAME , '[^/]+',1,level) is not null)
;


insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME )
SELECT CONCEPT_CODE, BB.MOL_NAME
from DRUG_CONCEPT_STAGE JOIN
(select FO_PRD_ID, PRD_NAME, regexp_substr(W,'\d+(\.\d*)?') as dosage, regexp_substr (W,'MG|IU|%|G|ML|MCG|MMOL|BILLION.*|MILLION.*|\D*UNITS|L|LOZ|µg|U' ) as unit, g as mol_name from MULTIPLE_INGREDIENTS )BB
on CONCEPT_CODE = FO_PRD_ID 
where CONCEPT_CLASS_ID = 'Drug Product'  and (DOSAGE IS NULL OR UNIT IS NULL);


insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,NUMERATOR_VALUE ,NUMERATOR_UNIT ,DENOMINATOR_UNIT )
select CONCEPT_CODE AS DRUG_CONCEPT_CODE, AA.MOL_NAME AS INGREDIENT_NAME, cast(AA.dosage as number)*10 AS NUMERATOR_VALUE, 'mg' as NUMERATOR_UNIT, 'ml' as DENOMINATOR_UNIT
from DRUG_CONCEPT_STAGE JOIN
(select FO_PRD_ID, PRD_NAME, regexp_substr(W,'\d+(\.\d*)?') as dosage, regexp_substr (W,'MG|IU|%|G|ML|MCG|MMOL|BILLION.*|MILLION.*|\D*UNITS|L|LOZ|µg|U' ) as unit, g as mol_name from MULTIPLE_INGREDIENTS ) AA
on CONCEPT_CODE = FO_PRD_ID 
where CONCEPT_CLASS_ID = 'Drug Product' and unit like '%!%%' escape '!' 
;

insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,AMOUNT_VALUE,AMOUNT_UNIT)
SELECT CONCEPT_CODE, BB.MOL_NAME, BB.DOSAGE, BB.UNIT
from DRUG_CONCEPT_STAGE JOIN
(select FO_PRD_ID, PRD_NAME, regexp_substr(W,'\d+(\.\d*)?') as dosage, regexp_substr (W,'MG|IU|%|G|ML|MCG|MMOL|BILLION.*|MILLION.*|\D*UNITS|L|LOZ|µg|U' ) as unit, g as mol_name from MULTIPLE_INGREDIENTS )BB
on CONCEPT_CODE = FO_PRD_ID 
where CONCEPT_CLASS_ID = 'Drug Product'  and unit not like '%!%%' escape '!'
;
 insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,NUMERATOR_VALUE ,NUMERATOR_UNIT ,DENOMINATOR_VALUE, DENOMINATOR_UNIT )
 select FO_PRD_ID as DRUG_CONCEPT_CODE,G as INGREDIENT_NAME, NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT from ds_multiple_liquid;
 


create table ds_trainee_upd as
select DRUG_CONCEPT_CODE,INGREDIENT_NAME,regexp_substr(regexp_substr(PRD_NAME,'\d+\w+/(\d)?(\.)?(\d)?\w+'),'(\d+)\w+') as numerator, regexp_replace(regexp_substr(PRD_NAME,'\d+\w+/(\d)?(\.)?(\d)?\w+'),'(\d+)\w+/') as denominator
from ds_strength_trainee a join drugs_for_strentgh b on fo_prd_id=drug_Concept_code
where PRD_NAME like '%/%' and amount_value is not null and mol_name not like '%/%'
and not regexp_like (regexp_substr(PRD_NAME,'(\d)+\w+/(\d)?(\.)?(\d)?\w+'),'SPRAY|PUMP|SACHET|INHAL|PUFF|DROP|DOSE|CAP|DO|SQUARE|LOZ|ELECTROLYTES|APPLICATI|BLIS|VIAL|BLIST');


create table ds_trainee_upd_2 as
select DRUG_CONCEPT_CODE,INGREDIENT_NAME,
case when denominator='STRAIN' then '0.1' when  denominator='33' then '33.6' when denominator like '%2%'  then '24' else regexp_substr(DENOMINATOR,'\d+') end as denominator_value,
case when denominator like '%H%' then 'HOUR' when denominator like '%L%' then 'L' when denominator='33' then 'MG' when denominator='STRAIN' then 'ML' when denominator like '%ACTUA%' then 'ACTUATION'
 when denominator like '%2%' then 'HOUR' else regexp_replace(DENOMINATOR,'\d+') end as denominator_unit,
 regexp_replace(NUMERATOR,'\d+') as numerator_unit,
regexp_substr(NUMERATOR,'\d+') as numerator_value
from ds_trainee_upd


;



 
delete ds_strength_trainee 
where drug_concept_code in (select drug_concept_code from ds_stage_manual_all);      
insert into ds_strength_trainee select * from ds_stage_manual_all;
update ds_strength_trainee 
set DENOMINATOR_UNIT= 'ACTUATION' where drug_concept_code in (select drug_concept_code  from ds_strength_trainee join drugs on drug_concept_code = fo_prd_id  where PRD_NAME like '%DOSE') and NUMERATOR_UNIT is not null and DENOMINATOR_VALUE is null;
update ds_strength_trainee 
set DENOMINATOR_UNIT= 'ACTUATION', NUMERATOR_VALUE= AMOUNT_VALUE, NUMERATOR_UNIT= AMOUNT_UNIT, AMOUNT_VALUE = null , AMOUNT_UNIT= null
where drug_concept_code in (select drug_concept_code  from ds_strength_trainee join drugs on drug_concept_code = fo_prd_id  where PRD_NAME like '%DOSE' and denominator_unit is null);
update ds_strength_trainee 
set DENOMINATOR_UNIT = 'ml' where drug_concept_code in (select DRUG_CONCEPT_CODE from ds_strength_trainee join drugs on drug_concept_code = fo_prd_id  where regexp_like(prd_name,'-\d+\w+/\d+$') and mol_name like '%/%');
update ds_strength_trainee 
set DENOMINATOR_UNIT = 'ml' where DENOMINATOR_UNIT = 'ML';
update ds_strength_trainee set AMOUNT_VALUE = null, AMOUNT_UNIT = null where AMOUNT_VALUE= '0';
UPDATE DS_STRENGTH_TRAINEE  SET DENOMINATOR_UNIT = 'HOUR' WHERE DENOMINATOR_VALUE = '24';
UPDATE DS_STRENGTH_TRAINEE  SET DENOMINATOR_UNIT = 'HOUR' WHERE DENOMINATOR_UNIT  = 'H';
UPDATE DS_STRENGTH_TRAINEE  SET INGREDIENT_NAME = 'NICOTINAMIDE' WHERE INGREDIENT_NAME  = 'NICOTINIC ACID';
DELETE FROM DS_STRENGTH_TRAINEE WHERE DRUG_CONCEPT_CODE = '28058' AND INGREDIENT_NAME = 'NICOTINAMIDE' AND AMOUNT_VALUE= '20';
UPDATE DS_STRENGTH_TRAINEE SET AMOUNT_VALUE ='520' WHERE DRUG_CONCEPT_CODE = '28058' AND INGREDIENT_NAME = 'NICOTINAMIDE';
DELETE FROM DS_STRENGTH_TRAINEE WHERE DRUG_CONCEPT_CODE = '27625' AND INGREDIENT_NAME = 'NICOTINAMIDE' AND AMOUNT_VALUE= '25';
UPDATE DS_STRENGTH_TRAINEE SET AMOUNT_VALUE = '125' WHERE DRUG_CONCEPT_CODE = '27625' AND INGREDIENT_NAME = 'NICOTINAMIDE';
DELETE FROM DS_STRENGTH_TRAINEE WHERE DRUG_CONCEPT_CODE = '15248' AND INGREDIENT_NAME = 'SILYBUM MARIANUM' AND AMOUNT_VALUE= '1';
UPDATE DS_STRENGTH_TRAINEE SET AMOUNT_VALUE = '8' WHERE DRUG_CONCEPT_CODE = '15248' AND INGREDIENT_NAME = 'SILYBUM MARIANUM';
DELETE FROM DS_STRENGTH_TRAINEE WHERE DRUG_CONCEPT_CODE = '88716' AND INGREDIENT_NAME = 'NICOTINAMIDE';
INSERT INTO DS_STRENGTH_TRAINEE (DRUG_CONCEPT_CODE,INGREDIENT_NAME) VALUES ('88716','NICOTINAMIDE');
update DS_STRENGTH_TRAINEE set  AMOUNT_UNIT = TRIM(regexp_replace(AMOUNT_UNIT,'S$'))   where  regexp_like (AMOUNT_UNIT,'^\s');
update DS_STRENGTH_TRAINEE set  NUMERATOR_UNIT = TRIM(regexp_replace(NUMERATOR_UNIT,'S$'))   where  regexp_like (NUMERATOR_UNIT,'^\s');
update DS_STRENGTH_TRAINEE set  DENOMINATOR_UNIT = TRIM(regexp_replace(DENOMINATOR_UNIT,'S$'))   where  regexp_like (DENOMINATOR_UNIT,'^\s');


truncate table ds_stage;
 insert into ds_stage (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
 select DRUG_CONCEPT_CODE,concept_code,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT from ds_strength_trainee join drug_concept_stage 
 on ingredient_name = concept_name where concept_class_id ='Ingredient';

--some new units appeared--
insert into DRUG_concept_STAGE (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select amount_unit,'AMT','Unit','',amount_unit,'Drug', TO_DATE('2016/10/01', 'yyyy/mm/dd'),TO_DATE('2099/12/31', 'yyyy/mm/dd'), ''
 from (select amount_unit from ds_strength_trainee union select NUMERATOR_UNIT from ds_strength_trainee union select DENOMINATOR_UNIT from ds_strength_trainee minus (select concept_name from DRUG_concept_STAGE where concept_class_id like 'Unit'))
 WHERE AMOUNT_UNIT IS NOT NULL;


create table relation_brandname_1 as
select d.concept_name, concept_id, r.concept_name as R from drug_concept_stage d
inner join devv5.concept r on trim(lower(d.concept_name)) = trim(lower(r.concept_name))  WHERE  d.concept_class_id like '%Brand%' and r.VOCABULARY_ID like '%Rx%' 
and r.INVALID_REASON is null AND r.concept_class_id like '%Brand Name%'
;
insert into relation_brandname_1
select CONCEPT_NAME,CONCEPT_ID_2,CONCEPT_NAME_2 from RELATION_MANUAL_BN;


create table RELATION_INGR_1 as
select d.concept_name, concept_id, r.concept_name as R from drug_concept_stage d
inner join devv5.concept r on trim(lower(d.concept_name)) = trim(lower(r.concept_name)) 
where  d.concept_class_id like '%Ingredient%' and r.VOCABULARY_ID like '%Rx%' and r.INVALID_REASON is null
and r.concept_class_id like 'Ingredient%'
; 


insert into RELATION_INGR_1
select d.concept_name, concept_id, CONCEPT_SYNONYM_NAME as R from drug_concept_stage d
inner join devv5.CONCEPT_SYNONYM r on trim(lower(d.concept_name)) = trim(lower(CONCEPT_SYNONYM_NAME)) 
where  d.concept_class_id like '%Ingredient%' and concept_id in  (select concept_id from devv5.concept where VOCABULARY_ID like '%Rx%' and INVALID_REASON is null
and concept_class_id like 'Ingredient%') and concept_code not in (select concept_code from RELATION_INGR_1)
;
insert into RELATION_INGR_1
select CONCEPT_NAME,CONCEPT_ID_2,CONCEPT_NAME_2 from RELATION_MANUAL_INGR;
 alter table RELATION_INGR_1
 add PRECEDENCE number;
 
 DELETE FROM RELATION_INGR_1 WHERE CONCEPT_NAME = 'AESCULUS HIPPOCASTANUM' AND   CONCEPT_ID = 44818465 AND   PRECEDENCE IS NULL;
DELETE FROM RELATION_INGR_1 WHERE CONCEPT_NAME = 'APRICOT' AND   CONCEPT_ID = 40170375 AND   PRECEDENCE IS NULL;
DELETE FROM RELATION_INGR_1 WHERE CONCEPT_NAME = 'APRICOT' AND   CONCEPT_ID = 42904131 AND   PRECEDENCE IS NULL;
DELETE FROM RELATION_INGR_1 WHERE CONCEPT_NAME = 'APRICOT' AND   CONCEPT_ID = 42900392 AND   PRECEDENCE IS NULL;
DELETE FROM RELATION_INGR_1 WHERE CONCEPT_NAME = 'APRICOT' AND   CONCEPT_ID = 42900393 AND   PRECEDENCE IS NULL;
DELETE FROM RELATION_INGR_1 WHERE CONCEPT_NAME = 'BUTYLENE GLYCOL' AND   CONCEPT_ID = 35605008 AND   PRECEDENCE IS NULL;
DELETE FROM RELATION_INGR_1 WHERE CONCEPT_NAME = 'BUTYLENE GLYCOL' AND   CONCEPT_ID = 46221190 AND   PRECEDENCE IS NULL;
DELETE FROM RELATION_INGR_1 WHERE CONCEPT_NAME = 'BUTYLENE GLYCOL' AND   CONCEPT_ID = 43533041 AND   PRECEDENCE IS NULL;
DELETE FROM RELATION_INGR_1 WHERE CONCEPT_NAME = 'BUTYLENE GLYCOL' AND   CONCEPT_ID = 43532985 AND   PRECEDENCE IS NULL;
DELETE FROM RELATION_INGR_1 WHERE CONCEPT_NAME = 'HOPS' AND   CONCEPT_ID = 35603443 AND   PRECEDENCE IS NULL;
DELETE FROM RELATION_INGR_1 WHERE CONCEPT_NAME = 'SUNFLOWER' AND   CONCEPT_ID = 40172580 AND   PRECEDENCE IS NULL;
DELETE FROM RELATION_INGR_1 WHERE CONCEPT_NAME = 'SUNFLOWER' AND   CONCEPT_ID = 40162079 AND   PRECEDENCE IS NULL;
DELETE FROM RELATION_INGR_1 WHERE CONCEPT_NAME = 'SUNFLOWER' AND   CONCEPT_ID = 42900564 AND   PRECEDENCE IS NULL;
DELETE FROM RELATION_INGR_1 WHERE CONCEPT_NAME = 'THYME' AND   CONCEPT_ID = 43013853 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'ACACIA' AND   CONCEPT_ID = 44784661 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'ACACIA' AND   CONCEPT_ID = 40160955 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'ACACIA' AND   CONCEPT_ID = 40170299 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'ACACIA' AND   CONCEPT_ID = 35606015 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'ACACIA' AND   CONCEPT_ID = 46221189 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'ACACIA' AND   CONCEPT_ID = 42628986 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 7 WHERE CONCEPT_NAME = 'ACACIA' AND   CONCEPT_ID = 43012212 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 8 WHERE CONCEPT_NAME = 'ACACIA' AND   CONCEPT_ID = 44785547 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 9 WHERE CONCEPT_NAME = 'ACACIA' AND   CONCEPT_ID = 46233723 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 10 WHERE CONCEPT_NAME = 'ACACIA' AND   CONCEPT_ID = 45775957 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 11 WHERE CONCEPT_NAME = 'ACACIA' AND   CONCEPT_ID = 40169251 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 12 WHERE CONCEPT_NAME = 'ACACIA' AND   CONCEPT_ID = 43013270 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'AESCULUS HIPPOCASTANUM' AND   CONCEPT_ID = 42898420 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'AESCULUS HIPPOCASTANUM' AND   CONCEPT_ID = 42898419 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'AESCULUS HIPPOCASTANUM' AND   CONCEPT_ID = 42898418 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'ALISMA' AND   CONCEPT_ID = 45776741 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'ALISMA' AND   CONCEPT_ID = 43532995 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'ALISMA' AND   CONCEPT_ID = 43525880 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 9 WHERE CONCEPT_NAME = 'ALOES' AND   CONCEPT_ID = 45892130 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'ALOES' AND   CONCEPT_ID = 42903463 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'ALOES' AND   CONCEPT_ID = 1315376 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'ALOES' AND   CONCEPT_ID = 35605242 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'ALOES' AND   CONCEPT_ID = 42900341 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'ALOES' AND   CONCEPT_ID = 42900340 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 7 WHERE CONCEPT_NAME = 'ALOES' AND   CONCEPT_ID = 958994 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 8 WHERE CONCEPT_NAME = 'ALOES' AND   CONCEPT_ID = 42898390 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'ALOES' AND   CONCEPT_ID = 960900 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 10 WHERE CONCEPT_NAME = 'ALOES' AND   CONCEPT_ID = 43526564 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 11 WHERE CONCEPT_NAME = 'ALOES' AND   CONCEPT_ID = 43525966 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'ALPINA GALANGA' AND   CONCEPT_ID = 42899009 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'ALPINA GALANGA' AND   CONCEPT_ID = 35606084 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'ALPINA GALANGA' AND   CONCEPT_ID = 42898393 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'ALTHAEA OFFICINALIS' AND   CONCEPT_ID = 43533001 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'ALTHAEA OFFICINALIS' AND   CONCEPT_ID = 42898411 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'ALTHAEA OFFICINALIS' AND   CONCEPT_ID = 42898264 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'ALTHAEA OFFICINALIS' AND   CONCEPT_ID = 43560012 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 23 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 43125909 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 22 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 43013356 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 21 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 42898332 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 20 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 1319232 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 19 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 42898279 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 18 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 46221714 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 17 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 42898278 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 16 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 44814302 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 15 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 42898331 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 14 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 46234378 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 13 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 42898330 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 12 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 45776245 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 11 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 42898329 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 10 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 44814270 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 9 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 45775258 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 8 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 42898328 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 7 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 46221691 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 43012497 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 43560461 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 42898327 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 42898326 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 43525819 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'ANGELICA' AND   CONCEPT_ID = 42898325 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'APRICOT' AND   CONCEPT_ID = 42903960 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'APRICOT' AND   CONCEPT_ID = 43533033 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'ARCTIUM' AND   CONCEPT_ID = 42903466 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'ARCTIUM' AND   CONCEPT_ID = 45776103 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'ARCTIUM' AND   CONCEPT_ID = 42898350 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'ARCTOSTAPHYLOS UVA-URSI' AND   CONCEPT_ID = 46275331 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'ARCTOSTAPHYLOS UVA-URSI' AND   CONCEPT_ID = 42900397 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'ARNICA MONTANA' AND   CONCEPT_ID = 42898360 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'ARNICA MONTANA' AND   CONCEPT_ID = 44785117 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'ARNICA MONTANA' AND   CONCEPT_ID = 19071833 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'ASPARAGUS' AND   CONCEPT_ID = 43125996 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'ASPARAGUS' AND   CONCEPT_ID = 42900400 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'ASPARAGUS' AND   CONCEPT_ID = 44784670 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'AVENA SATIVA' AND   CONCEPT_ID = 42903740 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'AVENA SATIVA' AND   CONCEPT_ID = 42898638 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'AVENA SATIVA' AND   CONCEPT_ID = 42898637 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'BACILLUS CALMETTE-GUERIN' AND   CONCEPT_ID = 19015423 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'BACILLUS CALMETTE-GUERIN' AND   CONCEPT_ID = 19086176 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'BACILLUS CALMETTE-GUERIN' AND   CONCEPT_ID = 19013730 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'BACILLUS CALMETTE-GUERIN' AND   CONCEPT_ID = 19023835 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'BAPTISIA' AND   CONCEPT_ID = 42898622 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'BAPTISIA' AND   CONCEPT_ID = 42904304 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'BIFIDOBACTERIUM' AND   CONCEPT_ID = 40242573 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'BIFIDOBACTERIUM' AND   CONCEPT_ID = 40242566 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'BIFIDOBACTERIUM' AND   CONCEPT_ID = 19136097 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'BIFIDOBACTERIUM' AND   CONCEPT_ID = 19006764 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'BIFIDOBACTERIUM' AND   CONCEPT_ID = 45776867 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'BILBERRY' AND   CONCEPT_ID = 44784998 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'BILBERRY' AND   CONCEPT_ID = 43525782 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'BILBERRY' AND   CONCEPT_ID = 1314955 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'BRYONIA' AND   CONCEPT_ID = 19015636 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'BRYONIA' AND   CONCEPT_ID = 42904031 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'BRYONIA' AND   CONCEPT_ID = 42904146 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'BRYONIA' AND   CONCEPT_ID = 42898489 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'BUPLEURUM' AND   CONCEPT_ID = 42898494 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'BUPLEURUM' AND   CONCEPT_ID = 42898493 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'CALENDULA' AND   CONCEPT_ID = 43532988 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'CALENDULA' AND   CONCEPT_ID = 42898557 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'CALENDULA' AND   CONCEPT_ID = 42898771 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'CALENDULA' AND   CONCEPT_ID = 42898770 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'CALENDULA' AND   CONCEPT_ID = 19071836 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'CALENDULA' AND   CONCEPT_ID = 35604983 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'CAMELLIA SINENSIS' AND   CONCEPT_ID = 42904180 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'CAMELLIA SINENSIS' AND   CONCEPT_ID = 43012418 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'CAMELLIA SINENSIS' AND   CONCEPT_ID = 35606317 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'CAMELLIA SINENSIS' AND   CONCEPT_ID = 42898782 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'CAMELLIA SINENSIS' AND   CONCEPT_ID = 42898781 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'CAPSICUM' AND   CONCEPT_ID = 19055492 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'CAPSICUM' AND   CONCEPT_ID = 915553 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'CAPSICUM' AND   CONCEPT_ID = 42903902 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'CENTELLA ASIATICA' AND   CONCEPT_ID = 42898717 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'CENTELLA ASIATICA' AND   CONCEPT_ID = 42898716 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'CHAMOMILE' AND   CONCEPT_ID = 19052620 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'CHAMOMILE' AND   CONCEPT_ID = 42898758 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'CHELIDONIUM' AND   CONCEPT_ID = 43013541 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'CHELIDONIUM' AND   CONCEPT_ID = 43560075 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'CHELIDONIUM' AND   CONCEPT_ID = 19071835 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'CHONDROITIN' AND   CONCEPT_ID = 1395573 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'CHONDROITIN' AND   CONCEPT_ID = 42903714 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET CONCEPT_ID = 45776108,
       PRECEDENCE = 1 WHERE CONCEPT_NAME = 'CIMICIFUGA' AND   CONCEPT_ID = 45776108 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET CONCEPT_ID = 42898407,
       PRECEDENCE = 2 WHERE CONCEPT_NAME = 'CIMICIFUGA' AND   CONCEPT_ID = 42898407 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'COMFREY' AND   CONCEPT_ID = 42904063 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'COMFREY' AND   CONCEPT_ID = 42903951 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'CORDYCEPS' AND   CONCEPT_ID = 43532068 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'CORDYCEPS' AND   CONCEPT_ID = 19070923 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'CORDYCEPS' AND   CONCEPT_ID = 45892323 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'COWSLIP' AND   CONCEPT_ID = 44785730 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'COWSLIP' AND   CONCEPT_ID = 42899873 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'DIOSCOREA' AND   CONCEPT_ID = 42899038 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'DIOSCOREA' AND   CONCEPT_ID = 46221697 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'DIOSCOREA' AND   CONCEPT_ID = 42899037 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'DIOSCOREA' AND   CONCEPT_ID = 42899036 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'DONG QUAI' AND   CONCEPT_ID = 43013356 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'DONG QUAI' AND   CONCEPT_ID = 42898332 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'DONG QUAI' AND   CONCEPT_ID = 1319232 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'ECHINACEA' AND   CONCEPT_ID = 1359148 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'ECHINACEA' AND   CONCEPT_ID = 1398816 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'ECHINACEA' AND   CONCEPT_ID = 42899040 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'ECHINACEA' AND   CONCEPT_ID = 1399063 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 7 WHERE CONCEPT_NAME = 'ECHINACEA' AND   CONCEPT_ID = 19059159 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'ECHINACEA' AND   CONCEPT_ID = 1389112 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 8 WHERE CONCEPT_NAME = 'ECHINACEA' AND   CONCEPT_ID = 40175995 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'ECHINACEA' AND   CONCEPT_ID = 43012668 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 9 WHERE CONCEPT_NAME = 'ECHINACEA' AND   CONCEPT_ID = 1398677 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 10 WHERE CONCEPT_NAME = 'ECHINACEA' AND   CONCEPT_ID = 42899031 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 11 WHERE CONCEPT_NAME = 'ECHINACEA' AND   CONCEPT_ID = 1391199 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 12 WHERE CONCEPT_NAME = 'ECHINACEA' AND   CONCEPT_ID = 1304233 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'EPOETIN' AND   CONCEPT_ID = 21014076 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'EPOETIN' AND   CONCEPT_ID = 21014072 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'EPOETIN' AND   CONCEPT_ID = 21014058 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'EPOETIN' AND   CONCEPT_ID = 19001311 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'EPOETIN' AND   CONCEPT_ID = 1301125 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'EQUISETUM ARVENSE' AND   CONCEPT_ID = 44818471 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'EQUISETUM ARVENSE' AND   CONCEPT_ID = 42899033 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'EQUISETUM ARVENSE' AND   CONCEPT_ID = 42899032 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'EUPHORBIA' AND   CONCEPT_ID = 43525792 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'EUPHORBIA' AND   CONCEPT_ID = 42898972 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'EUPHORBIA' AND   CONCEPT_ID = 35605011 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'EUPHORBIA' AND   CONCEPT_ID = 42904037 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'EUPHORBIA' AND   CONCEPT_ID = 45776415 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'EUPHORBIA' AND   CONCEPT_ID = 42904088 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 7 WHERE CONCEPT_NAME = 'EUPHORBIA' AND   CONCEPT_ID = 45776145 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 8 WHERE CONCEPT_NAME = 'EUPHRASIA' AND   CONCEPT_ID = 42904127 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 9 WHERE CONCEPT_NAME = 'EUPHRASIA' AND   CONCEPT_ID = 1304412 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'FENUGREEK' AND   CONCEPT_ID = 19037415 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'FENUGREEK' AND   CONCEPT_ID = 19004145 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'FENUGREEK' AND   CONCEPT_ID = 42900516 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'FRANGULA' AND   CONCEPT_ID = 43125917 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'FRANGULA' AND   CONCEPT_ID = 42904096 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'FRANGULA' AND   CONCEPT_ID = 19016537 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'FRANGULA' AND   CONCEPT_ID = 42898997 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'FRANGULA' AND   CONCEPT_ID = 42898996 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'GYMNEMA SYLVESTRE' AND   CONCEPT_ID = 19070953 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'GYMNEMA SYLVESTRE' AND   CONCEPT_ID = 44816309 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'HAMAMELIS' AND   CONCEPT_ID = 42903910 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'HAMAMELIS' AND   CONCEPT_ID = 42899159 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'HAMAMELIS' AND   CONCEPT_ID = 42899158 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'HAMAMELIS' AND   CONCEPT_ID = 42899157 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'HAMAMELIS' AND   CONCEPT_ID = 42899156 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'HAMAMELIS' AND   CONCEPT_ID = 42899155 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 7 WHERE CONCEPT_NAME = 'HAMAMELIS' AND   CONCEPT_ID = 42899154 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 8 WHERE CONCEPT_NAME = 'HAMAMELIS' AND   CONCEPT_ID = 42899153 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'HEPATITIS A VACCINE' AND   CONCEPT_ID = 44814322 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'HEPATITIS A VACCINE' AND   CONCEPT_ID = 596876 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'HOPS' AND   CONCEPT_ID = 21014134 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'HOPS' AND   CONCEPT_ID = 1398499 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'HYALURONIC ACID' AND   CONCEPT_ID = 787787 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'HYALURONIC ACID' AND   CONCEPT_ID = 798336 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'HYDRASTIS' AND   CONCEPT_ID = 19013826 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'HYDRASTIS' AND   CONCEPT_ID = 42903884 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'HYPERICUM PERFORATUM' AND   CONCEPT_ID = 42899140 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'HYPERICUM PERFORATUM' AND   CONCEPT_ID = 42899138 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'INSULIN ZINC' AND   CONCEPT_ID = 1562586 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'INSULIN ZINC' AND   CONCEPT_ID = 1513849 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'IVY' AND   CONCEPT_ID = 19091179 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'IVY' AND   CONCEPT_ID = 43125950 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'LINOLEIC ACID' AND   CONCEPT_ID = 19070929 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'LINOLEIC ACID' AND   CONCEPT_ID = 19100751 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'LYCOPERSICON' AND   CONCEPT_ID = 46234076 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'LYCOPERSICON' AND   CONCEPT_ID = 43013842 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'MAGNOLIA OFFICINALIS' AND   CONCEPT_ID = 42899334 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'MAGNOLIA OFFICINALIS' AND   CONCEPT_ID = 42899333 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'MAIZE STARCH' AND   CONCEPT_ID = 43532428 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'MAIZE STARCH' AND   CONCEPT_ID = 43532010 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'MAIZE STARCH' AND   CONCEPT_ID = 43012351 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'MELALEUCA' AND   CONCEPT_ID = 43526876 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'MELALEUCA' AND   CONCEPT_ID = 44785700 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'MELALEUCA' AND   CONCEPT_ID = 42899420 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'MELALEUCA' AND   CONCEPT_ID = 43560198 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'MELISSA OFFICINALIS' AND   CONCEPT_ID = 42899427 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'MELISSA OFFICINALIS' AND   CONCEPT_ID = 42899426 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'MELISSA OFFICINALIS' AND   CONCEPT_ID = 42899425 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'MENTHA PIPERITA' AND   CONCEPT_ID = 42899303 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'MENTHA PIPERITA' AND   CONCEPT_ID = 42904027 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'METHOHEXITONE' AND   CONCEPT_ID = 21014071 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'METHOHEXITONE' AND   CONCEPT_ID = 19005015 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'OLEA EUROPAEA' AND   CONCEPT_ID = 43526293 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'OLEA EUROPAEA' AND   CONCEPT_ID = 42899542 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'OLEA EUROPAEA' AND   CONCEPT_ID = 42899640 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'OLEA EUROPAEA' AND   CONCEPT_ID = 42904017 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'OLEA EUROPAEA' AND   CONCEPT_ID = 43526292 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'OLEA EUROPAEA' AND   CONCEPT_ID = 35606159 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 9 WHERE CONCEPT_NAME = 'PAEONIA' AND   CONCEPT_ID = 43526289 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 8 WHERE CONCEPT_NAME = 'PAEONIA' AND   CONCEPT_ID = 42899590 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 7 WHERE CONCEPT_NAME = 'PAEONIA' AND   CONCEPT_ID = 42899589 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'PAEONIA' AND   CONCEPT_ID = 35604868 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'PAEONIA' AND   CONCEPT_ID = 44814385 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'PAEONIA' AND   CONCEPT_ID = 42899588 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'PAEONIA' AND   CONCEPT_ID = 44814384 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'PAEONIA' AND   CONCEPT_ID = 42899587 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'PAEONIA' AND   CONCEPT_ID = 45776221 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'PANAX GINSENG' AND   CONCEPT_ID = 43013750 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'PANAX GINSENG' AND   CONCEPT_ID = 42899598 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'PANAX GINSENG' AND   CONCEPT_ID = 42899597 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'PANAX GINSENG' AND   CONCEPT_ID = 42899596 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'PASSIFLORA INCARNATA' AND   CONCEPT_ID = 35606039 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'PASSIFLORA INCARNATA' AND   CONCEPT_ID = 42899545 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'PASSIFLORA INCARNATA' AND   CONCEPT_ID = 43525821 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'PASSIFLORA INCARNATA' AND   CONCEPT_ID = 35603949 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'PASSIFLORA INCARNATA' AND   CONCEPT_ID = 42899632 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 7 WHERE CONCEPT_NAME = 'PASSIFLORA INCARNATA' AND   CONCEPT_ID = 42904145 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'PASSIFLORA INCARNATA' AND   CONCEPT_ID = 19065820 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'PERILLA FRUTESCENS' AND   CONCEPT_ID = 42899557 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'PERILLA FRUTESCENS' AND   CONCEPT_ID = 42899602 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'PERILLA FRUTESCENS' AND   CONCEPT_ID = 42899556 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'PERILLA FRUTESCENS' AND   CONCEPT_ID = 42899601 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'PERILLA FRUTESCENS' AND   CONCEPT_ID = 42899600 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'PLANTAGO MAJOR' AND   CONCEPT_ID = 42899920 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'PLANTAGO MAJOR' AND   CONCEPT_ID = 42899919 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'PLANTAGO MAJOR' AND   CONCEPT_ID = 42899918 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'POLIOMYELITIS VACCINE - INACTIVATED' AND   CONCEPT_ID = 523367 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'POLIOMYELITIS VACCINE - INACTIVATED' AND   CONCEPT_ID = 523365 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'POLIOMYELITIS VACCINE - INACTIVATED' AND   CONCEPT_ID = 523283 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'POLYGONUM CUSPIDATUM' AND   CONCEPT_ID = 43526319 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'POLYGONUM CUSPIDATUM' AND   CONCEPT_ID = 42899950 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'POLYGONUM CUSPIDATUM' AND   CONCEPT_ID = 44814593 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'POLYOXYL HYDROGENATED CASTOR OILS' AND   CONCEPT_ID = 42899578 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'POLYOXYL HYDROGENATED CASTOR OILS' AND   CONCEPT_ID = 43532079 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'POLYOXYL HYDROGENATED CASTOR OILS' AND   CONCEPT_ID = 42899576 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'POMEGRANATE' AND   CONCEPT_ID = 42899579 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'POMEGRANATE' AND   CONCEPT_ID = 42904274 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET R = 'Pomegranate Extract',
       PRECEDENCE = 1 WHERE CONCEPT_NAME = 'POMEGRANATE' AND   CONCEPT_ID = 1315003 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'POPULUS' AND   CONCEPT_ID = 42899867 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'POPULUS' AND   CONCEPT_ID = 42899866 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'POPULUS' AND   CONCEPT_ID = 45774934 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'POPULUS' AND   CONCEPT_ID = 42899865 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'POPULUS' AND   CONCEPT_ID = 43533010 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'PRUNUS SEROTINA' AND   CONCEPT_ID = 42899963 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'PRUNUS SEROTINA' AND   CONCEPT_ID = 42899962 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'QUASSIA' AND   CONCEPT_ID = 42899832 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'QUASSIA' AND   CONCEPT_ID = 43013798 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'RABIES VACCINE' AND   CONCEPT_ID = 544411 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'RABIES VACCINE' AND   CONCEPT_ID = 544505 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'REHMANNIA' AND   CONCEPT_ID = 44814419 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'REHMANNIA' AND   CONCEPT_ID = 42899772 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'RHUBARB' AND   CONCEPT_ID = 19060995 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'RHUBARB' AND   CONCEPT_ID = 44814229 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'RUMEX ACETOSA' AND   CONCEPT_ID = 35605326 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'RUMEX ACETOSA' AND   CONCEPT_ID = 43012310 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'SALIX' AND   CONCEPT_ID = 44814431 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'SALIX' AND   CONCEPT_ID = 42903421 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'SALIX' AND   CONCEPT_ID = 45892775 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 9 WHERE CONCEPT_NAME = 'SALIX' AND   CONCEPT_ID = 36249385 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'SALIX' AND   CONCEPT_ID = 42899714 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'SALIX' AND   CONCEPT_ID = 42899713 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 7 WHERE CONCEPT_NAME = 'SALIX' AND   CONCEPT_ID = 44816296 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 8 WHERE CONCEPT_NAME = 'SALIX' AND   CONCEPT_ID = 42899734 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'SALIX' AND   CONCEPT_ID = 42899712 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'SALVIA OFFICINALIS' AND   CONCEPT_ID = 44507633 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'SALVIA OFFICINALIS' AND   CONCEPT_ID = 44785368 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'SAMBUCUS' AND   CONCEPT_ID = 43012403 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'SAMBUCUS' AND   CONCEPT_ID = 35603511 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'SAMBUCUS' AND   CONCEPT_ID = 42899721 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'SAMBUCUS' AND   CONCEPT_ID = 42899720 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'SAMBUCUS' AND   CONCEPT_ID = 42904069 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'SAMBUCUS' AND   CONCEPT_ID = 43526356 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 7 WHERE CONCEPT_NAME = 'SARSAPARILLA' AND   CONCEPT_ID = 42899741 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'SARSAPARILLA' AND   CONCEPT_ID = 19056120 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'SCUTELLARIA' AND   CONCEPT_ID = 42899758 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'SCUTELLARIA' AND   CONCEPT_ID = 46233905 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'SCUTELLARIA' AND   CONCEPT_ID = 46275334 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'SCUTELLARIA' AND   CONCEPT_ID = 42899757 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'SCUTELLARIA' AND   CONCEPT_ID = 45775042 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'SENEGA' AND   CONCEPT_ID = 46234431 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'SENEGA' AND   CONCEPT_ID = 42899945 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'SENNA' AND   CONCEPT_ID = 19086491 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'SENNA' AND   CONCEPT_ID = 44507644 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'SENNA' AND   CONCEPT_ID = 45893009 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'SENNA' AND   CONCEPT_ID = 992409 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'SENNA' AND   CONCEPT_ID = 960820 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'SENNA' AND   CONCEPT_ID = 42899777 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 7 WHERE CONCEPT_NAME = 'SENNA' AND   CONCEPT_ID = 43526359 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 8 WHERE CONCEPT_NAME = 'SENNA' AND   CONCEPT_ID = 42899776 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'SOLIDAGO' AND   CONCEPT_ID = 46275329 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'SOLIDAGO' AND   CONCEPT_ID = 42899753 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'SOLIDAGO' AND   CONCEPT_ID = 42900078 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'SOLIDAGO' AND   CONCEPT_ID = 42903632 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'SOLIDAGO' AND   CONCEPT_ID = 42900077 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = NULL WHERE CONCEPT_NAME = 'SUNFLOWER' AND   CONCEPT_ID = 19040871 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'TAGETES' AND   CONCEPT_ID = 43012993 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'TAGETES' AND   CONCEPT_ID = 45774892 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'TAGETES' AND   CONCEPT_ID = 42900218 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'TAMARIND' AND   CONCEPT_ID = 42900219 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'TAMARIND' AND   CONCEPT_ID = 46234396 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'TARAXACUM' AND   CONCEPT_ID = 42900228 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'TARAXACUM' AND   CONCEPT_ID = 42900227 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'TARAXACUM' AND   CONCEPT_ID = 42900225 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'TARAXACUM' AND   CONCEPT_ID = 46234392 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'TARAXACUM' AND   CONCEPT_ID = 45776231 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'THUJA' AND   CONCEPT_ID = 42900084 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'THUJA' AND   CONCEPT_ID = 42904249 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'THUJA' AND   CONCEPT_ID = 42900083 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'THUJA' AND   CONCEPT_ID = 19082629 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'THUJA' AND   CONCEPT_ID = 42900082 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'THUJA' AND   CONCEPT_ID = 42900081 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 7 WHERE CONCEPT_NAME = 'THUJA' AND   CONCEPT_ID = 42900080 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'THYME' AND   CONCEPT_ID = 19060834 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'TRIFOLIUM PRATENSE' AND   CONCEPT_ID = 42904049 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'TRIFOLIUM PRATENSE' AND   CONCEPT_ID = 43013016 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'TRIFOLIUM PRATENSE' AND   CONCEPT_ID = 42900047 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'URTICA' AND   CONCEPT_ID = 42900056 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'URTICA' AND   CONCEPT_ID = 19071810 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'URTICA' AND   CONCEPT_ID = 43013863 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'URTICA' AND   CONCEPT_ID = 1315629 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 5 WHERE CONCEPT_NAME = 'URTICA' AND   CONCEPT_ID = 42900055 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 6 WHERE CONCEPT_NAME = 'URTICA' AND   CONCEPT_ID = 19097592 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 7 WHERE CONCEPT_NAME = 'URTICA' AND   CONCEPT_ID = 42900054 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'VALERIAN' AND   CONCEPT_ID = 44818506 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'VALERIAN' AND   CONCEPT_ID = 1397059 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 1 WHERE CONCEPT_NAME = 'VITIS VINIFERA' AND   CONCEPT_ID = 42900068 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 2 WHERE CONCEPT_NAME = 'VITIS VINIFERA' AND   CONCEPT_ID = 35606157 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 3 WHERE CONCEPT_NAME = 'VITIS VINIFERA' AND   CONCEPT_ID = 43525901 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE = 4 WHERE CONCEPT_NAME = 'VITIS VINIFERA' AND   CONCEPT_ID = 42900062 AND   PRECEDENCE IS NULL;
UPDATE RELATION_INGR_1    SET PRECEDENCE  = 1 WHERE PRECEDENCE is null;
update  RELATION_INGR_1
set concept_name= regexp_substr(concept_name, '[^"].*[^"]');
update  RELATION_INGR_1
set r =regexp_substr(r, '[^"].*[^"]');


--adding all to realtionship_to_concept--

truncate table RELATIONSHIP_TO_CONCEPT
;
insert into RELATIONSHIP_TO_CONCEPT
(CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE)
select b.concept_code, 'AMT',a .concept_id,a.precedence from aus_dose_forms_done a join drug_concept_stage b on a.dose_form=b.concept_name 
union 
select CONCEPT_CODE,'AMT',CONCEPT_ID,PRECEDENCE from RELATION_INGR_1 a join drug_concept_stage b on a.concept_name= b. concept_name where b.concept_class_id = 'Ingredient' 
;
insert into RELATIONSHIP_TO_CONCEPT
(CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2)
select CONCEPT_CODE,'AMT',CONCEPT_ID from relation_brandname_1 a join drug_concept_stage b on a.concept_name= b. concept_name where b.concept_class_id = 'Brand Name' 
union 
select CONCEPT_CODE, 'AMT',CONCEPT_ID from manual_supp a join drug_concept_stage b on a.concept_name= b. concept_name where b.concept_class_id = 'Supplier' 
;
insert into RELATIONSHIP_TO_CONCEPT
(CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select CONCEPT_CODE,'AMT',CONCEPT_ID_2,PRECEDENCE,CONVERSTION_FACTOR from relation_to_concept_unit
;
update RELATIONSHIP_TO_CONCEPT
set PRECEDENCE = '1' where PRECEDENCE is null
;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 43126201 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 43126196 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 21019309 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 21019140 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 21020637 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 19131388 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 21020344 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 21020318 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 21019596 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 21019581 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 43132698 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 43132581 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 21020344 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 21020318 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 21019596 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 43132698 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 21020360 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 43132496 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 19052251 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 43132849 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 43132829 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 43132600 AND   PRECEDENCE = 1;
DELETE FROM RELATIONSHIP_TO_CONCEPT WHERE CONCEPT_ID_2 = 43132357 AND   PRECEDENCE = 1;
UPDATE RELATIONSHIP_TO_CONCEPT  SET PRECEDENCE = 2 WHERE CONCEPT_ID_2 = 43012668 AND   PRECEDENCE = 3;
--pc stage--
truncate table pc_stage;
insert into pc_stage (PACK_CONCEPT_CODE,DRUG_CONCEPT_CODE,AMOUNT)
select FO_PRD_ID,CONCEPT_CODE,AMOUNT_PACK from pack_drug_product
join drug_concept_stage on PRD_NAME=concept_name;
--INTERNAL_RELATIONSHIP_STAGE--
truncate table INTERNAL_RELATIONSHIP_STAGE;
insert into INTERNAL_RELATIONSHIP_STAGE (CONCEPT_CODE_1, CONCEPT_CODE_2)
select distinct fo_prd_id as CONCEPT_CODE_1,CONCEPT_CODE as concept_code_2 
from drugs inner join (select CONCEPT_NAME, CONCEPT_CODE from DRUG_CONCEPT_STAGE where CONCEPT_CLASS_ID = 'Supplier')
on MANUFACTURER = CONCEPT_NAME
union
select distinct FO_PRD_ID,CONCEPT_CODE from bn join (select CONCEPT_NAME, CONCEPT_CODE from drug_concept_stage where CONCEPT_CLASS_ID = 'Brand Name')
on trim(NEW_NAME) = CONCEPT_NAME
union
select distinct fo_prd_id, concept_code from ingredients  inner join (select CONCEPT_NAME,concept_code from drug_concept_stage where CONCEPT_CLASS_ID like 'Ingredient')
on INGREDIENT = CONCEPT_NAME
union
select distinct fo_prd_id, concept_code from dose_form_test join (select CONCEPT_NAME, CONCEPT_CODE from drug_concept_stage where CONCEPT_CLASS_ID = 'Dose Form')
on dose_form=concept_name;


insert into INTERNAL_RELATIONSHIP_STAGE (CONCEPT_CODE_1, CONCEPT_CODE_2)
select a.concept_code as concept_code_1, b.concept_code as concept_code_2 from drug_concept_stage a
join 
(select prd_name, concept_code from pack_drug_product join drug_concept_stage on trim(manufacturer) = concept_name WHERE PRD_NAME NOT LIKE 'INACTIVE TABLET') b 
on a.concept_name=trim(prd_name) 
union
select distinct concept_code as concept_code_1, nfc_code as concept_code_2 from list join pack_drug_product on CONCEPT_NAME=PRD_NAME where nfc_code is not null
and CONCEPT_CLASS_ID='Drug Product' AND CONCEPT_NAME NOT LIKE 'INACTIVE TABLET'
;









 









