
--define all the concepts having modifiers, use filter a.RUBRIC_KIND ='modifierlink'
create table codes_need_modified as
select distinct a.CLASS_CODE, a.label,a.SUPERCLASS_CODE, b.CLASS_CODE as concept_code, b.label as concept_name, b.SUPERCLASS_CODE as super_concept_code 
 from classes a 
join classes b on b.class_code like a.class_code|| '%' 
  where a.RUBRIC_KIND =  'modifierlink' and b.RUBRIC_KIND = 'preferred' and b.class_code not like '%-%'
;
--add all the modifiers using patterns described in a table
--'I70M10_4' with or without gangrene related to gout, seems to be a bug, modifier says [See site code at the beginning of this chapter]
create table concepts_modifiers as
       with codes as (
        select a.*, b.MODIFIERCLASS_CODE, b.label as modifer_name from codes_need_modified a left join modifier_classes b on class_code = regexp_replace (regexp_replace (MODIFIERCLASS_MODIFIER, '^(I\d\d)|(S\d\d)'), '_\d') and b.RUBRIC_KIND ='preferred' 
        and MODIFIERCLASS_MODIFIER !='I70M10_4' --looks like a bug
        )
select distinct a.concept_code||b.MODIFIERCLASS_CODE as concept_code, a.concept_name||','|| b.MODIFER_NAME as concept_name from codes a 
join codes b on (regexp_substr (a.label, '\D\d\d') = b.concept_code  and a.label =b.label and a.class_code != b.class_code
or a.label = '[See at the beginning of this block for subdivisions]' and a.label =b.label and a.class_code != b.class_code and b.concept_code ='K25'
or a.label= '[See site code at the beginning of this chapter]' and a.label =b.label and a.class_code != b.class_code and b.concept_code like '_00' and regexp_substr (b.concept_code, '^\D') = regexp_substr (a.concept_code, '^\D')
) and (a.concept_code not like '%.%' and b.MODIFIERCLASS_CODE like '%.%' or a.concept_code  like '%.%' and b.MODIFIERCLASS_CODE not like '%.%')
union 
--basic modifiers having relationship modifier - concept
select distinct a.concept_code||a.MODIFIERCLASS_CODE as concept_code, a.concept_name||','|| a.MODIFER_NAME from codes a
where (a.concept_code not like '%.%' and a.MODIFIERCLASS_CODE like '%.%' or a.concept_code  like '%.%' and a.MODIFIERCLASS_CODE not like '%.%') and a.MODIFIERCLASS_CODE is not null
;
--full list of concepts 
create table concept_list as
select * from concepts_modifiers
union
select CLASS_CODE,label  from classes where RUBRIC_KIND ='preferred' and class_code not like '%-%'
;