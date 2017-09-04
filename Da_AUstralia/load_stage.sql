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


insert into drugs (FO_PRD_ID,PRD_NAME,MAST_PRD_NAME,DOSAGE,UNIT,DOSAGE2,UNIT2,MOL_EID,MOL_NAME,ATCCODE,ATC_NAME,MANUFACTURER)
select FO_PRD_ID,PRD_NAME,MAST_PRD_NAME,DOSAGE,UNIT,DOSAGE2,UNIT2,MOL_EID,MOL_NAME,ATCCODE,ATC_NAME,MANUFACTURER_NAME
from au_lpd where fo_prd_id not in (select fo_prd_id from drugs)
;
update drugs
SET MOL_NAME=REGEXP_REPLACE(mol_name,'"');
update drugs set mol_name =null where mol_name like 'INIT';

DROP TABLE drugs_update_1;
create table drugs_update_1 as
select distinct a.FO_PRD_ID,a.PRD_NAME,a.MAST_PRD_NAME,a.DOSAGE,a.UNIT,a.DOSAGE2,a.UNIT2,b.MOL_EID,b.MOL_NAME,A.MOL_NAME_2,a.ATCCODE,a.ATC_NAME,a.NFC_CODE,a.MANUFACTURER
from drugs a join
drugs b on a.fo_prd_id!=b.fo_prd_id and a.prd_name=b.prd_name
--regexp_replace(a.prd_name, '(TABS|CAPS|VIAL|ACCUHALER|SOLUTION|JELLY|UNSPECIFIED|SUBLINGUAL|GEL|SYRUP|TOPICAL|CREAM|PATCH|TRANSD|DROPS|SUPP|AMP|\d).*')=regexp_replace(b.prd_name, '(TABS|CAPS|VIAL|ACCUHALER|SOLUTION|JELLY|UNSPECIFIED|SUBLINGUAL|GEL|SYRUP|TOPICAL|CREAM|PATCH|TRANSD|DROPS|SUPP|AMP|\d).*') 
and b.mol_name is not null and a.mol_name is null
;
/*
drop table drugs_update_2;
create table drugs_update_2 as
select distinct a.FO_PRD_ID,a.PRD_NAME,a.MAST_PRD_NAME,a.DOSAGE,a.UNIT,a.DOSAGE2,a.UNIT2,b.MOL_EID,b.MOL_NAME,A.MOL_NAME_2,b.ATCCODE,b.ATC_NAME,b.NFC_CODE,a.MANUFACTURER
from drugs a join
drugs b on a.fo_prd_id!=b.fo_prd_id and 
regexp_replace(a.prd_name, '(TABS|CAPS|VIAL|ACCUHALER|SOLUTION|JELLY|UNSPECIFIED|SUBLINGUAL|GEL|SYRUP|TOPICAL|CREAM|PATCH|TRANSD|DROPS|SUPP|AMP|\d).*')=regexp_replace(b.prd_name, '(TABS|CAPS|VIAL|ACCUHALER|SOLUTION|JELLY|UNSPECIFIED|SUBLINGUAL|GEL|SYRUP|TOPICAL|CREAM|PATCH|TRANSD|DROPS|SUPP|AMP|\d).*') 
and b.mol_name is not null and a.mol_name is null and a.fo_prd_id not in (select fo_prd_id from drugs_update_1)
;
*/
delete from drugs where fo_prd_id in (select fo_prd_id from drugs_update_1);
insert into drugs 
select * from drugs_update_1
;
update drugs 
set PRD_NAME=regexp_replace(PRD_NAME,',','.') where PRD_NAME is not null;
update drugs
SET PRD_NAME=REGEXP_REPLACE(PRD_NAME,'"')
;


create table non_drug as (select  distinct * from drugs where ATCCODE in('V01AA07','V03AK','V04B','V04CL','V04CX','V20','D02A','D02AD','D09A','D02AX','D02BA','D02AC')
or ATCCODE like 'V06%' or ATCCODE like 'V07%');

insert into non_drug
select * from drugs where regexp_like (PRD_NAME,'^TENA |S(\S)?26|STOCKING|ACCU-CHEK|ACCUTREND|STRIPS|WIPES|REMOVER|LOZENGE|KCAL|NUTRISION|BREATH-ALERT|CHAMBER|\sSTRP|REMOVAL|GAUZE|SUPPLY|PROTECTORS|SOUP|DRESS|CLEANSER|BANDAGE|BEVERAGE|RESOURCE|WEIGHT|ENDURA OPTIMIZER|UNDERWEAR|\sSTRP|\sROLL|\sKCAL|\sGAUZE|LENS\sPLUS|LEUKOPLAST|[^IN]TEST[^O]')
and fo_prd_id not in (select fo_prd_id from non_drug);

insert into non_drug
select * from drugs where regexp_like (PRD_NAME,'CHEK|BIOTENE|CALOGEN|CETAPHIL|ENSURE|FREESTYLE|HAMILTON|LUBRI|MEDISENSE|CARESENS')
and fo_prd_id not in (select fo_prd_id from non_drug);


insert into non_drug  
select * from drugs where (MAST_PRD_NAME like '%SUN%' or   MAST_PRD_NAME like '%ACCU-CHEK%' or MAST_PRD_NAME like '%ACCUTREND%')  and  MAST_PRD_NAME not like '%SELSUN%'
and fo_prd_id not in (select fo_prd_id from non_drug);

insert into non_drug
select * from drugs where regexp_like(mol_name, 'IUD|LEUCOCYTES|AMIDOTRIZOATE|BANDAGE');

