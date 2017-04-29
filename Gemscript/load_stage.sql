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
--delete mappings to non-existing dm+ds
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

--define drug domain (Drug set by default)
--ORA-01427: single-row subquery returns more than one row 
--need to check, if don't match it puts null?
update concept_stage cs ; 
set domain_id = (select domain_id from (
select distinct --beware of multiple mappings
 r.concept_code_1,r.vocabulary_id_1, c.domain_id
 from
concept_relationship_stage r -- concept_code_1 = s1.concept_code and vocabulary_id_1 = vocabulary_id
join concept c on c.concept_code = r.concept_code_2 and r.vocabulary_id_2 = c.vocabulary_id and r.invalid_reason is null  and r.vocabulary_id_2 in ('dm+d', 'RxNorm', 'RxNorm Extension')
join 
(select concept_code_1 from (
select distinct --beware of multiple mappings
 r.concept_code_1,r.vocabulary_id_1, c.domain_id
 from
concept_relationship_stage r -- concept_code_1 = s1.concept_code and vocabulary_id_1 = vocabulary_id
 join concept c on c.concept_code = r.concept_code_2 and r.vocabulary_id_2 = c.vocabulary_id and r.invalid_reason is null  and r.vocabulary_id_2 in ('dm+d', 'RxNorm', 'RxNorm Extension')
) group by concept_code_1 having count(1) =1) zz 
on zz.concept_code_1 = r.concept_code_1
) rr
where rr.concept_code_1 = cs.concept_code and rr.vocabulary_id_1 = cs.vocabulary_id)
;
--for development purpose use temporary THIN_need_to_map table:  
drop table THIN_need_to_map;  --18457 the old version, 13965 --new version (join concept), well, really a big difference. not sure if those existing mappings are correct, 13877 - concept_relationship_stage version, why?
create table THIN_need_to_map as 
select --c.*
 c.concept_code as THIN_code, c.concept_name as THIN_name, t.GEMSCRIPT_DRUGCODE as GEMSCRIPT_code, t.BRAND as GEMSCRIPT_name, c.domain_id--why it's not drug by defaild
 from  concept_stage c
  join THIN_GEMSC_DMD_0417 t on t.ENCRYPTED_DRUGCODE = c.concept_code
left join  concept_relationship_stage r on c.concept_code = r.concept_code_1 and r.invalid_reason is null and r.vocabulary_id_2 in ('dm+d', 'RxNorm', 'RxNorm Extension') and relationship_id = 'Maps to' 
where    c.concept_class_id =  'Gemscript THIN' --for a current THIN task
and r.concept_code_2 is null
;
select count (1) from THIN_need_to_map-- well 13877, but if use generic and so on we get more concepts , OK, keep in mind, we have for about 100 difference
; 
--define domain_id
update THIN_need_to_map n set domain_id = 'Device'
where exists (select 1 from gemscript_reference g 
where regexp_like (PRODUCTNAME, '[a-z]')  --at least 1 [a-z] charachter
and regexp_count(PRODUCTNAME, '[a-z]')>5 -- sometime we have these non HCl, mg as a part of UPPER case concept_name
and DRUGSUBSTANCE is null and  g.GEMSCRIPTCODE = n.GEMSCRIPT_CODE )
--4758
;
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
--update thin_need_to_map
--set domain_id = 'Device'
--put these into concept above
select * from  thin_need_to_map
 where GEMSCRIPT_CODE in (
select GEMSCRIPT_CODE from thin_need_to_map where
regexp_like (lower(THIN_name),'bag|gluten|plast|wax|catheter|device|needle|needle|emollient|feeding|colostomy| toe |rubber|flange|cotton|stockinette|urostomy|tube |ostomy|cracker|shield|larve|belt|pasta|garments|bread')
or 
regexp_like (lower(gemscript_name),'bag|gluten|plast|wax|catheter|device|needle|needle|emollient|feeding|colostomy| toe |rubber|flange|cotton|stockinette|urostomy|tube |ostomy|cracker|shield|larve|belt|pasta|garments|bread')
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
'cream'
)
)
;
commit
;
