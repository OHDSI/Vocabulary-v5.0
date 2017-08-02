--1 Update latest_update field to new date 
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'Gemscript',
                                          pVocabularyDate        => TRUNC(SYSDATE),
                                          pVocabularyVersion     => 'Gemscript '||SYSDATE,
                                          pVocabularyDevSchema   => 'DEV_gemscript');									  
END;
/
COMMIT;

drop table rel_to_conc_old;
create table rel_to_conc_old as 
select c.concept_id as concept_id_1 , 'Source - RxNorm eq' as relationship_id, concept_id_2 from 
(
select * from dev_dpd.relationship_to_concept where PRECEDENCE  =1 
union 
select * from dev_aus.relationship_to_concept where PRECEDENCE  =1  
) a 
join concept c on c.concept_code = a.concept_code_1 and c.vocabulary_id = a.vocabulary_id_1 and c.invalid_reason is null
;
drop table ds_stage;
create table ds_stage as select * from dev_dmd.ds_stage where rownum =0
;
drop table drug_concept_stage;
create table drug_concept_stage as select * from dev_dmd.drug_concept_stage where rownum =0
;
alter table drug_concept_stage modify concept_code varchar (250) 
;
 drop table relationship_to_concept;
create table relationship_to_concept as select * from dev_dmd.relationship_to_concept where rownum =0
;
 drop table  internal_relationship_stage;
