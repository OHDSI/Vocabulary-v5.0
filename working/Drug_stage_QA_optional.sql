--these queries return not null results
--but these results are suspicious and need to be reviewed

-- drugs absent in drug_strength table
select distinct concept_code, 'Drug product doesnt have drug_strength info' from drug_concept_stage
 where concept_code not in (select drug_concept_code from ds_stage) and concept_class_id='Drug Product'
 union
 select distinct concept_code,'Missing relationship to Ingredient'  from drug_concept_stage where concept_class_id='Drug Product'
and concept_code not in(
select a.concept_code from  drug_concept_stage a 
join internal_relationship_stage s on s.concept_code_1= a.concept_code  
join drug_concept_stage b on b.concept_code = s.concept_code_2
 and  a.concept_class_id='Drug Product' and b.concept_class_id ='Ingredient'
)
union
--Ingredient doesnt relate to any drug
select distinct a.concept_code, 'Ingredient doesnt relate to any drug' from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
where a.concept_class_id= 'Ingredient' and b.concept_code_1 is null
union
--getting ingredient duplicates after relationsip_to_concept
select drug_concept_code, 'ingred duplic after relationsip_to_concept'  from ds_stage a
join relationship_to_concept b on ingredient_concept_code= concept_code_1 and precedence =1
group by  drug_concept_code, concept_id_2 having count (1) > 1
;
--units absent in RxNorm
select * from relationship_to_concept 
join concept n on n.concept_id = concept_id_2
where concept_class_id ='Unit'
and concept_id_2 not in ( select amount_unit_concept_id from (
select distinct amount_unit_concept_id from drug_strength join concept c on c.concept_id = drug_concept_id and c.vocabulary_id = 'RxNorm'
union 
select distinct numerator_unit_concept_id from drug_strength join concept c on c.concept_id = drug_concept_id and c.vocabulary_id = 'RxNorm'
union 
select distinct numerator_unit_concept_id from drug_strength join concept c on c.concept_id = drug_concept_id and c.vocabulary_id = 'RxNorm') where  amount_unit_concept_id is not null
);
--anyway need to look throught this table , mistakes here cost too much
select * from relationship_to_concept 
join concept n on n.concept_id = concept_id_2
where concept_class_id ='Unit'
;
select source_concept_class_id from drug_concept_stage where rownum =0
;
select * from ds_stage where numerator_unit ='%'
;
-- getting ingredient duplicates after relationsip_to_concept look up table
select ds.*,dcs.concept_name,dci.concept_name, c.concept_name from ds_stage ds
join relationship_to_concept b on ingredient_concept_code= concept_code_1 and precedence =1
join drug_concept_stage dcs on DRUG_CONCEPT_CODE = dcs.concept_code
join  drug_concept_stage dci on ingredient_CONCEPT_CODE = dci.concept_code
join concept c on concept_id = concept_id_2
where drug_concept_code  in (
select drug_concept_code from ds_stage a
join relationship_to_concept b on ingredient_concept_code= concept_code_1 and precedence =1
group by  drug_concept_code, concept_id_2 having count (1) > 1)
;
--select * from source_table where enr = '101149'