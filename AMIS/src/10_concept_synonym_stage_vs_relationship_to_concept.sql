truncate table Concept_synonym_stage;

Insert into Concept_synonym_stage 
(SYNONYM_CONCEPT_ID,SYNONYM_NAME,SYNONYM_CONCEPT_CODE,SYNONYM_VOCABULARY_ID,LANGUAGE_CONCEPT_ID)
Select '', INGREDIENT,INGREDIENT_CODE, 'AMIS',  '4182504'from ingredient_translation_all
Union 
Select '',Form,  concept_code, 'AMIS',  '4182504' from form_translation_all a
join dcs_form c on a.form = c.concept_name 
;

truncate table RELATIONSHIP_TO_CONCEPT;

insert into  RELATIONSHIP_TO_CONCEPT ( concept_code_1,  vocabulary_id_1	, concept_id_2	, precedence) 
select concept_code,'AMIS',CONCEPT_id_2,precedence from aut_ingr_all_mapped 
;
insert into  RELATIONSHIP_TO_CONCEPT ( concept_code_1,  vocabulary_id_1	, concept_id_2	, precedence) 
select concept_code,'AMIS',CONCEPT_id_2,precedence from AUT_FORM_ALL_MAPPED 
join drug_concept_stage on concept_name_1=concept_name and concept_class_id='Dose Form'
;
insert into relationship_to_concept (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select CONCEPT_CODE,'AMIS',CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR from aut_unit_all_mapped;

insert into  RELATIONSHIP_TO_CONCEPT ( concept_code_1,  vocabulary_id_1	, concept_id_2, precedence) 
select concept_code,'AMIS',CONCEPT_id_2, precedence from aut_brand_all_mapped 
join dcs_bn on concept_name=concept_name_1
;