create table internal_relationship_stage as select * from dev_dmd.internal_relationship_stage where rownum =0;
alter table internal_relationship_stage modify concept_code_1 varchar (250) ;
alter table internal_relationship_stage modify concept_code_2 varchar (250) 
;
select * from internal_relationship_stage
;
drop table pc_stage;
create table pc_stage as  select * from dev_dmd.pc_Stage where rownum =0 
;
--add Gemscript concept set, 
--dm+d variant is better 
TRUNCATE TABLE concept_stage
;
insert into concept_stage 
select
null as CONCEPT_ID,
dmd_drug_name as concept_name,  
'Drug' as domain_id,
'Gemscript' as vocabulary_id,
'Gemscript' as concept_class_id,
null as standard_concept,
gemscript_drug_code as concept_code,
(select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date ,-- TRUNC(SYSDATE)
to_date ('31122099', 'ddmmyyyy') as valid_end_date,
null as invalid_reason
from gemscript_dmd_map --table we had before, only God knows how we got this table
;
commit
;
--take concepts from additional tables
--reference table from CPRD
insert into concept_stage 
select 
null as CONCEPT_ID,
PRODUCTNAME as concept_name,  
'Drug' as domain_id,
'Gemscript' as vocabulary_id,
'Gemscript' as concept_class_id,
null as standard_concept,
GEMSCRIPTCODE as concept_code,
(select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date, -- TRUNC(SYSDATE)
to_date ('31122099', 'ddmmyyyy') as valid_end_date,
null as invalid_reason
from gemscript_reference where GEMSCRIPTCODE not in (select concept_code from concept_stage)
;
COMMIT
;
--mappings from Urvi
insert into concept_stage 
select 
null as CONCEPT_ID,
BRAND as concept_name,  
'Drug' as domain_id,
'Gemscript' as vocabulary_id,
'Gemscript' as concept_class_id,
null as standard_concept,
GEMSCRIPT_DRUGCODE as concept_code,
(select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date, -- TRUNC(SYSDATE)
to_date ('31122099', 'ddmmyyyy') as valid_end_date,
null as invalid_reason
from THIN_GEMSC_DMD_0717 where GEMSCRIPT_DRUGCODE not in (select concept_code from concept_stage)
;
COMMIT
;
--Gemscript THIN concepts 
insert into concept_stage 
select 
null as CONCEPT_ID,
GENERIC as concept_name,  
'Drug' as domain_id,
'Gemscript' as vocabulary_id,
'Gemscript THIN'  as concept_class_id,
null as standard_concept,
ENCRYPTED_DRUGCODE as concept_code,
(select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date, -- TRUNC(SYSDATE)
to_date ('31122099', 'ddmmyyyy') as valid_end_date,
null as invalid_reason
from THIN_GEMSC_DMD_0717 
;
COMMIT
;
--CLEAN UP --in the future put the thing into insert (need to find out what those !code mean)
DELETE FROM concept_stage WHERE CONCEPT_NAME IS NULL OR regexp_like (concept_code, '\D') 
;
COMMIT
;
--build concept_relationship_stage table
 truncate table concept_relationship_stage
 ;
 commit
 ;
--Gemscript to dm+d
--new table from URVI
insert into concept_relationship_stage
select 
null as CONCEPT_ID_1, 
null as CONCEPT_ID_2,
GEMSCRIPT_DRUGCODE as concept_code_1,
DMD_CODE as concept_code_2,
'Gemscript' as vocabulary_id_1,
'dm+d' as vocabulary_id_2,
'Maps to' as relationship_id,
(select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date,
to_date ('31122099', 'ddmmyyyy') as valid_end_date,
null as invalid_reason
from THIN_GEMSC_DMD_0717
 ;
commit
;
--old table from Christian
insert into concept_relationship_stage 
select 
null as CONCEPT_ID_1, 
null as CONCEPT_ID_2,
GEMSCRIPT_DRUG_CODE as concept_code_1,
DMD_CODE as concept_code_2,
'Gemscript' as vocabulary_id_1,
'dm+d' as vocabulary_id_2,
'Maps to' as relationship_id,
(select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date,
to_date ('31122099', 'ddmmyyyy') as valid_end_date,
null as invalid_reason
from gemscript_dmd_map  where  GEMSCRIPT_DRUG_CODE not in (select concept_code_1 from  concept_relationship_stage  )
;
commit
;
--mappings between THIN gemscript and Gemscript
insert into concept_relationship_stage
select 
null as CONCEPT_ID_1, 
null as CONCEPT_ID_2,
encrypted_DRUGCODE as concept_code_1,
GEMSCRIPT_DRUGCODE as concept_code_2,
'Gemscript' as vocabulary_id_1,
'Gemscript' as vocabulary_id_2,
'Maps to' as relationship_id,
(select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date,
to_date ('31122099', 'ddmmyyyy') as valid_end_date,
null as invalid_reason
from THIN_GEMSC_DMD_0717  
;
commit
;
--delete mappings to non-existing dm+ds because their ruin further procedures result
--it allows to exist old mappings , they are relatively good but not very precise actually, and we know that if there was exising dm+d concept it'll go to better dm+d RxE way, and actually gives us for about 4000 relationships, 
-- so if we have time we can remap these concepts to RxE, give to medical coder to review them
--but for now let's remain them
delete from concept_relationship_stage 
where vocabulary_id_2 ='dm+d' and concept_code_2 not in (select concept_code from concept where vocabulary_id = 'dm+d')
;
-- GATHER TABLE STATS
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_stage', cascade  => true);
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_relationship_stage', cascade  => true)
;
-- Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
/
COMMIT;

-- Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
/
COMMIT;

-- Add mapping from deprecated to fresh concepts, and also from non-standard to standard concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
/
COMMIT;

-- Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
/
COMMIT; 

--deprecate relationship mappings to Non-standard concepts
--how's this possible?
update concept_relationship_stage set invalid_reason ='D'
;
update concept_relationship_stage set invalid_reason = null where (concept_code_1, concept_Code_2, vocabulary_id_2)  in (
select concept_code_1, concept_Code_2, vocabulary_id_2 from concept_relationship_stage join concept on concept_code = concept_code_2 and vocabulary_id = vocabulary_id_2 and standard_concept ='S' 
)
;
commit
;
--define drug domain (Drug set by default) based on target concept domain
update concept_stage cs 
set domain_id = (select domain_id from (
select distinct --beware of multiple mappings
 r.concept_code_1,r.vocabulary_id_1, c.domain_id
 from
concept_relationship_stage r -- concept_code_1 = s1.concept_code and vocabulary_id_1 = vocabulary_id
join concept c on c.concept_code = r.concept_code_2 and r.vocabulary_id_2 = c.vocabulary_id and r.invalid_reason is null -- and r.vocabulary_id_2 in ('dm+d', 'RxNorm', 'RxNorm Extension')
join 
(select concept_code_1 from (
select distinct --beware of multiple mappings
 r.concept_code_1,r.vocabulary_id_1, c.domain_id
 from
concept_relationship_stage r -- concept_code_1 = s1.concept_code and vocabulary_id_1 = vocabulary_id
 join concept c on c.concept_code = r.concept_code_2 and r.vocabulary_id_2 = c.vocabulary_id and r.invalid_reason is null -- and r.vocabulary_id_2 in ('dm+d', 'RxNorm', 'RxNorm Extension')
) group by concept_code_1 having count(1) =1) zz --exclude those mapped to several domains such as Inert ingredient is a device (wrong BTW), cartridge is a device, etc.
on zz.concept_code_1 = r.concept_code_1
) rr
where rr.concept_code_1 = cs.concept_code and rr.vocabulary_id_1 = cs.vocabulary_id)
;
commit
;
--not covered are Drugs for now
update concept_stage
set domain_id = 'Drug' where domain_id is null
;
select distinct domain_id from concept_stage
;
commit
;
--why in this way????
--for development purpose use temporary THIN_need_to_map table:  
drop table THIN_need_to_map;  --18457 the old version, 13965 --new version (join concept), well, really a big difference. not sure if those existing mappings are correct, 13877 - concept_relationship_stage version, why?
create table THIN_need_to_map as --;select count (1) from THIN_need_to_map; 
select --c.*
t.ENCRYPTED_DRUGCODE as THIN_code, t.GENERIC as THIN_name, nvl (gr.GEMSCRIPTCODE, t.GEMSCRIPT_DRUGCODE) as GEMSCRIPT_code,  nvl ( gr.PRODUCTNAME, t.BRAND)  as GEMSCRIPT_name, c.domain_id
 from THIN_GEMSC_DMD_0717 t 
 full outer join gemscript_reference gr on gr.GEMSCRIPTCODE = t.GEMSCRIPT_DRUGCODE
  left join  concept_relationship_stage r on nvl (gr.GEMSCRIPTCODE, t.GEMSCRIPT_DRUGCODE)  = r.concept_code_1 and r.invalid_reason is null --and r.vocabulary_id_2 in ('dm+d', 'RxNorm', 'RxNorm Extension') and relationship_id = 'Maps to' 
   join concept_stage c -- join and left join gives us different results because of   !1360102 AND   !5264101 codes, so exclude those !!-CODES
   on nvl (gr.GEMSCRIPTCODE, t.GEMSCRIPT_DRUGCODE) = c.concept_code and c.concept_class_id = 'Gemscript'
where r.concept_code_2 is null

;


--define domain_id
--DRUGSUBSTANCE is null and lower
--!!! OK for gemscript part
update THIN_need_to_map n set domain_id = 'Device'
where exists (select 1 from gemscript_reference g 
where regexp_like (PRODUCTNAME, '[a-z]')  --at least 1 [a-z] charachter
and regexp_count(PRODUCTNAME, '[a-z]')>5 -- sometime we have these non HCl, mg as a part of UPPER case concept_name
and
( DRUGSUBSTANCE is null or DRUGSUBSTANCE ='Syringe For Injection') 
and  g.GEMSCRIPTCODE = n.GEMSCRIPT_CODE )
--4758
;
commit
;
--device by the name (taken from dmd?) part 1
--ok
update thin_need_to_map
set domain_id = 'Device' 
where GEMSCRIPT_CODE in (
select GEMSCRIPT_CODE from thin_need_to_map where
regexp_like (lower(THIN_name), 'stoma caps|urinal systems|shampoo|sunscreen|amidotrizoate|dialysis|smoflipid|camino|maxamum|sno-pro|lubri|peptamen|pepti-junior|dressing|diagnostic|glove|supplement| rope|weight|resource|accu-chek|accutrend|procal|glytactin|gauze|keyomega|cystine|docomega|anamixcranberry|pedialyte|hydralyte|hcu cooler|pouch')
union 
select GEMSCRIPT_CODE from thin_need_to_map where
regexp_like (lower(THIN_name),'burger|biscuits|stocking|strip|remover|chamber|gauze|supply|beverage|cleanser|soup|protector|nutrision|repellent|wipes|kilocalories|cake|roll|adhesive|milk|dessert|medium chain|prozero|amino acid supplement|long chain|low protein|pouches|ribbon|cannula|swabs|bandage|cylinder')
union
select GEMSCRIPT_CODE from  thin_need_to_map where
regexp_like (lower(gemscript_name),'amidotrizoate|burger|biscuits|stocking|strip|remover|chamber|gauze|supply|beverage|cleanser|soup|protector|nutrision|repellent|wipes|kilocalories|cake|roll|adhesive|milk|dessert|medium chain|prozero|amino acid supplement|long chain|low protein|pouches|ribbon|cannula|swabs|bandage|cylinder')
union
select GEMSCRIPT_CODE from  thin_need_to_map where
regexp_like (lower(gemscript_name), 'dialysis|smoflipid|camino|maxamum|sno-pro|lubri|peptamen|pepti-junior|dressing|diagnostic|glove|supplement| rope|weight|resource|accu-chek|accutrend|procal|glytactin|gauze|keyomega|cystine|docomega|anamixcranberry|pedialyte|hydralyte|hcu cooler|pouch')
)
and domain_id ='Drug'
;
commit
;
--device by the name (taken from dmd?) part 2
--ok
update thin_need_to_map
set domain_id = 'Device'
--put these into script above
 where GEMSCRIPT_CODE in (
select GEMSCRIPT_CODE from thin_need_to_map where
regexp_like (lower(THIN_name),'breath test|pizza|physical|diet food|sunscreen|tubing|nutrison|elasticated vest|oxygen|spaghetti|irrigation |sunscreen cream|sheaths|lancet| wash|contact lens|bag|gluten|plast|wax|catheter|device|needle|needle|emollient|feeding|colostomy| toe |rubber|flange|cotton|stockinette|urostomy|tube |ostomy|cracker|shield|larve|belt|pasta|garments|bread')
or 
regexp_like (lower(gemscript_name),'breath test|pizza|physical|diet food|sunscreen|tubing|nutrison|elasticated vest|oxygen|spaghetti|irrigation |sunscreen cream|sheaths|lancet| wash|contact lens|bag|gluten|plast|wax|catheter|device|needle|needle|emollient|feeding|colostomy| toe |rubber|flange|cotton|stockinette|urostomy|tube |ostomy|cracker|shield|larve|belt|pasta|garments|bread')
)
and domain_id ='Drug'
;
commit
;
--these concepts are drugs anyway
--put this condition into concept above!!! 
--ok
update thin_need_to_map n set domain_id = 'Drug' where exists (
select 1 from 
 gemscript_reference g where g.GEMSCRIPTCODE = n.GEMSCRIPT_CODE
and n.domain_id='Device' and lower( formulation) in (
'capsule',
'chewable tablet',
--'cream',
'cutaneous solution',
'ear drops',
'ear/eye drops solution',
'emollient',
'emulsion',
'emulsion for infusion',
'enema',
'eye drops',
'eye ointment',
--'gel',
'granules',
'homeopathic drops',
'homeopathic pillule',
'homeopathic tablet',
'inhalation powder',
'injection',
'injection solution',
'lotion',
'ointment',
'oral gel',
'oral solution',
'oral suspension',
--'plasters',
'powder',
'sachets',
'solution for injection',
'suppository',
'tablet', 
'infusion',
'solution',
'Suspension for injection',
'Spansule',
'lozenge', 
'cream',
'Intravenous Infusion'
)
)
;
--make standard representation of multicomponent drugs
update thin_need_to_map 
set THIN_NAME = regexp_replace (THIN_NAME, '%/','% / ') 
where regexp_like (thin_name, '%/') and domain_id= 'Drug'
;
update thin_need_to_map 
set THIN_NAME = regexp_replace (thin_name, '( with )(\D)',' / \2')
where regexp_like (thin_name, ' with ') and domain_id= 'Drug'
;
update thin_need_to_map 
set THIN_NAME = regexp_replace (thin_name, '( with )(\d)','+\2')
where regexp_like (thin_name, ' with ') and domain_id= 'Drug'
;
update thin_need_to_map 
set THIN_NAME = regexp_replace (THIN_NAME, ' & ',' / ') 
where regexp_like (thin_name, ' & ') and not regexp_like (thin_name, ' & \d') and domain_id= 'Drug'
;
update thin_need_to_map 
set THIN_NAME = regexp_replace (THIN_NAME, ' and ',' / ') 
where regexp_like (thin_name, ' and ') and not regexp_like (thin_name, ' and \d') and domain_id= 'Drug'
; 
commit
;
update thin_need_to_map 
set gemscript_name = regexp_replace (gemscript_name, '%/','% / ') 
where regexp_like (gemscript_name, '%/') and domain_id= 'Drug'
;
update thin_need_to_map 
set gemscript_name = regexp_replace (gemscript_name, '( with )(\D)',' / \2')
where regexp_like (gemscript_name, ' with ')   and domain_id= 'Drug'
;
update thin_need_to_map 
set THIN_NAME = regexp_replace (gemscript_name, '( with )(\d)','+\2')
where regexp_like (gemscript_name, ' with ') and domain_id= 'Drug'
;
update thin_need_to_map 
set gemscript_name = regexp_replace (gemscript_name, ' & ',' / ') 
where regexp_like (gemscript_name, ' & ') and not regexp_like (gemscript_name, ' & \d') and domain_id= 'Drug'
;
update thin_need_to_map 
set gemscript_name = regexp_replace (gemscript_name, ' and ',' / ') 
where regexp_like (gemscript_name, ' and ') and not regexp_like (gemscript_name, ' and \d') and domain_id= 'Drug'
;
update thin_need_to_map set THIN_NAME = regexp_replace (THIN_NAME, 'i.u.','iu')  where thin_name like '%i.u.%'
;
update thin_need_to_map set gemscript_name = regexp_replace (gemscript_name, 'i.u.','iu')  where gemscript_name like '%i.u.%'
;
commit
;
--define what's a pack based on the concept_name, then manually parse this out, then add pack_component names as a codes (check the code replacing script) and add pack_components as a drug components in ds_stage creation algorithms
drop table packs_out;
create table packs_out as
select  THIN_NAME,GEMSCRIPT_CODE,GEMSCRIPT_NAME , cast ('' as varchar (250)) as pack_component , cast ('' as int) as amount
 from   
  thin_need_to_map t  
where  t.domain_id = 'Drug' and gemscript_name not like 'Becloforte%'
and (
gemscript_name like '% pack%'
or
gemscript_code in
--packs defined manually
 ('67678021', '76122020', '80033020', '1637007')
 or
 regexp_like (thin_name, '(\d\s*x\s*\d)|(estradiol.*\+)')
 or 
 regexp_count (thin_name, 'tablet| cream|capsule')>1
 )
 ;
 
 drop table  packs_in;
create table  packs_in as select * from packs_out where rownum =0
;
WbImport -file=C:/work/gemscript_packs_in.txt
         -type=text
         -table=PACKS_IN
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -decimal=.
         -fileColumns=GEMSCRIPT_CODE,THIN_NAME,GEMSCRIPT_NAME,PACK_COMPONENT,AMOUNT,$wb_skip$
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100;
 
; 
 insert into pc_stage (PACK_CONCEPT_CODE,DRUG_CONCEPT_CODE,AMOUNT,BOX_SIZE)
 select GEMSCRIPT_CODE, PACK_COMPONENT,AMOUNT, ''  from packs_in
;
 commit
 ;
insert into thin_need_to_map (THIN_CODE,THIN_NAME,GEMSCRIPT_CODE,GEMSCRIPT_NAME,DOMAIN_ID)
select distinct '', DRUG_CONCEPT_CODE, DRUG_CONCEPT_CODE,DRUG_CONCEPT_CODE, 'Drug' from pc_stage
;
commit
; 
 drop table thin_comp;
create table thin_comp as 
select regexp_substr 
(lower (a.drug_comp), 
'((\d)*[.,]*\d+)(\s)*(mg|%|ml|mcg|hr|hours|unit(s?)|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit(s?)|nanogram(s)*|x|ppm|million units| Kallikrein inactivator units|kBq|microlitres|MBq|molar|micromol)(/((\d)*[.,]*\d+)*(\s*)(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop))*') as dosage
,  replace ( trim (regexp_substr  (lower (thin_name),'(\s|\()[[:digit:]\.]+(\s*)(litre(s?)|ml)')),'(')  as volume, A.* 
 from (
select distinct
trim(regexp_substr(  (regexp_replace (t.thin_name, ' / ', '!')), '[^!]+', 1, levels.column_value))  as drug_comp , t.* 
from thin_need_to_map t, --(!!!select * from thin_need_to_map union select ... from packs_in) t
table(cast(multiset(select level from dual connect by  level <= length (regexp_replace(regexp_replace (t.thin_name, ' / ', '!'), '[^!]+'))  + 1) as sys.OdciNumberList)) levels) a
where a.domain_id ='Drug' 
--exclusions
--Bendroflumethiazide / potassium 2.5mg+7.7mmol modified release tablets 
and not regexp_like (lower (thin_name), '[[:digit:]\,\.]+.*\+(\s*)[[:digit:]\,\.].*') 
--Co-triamterzide 50mg/25mg tablets
--and not regexp_like (thin_name, '\dm(c*)g/[[:digit:]\,\.]+m(c*)g')
union
--Bendroflumethiazide / potassium 2.5mg+7.7mmol modified release tablets 
 select 
trim (regexp_substr(dosage_0, '[^+]+',1,levels.column_value)) ||denom  
  as dosage, volume,
trim(regexp_substr(  (regexp_replace (t.thin_name, ' / ', '!')), '[^!]+', 1, levels.column_value))  as drug_comp 
    ,THIN_CODE,THIN_NAME,GEMSCRIPT_CODE,GEMSCRIPT_NAME,DOMAIN_ID 
from (
select regexp_substr (lower (thin_name), '((\d)*[.,]*\d+)(\s)*(g|mg|%|mcg|iu|mmol|micrograms)(\s)*\+(\s)*[[:digit:]\,\.]+(g|mg|%|mcg|iu|mmol|micrograms|ku)((\s)*\+(\s)*((\d)*[.,]*\d+)*(\s)*(g|mg|%|mcg|iu|mmol|micrograms))*') as dosage_0,
regexp_substr (lower (THIN_NAME) , '/[[:digit:]\,\.]+(ml| hr|g|mg)') as denom,
replace ( trim (regexp_substr  (thin_name,'(\s|\()[[:digit:]\.]+(\s*)(litre(s?)|ml)')),'(')  as volume,
 t.* from 
thin_need_to_map t
where regexp_like (thin_name, '((\d)*[.,]*\d+)(\s)*(g|mg|%|mcg|iu|mmol|micrograms)(\s)*\+(\s)*[[:digit:]\,\.]+(g|mg|%|mcg|iu|mmol|micrograms|ku)((\s)*\+(\s)*((\d)*[.,]*\d+)*(\s)*(g|mg|%|mcg|iu|mmol|micrograms))*', 'i') and domain_id ='Drug' 
) t,
table(cast(multiset(select level from dual connect by level <= length (regexp_replace(regexp_replace (t.thin_name, ' / ', '!'), '[^!]+'))  + 1) as sys.OdciNumberList)) levels 
;
--/ampoule is treated as denominator then
update thin_comp set dosage = replace (dosage, '/ampoule') where dosage like '%/ampoule'
;
--',c is treated as dosage
update thin_comp set dosage = null where regexp_like (dosage, '^\,')
;
commit
;
--select * from thin_comp
;
CREATE INDEX drug_comp_ix ON thin_comp (lower (drug_comp))  
;
--how to define Ingredient, change scripts to COMPONENTS and use only (  lower (a.thin_name) like lower (b.concept_name)||' %' tomorrow!!!
--take the longest ingredient, if this works, rough dm+d is better, becuase it has Sodium bla-bla-nate and RxNorm has just bla-bla-nate 
--don't need to have two parts here
--Execution time: 57.41s
--Execution time: 1m 41s when more vocabularies added 

drop table i_map;
create table i_map as ( -- enhanced algorithm added  lower (a.thin_name) like lower '% '||(b.concept_name)||' %'
select * from 
(
select distinct a.*, b.concept_id, b.concept_name,  b.vocabulary_id,  RANK() OVER (PARTITION BY a.drug_comp ORDER BY
length(b.concept_name)  desc, b.vocabulary_id desc) as rank1
--look what happened to previous 4 
from  thin_comp a 
 join  concept b
on (  
 lower (a.drug_comp) like lower (b.concept_name)||' %' or lower (a.drug_comp)=lower (b.concept_name) 
 )
and vocabulary_id in('RxNorm', 'dm+d','RxNorm Extension', 'AMT', 'LPD_Australia', 'DPD', 'GRR',
'BDPM', 'AMIS', 'Multilex') and concept_class_id in ( 'Ingredient', 'VTM', 'AU Substance')  and ( b.invalid_reason is null or b.invalid_reason ='U')
where a.domain_id ='Drug')
--take the longest ingredient
where rank1 = 1 
)
;
--map Ingredients derived from different vocabularies to RxNorm(E)
drop table rel_to_ing_1 ;
create table rel_to_ing_1 as
select distinct i.DOSAGE,i.DRUG_COMP,i.THIN_CODE,i.THIN_NAME,i.GEMSCRIPT_CODE,i.GEMSCRIPT_NAME,i.VOLUME
, b.concept_id as target_id, b.concept_name as target_name, b.vocabulary_id as target_vocab, b.concept_class_id as target_class from 
i_map i
 join (
select concept_id_1,relationship_id, concept_id_2 from concept_relationship where invalid_reason is null union select concept_id_1,relationship_id, concept_id_2 from rel_to_conc_old
) r on i.concept_id = r.concept_id_1 and relationship_id in ('Maps to', 'Source - RxNorm eq', 'Concept replaced by' ) 
  join concept b on b.concept_id = r.concept_id_2  and b.vocabulary_id like 'RxNorm%' and b.invalid_reason is null 
  and b.concept_id !=  21014036 -- Syrup Ingredient
;

--the same but with gemscript_name
--make standard representation of multicomponent drugs
--select count(*) from thin_comp2 ; select * from thin_comp where thin_code = '97245997'; select * from rel_to_ing_1 where thin_code is null;
;
drop table thin_comp2; 
create table thin_comp2 as 
select regexp_substr 
(lower (a.drug_comp), 
'((\d)*[.,]*\d+)(\s)*(mg|%|ml|mcg|hr|hours|unit(s?)|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit(s?)|nanogram(s)*|x|ppm|million units| Kallikrein inactivator units|kBq|microlitres|MBq|molar|micromol)(/((\d)*[.,]*\d+)*(\s*)(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop))*') as dosage
,  replace ( trim (regexp_substr  (lower (gemscript_name),'(\s|\()[[:digit:]\.]+(\s*)(litre(s?)|ml)')),'(')  as volume, A.* 
 from (
select distinct
trim(regexp_substr(  (regexp_replace (t.gemscript_name, ' / ', '!')), '[^!]+', 1, levels.column_value))  as drug_comp , t.* 
from thin_need_to_map t,
table(cast(multiset(select level from dual connect by  level <= length (regexp_replace(regexp_replace (t.gemscript_name, ' / ', '!'), '[^!]+'))  + 1) as sys.OdciNumberList)) levels) a
where a.domain_id ='Drug' 
--exclusions
--Bendroflumethiazide / potassium 2.5mg+7.7mmol modified release tablets 
and not regexp_like (gemscript_name, '[[:digit:]\,\.]+.*\+(\s*)[[:digit:]\,\.].*', 'i') 
and gemscript_code not in (select gemscript_code from rel_to_ing_1)
--Co-triamterzide 50mg/25mg tablets
--and not regexp_like (gemscript_name, '\dm(c*)g/[[:digit:]\,\.]+m(c*)g')
union
--Bendroflumethiazide / potassium 2.5mg+7.7mmol modified release tablets 
 select 
trim (regexp_substr(dosage_0, '[^+]+',1,levels.column_value)) ||denom  
  as dosage, volume,
trim(regexp_substr(  (regexp_replace (t.gemscript_name, ' / ', '!')), '[^!]+', 1, levels.column_value))  as drug_comp 
    ,THIN_CODE,gemscript_name,GEMSCRIPT_CODE,GEMSCRIPT_NAME,DOMAIN_ID 
from (
select regexp_substr (lower (gemscript_name), '((\d)*[.,]*\d+)(\s)*(mg|%|mcg|iu|mmol|micrograms)(\s)*\+(\s)*[[:digit:]\,\.]+(mg|%|mcg|iu|mmol|micrograms)((\s)*\+(\s)*((\d)*[.,]*\d+)*(\s)*(mg|%|mcg|iu|mmol|micrograms))*') as dosage_0,
regexp_substr (lower (gemscript_name) , '/[[:digit:]\,\.]+(ml| hr|g|mg)') as denom,
replace ( trim (regexp_substr  (lower (gemscript_name),'(\s|\()[[:digit:]\.]+(\s*)(litre(s?)|ml)')),'(')  as volume,
 t.* from 
thin_need_to_map t
where regexp_like (lower (gemscript_name), '((\d)*[.,]*\d+)(\s)*(mg|%|mcg|iu|mmol|micrograms)(\s)*\+(\s)*[[:digit:]\,\.]+(mg|%|mcg|iu|mmol|micrograms)((\s)*\+(\s)*((\d)*[.,]*\d+)*(\s)*(mg|%|mcg|iu|mmol|micrograms))*')
 and domain_id ='Drug' and gemscript_code not in (select gemscript_code from rel_to_ing_1)
) t,
table(cast(multiset(select level from dual connect by level <= length (regexp_replace(regexp_replace (t.gemscript_name, ' / ', '!'), '[^!]+'))  + 1) as sys.OdciNumberList)) levels 
;
--/ampoule is treated as denominator then
update thin_comp2 set dosage = replace (dosage, '/ampoule') where dosage like '%/ampoule'
;
--',c is treated as dosage
update thin_comp2 set dosage = null where regexp_like (dosage, '^\,')
;
commit
;
drop table i_map2;
create table i_map2 as ( -- enhanced algorithm added  lower (a.gemscript_name) like lower '% '||(b.concept_name)||' %'
select * from 
(
select distinct a.*, b.concept_id, b.concept_name,  b.vocabulary_id,  RANK() OVER (PARTITION BY a.drug_comp ORDER BY
length(b.concept_name)  desc, b.vocabulary_id desc) as rank1
--look what happened to previous 4 
from  thin_comp2 a 
 join  concept b
on (  
 lower (a.drug_comp) like lower (b.concept_name)||' %' or lower (a.drug_comp)=lower (b.concept_name) 
 )
and vocabulary_id in('RxNorm', 'dm+d','RxNorm Extension', 'AMT', 'LPD_Australia', 'DPD', 'GRR',
'BDPM', 'AMIS', 'Multilex') and concept_class_id in ( 'Ingredient', 'VTM', 'AU Substance')  and b.invalid_reason is null
where a.domain_id ='Drug')
--take the longest ingredient
where rank1 = 1 
)
;

drop table rel_to_ing_2 ;
create table rel_to_ing_2 as
select distinct i.DOSAGE,i.DRUG_COMP,i.THIN_CODE,i.THIN_NAME,i.GEMSCRIPT_CODE,i.GEMSCRIPT_NAME, i.volume
, b.concept_id as target_id, b.concept_name as target_name, b.vocabulary_id as target_vocab, b.concept_class_id as target_class from 
i_map2 i
 join (
select concept_id_1,relationship_id, concept_id_2 from concept_relationship where invalid_reason is null union select concept_id_1,relationship_id, concept_id_2 from rel_to_conc_old
) r on i.concept_id = r.concept_id_1 and relationship_id in ('Maps to', 'Source - RxNorm eq', 'Concept replaced by') 
  join concept b on b.concept_id = r.concept_id_2  and b.vocabulary_id like 'RxNorm%' and b.invalid_reason is null
    and b.concept_id !=  21014036 -- Syrup Ingredient
; 

--make temp tables as it was in dmd drug procedure
drop table ds_all_tmp;  
create table ds_all_tmp as 
select dosage, drug_comp, thin_name as concept_name, gemscript_code as concept_code, target_name as INGREDIENT_CONCEPT_CODE, target_name as ingredient_concept_name, trim (volume) as volume, TARGET_ID as ingredient_id from rel_to_ing_1 
union 
select dosage, drug_comp, thin_name as concept_name, gemscript_code as concept_code, target_name as INGREDIENT_CONCEPT_CODE, target_name as ingredient_concept_name, trim (volume)  as volume , TARGET_ID as ingredient_id from rel_to_ing_2
;
--!!! manual table
 
drop table full_manual;
create table full_manual 
(
DOSAGE varchar (50),	VOLUME  varchar (50),	THIN_NAME	 varchar (550), GEMSCRIPT_NAME  varchar (550),	ingredient_id	 int, THIN_CODE  varchar (50),	gemscript_code  varchar (50),	INGREDIENT_CONCEPT_CODE  varchar (250),	DOMAIN_ID  varchar (50)
)
;
WbImport -file=C:/work/gemscript_manual/full_manual.txt
         -type=text
         -table=FULL_MANUAL
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -decimal=.
         -fileColumns=DOSAGE,VOLUME,THIN_NAME,GEMSCRIPT_NAME,INGREDIENT_ID,THIN_CODE,GEMSCRIPT_CODE,INGREDIENT_CONCEPT_CODE,DOMAIN_ID
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=1000;
;
Update full_manual set ingredient_concept_code=regexp_replace(ingredient_concept_code, '"')
;
MERGE INTO full_manual fm
     USING (SELECT distinct  first_value (c.concept_id) over (PARTITION BY c.concept_name order by c.concept_id ) as concept_id, lower (c.concept_name) as concept_name
              FROM concept a join concept_relationship cr
              on a.concept_id = cr.concept_id_1 
              JOIN CONCEPT C on c.concept_id = cr.concept_id_2 and relationship_id in ('Maps to', 'Source - RxNorm eq', 'Concept replaced by' ) 

 where  c.vocabulary_id like 'RxNorm%' and c.concept_class_id = 'Ingredient' and c.invalid_reason is null) i
        ON ( replace (lower(fm.ingredient_concept_code), '"') = lower (i.concept_name))
WHEN MATCHED
THEN
   UPDATE SET fm.INGREDIENT_ID = i.concept_id;
COMMIT;

MERGE INTO full_manual fm
     USING (SELECT distinct   c.concept_name  , c.concept_id 
              FROM concept c where  c.vocabulary_id like 'RxNorm%' and c.concept_class_id = 'Ingredient' and c.invalid_reason is null) i
        ON (fm.INGREDIENT_ID = i.concept_id)
WHEN MATCHED
THEN
   UPDATE SET fm.ingredient_concept_code = i.concept_name;
COMMIT;

 -- update full_manual set ingredient_concept_code = initcap (ingredient_concept_code)
--  ;
--  update full_manual set dosage = lower (dosage)
 -- ;
  commit
 ;

delete from ds_all_tmp where concept_code in (select gemscript_code from full_manual where INGREDIENT_CONCEPT_CODE is not null);
commit
;
insert into ds_all_tmp (DOSAGE,DRUG_COMP,CONCEPT_NAME,CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,INGREDIENT_CONCEPT_NAME,VOLUME, ingredient_id)
select distinct DOSAGE, '', nvl (thin_name, gemscript_name), gemscript_CODE, INGREDIENT_CONCEPT_CODE, INGREDIENT_CONCEPT_CODE, volume, INGREDIENT_ID from full_manual  where ingredient_concept_code is not null
;
--domain_id definition
update  thin_need_to_map t set domain_id = (select distinct domain_id from full_manual m where t.gemscript_code = m.gemscript_code)
where exists (select 1 from full_manual m where t.gemscript_code = m.gemscript_code and domain_id is not null)
;
commit
;
--packs after manual table in case if in manual table there will be packs
delete from ds_all_tmp where concept_code in (Select pack_concept_code from pc_stage)
;
--then merge it with ds_all_tmp, for now temporary decision - make dosages NULL to avoid bug
--remove ' ' inside the dosage to make the same as it was before in dmd
update ds_all_tmp set dosage = replace (dosage, ' ')
;
--clean up
update ds_all_tmp set dosage =  replace(dosage, '/') where regexp_like (dosage, '/$')
;
--dosage distribution along the ds_Stage
drop table ds_all;
create table ds_all as 
select distinct
case when regexp_substr (lower (dosage), '[[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units|unit dose|drop)') = lower (dosage) 
and not regexp_like (dosage, '%') 
then regexp_replace (regexp_substr (dosage, '[[:digit:]\,\.]+'), ',')
else  null end 
as amount_value,

case when regexp_substr (lower (dosage), '[[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units|unit dose|drop)') = lower (dosage) 
and not regexp_like (dosage, '%') 
then  regexp_replace  (lower (dosage), '[[:digit:]\,\.]+') 
else  null end
as amount_unit,

case when 
( regexp_substr (lower (dosage),
 '[[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop)') = lower (dosage)

 and regexp_substr (volume, '[[:digit:]\,\.]+') is null or regexp_like (dosage, '%') )
then regexp_replace (regexp_substr (dosage, '^[[:digit:]\,\.]+') , ',')
    when  regexp_substr (lower (dosage),
 '[[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop)') = lower (dosage)
  and regexp_substr (volume, '[[:digit:]\,\.]+') is not null then
 cast (  regexp_substr (volume, '[[:digit:]\,\.]+') * regexp_replace (regexp_substr (dosage, '^[[:digit:]\,\.]+') , ',')  / nvl ( regexp_replace( regexp_replace (regexp_substr (dosage, '/[[:digit:]\,\.]+'), ','), '/'), 1)  as varchar (250))
else  null end
as numerator_value,

case when regexp_substr (lower (dosage), 
'[[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop)') = lower (dosage)
or regexp_like (dosage, '%') 
then regexp_substr (dosage, 'mg|%|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|microlitres', 1,1, 'i') 
else  null end
as numerator_unit,

case when 
(
regexp_substr (dosage, '[[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)|h|square cm|microlitres|unit dose|drop)') = dosage
or regexp_like (dosage, '%')
)
and volume is null
then regexp_replace( regexp_replace (regexp_substr (dosage, '/[[:digit:]\,\.]+'), ','), '/')
when  volume is not  null then  regexp_substr (volume, '[[:digit:]\,\.]+')
else  null end
as denominator_value,

case when 
(regexp_substr (dosage, '[[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|microlitres|hour(s)*|h|square cm|unit dose|drop)') = dosage
or regexp_like (dosage, '%')
) and volume is null
then regexp_substr (dosage, '(g|dose|ml|mg|ampoule|litre|hour(s)*|h*|square cm|microlitres|unit dose|drop)$') 
when volume is not  null then  regexp_replace (volume, '[[:digit:]\,\.]+')
else null end
as denominator_unit,
concept_code, concept_name, DOSAGE, DRUG_COMP, INGREDIENT_CONCEPT_CODE, INGREDIENT_CONCEPT_NAME
from ds_all_tmp 
;
--!!!check the previous script for dmd -patterns should be similar here
--add missing denominator if for the other combination it exist
update ds_all a set (a.DENOMINATOR_VALUE, a.DENOMINATOR_unit )= 
(select distinct b.DENOMINATOR_VALUE, b.DENOMINATOR_unit  from 
 ds_all b where a.CONCEPT_CODE = b.CONCEPT_CODE 
 and a.DENOMINATOR_unit is null and b.DENOMINATOR_unit is not null )
-- a.numerator_value= a.amount_value,a.numerator_unit= a.amount_unit,a.amount_value = null, a.amount_unit = null
 where exists 
 (select 1 from 
 ds_all b where a.CONCEPT_CODE = b.CONCEPT_CODE 
 and a.DENOMINATOR_unit is null and b.DENOMINATOR_unit is not null )
;
--somehow we get amount +denominator
update ds_all a  set  a.numerator_value= a.amount_value,a.numerator_unit= a.amount_unit,a.amount_value = null, a.amount_unit = null
where a.denominator_unit is not null and numerator_unit is null
;
commit

;
update ds_all
 set amount_VALUE = null where amount_VALUE ='.'
;
truncate table DS_STAGE
;
insert into DS_STAGE (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT) 
select distinct
--add distinct here because of Paracetamol / pseudoephedrine / paracetamol / diphenhydramine tablet
 CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT from ds_all
;

-- update denominator with existing value for concepts having empty and non-emty denominator value/unit
 --fix wierd units
update ds_Stage
set amount_unit = 'unit' where amount_unit in('u', 'iu')
;
update ds_Stage
set NUMERATOR_UNIT = 'unit' where NUMERATOR_UNIT in('u', 'iu')
;
update ds_Stage
set DENOMINATOR_UNIT = '' where DENOMINATOR_UNIT ='ampoule'
;
update ds_Stage
set DENOMINATOR_UNIT = replace (DENOMINATOR_UNIT, ' ') where DENOMINATOR_UNIT like '% %'
 ;
delete from ds_Stage where ingredient_concept_code ='Syrup'
;
delete from ds_Stage where 0 in (numerator_value,amount_value,denominator_value)
;
--sum up the Zinc undecenoate 20% / Undecenoic acid 5% cream
DELETE
FROM DS_STAGE
WHERE DRUG_CONCEPT_CODE = '1637007' AND   INGREDIENT_CONCEPT_CODE = 'OMOP1021956' AND   NUMERATOR_VALUE = 50;
UPDATE DS_STAGE    SET NUMERATOR_VALUE = 250
WHERE DRUG_CONCEPT_CODE = '1637007' AND   INGREDIENT_CONCEPT_CODE = 'OMOP1021956' AND   NUMERATOR_VALUE = 200;
; 

--percents
--update ds_stage changing % to mg/ml, mg/g, etc.
--simple, when we have denominator_unit so we can define numerator based on denominator_unit
update ds_stage 
set numerator_value =  DENOMINATOR_VALUE * NUMERATOR_VALUE * 10, 
numerator_unit = 'mg'
where numerator_unit = '%' and DENOMINATOR_UNIT in ('ml', 'gram', 'g')
;
update ds_stage 
set numerator_value =  DENOMINATOR_VALUE * NUMERATOR_VALUE * 0.01, 
numerator_unit = 'mg'
where numerator_unit = '%' and DENOMINATOR_UNIT in ('mg')
;
update ds_stage 
set numerator_value =  DENOMINATOR_VALUE * NUMERATOR_VALUE * 10, 
numerator_unit = 'g'
where numerator_unit = '%' and DENOMINATOR_UNIT in ('litre')
;
--let's make only %-> mg/ml if denominator is null
 update ds_stage ds
set numerator_value = NUMERATOR_VALUE * 10, 
numerator_unit = 'mg',
denominator_unit = 'ml'
where numerator_unit = '%' 
and denominator_unit is null and denominator_value is null
;
commit
;
delete from ds_stage where drug_concept_code in (Select pack_concept_code from pc_stage)
;
commit
;
--check for non ds_stage cover
select * from thin_need_to_map where gemscript_code not in (select drug_concept_code from ds_stage where drug_concept_code is not null)
 and gemscript_code not in (select gemscript_code from full_manual where gemscript_code is not null) and domain_id = 'Drug' 
and gemscript_code not in (select pack_concept_code from pc_stage where pack_concept_code is not null )
;
--apply the dose form updates then to extract them from the original names
--make a proper dose form from the short terms used in a concept_names

update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'oin$','ointment' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'tab$','tablet' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'inj$','injection' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'cre$','cream' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'lin$','linctus', 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'sol$','solution' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'cap$','capsule' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'loz$','lozenge' , 1,1,'i')
;
update thin_need_to_map set  
thin_name = regexp_replace (thin_name, 'lozenge$','lozenges' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'sus$','suspension' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'eli$','elixir' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'sup$','suppositories' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'gra$','granules' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'pow$','powder' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'pel$','pellets' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'lot$','lotion' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'pre-filled syr$','pre-filled syringe' , 1,1,'i') 
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'syr$','syrup' , 1,1,'i') 
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'app$','applicator' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'dro$','drops' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'aer$','aerosol' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'liq$','liquid' ,1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'homeopathic pillules$','pillules' ,1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'spa$','spansules' ,1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'emu$','emulsion' ,1,1,'i')
;
--paste
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'pas$','paste' ,1,1,'i')
;
--pillules
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'pills$','pillules' ,1,1,'i')
;
--spray
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'spr$','spray' ,1,1,'i')
;
--inhalation
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'inh$','inhalation' ,1,1,'i')
;
--suppositories
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'suppository$','suppositories' ,1,1,'i')
;
--oitnment
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'oitnment$','ointment' ,1,1,'i')
;
--pessary
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'pes$','pessary' ,1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'pessary$','pessaries' ,1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'spansules$','capsule' ,1,1,'i') 
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'globuli$','granules' ,1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'sach$','sachet' ,1,1,'i')
;
commit
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'oin$','ointment' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'tab$','tablet' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'inj$','injection' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'cre$','cream' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'lin$','linctus', 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'sol$','solution' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'cap$','capsule' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'loz$','lozenge' , 1,1,'i')
;
update thin_need_to_map set  
thin_name = regexp_replace (thin_name, 'lozenge$','lozenges' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'sus$','suspension' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'eli$','elixir' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'sup$','suppositories' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'gra$','granules' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'pow$','powder' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'pel$','pellets' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'lot$','lotion' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'pre-filled syr$','pre-filled syringe' , 1,1,'i') 
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'syr$','syrup' , 1,1,'i') 
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'app$','applicator' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'dro$','drops' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'aer$','aerosol' , 1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'liq$','liquid' ,1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'homeopathic pillules$','pillules' ,1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'spa$','spansules' ,1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'emu$','emulsion' ,1,1,'i')
;
--paste
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'pas$','paste' ,1,1,'i')
;
--pillules
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'pills$','pillules' ,1,1,'i')
;
--spray
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'spr$','spray' ,1,1,'i')
;
--inhalation
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'inh$','inhalation' ,1,1,'i')
;
--suppositories
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'suppository$','suppositories' ,1,1,'i')
;
--oitnment
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'oitnment$','ointment' ,1,1,'i')
;
--pessary
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'pes$','pessary' ,1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'pessary$','pessaries' ,1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'spansules$','capsule' ,1,1,'i') 
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'globuli$','granules' ,1,1,'i')
;
update thin_need_to_map set 
thin_name = regexp_replace (thin_name, 'sach$','sachet' ,1,1,'i')
;
commit
;
--Capsules
--;
--select  * from concept where lower( concept_name) ='capsules'
;
--how to make plural: add 's' or 'y' replace with 'ies'
--apply the same algotithm as used for ingredients
--Execution time: 3m 28s when "mm" is used
 
