--fill RLC
--Ingredients

insert into relationship_to_concept (concept_code_1,vocabulary_id_1,concept_id_2,precedence)
select a.concept_code as concept_code_1,'DA_France',c.concept_id as concept_id_2 , rank() over (partition by a.concept_code order by concept_id) as precedence 
from drug_concept_stage a join devv5.concept c 
on upper (c.concept_name) = upper(a.concept_name) and c.concept_class_id = 'Ingredient' and c.vocabulary_id like 'Rx%' and c.standard_concept='S'
where a.concept_class_id = 'Ingredient'
;

insert into relationship_to_concept 
select distinct a.concept_code,a.VOCABULARY_ID,c.concept_id,
rank() over (partition by a.concept_code order by concept_id_2) as precedence,
'' as conversion_factor
from drug_concept_stage a 
join ingredient_all_completed b on a.concept_name=b.concept_name
join devv5.concept c on c.concept_id=concept_id_2
where a.concept_class_id='Ingredient'
and (b.concept_name,concept_id_2) not in (select concept_name,concept_id_2 from drug_concept_stage 
join relationship_to_concept on concept_code=concept_code_1 and concept_class_id='Ingredient')
;

--Brand Names
--using full match of concept_names
insert into relationship_to_concept (concept_code_1,vocabulary_id_1,concept_id_2,precedence)
select a.concept_code as concept_code_1,'DA_France',c.concept_id as concept_id_2 , rank() over (partition by a.concept_code order by concept_id) as precedence 
from drug_concept_stage a join devv5.concept c 
on upper (c.concept_name) = upper(a.concept_name) and c.concept_class_id = 'Brand Name' and c.vocabulary_id like 'Rx%' and c.invalid_reason is null
where a.concept_class_id = 'Brand Name';


--manually found after utl_match
insert into relationship_to_concept (concept_code_1, vocabulary_id_1,concept_id_2, precedence)
select concept_code,'Da_France',concept_id_2,rank() over (partition by concept_code order by concept_id_2)
from  brand_names_manual a join drug_concept_stage b on upper(a.concept_name) =upper(b.concept_name)
;




--Dose Forms
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor)
select b.concept_code, 'DA_France',	CONCEPT_ID_2	, PRECEDENCE, '' from new_form_name_mapping a  --munualy created table 
join drug_concept_stage b on b.concept_name = a.DOSE_FORM_NAME
;
    
--Units
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('%', 'DA_France',8554,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('G', 'DA_France',8576,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('IU', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('IU', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('K', 'DA_France',8510,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('K', 'DA_France',8718,2,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('KG', 'DA_France',8576,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('L', 'DA_France',8587,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('M', 'DA_France',8510,1,1000000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MCG', 'DA_France',8576,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MG', 'DA_France',8576,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ML', 'DA_France',8576,2,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('U', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('U', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('Y', 'DA_France',8576,1,0.001);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('UI', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('UI', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MUI', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MUI', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('GM', 'DA_France',8576,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('DOS', 'DA_France',45744809,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('TU', 'DA_France',9413,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('TU', 'DA_France',8510,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('TU', 'DA_France',8718,3,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MU', 'DA_France',8510,2,0.000001);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MU', 'DA_France',8718,3,0.000001);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('H', 'DA_France',8505,1,1);
