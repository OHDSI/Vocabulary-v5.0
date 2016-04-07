--use this script to prepare table for manual review highlightening incorrect mappings or probably incorrect (classes are not a clinical finding need more attention  

drop table icd9_mapping;
create table icd9_mapping as (
select 
a.concept_code as concept_code_1, a.concept_name as concept_name_1, b.relationship_id, b.concept_code as concept_code_2, b.concept_name as concept_name_2,b.concept_class_id, b.invalid_reason as invalid_reason_2
from devv5.concept a 
left join (select concept_id_1,relationship_id, concept_id_2, c.concept_code, c.concept_name,c.concept_class_id,  c.invalid_reason from devv5.concept_relationship b 
join devv5.concept c on c.concept_id = b.concept_id_2 and c.vocabulary_id = 'SNOMED' and b.invalid_reason is null) b on a.concept_id = b.concept_id_1 
where a.vocabulary_id ='ICD9CM' and a.invalid_reason is null
)
;
alter table icd9_mapping add mistake_type varchar (200)
;
-- no map
update icd9_mapping
set mistake_type = 'no map'
 where concept_code_2 is null
;
-- maps to finding with explicit context, i.e. 444166003 unilateral clinical finding 
--(not a 417662000 history of clinical finding in subject, 416471007 family history of clinical finding allowed by rules )
update icd9_mapping 
set mistake_type ='maps to finding with explicit context'
where concept_code_2  in (select c.concept_code from devv5.concept c 
join devv5.concept_ancestor a on c.concept_id = a.DESCENDANT_CONCEPT_ID and ANCESTOR_CONCEPT_ID =4187630 )
and concept_code_2 not in('416471007', '417662000')
;
update icd9_mapping
set mistake_type = 'Morphological abnormality'
where concept_CLASS_ID = 'Morphological abnormality'
;
update icd9_mapping 
set mistake_type ='one of target codes has class other then Clinical Finding' where concept_code_1  in (
select concept_code_1 from icd9_mapping where concept_CLASS_ID != 'Clinical Finding') and mistake_type is null
;
