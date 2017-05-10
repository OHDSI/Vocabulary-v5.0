--1 Update latest_update field to new date 
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'Gemscript',
                                          pVocabularyDate        => TRUNC(SYSDATE),
                                          pVocabularyVersion     => 'Gemscript '||SYSDATE,
                                          pVocabularyDevSchema   => 'DEV_gemscript');									  
END;
/
COMMIT;
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
from gemscript_dmd_map
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
from THIN_GEMSC_DMD_0417 where GEMSCRIPT_DRUGCODE not in (select concept_code from concept_stage)
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
from THIN_GEMSC_DMD_0417 
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
from THIN_GEMSC_DMD_0417
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
from THIN_GEMSC_DMD_0417  
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
update concept_relationship_stage set invalid_reason ='D'
;
update concept_relationship_stage set invalid_reason = null where (concept_code_1, concept_Code_2, vocabulary_id_2)  in (
select concept_code_1, concept_Code_2, vocabulary_id_2 from concept_relationship_stage join concept on concept_code = concept_code_2 and vocabulary_id = vocabulary_id_2 and standard_concept ='S' 
)
;
commit
;

--define drug domain (Drug set by default)
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
commit
;
--for development purpose use temporary THIN_need_to_map table:  
drop table THIN_need_to_map;  --18457 the old version, 13965 --new version (join concept), well, really a big difference. not sure if those existing mappings are correct, 13877 - concept_relationship_stage version, why?
create table THIN_need_to_map as 
select --c.*
 c.concept_code as THIN_code, c.concept_name as THIN_name, t.GEMSCRIPT_DRUGCODE as GEMSCRIPT_code, t.BRAND as GEMSCRIPT_name, c.domain_id--why it's not drug by defaild
 from  concept_stage c
  join THIN_GEMSC_DMD_0417 t on t.ENCRYPTED_DRUGCODE = c.concept_code
left join  concept_relationship_stage r on c.concept_code = r.concept_code_1 and r.invalid_reason is null --and r.vocabulary_id_2 in ('dm+d', 'RxNorm', 'RxNorm Extension') and relationship_id = 'Maps to' 
where    c.concept_class_id =  'Gemscript THIN' --for a current THIN task
and r.concept_code_2 is null
;
/*
--doesn't work, just 107, so forget at least about this
--name thing, few concepts make a lot of troubles with duplicates, just skip them
select * from (
 select r.*, count ( concept_code_2) over (partition by thin_code) as cnt from (
select distinct m.*, crs.concept_code_2, vocabulary_id_2 , cc.concept_name
 from  THIN_need_to_map m
 join concept_stage  c on  lower(GEMSCRIPT_name) = lower (concept_Name)
 join concept_relationship_stage crs on crs.concept_code_1 = c.concept_Code 
 join concept cc on cc.concept_code = crs.concept_code_2 and cc.vocabulary_id = crs.vocabulary_id_2 and crs.invalid_reason is null
and c.concept_code not in (select thin_code from THIN_need_to_map) and c.concept_code not in (select GEMSCRIPT_code from THIN_need_to_map)
) r) x where x.cnt =1
--3549 due to the duplicates ,but really just 107
*/
  --   count(c1.concept_id) over (partition by c2.concept_id) as cnt 