insert into non_drug
select * from drugs where regexp_like(nfc_code,'VZT|VGB|VGA|VZY|VEA|VED|VEK|VZV') and fo_prd_id not in (select fo_prd_id from non_drug);

 insert into non_drug
 select * from drugs where fo_prd_id in (58557,605075,19298,19308,25214,19317,586445,18816,33606,2043629,26893,2042567,2042566,2043068,2043069,2040332,2047035,2040625,588960,2040344,586387,2044122,588399,588398,2041031,606459,2050029,2041619,2048638,2048639,
2048642,2042520,2042519,2040093,33512,2046954,2046955,2041294,2041373,2042857,591584,586298,602040,602041,2049426,588380,586462,586463,88178,586441,88159,88162,88175,88176,2047881,2044399,2044254,2047085,88083,2043833,34825,34959,587498,588222,588432,588424,
2046588,58557,2044042,2045706,2045707,2047191,2047298,2045998,590969,591417,32989,2045897,605545,2041685,2046849,2045269,33112,2041739,603439,603440,2043567,2039962,2044712,34497,2045725,2050730,2046632,2042292,2045041,2041396,2043896,2040362,2044727,2041375,
2045040,2046267,2045462,2043020,22186,592070,592243,4454,4455,2042477,34639,2046505,2048158,3003,33861,2040442,2040443,2043132,588198,588199,588213,588214,2045537,2047003,2048682,2043029,2042110,2049484,6066,587833,590535,2050503,587949,588204,588205,587822,
588207,2046494,586306,2045668,2043843,2042620,591627,605549,605550,604390,29291,2044402,2042870,586959,586960,2045457,2047083,2045458,2042724,33648,605548,22807,38919,587834,587835,587668,586460,586459,587836,2046938,2048554,2048555,2046645,2044964,2046937,
586368,28263,8530,588350,596295,2043217,2047595,2041520,2042851,2041971,27633,588092,587563,2043458,588334,588333,588295,2047098,598487,2048439,27415,2043415,586377,588215,2045741,591367,11670,2049800,2046104,2925,38896,32110,588306,588282,2046493,2048763,
2047433,592031,2044126,2042908,2047034,2050601,37372,33939,586570,587894,588200,2048608,2041798,588211,2047523,2045932,16247,34561,2048156,2047403,2045943,606044,2044652,5591,5593,28013,28012,36452,33759,589922,605083,2050328,605082,2050837,34352,2042067,
2040345,2042767,2049047,2049049,2047087,2044051,2044052,2050217,2050218,589143,589144,2041193,592231,588373,2050051,2049662,2046869,2045261,
2043307,34531,2042894,605664,586308,6429,2044683,2046806,2049377,2047681,34335,34339,34336,2040363,2046825,588549,588548,2042119)
and fo_prd_id not in (select fo_prd_id from non_drug);

ALTER TABLE non_drug
 RENAME COLUMN fo_prd_id to concept_code;
 
/*
declare
 ex1 number;
begin
  select max(cast(substr(concept_code, 5) as integer))+1 into ex1 from devv5.concept where concept_code like 'OMOP%' and concept_code not like '% %'; -- Last valid value of the OMOP123-type codes
  begin
    execute immediate 'create sequence nv1 increment by 1 start with ' || ex1 || ' nocycle cache 20 noorder';
  end;
end;
/
*/
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
from (SELECT * FROM DRUGS WHERE MOL_NAME IS NOT NULL) t,
table(cast(multiset(select level from dual connect by  level <= length (regexp_replace(t.MOL_NAME, '[^/]+'))  + 1) as sys.OdciNumberList)) levels) 
 );
insert into ingredients 
select distinct upper(concept_name),fo_prd_id from i_map_postprocess where fo_prd_id not in (select fo_prd_id from ingredients)
;
update ingredients SET INGREDIENT = 'NICOTINAMIDE' WHERE INGREDIENT  = 'NICOTINIC ACID';
delete from ingredients where fo_prd_id in (select fo_prd_id from no_ds_done where ingredient_name is not null);
insert into ingredients 
select distinct ingredient_name,fo_prd_id from no_ds_done where ingredient_name is not null;
delete from ingredients where trim(replace(ingredient,'#')) in (select trim(replace(concept_name,'#')) from RELATIONSHIP_MANUAL_INGREDIENT_DONE where dummy is not null);


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
select fo_prd_id, prd_name,nfc_code,regexp_substr(prd_name,'oral drop|oral emulsion|oral liquid|oral paint|oral powder|oral syringe|oro-dispersible film|paediatric capsule|paediatric drop|paediatric mixture|paediatric solution',1,1,'i') from drugs
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
select fo_prd_id,prd_name, nfc_code ,regexp_substr(prd_name,'SUPP\s|SUPPO|CAPSULE|SYRUP|SYRINGE|ORALDISTAB|AMPOULE|AUTOHA|INHALE|HALER|CHEW.*GUM|CHEW.*TAB|DISP.*TAB|TABSULE|AUTOINJ|\sPENFILL|PRE-FILLED|SUSPEN|REPETAB|LOTION|VAG.*GEL|GEL.*ORAL|ORAL.*GEL|EYE.*GEL',1,1,'i') FROM DRUGS; 
insert into dose_form_test
select fo_prd_id,prd_name, nfc_code ,regexp_substr(prd_name,'EYE.*OINT|ANAL.*\sOINT|EAR/*\sOINT|\sOINT|\sORAL.*SOL|\sSOL.*ORAL|\sMICROENEMA|\sENEMA|\sNASAL.*DROP|\sDROP|EYE.*DRO|s\EAR.*DRO|\sMOUTHWASH|\sMOUTHWASH.*SOL|\sELIXI|PATCH|\sTABL|\sSHAMPOO|CAPSEAL|\sINJ') from drugs;
insert into dose_form_test
select fo_prd_id,prd_name, nfc_code ,regexp_substr(PRD_NAME, 'NEB.*SOL|PESSARY|INFUSION|WAFER|LINIMENT|MIXTURE|CAPSU|TAB-\d+|\s.*ABLE.*TAB|SOLUTION|PASTE|\sPEN\s|GEL|\sSOLUT\s|\sPOWDE|\sCAP\s|\sPASTILE|\sLOZE\s|EMULSION|MOUTHRINSE|NASAL SPRAY|EYE/EAR DROP|SOFTGELCAP') FROM DRUGS;
delete from dose_form_test where dose_form is null;
delete from dose_form_test where fo_prd_id in (select concept_code from non_drug);
insert into dose_form_test
select fo_prd_id,prd_name, nfc_code ,regexp_substr(prd_name,'(\sSYR|EYE.*DR|SUSP|AERO|\sCRM|BALM|INH|CREA|ELIXIR|NASAL SPR|PRE.?FILL SYR|SUSP|CAP|AMP|TAB|SHAMPOO|LOZ|OINT|PENFILL)(S)?(\s|$)') from drugs where fo_prd_id not in (select fo_prd_id from dose_form_test)
and regexp_substr(prd_name,'(\sSYR|EYE.*DRP|SUSP|AERO|\sCRM|BALM|INH|CREA|ELIXIR|NASAL SPR|PRE.?FILL SYR|SUSP|CAP|AMP|TAB|SHAMPOO|LOZ|OINT|PENFILL)(S)?(\s|$)') is not null and fo_prd_id not in (select concept_code from non_drug);