drop table f_map;
create table f_map as ( -- enhanced algorithm added  lower (a.thin_name) like lower '% '||(b.concept_name)||' %'
select * from 
(
select distinct a.*, b.concept_id, b.concept_name,  b.vocabulary_id, mm.concept_name_2, mm.concept_id_2, mm.vocabulary_id_2,  RANK() OVER (PARTITION BY a.gemscript_code ORDER BY  length(b.concept_name) desc, b.vocabulary_id desc) as rank1
 
from  thin_need_to_map a 
 join  concept b
on (
regexp_like (
 lower (nvl (a.thin_name, a.GEMSCRIPT_NAME)),
 lower  (' '||b.concept_name||'( |$|s|es)')
 ) 
or regexp_like (
 lower (nvl (a.thin_name, a.GEMSCRIPT_NAME)), lower  (' '||regexp_replace  (b.concept_name, 'y$', 'ies') ||'( |$)')
 ) 
)
and vocabulary_id in('RxNorm', 'dm+d','RxNorm Extension', 'AMT', 'BDPM', 'AMIS', 'Multilex', 'DPD', 'LPD_Australia') and concept_class_id in ( 'Dose Form', 'Form', 'AU Qualifier')   and invalid_reason is null
join 
(
select  c.concept_id as source_id, nvl (d.concept_name, c.concept_name) as concept_name_2, nvl (d.concept_id, c.concept_id) as concept_id_2 ,nvl (d.vocabulary_id, c.vocabulary_id) as vocabulary_id_2
 from concept c
left join 
(
select concept_id_1,relationship_id, concept_id_2 from concept_relationship where invalid_reason is null union select concept_id_1,relationship_id, concept_id_2 from rel_to_conc_old
) r  on c.concept_id = r.concept_id_1 and relationship_id ='Source - RxNorm eq'
left join concept d on d.concept_id = r.concept_id_2  and d.vocabulary_id like 'RxNorm%' and d.invalid_reason is null and d.concept_class_id = 'Dose Form'
where c.vocabulary_id in('RxNorm', 'dm+d','RxNorm Extension', 'AMT', 'BDPM', 'AMIS', 'Multilex', 'DPD', 'LPD_Australia') and c.concept_class_id in ( 'Dose Form', 'Form', 'AU Qualifier')  and c.invalid_reason is null
) mm 
on mm.source_id = b.concept_id 
where a.domain_id ='Drug' and mm.vocabulary_id_2 in ( 'RxNorm', 'RxNorm Extension') --not clear, need to fix in the future
)
--take the longest ingredient
where rank1 = 1 
)
;
--fix inacurracies
--change from vaginal gel to Topical gel
update f_map set concept_id_2 =  19095973, CONCEPT_NAME_2 = 'Topical Gel'
where 
concept_id_2 = 
19010880
and thin_code !='98114992'
 ;
