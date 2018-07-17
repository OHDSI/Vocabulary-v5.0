truncate table relationship_to_concept;
--insert into relationship_to_concept mappings from previos run
--update existing relationship to concept (Timur)

--delete deprecated concepts (mainly wrong BN)
delete from drug_concept_stage where concept_code in
 (select concept_code_1 from relationship_to_concept 
join concept c on concept_id_2=c.concept_id 
and c.invalid_reason='D' and concept_class_id!='Ingredient'
and concept_id_2 not in (43252204,43252218));

delete from internal_relationship_stage where concept_code_2 in
 (select concept_code_1 from relationship_to_concept 
join concept c on concept_id_2=c.concept_id 
and c.invalid_reason='D' and concept_class_id!='Ingredient'
and concept_id_2 not in (43252204,43252218));

delete from relationship_to_concept 
where concept_code_1 in (select concept_code_1 from
relationship_to_concept
join concept c on concept_id_2=c.concept_id 
and c.invalid_reason='D' and concept_class_id!='Ingredient'
and concept_id_2 not in (43252204,43252218));

--give Medical Coders list of unmapped concepts