insert into dose_form_test
select fo_prd_id,prd_name, nfc_code ,regexp_substr(prd_name,'\sSYR|EYE.*DR|SUSP|AERO|\sCRM|BALM|INH|CREA|ELIXIR|NASAL SPR|SOLN') from drugs where fo_prd_id not in (select fo_prd_id from dose_form_test)
and regexp_substr(prd_name,'\sSYR|EYE.*DRP|SUSP|AERO|\sCRM|BALM|INH|CREA|ELIXIR|NASAL SPR|SOLN') is not null and fo_prd_id not in (select concept_code from non_drug);

delete from dose_form_test where fo_prd_id in (select fo_prd_id from pack_drug_product_2);

insert into dose_form_test (prd_name,dose_form)
select distinct prd_name, nvl(regexp_substr(regexp_substr(upper(prd_name),'_.*'),'CAP|TAB|CREAM|PATCH|POWDER|SACHET|SUSP|INJ'),regexp_substr (upper(prd_name),'CAP|TABLET|CREAM|SYRUP|INJ|VAGINAL SUPPOSITORY'))
from pack_drug_product_2 where 
nvl(regexp_substr(regexp_substr(upper(prd_name),'_.*'),'CAP|TAB|CREAM|PATCH|POWDER|SACHET|SUSP|INJ'),regexp_substr (upper(prd_name),'CAP|TABLET|CREAM|SYRUP|INJ|VAGINAL SUPPOSITORY')) is not null;
update dose_form_test set dose_form = TRIM(upper(dose_form));
delete from dose_form_test where dose_form is null;
UPDATE dose_form_test SET dose_form= 'TABLET' WHERE dose_form LIKE 'TAB-%' OR dose_form LIKE 'TABSULE' OR  dose_form LIKE 'TABLET%' OR DOSE_FORM LIKE '%REPETAB%' OR DOSE_FORM LIKE '%TABL' OR regexp_like(DOSE_FORM ,'TAB(S)?') ;
UPDATE dose_form_test SET dose_form= 'EFFERVESCENT TABLET' WHERE dose_form LIKE '%EFFERVESCENT%TABLET%';
UPDATE dose_form_test SET dose_form= 'CHEWABLE TABLET' WHERE dose_form LIKE '%CHEW%TAB%' OR DOSE_FORM LIKE '%ABLE%TAB%';
UPDATE dose_form_test SET dose_form= 'CHEWING GUM' WHERE dose_form LIKE '%CHEW%GUM%';
UPDATE dose_form_test SET dose_form= 'DISPERSIBLE TABLET' WHERE dose_form LIKE '%DISP%TAB%' OR DOSE_FORM LIKE '%ORALDISTAB%';
UPDATE dose_form_test SET dose_form= 'SUPPOSITORY' WHERE dose_form LIKE '%SUPP%';
UPDATE dose_form_test SET dose_form= 'NASAL DROP' WHERE dose_form LIKE '%NASAL RELIEF SALINE NASAL DROP%'or dose_form like 'NOSE DROP';
UPDATE dose_form_test SET dose_form= 'ORAL GEL' WHERE dose_form LIKE '%ORAL %GEL%';
UPDATE dose_form_test SET dose_form= 'CAPSULE' WHERE dose_form LIKE '%CAPS%' OR dose_form LIKE 'CAP' OR DOSE_FORM LIKE 'SOFTGELCAP';
UPDATE dose_form_test SET dose_form= 'INJECTION' WHERE dose_form LIKE 'INJ';
UPDATE dose_form_test SET dose_form= 'EYE DROP' WHERE dose_form LIKE '%EYE%DR' or dose_form in ('EYE DRP','EYE DRPS','EYE /DRP') or regexp_like(dose_form,'EYE.*DR');
UPDATE dose_form_test SET dose_form= 'EYE OINTMENT' WHERE dose_form LIKE '%EYE%OINT';
UPDATE dose_form_test SET dose_form= 'VAGINAL GEL' WHERE dose_form LIKE '%VAG%GEL%';
UPDATE dose_form_test SET dose_form= 'LOTION' WHERE dose_form LIKE '%LOT%';
UPDATE dose_form_test SET dose_form= 'ELIXIR' WHERE dose_form LIKE '%ELIXI%';
UPDATE dose_form_test SET dose_form= 'SOLUTION' WHERE dose_form LIKE 'SOLUTION' OR dose_form LIKE 'SOLUT' OR dose_form LIKE 'SOLN';
UPDATE dose_form_test SET dose_form= 'ORAL SOLUTION' WHERE dose_form LIKE '%SOLUTION%ORAL%' or dose_form like 'ORAL SOL';
UPDATE dose_form_test SET dose_form= 'ORAL GEL' WHERE dose_form LIKE 'GEL ORAL' OR dose_form LIKE 'GEL-ORAL';
UPDATE dose_form_test SET dose_form= 'INHALATION' WHERE dose_form LIKE 'INHALATOR' OR dose_form LIKE 'INHALE' OR dose_form LIKE 'HALER' or dose_form LIKE 'INH' or dose_form LIKE 'AERO';
UPDATE dose_form_test SET dose_form= 'ENEMA' WHERE dose_form LIKE '%ENEMA%';
UPDATE dose_form_test SET dose_form= 'INHALATION SOLUTION' WHERE dose_form LIKE '%NEB%SOL%';
UPDATE dose_form_test SET dose_form= 'PENFILL INJECTION' WHERE dose_form LIKE '%PENFILL%';
UPDATE dose_form_test SET dose_form= 'OINTMENT' WHERE dose_form LIKE 'OINT';
UPDATE dose_form_test SET dose_form= 'LOZENGE' WHERE dose_form LIKE 'LOZ%';
UPDATE dose_form_test SET dose_form= 'ORAL DROP' WHERE dose_form LIKE 'ORAL DROPS ORAL SOL';
UPDATE dose_form_test SET dose_form= 'PATCH' WHERE dose_form LIKE 'PATCHE';
UPDATE dose_form_test SET dose_form= 'POWDER' WHERE dose_form LIKE 'POWDE';
UPDATE dose_form_test SET dose_form= 'ORAL GEL' WHERE dose_form LIKE 'ORALBALANCE DRY MOUTH MOISTURISING GEL';
UPDATE dose_form_test SET dose_form= 'AMPOULE' WHERE dose_form LIKE 'AMP%';
UPDATE dose_form_test SET dose_form= 'PRE-FILLED' WHERE dose_form in('PRE-FILL SYR','PREFILL SYR');
UPDATE dose_form_test SET dose_form= 'SUSPEN' WHERE dose_form LIKE 'SUSP';
UPDATE dose_form_test SET dose_form= 'CREAM' WHERE dose_form LIKE 'CREA' or dose_form LIKE 'CRM';
UPDATE dose_form_test SET dose_form= 'NASAL SPRAY' WHERE dose_form LIKE 'NASAL SPR';
UPDATE dose_form_test SET dose_form= 'AUTOHALER' WHERE dose_form LIKE 'AUTOHA%';
UPDATE dose_form_test SET dose_form= 'SYRINGE' WHERE dose_form LIKE 'SYR';
update dose_form_test set dose_form= 'EYE/EAR DROP' where fo_prd_id in (16913,19667,23512);
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
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '2043413' AND   DOSE_FORM = 'OINTMENT';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '2044107' AND   DOSE_FORM = 'OINTMENT';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '2040040' AND   DOSE_FORM = 'OIL';
DELETE FROM DOSE_FORM_TEST WHERE FO_PRD_ID = '2050048' AND   DOSE_FORM = 'SACHET';


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