delete from f_map 
where thin_code in (
'92530998',
'98481997',
'99895992',
'97322998'

)
and concept_id_2 in (21308470, 46234469, 19082227)
;
--gel and oil have the same damn length
delete from f_map where gemscript_code in  ('61770020', '76284020') and concept_id = 21308470  
;
commit
;
 
--manual table for Dose Forms
select * from thin_need_to_map
where gemscript_code not in (select gemscript_code from f_map where gemscript_code is not null)
and domain_id ='Drug'
;

--then insert into f_map (also look for domains)

;
--make Suppliers, some clean up
UPDATE THIN_NEED_TO_MAP
   SET GEMSCRIPT_NAME =GEMSCRIPT_NAME||')' where GEMSCRIPT_NAME like '%(Neon Diagnostics'
;
drop table s_rel;
create table s_rel as
select  regexp_replace( regexp_replace (regexp_substr (GEMSCRIPT_NAME, '\([A-Z].+\)$'), '^\('), '\)$')   as Supplier, n.*
 from thin_need_to_map n where domain_id = 'Drug'
;
drop table s_map;
create table s_map as
select distinct s.gemscript_code, s.GEMSCRIPT_NAME, sss.concept_id_2,concept_name_2,vocabulary_id_2  from s_rel s
join concept c on  lower (s.Supplier) = lower (c.concept_name)
 join (
select  c.concept_id as source_id, nvl (d.concept_name, c.concept_name) as concept_name_2, nvl (d.concept_id, c.concept_id) as concept_id_2 ,nvl (d.vocabulary_id, c.vocabulary_id) as vocabulary_id_2 from concept c
left join 
(
select concept_id_1,relationship_id, concept_id_2 from concept_relationship where invalid_reason is null union select concept_id_1,relationship_id, concept_id_2 from rel_to_conc_old
) r  on c.concept_id = r.concept_id_1 and relationship_id ='Source - RxNorm eq'
left join concept d on d.concept_id = r.concept_id_2  and d.vocabulary_id like 'RxNorm%' and d.invalid_reason is null and d.concept_class_id = 'Supplier'
where c.concept_class_id in ( 'Supplier')  and c.invalid_reason is null
) sss on sss.source_id = c.concept_id AND sss.vocabulary_id_2 in ( 'RxNorm', 'RxNorm Extension') --not clear, need to fix in the future
where c.concept_class_id = 'Supplier'
;
--make Brand Names
--select * from THIN_NEED_TO_MAP where thin_name like 'Generic%'
;
 
