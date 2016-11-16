delete drug_concept_stage where concept_Code in (
select distinct a.concept_code from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
where a.concept_class_id= 'Brand Name' and b.concept_code_1 is null
union
select distinct a.concept_code from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
where a.concept_class_id= 'Dose Form' and b.concept_code_1 is null
);