delete bn where new_name in (select concept_name from  RELATIONSHIP_MANUAL_BRAND_DONE where DUMMY is not null);

update bn set new_name=regexp_replace (new_name, '(MOUTHWASH|PESSARY|\sENEMA|\[.*\])')
where regexp_like (new_name, '(MOUTHWASH|PESSARY|\sENEMA|\[.*\])');
update bn set new_name = 'MS CONTIN' where new_name='MS';
update bn set new_name = 'IN A WINK' where new_name='IN';


--manufacturer

create table manufacturer as (
select FO_PRD_ID, trim(manufacturer) manufacturer
from drugs
where manufacturer!='UNBRANDED' and upper(manufacturer) not like 'GENERIC' and manufacturer is not null and fo_prd_id not in(select concept_code from non_drug)
);
delete from manufacturer where manufacturer in (select concept_name from RELATIONSHIP_MANUAL_SUPPLIER_DONE where dummy is not null);


create table list as (
select distinct trim(manufacturer) as concept_name,'Supplier' as concept_class_id from manufacturer
union
select distinct trim(INGREDIENT) as concept_name,'Ingredient' as concept_class_id from INGREDIENTS where INGREDIENT is not null
union
select distinct trim(NEW_NAME), 'Brand Name' as concept_class_id from bn
union
select distinct trim(PRD_NAME) as concept_name,'Drug Product' as concept_class_id from pack_drug_product_2
)
union 
select distinct trim(dose_form) as concept_name, 'Dose Form' as concept_class_id from dose_form_test
;

alter table list
add concept_code varchar(255);
update list
set concept_code='OMOP'||nv1.nextval;

truncate table DRUG_concept_STAGE;
insert into DRUG_concept_STAGE (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,pack_size,domain_id,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct CONCEPT_NAME, 'Lpd_Australia', CONCEPT_CLASS_ID, '', CONCEPT_CODE, '', '','Drug', TO_DATE('2016/10/01', 'yyyy/mm/dd') as valid_start_date,
TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date, ''
 from 
(
select concept_name,concept_class_id, concept_code from list
union
select distinct PRD_NAME,'Drug Product' as CONCEPT_CLASS_ID,fo_prd_id from drugs where fo_prd_id not in (select concept_code from non_drug)
 )
 ;
 insert into DRUG_concept_STAGE (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,pack_size,domain_id,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct CONCEPT_NAME, 'Lpd_Australia', CONCEPT_CLASS_ID, 's', CONCEPT_CODE, '', '','Device', TO_DATE('2016/10/01', 'yyyy/mm/dd') as valid_start_date,
TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date, ''
 from 
(
select distinct PRD_NAME as concept_name,'Device' as CONCEPT_CLASS_ID,concept_code as concept_code from non_drug
 );
update DRUG_concept_STAGE
set STANDARD_CONCEPT = 'S' where CONCEPT_CLASS_ID = 'Ingredient';


create table drugs_for_strentgh as
select fo_prd_id , prd_name, dosage,unit,dosage2, unit2, mol_name from drugs where fo_prd_id not in (select concept_code from non_drug) and fo_prd_id not in (select fo_prd_id from PACK_DRUG_PRODUCT_2);
update drugs_for_strentgh 
set PRD_NAME=regexp_replace(PRD_NAME,',','.') where PRD_NAME is not null;
update drugs_for_strentgh 
set PRD_NAME = 'DEXSAL ANTACID LIQUID 1.25G-20MG/15' where prd_name = 'DEXSAL ANTACID LIQUID 1.25G-20MG/1';

create table ds_strength_trainee (DRUG_CONCEPT_CODE VARCHAR2(255 Byte),INGREDIENT_NAME VARCHAR2(255 Byte),BOX_SIZE NUMBER,AMOUNT_VALUE FLOAT(126),AMOUNT_UNIT VARCHAR2(255 Byte),NUMERATOR_VALUE FLOAT(126),NUMERATOR_UNIT VARCHAR2(255 Byte),DENOMINATOR_VALUE FLOAT(126), 
DENOMINATOR_UNIT VARCHAR2(255 Byte));
update drugs_for_strentgh set unit = 'MCG' where unit like 'µg';
update drugs_for_strentgh set unit2 = 'MCG' where unit2 like 'µg';

truncate table ds_strength_trainee;
--1 molecule denominator in Hours--
insert into ds_strength_trainee (DRUG_CONCEPT_CODE,INGREDIENT_NAME,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
select distinct FO_PRD_ID,mol_name,
regexp_substr(regexp_substr(prd_name,'\d+(\.\d+)*(MG|MCG|Y)\s?/'),'\d+(\.\d+)*'),
regexp_replace(regexp_substr(prd_name,'\d+(\.\d+)*(MG|MCG|Y)\s?/'),'\d+(\.\d+)*|/'),
replace(regexp_substr(prd_name,'\d+(\.\d+)*H'),'H'),
'H' from drugs_for_strentgh
where REGEXP_LIKE(PRD_NAME,'\d+(\.\d+)*(H|HRS|HOUR|HOURS|HR)(\)|$)') and mol_name not like '%/%';

--1 molecule where %--
insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,NUMERATOR_VALUE ,NUMERATOR_UNIT ,DENOMINATOR_UNIT )
SELECT fo_prd_id AS DRUG_CONCEPT_CODE, MOL_NAME AS INGREDIENT_NAME, cast(dosage as number)*10 AS NUMERATOR_VALUE, 'mg' as NUMERATOR_UNIT, 'ml' as DENOMINATOR_UNIT
FROM drugs_for_strentgh
WHERE mol_name not like '%/%' and unit2 is null and unit like '%!%%' escape '!' and fo_prd_id not in (select drug_concept_code from ds_strength_trainee)
;
--1 molecule not %--
insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,AMOUNT_VALUE,AMOUNT_UNIT)
SELECT fo_prd_id,MOL_NAME,DOSAGE,UNIT
from drugs_for_strentgh
WHERE mol_name not like '%/%' and unit2 is null and unit not like '%!%%' escape '!' and dosage2 is null and not regexp_like(prd_name, '(/(ACTUAT|SPRAY|PUMP|DOSE|INHAL))|MG/(G|ML)') 
and fo_prd_id not in (select drug_concept_code from ds_strength_trainee)
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
insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,NUMERATOR_VALUE,NUMERATOR_UNIT, DENOMINATOR_VALUE,DENOMINATOR_UNIT )
select fo_prd_id,mol_name,
regexp_substr(regexp_substr(prd_name, '\d+(\.\d+)*(MCG|MG)/'),'\d+(\.\d+)*') as numerator_value,
regexp_substr(regexp_substr(prd_name, '\d+(\.\d+)*(MCG|MG)/'),'MCG|MG') as numerator_unit,
'1' as denominator_value,
regexp_replace(regexp_substr(prd_name,'/(ACTUAT|SPRAY|PUMP|DOSE|INHAL)'),'/') as denominator_unit
from drugs where fo_prd_id not in (select DRUG_CONCEPT_CODE from ds_strength_trainee) and  mol_name not like '%/%' and regexp_like(prd_name, '/(ACTUAT|SPRAY|PUMP|DOSE|INHAL)') and fo_prd_id not in (select concept_code from non_drug)
;

insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,NUMERATOR_VALUE,NUMERATOR_UNIT, DENOMINATOR_VALUE,DENOMINATOR_UNIT )
select fo_prd_id,mol_name,
 regexp_substr(regexp_substr(prd_name,'\d+(\.\d+)*(MCG|MG)/'),'\d+(\.\d+)*') as numerator_value,
replace(regexp_substr(prd_name,'(MCG|MG|G)/'),'/') as numerator_unit,
'1' as denominator_value,
regexp_replace(regexp_substr(prd_name,'/(MCG|MG|ML|L|G)'),'/') as denominator_unit
from drugs where fo_prd_id not in (select DRUG_CONCEPT_CODE from ds_strength_trainee) and  mol_name not like '%/%' and regexp_like(prd_name, '(MCG|MG|G)/(G|ML|L)') and fo_prd_id not in (select concept_code from non_drug)
;
--NEED MANUAL PROCEDURE( NEARLY 40 ROWS) WHERE CONCEPT_CLASS_ID = 'Drug Product' and FO_PRODUCT.MOL_NAME  not like '%/%' and unit2 is not null and (unit like '%!%%' escape '!' or unit2  like '%!%%' escape '!')--
--multiple ingr--
--multiple with pattern ' -%-%-/'--
create or replace view multiple_liquid as
select FO_PRD_ID, PRD_NAME,regexp_replace(regexp_substr( prd_name, '(\d+(\.\d+)?\D*-)+\d+(\.\d+)?\D*'), '/.*') as AA,
nvl(regexp_substr(regexp_substr(regexp_substr(prd_name, '(\d+(\.\d+)?\D*-)+\d+(\.\d+)?\D*/.*'),'/\d+.*\s?\(?'), '(\d+(\.\d)?)' ),1) as DENOMINATOR_VALUE ,
regexp_substr(regexp_substr(regexp_substr( prd_name, '(\d+(\.\d+)?\D*-)+\d+(\.\d+)?\D*/.*'),'/.*'), '(ACTUAT|MG|IU|%|G|ML|DROP|MCG|MMOL|DOSE|BILLION.*|MILLION.*|\D*UNITS.|LOZ|LOZENGE|µg|U|L|M){1}')  as DENOMINATOR_UNIT, mol_name
from
(select * from drugs_for_strentgh where regexp_like(prd_name, '(\d+(\.\d+)?\D*-)+\d+(\.\d+)?\D*/{1}\d?(\.\d+)?\D*') and MOL_NAME like '%/%')
;

create or replace view ds_multiple_liquid as
select FO_PRD_ID,PRD_NAME,G,
regexp_substr(W,'\d+(\.\d+)?') as numerator_value, 
regexp_substr(W,'ACTUAT|MG|IU|%|G|ML|DROP|MCG|MMOL|DOSE|BILLION.*|MILLION.*|\D*UNITS.|LOZ|LOZENGE|µg|U|L|M') as numerator_unit,
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
select regexp_substr(prd_name,'\d+.?\d*(ACTUAT|MG|IU|%|G|ML|DROP|MCG|MMOL|DOSE|BILLION.*|MILLION.*|\D*.*UNITS.|LOZ|LOZENGE|µg|U|L|M){1}/\d+.*') as A, PRD_NAME,FO_PRD_ID, mol_name
from drugs_for_strentgh 
where mol_name like '%/%' and FO_PRD_ID not in (select distinct FO_PRD_ID from ds_multiple_liquid)) where A is not null
;

--multiple with pattern '-'--
create or replace view ds_multiple2 as
select FO_PRD_ID, PRD_NAME, b, mol_name from (
select regexp_substr(prd_name,'\d.?\d*(ACTUAT|MG|IU|%|G|ML|DROP|MCG|MMOL|DOSE|BILLION.*|MILLION.*|\D*UNITS.|LOZ|LOZENGE|µg|U|L|M){1}-\d.*') as b, PRD_NAME,fo_prd_id, mol_name
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
(select FO_PRD_ID, PRD_NAME, regexp_substr(W,'\d+(\.\d*)?') as dosage, regexp_substr (W,'ACTUAT|MG|IU|%|G|ML|DROP|MCG|MMOL|DOSE|BILLION.*|MILLION.*|\D*UNITS.|LOZ|LOZENGE|µg|U|L|M' ) as unit, g as mol_name from MULTIPLE_INGREDIENTS )BB
on CONCEPT_CODE = FO_PRD_ID 
where CONCEPT_CLASS_ID = 'Drug Product'  and (DOSAGE IS NULL OR UNIT IS NULL);


insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,NUMERATOR_VALUE ,NUMERATOR_UNIT ,DENOMINATOR_UNIT )
select CONCEPT_CODE AS DRUG_CONCEPT_CODE, AA.MOL_NAME AS INGREDIENT_NAME, cast(AA.dosage as number)*10 AS NUMERATOR_VALUE, 'mg' as NUMERATOR_UNIT, 'ml' as DENOMINATOR_UNIT
from DRUG_CONCEPT_STAGE JOIN
(select FO_PRD_ID, PRD_NAME, regexp_substr(W,'\d+(\.\d*)?') as dosage, regexp_substr (W,'ACTUAT|MG|IU|%|G|ML|DROP|MCG|MMOL|DOSE|BILLION.*|MILLION.*|\D*UNITS.|LOZ|LOZENGE|µg|U|L|M' ) as unit, g as mol_name from MULTIPLE_INGREDIENTS ) AA
on CONCEPT_CODE = FO_PRD_ID 
where CONCEPT_CLASS_ID = 'Drug Product' and unit like '%!%%' escape '!' 
;

insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,AMOUNT_VALUE,AMOUNT_UNIT)
SELECT CONCEPT_CODE, BB.MOL_NAME, BB.DOSAGE, BB.UNIT
from DRUG_CONCEPT_STAGE JOIN
(select FO_PRD_ID, PRD_NAME, regexp_substr(W,'\d+(\.\d*)?') as dosage, regexp_substr (W,'ACTUAT|MG|IU|%|G|ML|DROP|MCG|MMOL|DOSE|BILLION.*|MILLION.*|\D*UNITS.|LOZ|LOZENGE|µg|U|L|M' ) as unit, g as mol_name from MULTIPLE_INGREDIENTS )BB
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
insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME, AMOUNT_VALUE, AMOUNT_UNIT, NUMERATOR_VALUE ,NUMERATOR_UNIT ,DENOMINATOR_VALUE, DENOMINATOR_UNIT )
select distinct concept_code,MOL_NAME, AMOUNT_VALUE, AMOUNT_UNIT, NUMERATOR_VALUE, NIMERATOT_UNIT, DENOMINATOR_VALUE, DENOMINATOR_UNIT from 
pack_drug_product_2 a join drug_concept_stage b on prd_name=concept_name;
 
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
update ds_strength_trainee set AMOUNT_VALUE = null, AMOUNT_UNIT = null where AMOUNT_VALUE= '0' and INGREDIENT_NAME !='INERT INGREDIENTS';
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
DELETE FROM ds_strength_trainee WHERE NUMERATOR_UNIT='unknown';