drop table b_map_0;
create table b_map_0 AS
select  T.GEMSCRIPT_CODE, T.GEMSCRIPT_NAME, T.THIN_CODE, T.THIN_NAME , C.CONCEPT_ID, C.CONCEPT_NAME, C.vocabulary_id from THIN_NEED_TO_MAP T
join concept c on lower (GEMSCRIPT_NAME) like lower(c.concept_name)||' %' 
where c.concept_class_id = 'Brand Name' and invalid_reason is null and vocabulary_id in('RxNorm', 'RxNorm Extension')
--exclude ingredients that accindentally got into Brand Names massive
and lower(c.concept_name) not in (
select  lower (concept_name ) from concept where concept_class_id ='Ingredient' and invalid_reason is null)
and t.domain_id ='Drug'
;
delete from b_map_0 where CONCEPT_NAME in (
'Gamma',
'Mst',
'Gx',
'Simple',
'Saline',
'DF', 
'Stibium'
)
;
commit
;
drop table b_map_1;
create table b_map_1 AS
select  T.GEMSCRIPT_CODE, T.GEMSCRIPT_NAME, T.THIN_CODE, T.THIN_NAME , C.CONCEPT_ID, C.CONCEPT_NAME, C.vocabulary_id from THIN_NEED_TO_MAP T
join concept c on lower (THin_name) like lower(c.concept_name)||' %' 
where c.concept_class_id = 'Brand Name' and invalid_reason is null and vocabulary_id in('RxNorm', 'RxNorm Extension')
--exclude ingredients that accindally got into Brand Names massive
and lower(c.concept_name) not in (
select  lower (concept_name ) from concept where concept_class_id ='Ingredient' and invalid_reason is null)
and t.domain_id ='Drug'
and t.gemscript_code not in (select gemscript_code from b_map_0)
;
delete from b_map_1 where CONCEPT_NAME in ( 
'Natrum muriaticum',
'Pulsatilla nigricans',
'Multivitamin',
'Saline',
'Simple'
)
;
commit
;
drop table b_map
;
 create table b_map as
