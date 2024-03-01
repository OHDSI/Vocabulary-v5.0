--compare 2 vocabulary versions if mapping changed on the ingredient level for the NDCs

with new_map as (
select a.concept_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as relationship_agg,
       string_agg (case when a.concept_id = b.concept_id then '<Mapped to itself>' else b.concept_code end, '-/-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as code_agg,
       string_agg (case when a.concept_id = b.concept_id then '<Mapped to itself>' else b.concept_name end, '-/-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as name_agg
from new_voc_schema.concept a
 join new_voc_schema.concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Maps to', 'Maps to value') and r.invalid_reason is null
 join new_voc_schema.concept_ancestor ca on ca.descendant_concept_id  = r.concept_id_2 
 join new_voc_schema.concept b on b.concept_id = ca.ancestor_concept_id and b.concept_class_id ='Ingredient' and b.vocabulary_id ='RxNorm' and b.standard_concept ='S'
where a.vocabulary_id IN ('NDC')
group by a.concept_id, a.vocabulary_id, a.concept_class_id, a.standard_concept, a.concept_code, a.concept_name
)
,
old_map as (
select concept_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       concept_name,
     string_agg (c_concept_code , '-/-' order by  c_concept_code) as code_agg,
       string_agg ( c_concept_name , '-/-' order by  c_concept_code) as name_agg
       from 
(
select distinct a.concept_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.concept_name,
       c.concept_code as c_concept_code, 
       c.concept_name as c_concept_name
from old_voc_schema.concept a
 join old_voc_schema.concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Maps to', 'Maps to value') and r.invalid_reason is null
 join old_voc_schema.concept_ancestor ca on ca.descendant_concept_id  = r.concept_id_2 
 join old_voc_schema.concept b on b.concept_id = ca.ancestor_concept_id and b.concept_class_id ='Ingredient' and b.vocabulary_id ='RxNorm' and b.standard_concept ='S'
 --join with new CR to replace old concepts if replacement exists
 join  new_voc_schema.concept_relationship r2 on r2.concept_id_1 = b.concept_id and r2.relationship_id ='Maps to'
 join new_voc_schema.concept c on c.concept_id = r2.concept_id_2 
where a.vocabulary_id IN ('NDC')
) a
group by concept_id, vocabulary_id, concept_class_id, standard_concept, concept_code, concept_name
)
select b.vocabulary_id as vocabulary_id,
       b.concept_class_id,
       b.standard_concept,
       b.concept_code as source_code,
       b.concept_name as source_name,
       a.code_agg as old_code_agg,
       a.name_agg as old_name_agg,
       b.code_agg as new_code_agg,
       b.name_agg as new_name_agg
from old_map a
join new_map b
on a.concept_id = b.concept_id and coalesce (a.code_agg, '') != coalesce (b.code_agg, '')
order by a.concept_code
;