truncate table ds_stage;
 insert into ds_stage (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
 select distinct DRUG_CONCEPT_CODE,concept_code,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT from ds_strength_trainee join drug_concept_stage 
 on ingredient_name = concept_name where concept_class_id ='Ingredient';
 
insert into ds_stage (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
 select fo_prd_id,concept_code,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT from i_map_postprocess a join drug_concept_stage b  
 on upper(a.concept_name) = upper(b.concept_name) where concept_class_id ='Ingredient' and NVL(AMOUNT_VALUE,NUMERATOR_VALUE)is not null and cast(fo_prd_id as varchar(20)) not in (select drug_concept_code from ds_stage);
 
insert into ds_stage (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
 select fo_prd_id,concept_code,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT from no_ds_done a join drug_concept_stage b  
 on upper(a.INGREDIENT_NAME) = upper(b.concept_name) where concept_class_id ='Ingredient' and NVL(AMOUNT_VALUE,NUMERATOR_VALUE)is not null and cast(fo_prd_id as varchar(20)) not in (select drug_concept_code from ds_stage);


UPDATE ds_stage SET  amount_unit=trim(UPPER(amount_unit)),NUMERATOR_UNIT=trim(UPPER(NUMERATOR_UNIT)), DENOMINATOR_UNIT=trim(UPPER(DENOMINATOR_UNIT));
update ds_stage set amount_unit='U' where amount_unit IN ('UNITS','BILLION CFU','BILLION','BILLION ORGANISMS');
update ds_stage set NUMERATOR_UNIT='U' where NUMERATOR_UNIT IN ('UNITS','BILLION CFU','BILLION','BILLION ORGANISMS');
update ds_stage set amount_unit='MG' where amount_unit IN ('M');
update ds_stage set amount_unit='MCG' where amount_unit IN ('?G','ÂΜG','Y');
update ds_stage set NUMERATOR_UNIT='MCG' where NUMERATOR_UNIT IN ('?G','ÂΜG','Y');
update ds_stage set DENOMINATOR_UNIT='MCG' where DENOMINATOR_UNIT IN ('?G','ÂΜG','Y');
update ds_stage set DENOMINATOR_UNIT='HOUR' where DENOMINATOR_UNIT IN ('H');
update ds_stage set DENOMINATOR_UNIT='ACTUATION' where DENOMINATOR_UNIT IN ('DOSE','INHAL','PUMP','SPRAY','ACTUAT');
update ds_stage set NUMERATOR_VALUE=NUMERATOR_VALUE*DENOMINATOR_VALUE*10, NUMERATOR_UNIT='MG', DENOMINATOR_UNIT='ML'
where NUMERATOR_UNIT='%';
DELETE FROM DS_STAGE WHERE DRUG_CONCEPT_CODE IN (SELECT cast(FO_PRD_ID as varchar(20)) FROM DS_TO_DELETE_DONE);
INSERT INTO DS_STAGE 
SELECT FO_PRD_ID,CONCEPT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT
FROM DS_TO_DELETE_DONE A JOIN DRUG_CONCEPT_STAGE B ON UPPER(A.CONCEPT_NAME)=UPPER(B.CONCEPT_NAME) AND B.CONCEPT_CLASS_ID='Ingredient' where valid_ds is null
and fo_prd_id not in (select concept_code from non_drug);

delete from ds_stage where drug_concept_code in (select concept_code from drug_concept_stage where concept_class_id='Device');
delete from ds_stage where drug_concept_code in (select fo_prd_id from pack_drug_product_2);
delete from ds_stage where nvl(AMOUNT_VALUE,NUMERATOR_VALUE) is null;
delete from ds_stage where (drug_concept_code,ingredient_concept_code) in (SELECT drug_concept_code,ingredient_concept_code FROM ds_stage GROUP BY drug_concept_code, ingredient_concept_code  HAVING COUNT(1) > 1)
and rowid in (select max(rowid) FROM ds_stage GROUP BY drug_concept_code, ingredient_concept_code  HAVING COUNT(1) > 1);
            
--units appeared--
insert into DRUG_concept_STAGE (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct amount_unit,'Lpd_Australia','Unit','',amount_unit,'Drug', TO_DATE('2016/10/01', 'yyyy/mm/dd'),TO_DATE('2099/12/31', 'yyyy/mm/dd'), ''
 from (select amount_unit from ds_stage union select NUMERATOR_UNIT from ds_stage union select DENOMINATOR_UNIT from ds_stage )
 WHERE AMOUNT_UNIT IS NOT NULL;


create table relation_brandname_1 as
select distinct d.concept_name, concept_id, r.concept_name as R from drug_concept_stage d
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
select distinct a.concept_name,d.concept_id,d.concept_name from drug_concept_stage a join concept b 
on upper(a.concept_name)=upper(b.concept_name) and b.concept_class_id='Ingredient'
join concept_relationship c on b.concept_id=c.concept_id_1
join concept d on d.concept_id=concept_id_2 and d.concept_class_id='Ingredient' and d.standard_concept='S'
where a.concept_class_id like 'Ingredient' and a.concept_name not in ( select concept_name from RELATION_INGR_1)
;

insert into RELATION_INGR_1
select d.concept_name, concept_id, CONCEPT_SYNONYM_NAME as R from drug_concept_stage d
inner join devv5.CONCEPT_SYNONYM r on trim(lower(d.concept_name)) = trim(lower(CONCEPT_SYNONYM_NAME)) 
where  d.concept_class_id like '%Ingredient%' and concept_id in  (select concept_id from devv5.concept where VOCABULARY_ID like '%Rx%' and INVALID_REASON is null
and concept_class_id like 'Ingredient%') and concept_code not in (select concept_code from RELATION_INGR_1)
;
 
--adding all to realtionship_to_concept--

truncate table RELATIONSHIP_TO_CONCEPT
;
insert into RELATIONSHIP_TO_CONCEPT
(CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE)
select distinct b.concept_code, 'Lpd_Australia',a .concept_id,a.precedence from aus_dose_forms_done a join drug_concept_stage b on a.dose_form=b.concept_name
;
insert into RELATIONSHIP_TO_CONCEPT
(CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE)
select distinct CONCEPT_CODE,'Lpd_Australia',CONCEPT_ID,rank () over (partition by concept_code order by concept_id)
from RELATION_INGR_1 a join drug_concept_stage b on a.concept_name= b. concept_name where b.concept_class_id = 'Ingredient' 
;

insert into RELATIONSHIP_TO_CONCEPT
(CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE)
select distinct concept_code as concept_code_1,'Lpd_Australia',CONCEPT_ID as concept_id_2,nvl(precedence,1)
 from RELATIONSHIP_MANUAL_INGREDIENT_DONE a join drug_concept_stage b on a.concept_name=b.concept_name and CONCEPT_ID is not null
 and b.concept_class_id='Ingredient';

insert into RELATIONSHIP_TO_CONCEPT
(CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE)
select distinct CONCEPT_CODE,'Lpd_Australia',CONCEPT_ID,rank () over (partition by CONCEPT_CODE order by concept_id)
from relation_brandname_1 a join drug_concept_stage b on a.concept_name= b. concept_name where b.concept_class_id = 'Brand Name' 
and concept_code not in (select concept_code_1 from RELATIONSHIP_TO_CONCEPT)
;

insert into RELATIONSHIP_TO_CONCEPT
(CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE)
select distinct concept_code as concept_code_1,'Lpd_Australia',CONCEPT_ID as concept_id_2,nvl(precedence,1)
 from RELATIONSHIP_MANUAL_BRAND_DONE a join drug_concept_stage b on a.concept_name=b.concept_name and CONCEPT_ID is not null
  and b.concept_class_id='Brand Name';

insert into RELATIONSHIP_TO_CONCEPT (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE)
select distinct a.concept_code a,'Lpd_Australia',b.concept_id,'1' from drug_concept_stage a join devv5.concept b on lower(a.concept_name)=lower(b.concept_name) where 
b.concept_class_id = 'Supplier' and a.concept_class_id = 'Supplier' and b.invalid_reason is null
and b.vocabulary_id like 'Rx%' 
;
insert into RELATIONSHIP_TO_CONCEPT (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE)
select distinct concept_code as concept_code_1,'Lpd_Australia',CONCEPT_ID as concept_id_2,nvl(precedence,1)
 from RELATIONSHIP_MANUAL_SUPPLIER_DONE a join drug_concept_stage b on a.concept_name=b.concept_name and CONCEPT_ID is not null
  and b.concept_class_id='Supplier';

insert into RELATIONSHIP_TO_CONCEPT (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE)
select distinct b.CONCEPT_CODE, 'Lpd_Australia',c.CONCEPT_ID,rank () over (partition by b.CONCEPT_CODE order by c.concept_id)
from manual_supp a join drug_concept_stage b on a.concept_name= b. concept_name
join devv5.concept c on a.concept_id=c.concept_id 
where b.concept_class_id = 'Supplier'
and c.invalid_reason is  null
and (b.concept_code,c.concept_id) not in (select concept_code_1,concept_id_2 from relationship_to_concept)
;
insert into RELATIONSHIP_TO_CONCEPT
(CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select distinct CONCEPT_CODE_1,'Lpd_Australia',CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR from aus_unit_done
;




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
DELETE FROM RELATIONSHIP_TO_CONCEPT where concept_id_2 in (select concept_id from devv5.concept where invalid_reason is not null);



drop table ds_sum;
create table ds_sum as 
with a  as (
SELECT distinct ds.drug_concept_code,ds.ingredient_concept_code,ds.box_size, ds.AMOUNT_VALUE,ds.AMOUNT_UNIT,ds.NUMERATOR_VALUE,ds.NUMERATOR_UNIT,ds.DENOMINATOR_VALUE,ds.DENOMINATOR_UNIT,rc.concept_id_2
      FROM ds_stage ds
        JOIN ds_stage ds2 ON ds.drug_concept_code = ds2.drug_concept_code AND ds.ingredient_concept_code != ds2.ingredient_concept_code
        JOIN relationship_to_concept rc ON ds.ingredient_concept_code = rc.concept_code_1
        JOIN relationship_to_concept rc2 ON ds2.ingredient_concept_code = rc2.concept_code_1
            WHERE rc.concept_id_2 = rc2.concept_id_2
            )
 select distinct DRUG_CONCEPT_CODE,max(INGREDIENT_CONCEPT_CODE)over (partition by DRUG_CONCEPT_CODE,concept_id_2) as ingredient_concept_code,box_size,
 sum(AMOUNT_VALUE) over (partition by DRUG_CONCEPT_CODE)as AMOUNT_VALUE,AMOUNT_UNIT,sum(NUMERATOR_VALUE) over (partition by DRUG_CONCEPT_CODE,concept_id_2)as NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT
 from a
 union
 select DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,box_size, null as AMOUNT_VALUE, '' as AMOUNT_UNIT, null as NUMERATOR_VALUE, '' as NUMERATOR_UNIT, null as DENOMINATOR_VALUE, '' as DENOMINATOR_UNIT 
 from a where (drug_concept_code,ingredient_concept_code) not in (select drug_concept_code, max(ingredient_concept_code) from a group by drug_concept_code);
delete from ds_stage where  (drug_concept_code,ingredient_concept_code) in (select drug_concept_code,ingredient_concept_code from ds_sum);
INSERT INTO DS_STAGE SELECT * FROM DS_SUM where nvl(AMOUNT_VALUE,NUMERATOR_VALUE) is not null;



--pc stage--
truncate table pc_stage;
insert into pc_stage (PACK_CONCEPT_CODE,DRUG_CONCEPT_CODE,AMOUNT)
select distinct FO_PRD_ID,CONCEPT_CODE,AMOUNT_PACK from pack_drug_product_2
join drug_concept_stage on PRD_NAME=concept_name;


truncate table INTERNAL_RELATIONSHIP_STAGE;
--drug to ingredient
insert into INTERNAL_RELATIONSHIP_STAGE (CONCEPT_CODE_1, CONCEPT_CODE_2)
select distinct fo_prd_id, concept_code from ingredients  join (select CONCEPT_NAME,concept_code from drug_concept_stage where concept_class_id='Ingredient')
on INGREDIENT = CONCEPT_NAME where fo_prd_id not in (select fo_prd_id from pack_drug_product_2)
union
select distinct b.concept_code,c.concept_code
from pack_drug_product_2 a join drug_concept_stage b on a.prd_name=b.concept_name and b.concept_class_id='Drug Product'
join drug_concept_stage c on a.mol_name=c.concept_name and c.concept_class_id='Ingredient'
;
insert into internal_relationship_stage
select distinct drug_concept_code,ingredient_concept_code from ds_stage where (drug_concept_code,ingredient_concept_code) not in (select concept_code_1,concept_code_2 from internal_relationship_stage)
;


--drug to bn
insert into INTERNAL_RELATIONSHIP_STAGE (CONCEPT_CODE_1, CONCEPT_CODE_2)
select distinct FO_PRD_ID,CONCEPT_CODE from bn join (select CONCEPT_NAME, CONCEPT_CODE from drug_concept_stage where CONCEPT_CLASS_ID = 'Brand Name')
on trim(NEW_NAME) = CONCEPT_NAME
union 
select distinct b.concept_code,d.concept_code
from pack_drug_product_2 a join drug_concept_stage b on a.prd_name=b.concept_name and b.concept_class_id='Drug Product'
join bn c on a.fo_prd_id=c.fo_prd_id
join (select CONCEPT_NAME, CONCEPT_CODE from drug_concept_stage where CONCEPT_CLASS_ID = 'Brand Name') d
on trim(NEW_NAME) = d.CONCEPT_NAME
where a.prd_name != 'INACTIVE TABLET'
;

--drug to supp
insert into INTERNAL_RELATIONSHIP_STAGE (CONCEPT_CODE_1, CONCEPT_CODE_2)
select distinct fo_prd_id as CONCEPT_CODE_1,CONCEPT_CODE as concept_code_2 
from manufacturer inner join (select CONCEPT_NAME, CONCEPT_CODE from DRUG_CONCEPT_STAGE where CONCEPT_CLASS_ID = 'Supplier')
on MANUFACTURER = CONCEPT_NAME
union 
select distinct b.concept_code,d.concept_code
from pack_drug_product_2 a join drug_concept_stage b on a.prd_name=b.concept_name and b.concept_class_id='Drug Product'
join manufacturer c on a.fo_prd_id=c.fo_prd_id
join (select CONCEPT_NAME, CONCEPT_CODE from drug_concept_stage where CONCEPT_CLASS_ID = 'Supplier') d
on trim(MANUFACTURER) = d.CONCEPT_NAME
where a.prd_name != 'INACTIVE TABLET'
;

--drug to dose form
insert into INTERNAL_RELATIONSHIP_STAGE (CONCEPT_CODE_1, CONCEPT_CODE_2)
select distinct fo_prd_id, concept_code from dose_form_test join (select CONCEPT_NAME, CONCEPT_CODE from drug_concept_stage where CONCEPT_CLASS_ID = 'Dose Form')
on dose_form=concept_name where fo_prd_id not in (select fo_prd_id from pack_drug_product_2)
;

insert into INTERNAL_RELATIONSHIP_STAGE (CONCEPT_CODE_1, CONCEPT_CODE_2)
select a.concept_code,c.concept_code
from drug_concept_stage a join dose_form_test b on a.concept_name=b.prd_name
join drug_concept_stage c on c.concept_name=b.dose_form and c.concept_class_id='Dose Form'
where a.concept_code in (select drug_concept_code from pc_stage)
;









--drug to nfc_code

insert into INTERNAL_RELATIONSHIP_STAGE (CONCEPT_CODE_1, CONCEPT_CODE_2)
select distinct concept_code as concept_code_1, nfc_code as concept_code_2 from 
drugs a join drug_concept_stage b on a.fo_prd_id=b.concept_code
where fo_prd_id not in (select fo_prd_id from pack_drug_product_2) and nfc_code is not null
;


delete from internal_relationship_stage where (concept_code_1,concept_code_2) in (
SELECT concept_code_1,concept_code_2
      FROM (SELECT DISTINCT concept_code_1,concept_code_2, COUNT(concept_code_2) OVER (PARTITION BY concept_code_1) AS irs_cnt
            FROM internal_relationship_stage
              JOIN drug_concept_stage ON concept_code = concept_code_2 AND concept_class_id = 'Ingredient') irs
        JOIN (SELECT DISTINCT drug_concept_code, COUNT(ingredient_concept_code) OVER (PARTITION BY drug_concept_code) AS ds_cnt
              FROM ds_stage) ds
          ON drug_concept_code = concept_code_1   AND irs_cnt != ds_cnt)
and  (concept_code_1,concept_code_2) not in (select drug_concept_code,ingredient_concept_code from ds_stage);    
;











      