select * from (
select z.*, 
RANK() OVER (PARTITION BY gemscript_code ORDER BY
length(concept_name)  desc ) as rank1
from (
select * from b_map_0
union
select * from b_map_1
) z where z.vocabulary_id in ( 'RxNorm', 'RxNorm Extension') --not clear, need to fix in the future
) x where x.rank1 = 1
;
--making input tables
--drug_concept_stage
truncate table drug_concept_stage
;

--Drug Product
insert into drug_concept_stage 
(CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON,SOURCE_CONCEPT_CLASS_ID)
select distinct '', gemscript_name ,domain_id, 'Gemscript', 'Drug Product',  '', gemscript_code, (select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date ,-- TRUNC(SYSDATE)
to_date ('31122099', 'ddmmyyyy') as valid_end_date , '', 'Gemscript'  from thin_need_to_map where domain_id = 'Drug' 
;
--Device
insert into drug_concept_stage 
(CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON,SOURCE_CONCEPT_CLASS_ID)
select distinct '', gemscript_name,domain_id, 'Gemscript', 'Device', 'S', gemscript_code, (select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date ,-- TRUNC(SYSDATE)
to_date ('31122099', 'ddmmyyyy') as valid_end_date , '', 'Gemscript'  from thin_need_to_map where domain_id = 'Device'
;
--Ingredient
insert into drug_concept_stage 
(CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON,SOURCE_CONCEPT_CLASS_ID)
select distinct '', Ingredient_concept_code , 'Drug', 'Gemscript', 'Ingredient', '', Ingredient_concept_code, (select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date ,-- TRUNC(SYSDATE)
to_date ('31122099', 'ddmmyyyy') as valid_end_date , '', 'Gemscript'  from ds_all_tmp
--only 1041 --looks susprecious
;
--Supplier
insert into drug_concept_stage 
(CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON,SOURCE_CONCEPT_CLASS_ID)
select distinct '', CONCEPT_NAME_2, 'Drug', 'Gemscript', 'Supplier', '', CONCEPT_NAME_2, (select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date ,-- TRUNC(SYSDATE)
to_date ('31122099', 'ddmmyyyy') as valid_end_date , '', 'Gemscript'  from s_map
 ;
 --Dose Form
insert into drug_concept_stage 
(CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON,SOURCE_CONCEPT_CLASS_ID)
select distinct '', CONCEPT_NAME_2, 'Drug', 'Gemscript', 'Dose Form', '', CONCEPT_NAME_2, (select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date ,-- TRUNC(SYSDATE)
to_date ('31122099', 'ddmmyyyy') as valid_end_date , '', 'Gemscript'  from f_map
 ;
 --Brand Name
insert into drug_concept_stage 
(CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON,SOURCE_CONCEPT_CLASS_ID)
select distinct '', CONCEPT_NAME, 'Drug', 'Gemscript', 'Brand Name', '', CONCEPT_NAME, (select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date ,-- TRUNC(SYSDATE)
to_date ('31122099', 'ddmmyyyy') as valid_end_date , '', 'Gemscript'  from b_map
;
insert into drug_concept_stage 
(CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON,SOURCE_CONCEPT_CLASS_ID)
select distinct '', CONCEPT_NAME, 'Drug', 'Gemscript', 'Unit', '', CONCEPT_NAME, (select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date ,-- TRUNC(SYSDATE)
to_date ('31122099', 'ddmmyyyy') as valid_end_date , '', 'Gemscript' from dev_dmd.DRUG_CONCEPT_STAGE_042017  WHERE concept_class_id= 'Unit' and concept_code !='ml '
;
commit
;
--internal_relationship_stage
insert into internal_relationship_stage
select GEMSCRIPT_CODE,CONCEPT_NAME  from  b_map
union
select GEMSCRIPT_CODE,CONCEPT_NAME_2  from f_map
union 
select GEMSCRIPT_CODE,CONCEPT_NAME_2  from s_map
union
select distinct CONCEPT_CODE,ingredient_concept_code from ds_all_tmp
 ; 
 truncate table relationship_to_concept;
insert into relationship_to_concept  (concept_code_1, concept_id_2, precedence, conversion_factor)
--existing concepts used in mappings
--bug in RxE, so take the first_value of concept_id_2
 select distinct concept_code_1, first_value (concept_id_2) over (PARTITION BY concept_code_1,   precedence, conversion_factor order by concept_id_2) as  concept_id_2 , precedence, conversion_factor 
from (
select distinct   CONCEPT_NAME  as concept_code_1, concept_id as CONCEPT_ID_2, 1 as precedence, 1 as conversion_factor  from  b_map
union
select distinct  CONCEPT_NAME_2, concept_id_2, 1, 1 from f_map
union 
select distinct  CONCEPT_NAME_2 , concept_id_2, 1, 1   from s_map
union
select distinct  INGREDIENT_CONCEPT_CODE  , INGREDIENT_ID, 1, 1 from ds_all_tmp where INGREDIENT_ID is not null
union
--add units from dm+D
select concept_code_1, CONCEPT_ID_2, precedence, conversion_factor from dev_dmd.relationship_to_concept 
join dev_dmd.DRUG_CONCEPT_STAGE_042017 on concept_code = concept_code_1 WHERE concept_class_id= 'Unit' 
and precedence = 1
)  
--need to change the mapping from mcg to 0.001 mg
;
commit
;
UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 8576,
       CONVERSION_FACTOR = 0.001
WHERE CONCEPT_CODE_1 = 'mcg'
;
update relationship_to_concept set concept_id_2 = 19069149 where concept_id_2 = 46274409
;
--mapping to U instead of iU
update relationship_to_concept set concept_id_2 = 8510  where concept_id_2 =  8718
;
--RxE builder requires Ingredients used in relationships to be a standard
update drug_concept_stage set Standard_concept ='S' where concept_class_id = 'Ingredient'
;
commit
;
--ds_stage shouldn't have empty dosage
delete from ds_stage where drug_concept_code in (
select drug_concept_code from 
  ds_stage 
 where coalesce(amount_value, numerator_value, 0)=0 -- needs to have at least one value, zeros don't count
  or coalesce(amount_unit, numerator_unit) is null -- needs to have at least one unit
  or (amount_value is not null and amount_unit is null) -- if there is an amount record, there must be a unit
  or (nvl(numerator_value, 0)!=0 and coalesce(numerator_unit, denominator_unit) is null) -- if there is a concentration record there must be a unit in both numerator and denominator
  or amount_unit='%' -- % should be in the numerator_unit
)  
;
commit
;  
delete from internal_relationship_stage where concept_code_1 = '4915007' and concept_code_2 = 'Chewing Gum'
;
commit
;
drop sequence code_seq
;
declare
 ex number;
begin
select max(iex)+1 into ex from (  
    select cast(substr(concept_code, 5) as integer) as iex from drug_concept_stage where concept_code like 'OMOP%' and concept_code not like '% %' -- Last valid value of the OMOP123-type codes
  union
    select cast(substr(concept_code, 5) as integer) as iex from concept where concept_code like 'OMOP%' and concept_code not like '% %'
);
  begin
    execute immediate 'create sequence code_seq increment by 1 start with ' || ex || ' nocycle cache 20 noorder';
    exception
      when others then null;
  end;
end;
/

drop table  code_replace; 
 create table code_replace as 
 select 'OMOP'||code_seq.nextval as new_code, concept_code as old_code from (
select distinct  concept_code from drug_concept_stage where concept_class_id in ('Ingredient', 'Brand Name', 'Supplier', 'Dose Form') or concept_code in (select drug_concept_code from pc_stage)
)
;
update drug_concept_stage a set concept_code = (select new_code from code_replace b where a.concept_code = b.old_code) 
where a.concept_class_id in ('Ingredient', 'Brand Name', 'Supplier', 'Dose Form') or concept_code in (select drug_concept_code from pc_stage)
;--select * from code_replace where old_code ='OMOP28663';
commit
;
update relationship_to_concept a  set concept_code_1 = (select new_code from code_replace b where a.concept_code_1  =   b.old_code)
where exists (select 1 from code_replace b where a.concept_code_1 = b.old_code)
;
commit
;
update ds_stage a  set ingredient_concept_code = (select new_code from code_replace b where a.ingredient_concept_code = b.old_code)
where exists (select 1 from code_replace b where a.ingredient_concept_code = b.old_code)
;

commit
;
update ds_stage a  set drug_concept_code = (select new_code from code_replace b where a.drug_concept_code = b.old_code)
where exists (select 1 from code_replace b where a.drug_concept_code = b.old_code)
;
commit
;
 
update internal_relationship_stage a  set concept_code_1 = (select new_code from code_replace b where a.concept_code_1 = b.old_code)
where exists (select 1 from code_replace b where a.concept_code_1 = b.old_code)
;
commit
;
update internal_relationship_stage a  set concept_code_2 = (select new_code from code_replace b where a.concept_code_2 = b.old_code)
where exists (select 1 from code_replace b where a.concept_code_2 = b.old_code)
;
commit
;
update pc_stage a  set DRUG_CONCEPT_CODE = (select new_code from code_replace b where a.DRUG_CONCEPT_CODE = b.old_code)
where exists (select 1 from code_replace b where a.DRUG_CONCEPT_CODE = b.old_code)
;
commit
;
--Marketed Product must have strength and dose form otherwise Supplier needs to be removed
delete from internal_relationship_stage where   (concept_code_1,  concept_code_2) in (
SELECT irs.concept_code_1, irs.concept_code_2
FROM internal_relationship_stage irs
JOIN drug_concept_stage  ON concept_code_2 = concept_code  AND concept_class_id = 'Supplier'
left join ds_stage ds on drug_concept_code = irs.concept_code_1
left join   
(SELECT concept_code_1  FROM internal_relationship_stage
 JOIN drug_concept_stage   ON concept_code_2 = concept_code  AND concept_class_id = 'Dose Form') rf on rf.concept_code_1 = irs.concept_code_1
where ds.drug_concept_code is null or rf.concept_code_1 is null
)
;
--some ds_stage update
 update ds_stage a set  a.DENOMINATOR_unit  = 
(select distinct b.DENOMINATOR_unit  from 
 ds_stage b where a.drug_CONCEPT_CODE = b.drug_CONCEPT_CODE 
 and a.DENOMINATOR_unit is null and b.DENOMINATOR_unit is not null ) 
 where exists 
 (select 1 from 
 ds_stage b where a.drug_CONCEPT_CODE = b.drug_CONCEPT_CODE 
 and a.DENOMINATOR_unit is null and b.DENOMINATOR_unit is not null )
 ;
 update ds_stage a  set  a.numerator_value= a.amount_value,a.numerator_unit= a.amount_unit,a.amount_value = null, a.amount_unit = null
where a.denominator_unit is not null and numerator_unit is null
;
commit
;
--for further work with CNDV and then mapping creation roundabound, make copies of existing concept_stage and concept_relationship_stage
drop table basic_concept_stage;
create table basic_concept_stage as select * from concept_stage
;
drop table basic_con_rel_stage;
create table basic_con_rel_stage as select * from concept_relationship_stage
;
   UPDATE DS_STAGE
   SET DENOMINATOR_VALUE = 30
WHERE DRUG_CONCEPT_CODE = '4231007'
AND   DENOMINATOR_VALUE is null
;
select * from drug_concept_stage where concept_name in (
'Eftrenonacog alfa 250unit powder / solvent for solution for injection vials',
'Odefsey 200mg/25mg/25mg tablets (Gilead Sciences International Ltd)',
'Insuman rapid 100iu/ml Injection (Aventis Pharma)',
'Engerix b 10microgram/0.5ml Paediatric vaccination (GlaxoSmithKline UK Ltd)',
'Ethyloestranol 2mg Tablet'
)
;
--clean up
--ds_stage was parsed wrongly by some reasons
UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 10,
       NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '6912007'
AND   NUMERATOR_VALUE = 5
AND   NUMERATOR_UNIT = 'ml';
UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 20,
       NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '6916007'
AND   NUMERATOR_VALUE = 10
AND   NUMERATOR_UNIT = 'ml';
UPDATE DS_STAGE
   SET AMOUNT_VALUE = NULL,
       AMOUNT_UNIT = '',
       NUMERATOR_VALUE = 10000000,
       NUMERATOR_UNIT = 'unit',
       DENOMINATOR_VALUE = 1,
       DENOMINATOR_UNIT = 'ml'
WHERE DRUG_CONCEPT_CODE = '94291020'
AND   NUMERATOR_VALUE IS NULL
AND   NUMERATOR_UNIT IS NULL;
UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 4,
       NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '49537020'
AND   NUMERATOR_VALUE = 8
AND   NUMERATOR_UNIT = 'ml';
UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 20,
       NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '3252007'
AND   NUMERATOR_VALUE = 10
AND   NUMERATOR_UNIT = 'ml';
UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 30,
       NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '81443020'
AND   NUMERATOR_VALUE = 10
AND   NUMERATOR_UNIT = 'ml';
UPDATE DS_STAGE
   SET AMOUNT_VALUE = NULL,
       AMOUNT_UNIT = '',
       NUMERATOR_VALUE = 6000000,
       NUMERATOR_UNIT = 'unit',
       DENOMINATOR_VALUE = 1,
       DENOMINATOR_UNIT = 'ml'
WHERE DRUG_CONCEPT_CODE = '80015020'
AND   NUMERATOR_VALUE IS NULL
AND   NUMERATOR_UNIT IS NULL;
UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 40,
       NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '58170020'
AND   NUMERATOR_VALUE = 20
AND   NUMERATOR_UNIT = 'ml';
UPDATE DS_STAGE
   SET NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '58166020'
AND   NUMERATOR_VALUE = 50
AND   NUMERATOR_UNIT = 'ml';
UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 60,
       NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '2113007'
AND   NUMERATOR_VALUE = 10
AND   NUMERATOR_UNIT = 'ml';
UPDATE DS_STAGE
   SET AMOUNT_VALUE = NULL,
       AMOUNT_UNIT = '',
       NUMERATOR_VALUE = 50,
       NUMERATOR_UNIT = 'mcg',
       DENOMINATOR_VALUE = 5,
       DENOMINATOR_UNIT = 'ml'
WHERE DRUG_CONCEPT_CODE = '67456020'
AND   NUMERATOR_VALUE IS NULL
AND   NUMERATOR_UNIT IS NULL;
UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 10,
       NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '58165020'
AND   NUMERATOR_VALUE = 20
AND   NUMERATOR_UNIT = 'ml';

commit
;
delete from ds_stage where drug_concept_Code in (
SELECT drug_concept_Code 
      FROM ds_stage
      join thin_need_to_map on gemscript_code = DRUG_CONCEPT_CODE
      WHERE lower(numerator_unit) IN ('ml')
      OR    lower(amount_unit) IN ('ml')
      )
;      
commit
;
      delete from ds_stage where DRUG_CONCEPT_CODE in (
      SELECT DRUG_CONCEPT_CODE 
      FROM ds_stage s
          JOIN drug_concept_stage a ON a.concept_code = s.drug_concept_code  AND a.concept_class_id = 'Device'
)
;
commit
;   
delete 
      FROM drug_concept_stage
      WHERE concept_name = 'Syrup' and concept_class_id = 'Ingredient'
                             ;
                             delete 
      FROM drug_concept_stage
      WHERE concept_name = 'Stibium' and concept_class_id = 'Brand Name'
                             ;
                             commit
                             ;

--Marketed Drugs without the dosage or Drug Form are not allowed
delete from internal_relationship_stage where (concept_code_1, concept_code_2) in 
(
select concept_code_1,concept_code_2   from drug_concept_stage  dcs
join (
SELECT concept_code_1, concept_code_2
FROM internal_relationship_stage
JOIN drug_concept_stage  ON concept_code_2 = concept_code  AND concept_class_id = 'Supplier'
left join ds_stage on drug_concept_code = concept_code_1 
where drug_concept_code is null
union 
SELECT concept_code_1, concept_code_2
FROM internal_relationship_stage
JOIN drug_concept_stage  ON concept_code_2 = concept_code  AND concept_class_id = 'Supplier'
where concept_code_1 not in (SELECT concept_code_1
                                  FROM internal_relationship_stage
                                    JOIN drug_concept_stage   ON concept_code_2 = concept_code  AND concept_class_id = 'Dose Form')
) s on s.concept_code_1 = dcs.concept_code
where dcs.concept_class_id = 'Drug Product' and invalid_reason is null 
)
;
commit
;
--not smart clean up
UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 44012620
AND   CONCEPT_ID_2 = 43125877;

UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 1505346
AND   CONCEPT_ID_2 = 36878682;

UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 36879003
AND   CONCEPT_ID_2 = 21014145;

UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 44784806
AND   CONCEPT_ID_2 = 36878894
;
  delete from ds_Stage where drug_concept_code ='63620020'
  ;
  commit
  ;
  UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 21020188
WHERE CONCEPT_ID_2 = 19131170
;