-- well 13877, but if use generic and so on we get more concepts , OK, keep in mind, we have for about 100 difference
; 
--define domain_id
--DRUGSUBSTANCE is null and lower
update THIN_need_to_map n set domain_id = 'Device'
where exists (select 1 from gemscript_reference g 
where regexp_like (PRODUCTNAME, '[a-z]')  --at least 1 [a-z] charachter
and regexp_count(PRODUCTNAME, '[a-z]')>5 -- sometime we have these non HCl, mg as a part of UPPER case concept_name
and DRUGSUBSTANCE is null and  g.GEMSCRIPTCODE = n.GEMSCRIPT_CODE )
--4758
;
commit
;
--device by the name (taken from dmd?) part 1
update thin_need_to_map
set domain_id = 'Device' 
where GEMSCRIPT_CODE in (
select GEMSCRIPT_CODE from thin_need_to_map where
regexp_like (lower(THIN_name), 'dialysis|smoflipid|camino|maxamum|sno-pro|lubri|peptamen|pepti-junior|dressing|diagnostic|glove|supplement| rope|weight|resource|accu-chek|accutrend|procal|glytactin|gauze|keyomega|cystine|docomega|anamixcranberry|pedialyte|hydralyte|hcu cooler|pouch')
union 
select GEMSCRIPT_CODE from thin_need_to_map where
regexp_like (lower(THIN_name),'burger|biscuits|stocking|strip|remover|chamber|gauze|supply|beverage|cleanser|soup|protector|nutrision|repellent|wipes|kilocalories|cake|roll|adhesive|milk|dessert|medium chain|prozero|amino acid supplement|long chain|low protein|pouches|ribbon|cannula|swabs|bandage|cylinder')
union
select GEMSCRIPT_CODE from  thin_need_to_map where
regexp_like (lower(gemscript_name),'burger|biscuits|stocking|strip|remover|chamber|gauze|supply|beverage|cleanser|soup|protector|nutrision|repellent|wipes|kilocalories|cake|roll|adhesive|milk|dessert|medium chain|prozero|amino acid supplement|long chain|low protein|pouches|ribbon|cannula|swabs|bandage|cylinder')
union
select GEMSCRIPT_CODE from  thin_need_to_map where
regexp_like (lower(gemscript_name), 'dialysis|smoflipid|camino|maxamum|sno-pro|lubri|peptamen|pepti-junior|dressing|diagnostic|glove|supplement| rope|weight|resource|accu-chek|accutrend|procal|glytactin|gauze|keyomega|cystine|docomega|anamixcranberry|pedialyte|hydralyte|hcu cooler|pouch')
)
and domain_id ='Drug'
;
commit
;
--device by the name (taken from dmd?) part 2
update thin_need_to_map
set domain_id = 'Device'
--put these into script above
 where GEMSCRIPT_CODE in (
select GEMSCRIPT_CODE from thin_need_to_map where
regexp_like (lower(THIN_name),'physical|diet food|sunscreen|tubing|nutrison|elasticated vest|oxygen|spaghetti|irrigation |sunscreen cream|sheaths|lancet| wash|contact lens|bag|gluten|plast|wax|catheter|device|needle|needle|emollient|feeding|colostomy| toe |rubber|flange|cotton|stockinette|urostomy|tube |ostomy|cracker|shield|larve|belt|pasta|garments|bread')
or 
regexp_like (lower(gemscript_name),'physical|diet food|sunscreen|tubing|nutrison|elasticated vest|oxygen|spaghetti|irrigation |sunscreen cream|sheaths|lancet| wash|contact lens|bag|gluten|plast|wax|catheter|device|needle|needle|emollient|feeding|colostomy| toe |rubber|flange|cotton|stockinette|urostomy|tube |ostomy|cracker|shield|larve|belt|pasta|garments|bread')
)
and domain_id ='Drug'
;
commit
;
--these concepts are drugs anyway
--put this condition into concept above!!! 
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
set THIN_NAME = regexp_replace (THIN_NAME, ' with ',' / ') 
where regexp_like (thin_name, ' with ') and not regexp_like (thin_name, ' with \d')  and domain_id= 'Drug'
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
select * from thin_need_to_map where THIN_NAME like '% / %'
;

drop table thin_comp;
create table thin_comp as 
select regexp_substr 
(a.thin_name, 
'[[:digit:]\,\.]+(\s)*(mg|%|ml|mcg|hr|hours|unit(s?)|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit(s?)|nanogram(s)*|x|ppm|million units| Kallikrein inactivator units|kBq|microlitres|MBq|molar|micromol)/*[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop)*') as dosage
, A.* from (
select distinct
trim(regexp_substr(  (regexp_replace (t.thin_name, ' / ', '!')), '[^!]+', 1, levels.column_value))  as drug_comp , t.* 
from thin_need_to_map t,
table(cast(multiset(select level from dual connect by  level <= length (regexp_replace(regexp_replace (t.thin_name, ' / ', '!'), '[^!]+'))  + 1) as sys.OdciNumberList)) levels) a
where a.domain_id ='Drug'
;
--select * from thin_comp where lower( thin_name) LIKE '%hypromellose%'
;
--select * from thin_need_to_map where regexp_like (thin_name, '%/')
;

--volume
--correct way of the volume definition
--what happens with these: "Diazepam 2mg/5ml oral suspension" or these "Adalimumab 40mg/0.4ml solution for injection pre-filled syringes"
ALTER TABLE thin_comp
ADD volume varchar (20)
;
 update thin_comp set volume = regexp_substr (regexp_substr (thin_name, '[[:digit:]\.]+\s*(ml|g|litre|mg) (pre-filled syringes|bags|bottles|vials|applicators|sachets|ampoules)'), '[[:digit:]\.]+\s*(ml|g|litre|mg)')
where regexp_substr (regexp_substr (thin_name, '[[:digit:]\.]+\s*(ml|g|litre|mg) (pre-filled syringes|bags|bottles|vials|applicators|sachets|ampoules)'), '[[:digit:]\.]+\s*(ml|g|litre|mg)') is not null
 and (  regexp_substr (regexp_substr (thin_name, '[[:digit:]\.]+\s*(ml|g|litre|mg) (pre-filled syringes|bags|bottles|vials|applicators|sachets|ampoules)'), '[[:digit:]\.]+\s*(ml|g|litre|mg)') != dosage or dosage is null)
--it gives only 57 rows, needs further checks 
;
--dosage distribution along the ds_Stage
drop table ds_all;
create table ds_all as 
select 
case when regexp_substr (dosage, '[[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units|unit dose|drop)') = dosage 
and not regexp_like (dosage, '%') 
then regexp_replace (regexp_substr (dosage, '[[:digit:]\,\.]+'), ',')
else  null end 
as amount_value,

case when regexp_substr (dosage, '[[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units|unit dose|drop)') = dosage 
and not regexp_like (dosage, '%') 
then  regexp_replace  (dosage, '[[:digit:]\,\.]+') 
else  null end
as amount_unit,

case when 
regexp_substr (dosage,
 '[[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop)') = dosage
or regexp_like (dosage, '%') 
then regexp_replace (regexp_substr (dosage, '^[[:digit:]\,\.]+') , ',')
else  null end
as numerator_value,

case when regexp_substr (dosage, 
'[[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop)') = dosage
or regexp_like (dosage, '%') 
then regexp_substr (dosage, 'mg|%|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|microlitres', 1,1) 
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

CREATE INDEX need_to_map_ln ON thin_need_to_map (lower (thin_name))  
;
--how to define Ingredient, change scripts to COMPONENTS and use only (  lower (a.thin_name) like lower (b.concept_name)||' %' tomorrow!!!
--take the longest ingredient, if this works, rough dm+d is better, becuase it has Sodium bla-bla-nate and RxNorm has just bla-bla-nate 
drop table i_map_2;
create table i_map_2 as ( -- enhanced algorithm added  lower (a.thin_name) like lower '% '||(b.concept_name)||' %'
select * from 
(
select distinct a.*, b.concept_id, b.concept_name,  b.vocabulary_id, r.DRUGSUBSTANCE, RANK() OVER (PARTITION BY a.thin_code ORDER BY b.vocabulary_id desc, length(b.concept_name)  desc) as rank1
--look what happened to previous 4 
from  thin_need_to_map a 
 join  devv5.concept b
on (  lower (a.thin_name) like lower (b.concept_name)||' %'
 or lower (a.thin_name) like  '% '||lower(b.concept_name)||' %')
--usually the name starts from the Ingredient 
--or  lower (concept_name) LIKE lower (b.concept_name) 
and vocabulary_id in( 'RxNorm', 'dm+d') and b.concept_class_id in ( 'Ingredient', 'VTM')  and b.invalid_reason is null
left join gemscript_reference  r on a.gemscript_code = r.gemscriptcode and r.DRUGSUBSTANCE is null
where a.domain_id ='Drug')
where rank1 = 1 
)
;
create table i_map_subst -- DRUGSUBSTANCE is not null
 as ( -- enhanced algorithm added  lower (a.thin_name) like lower '% '||(b.concept_name)||' %'
select * from 
(
select distinct a.*, b.concept_id, b.concept_name,  b.vocabulary_id, r.DRUGSUBSTANCE, RANK() OVER (PARTITION BY a.thin_code ORDER BY b.vocabulary_id desc, length(b.concept_name)  desc) as rank1
--look what happened to previous 4 
from  thin_need_to_map a 
 join  devv5.concept b
on (  lower (a.thin_name) like lower (b.concept_name)||' %'
 or lower (a.thin_name) like  '% '||lower(b.concept_name)||' %')
--usually the name starts from the Ingredient 
--or  lower (concept_name) LIKE lower (b.concept_name) 
and vocabulary_id in( 'RxNorm', 'dm+d') and b.concept_class_id in ( 'Ingredient', 'VTM')  and b.invalid_reason is null
left join gemscript_reference  r on a.gemscript_code = r.gemscriptcode and r.DRUGSUBSTANCE is not null
where a.domain_id ='Drug')
where rank1 = 1 
)
;
select * from i_map_subst
;
--21179046 Co-codamol??

;
select distinct concept_class_id from concept where vocabulary_id = 'dm+d'
;
select distinct SOURCE_CONCEPT_CLASS_ID from dev_dmd.drug_concept_stage where concept_class_id = 'Ingredient'
;
select count(1) from concept where vocabulary_id in( 'RxNorm', 'dm+d') and concept_class_id in ( 'VTM')
;
--ok. define ingredients
select * from concept where concept_name = 'Menotrophin'
;
--i_map generated ingredient is better when it's mono-component drug
--somehow it should be reviewed manualy
drop table rel_to_ing_1 ;
create table rel_to_ing_1 as
select distinct   THIN_CODE,THIN_NAME,GEMSCRIPT_CODE,GEMSCRIPT_NAME,DOMAIN_ID, TARGET_ID,TARGET_NAME,TARGET_VOCAB, TARGET_CLASS from (
select i.*, b.concept_id as target_id, b.concept_name as target_name, b.vocabulary_id as target_vocab, b.concept_class_id as target_class from 
(select * from i_map_2 
union 
select * from i_map_subst where DRUGSUBSTANCE not like '%/%') i
 join concept_relationship r on i.concept_id = r.concept_id_1 and relationship_id ='Maps to' and r.invalid_reason is null
  join concept b on b.concept_id = r.concept_id_2  and b.vocabulary_id like 'RxNorm%'
  )
;
select * from rel_to_ing_1 where thin_code = '31085978'
;
select * from thin_need_to_map where thin_code not in (
select thin_code from rel_to_ing_1
)
and domain_id = 'Drug'
;
Diazepam 5mg/5ml oral suspension?
Adrenaline (base) 1mg/1ml (1 in 1,000) solution for injection ampoules?
Colecalciferol 1,000unit capsules
;
select * from concept where concept_name ='Diazepam'
;
select * from concept i 
 join concept_relationship r on i.concept_id = r.concept_id_1 and relationship_id ='Maps to' and r.invalid_reason is null
  join concept b on b.concept_id = r.concept_id_2  and b.vocabulary_id like 'RxNorm%' and i.vocabulary_id = 'RxNorm' and i.concept_class_id= 'Ingredient'
  ;
  --what happens to 31085978 Diazepam 5mg/5ml oral suspension?
select * from thin_need_to_map where thin_code = '31085978'
;

select * from i_map_subst where thin_code =  '31085978'
;
--looks nice, then add mapping to RxNorm and we'are good here with ingredients
--next steps:
--check the ingredient info given by the default
--check the dosage definition algorithm
--most of drugs that not covered by name equal algorithm are bullshit
--but some are good anyway, put to a manual part
94489992	Lederdopa 125 mg tablet	5510007	LEDERDOPA 125 MG TAB	Drug
94279992	Phenobarbitone 22.5 mg tablet	5720007	PHENOBARBITONE 22.5 MG TAB	Drug
96472992	Sulphamethizole 100 mg syringe	3527007	SULPHAMETHIZOLE 100 MG SYR	Drug
94399992	Albamycin t 250 mg capsule	5600007	ALBAMYCIN T 250 MG CAP	Drug
97646992	Ledercillin 250 mg tablet	2353007	LEDERCILLIN 250 MG TAB	Drug
94993992	Ethinyloestradiol 50mcg/norgestrel500mcg mcg tablet	5006007	ETHINYLOESTRADIOL 50MCG/NORGESTREL500MCG MCG TAB	Drug
97255992	Dexamphetamine sulphate 10 mg capsule	2744007	DEXAMPHETAMINE SULPHATE 10 MG CAP	Drug
94087992	Buscopan 20 mg tablet	5912007	BUSCOPAN 20 MG TAB	Drug
96671992	Gentamycin 40 mg injection	3328007	GENTAMYCIN 40 MG INJ	Drug
96198992	Dienoestrol 10 mg tablet	3801007	DIENOESTROL 10 MG TAB	Drug
94910992	Dexedrine 2.5 mg tablet	5089007	DEXEDRINE 2.5 MG TAB	Drug
96227992	Erythropoetin 5000 i/u injection	3772007	ERYTHROPOETIN 5000 I/U INJ	Drug
95044992	Sulfafurazole 500mg/5ml syrup	4955007	GANTRISIN .5 GM SYR	Drug
97635992	Keflex 500 mg injection	2364007	KEFLEX 500 MG INJ	Drug --  (cephalexin) so it's a real drug
97372992	Ergot prep 60 mg tablet	2627007	ERGOT PREP 60 MG TAB	Drug -- Ergotamine 
93679992	Acepifylline 500 mg suppositories	6320007	ACEPIFYLLINE 500 MG SUP	Drug
96599992	Calciferol 75 mcg injection	3400007	CALCIFEROL 75 MCG INJ	Drug
95714992	Uniprofen 400 mg tablet	4285007	UNIPROFEN 400 MG TAB	Drug  
99515998	Sulfametopyrazine 2g tablets	50012020	Kelfizine w 2g Tablet (Pharmacia Ltd)	Drug
93405992	Pipril 2 mg injection	6594007	PIPRIL 2 MG INJ	Drug
93323998	Generic Solpadeine Plus capsules	73512020	Paracetamol 500mg with codeine phosphate 8mg & caffeine 30mg capsule	Drug
97303992	Dienoestrol .3 mg tablet	2696007	DIENOESTROL .3 MG TAB	Drug
97023992	Calciferol 100,000 iu/ml injection	2976007	CALCIFEROL 100,000 IU/ML INJ	Drug
96284992	Insulin humulin m4 100 i/u injection	3715007	INSULIN HUMULIN M4 100 I/U INJ	Drug
;
select * from rel_to_ing_1 where THIN_NAME like '% / %'
;
