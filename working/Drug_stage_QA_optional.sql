--these queries return not null results
--but these results are suspicious and need to be reviewed

-- drugs absent in drug_strength table
select distinct concept_code, 'Drug product doesnt have drug_strength info' from drug_concept_stage
 where concept_code not in (select drug_concept_code from ds_stage) and concept_class_id='Drug Product' and concept_code not in 
 (select pack_concept_code from pc_stage)
 union
 select distinct concept_code,'Missing relationship to Ingredient'  from drug_concept_stage where concept_class_id='Drug Product'
  and concept_code not in  (select pack_concept_code from pc_stage)
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
select distinct denominator_unit_concept_id from drug_strength join concept c on c.concept_id = drug_concept_id and c.vocabulary_id = 'RxNorm') where  amount_unit_concept_id is not null
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

-- some tests , have features usable only in AMT vocabulary, but can be reused with the other vocabularies
select * from ds_stage 
join drug_concept_stage on concept_code = drug_concept_code
where denominator_value is not null and rownum < 100
;
select * from ds_stage 
join drug_concept_stage on concept_code = drug_concept_code
where denominator_value is  null 
and regexp_like (concept_name , '\d+ Ml$')
and regexp_substr (concept_name , '\d+ Ml$') != '5 Ml' and  regexp_substr (concept_name , '\d+ Ml$') != '10 Ml'
and rownum < 100
;
select * from drug_concept_stage where domain_id is null or domain_id !='Drug'
;
select s.concept_name as source_name, S.concept_class_id as source_class, c.concept_name as target_name, c.concept_class_id as target_class, PRECEDENCE, CONVERSION_FACTOR
 from relationship_to_concept  
join concept c on concept_id = concept_id_2
join drug_concept_stage s on s.concept_code = concept_code_1
where s.concept_class_id = 'Ingredient'
and UTL_MATCH.JARO_WINKLER_SIMILARITY (s.concept_name, c.concept_name) < 80
;
select * from ds_stage 
join drug_concept_stage on drug_concept_code = concept_code
where rownum < 2000
;
select * from ds_stage where AMOUNT_UNIT ='%' or NUMERATOR_UNIT ='%' or DENOMINATOR_UNIT ='%'
;
select distinct a.concept_class_id, b.concept_class_id from internal_relationship_stage i
join drug_concept_stage a on i.concept_code_1= a.concept_code
join drug_concept_stage b on i.concept_code_2= b.concept_code
;
--missing relationship to Dose Form
select * from drug_concept_stage where concept_code not in (
select distinct a.concept_code from internal_relationship_stage i
join drug_concept_stage a on i.concept_code_1= a.concept_code
join drug_concept_stage b on i.concept_code_2= b.concept_code
where b.CONCEPT_CLASS_ID = 'Dose Form'
)
and concept_class_id = 'Drug Product'
;
--missing relationship to Brand Name
select * from drug_concept_stage where concept_code not in (
select distinct a.concept_code from internal_relationship_stage i
join drug_concept_stage a on i.concept_code_1= a.concept_code
join drug_concept_stage b on i.concept_code_2= b.concept_code
where b.CONCEPT_CLASS_ID = 'Brand Name'
)
and SOURCE_CONCEPT_CLASS_ID = 'Trade Product Pack'
and rownum < 1000
;
--missing relationship to Supplier
select * from drug_concept_stage where concept_code not in (
select distinct a.concept_code from internal_relationship_stage i
join drug_concept_stage a on i.concept_code_1= a.concept_code
join drug_concept_stage b on i.concept_code_2= b.concept_code
where b.CONCEPT_CLASS_ID = 'Supplier'
)
and SOURCE_CONCEPT_CLASS_ID = 'Trade Product Pack' and regexp_like (concept_name, '\(...+\)')  
and rownum < 1000
;
select * from drug_concept_stage
;
select s.concept_name as source_name, S.concept_class_id as source_class, c.concept_name as target_name, c.concept_class_id as target_class, PRECEDENCE, CONVERSION_FACTOR
 from relationship_to_concept  
join concept c on concept_id = concept_id_2
join drug_concept_stage s on s.concept_code = concept_code_1
where s.concept_class_id = 'Brand Name'
and UTL_MATCH.JARO_WINKLER_SIMILARITY (lower (s.concept_name), lower (c.concept_name)) < 90
;
select count (1)
--s.concept_name as source_name, S.concept_class_id as source_class, c.concept_name as target_name, c.concept_class_id as target_class, PRECEDENCE, CONVERSION_FACTOR
 from relationship_to_concept  
join concept c on concept_id = concept_id_2
join drug_concept_stage s on s.concept_code = concept_code_1
where s.concept_class_id = 'Supplier'
--and UTL_MATCH.JARO_WINKLER_SIMILARITY (lower (s.concept_name), lower (c.concept_name)) < 90
;
select count (1) 
--s.concept_name as source_name, S.concept_class_id as source_class, c.concept_name as target_name, c.concept_class_id as target_class, PRECEDENCE, CONVERSION_FACTOR
 from relationship_to_concept  
join concept c on concept_id = concept_id_2
join drug_concept_stage s on s.concept_code = concept_code_1
where s.concept_class_id = 'Brand Name'
--and UTL_MATCH.JARO_WINKLER_SIMILARITY (lower (s.concept_name), lower (c.concept_name)) < 90
;
select count (1) 
--s.concept_name as source_name, S.concept_class_id as source_class, c.concept_name as target_name, c.concept_class_id as target_class, PRECEDENCE, CONVERSION_FACTOR
 from relationship_to_concept  
join concept c on concept_id = concept_id_2
join drug_concept_stage s on s.concept_code = concept_code_1
where s.concept_class_id = 'Ingredient'
;
select s.concept_class_id , count (1) 
 from relationship_to_concept  
join concept c on concept_id = concept_id_2
join drug_concept_stage s on s.concept_code = concept_code_1
group by  s.concept_class_id 
;
select distinct b.concept_name from ds_stage a
join drug_concept_stage b on a.ingredient_concept_code = concept_code
 where ingredient_concept_code not in (select concept_code_1 from relationship_to_concept)
 ;
 select-- count (1) 
s.concept_name as source_name, S.concept_class_id as source_class, c.concept_name as target_name, c.concept_class_id as target_class, PRECEDENCE, CONVERSION_FACTOR
 from relationship_to_concept  
join concept c on concept_id = concept_id_2
join drug_concept_stage s on s.concept_code = concept_code_1
where s.concept_class_id = 'Unit'
;
select * from concept where vocabulary_id = 'UCUM'
;
select b.concept_name, a.concept_name, p.* from pc_stage p
join drug_concept_stage a on a.CONCEPT_CODE = p.DRUG_CONCEPT_CODE
join drug_concept_stage b on b.CONCEPT_CODE = p.PACK_CONCEPT_CODE
;
--missing relationship to Brand Name
select * from drug_concept_stage where concept_code not in (
select distinct a.concept_code from internal_relationship_stage i
join drug_concept_stage a on i.concept_code_1= a.concept_code
join drug_concept_stage b on i.concept_code_2= b.concept_code
where b.CONCEPT_CLASS_ID = 'Brand Name'
)
and SOURCE_CONCEPT_CLASS_ID = 'Trade Product Pack'
and rownum < 1000
;
--missing relationship to Supplier
select  * from drug_concept_stage where concept_code NOT in (
select distinct a.concept_code from internal_relationship_stage i
join drug_concept_stage a on i.concept_code_1= a.concept_code
join drug_concept_stage b on i.concept_code_2= b.concept_code
where b.CONCEPT_CLASS_ID = 'Supplier'
)
and SOURCE_CONCEPT_CLASS_ID = 'Trade Product Pack' --and LENGTH ( regexp_SUBSTR  (concept_name, '\(...+\)?')  ) < 20
and concept_code in (select pack_concept_code from pc_stage)
and rownum < 1000
;
--missing relationship to Brand Name
select  * from drug_concept_stage where concept_code not in (
select distinct a.concept_code from internal_relationship_stage i
join drug_concept_stage a on i.concept_code_1= a.concept_code
join drug_concept_stage b on i.concept_code_2= b.concept_code
where b.CONCEPT_CLASS_ID = 'Brand Name' and a.concept_code is not null
)
and SOURCE_CONCEPT_CLASS_ID = 'Trade Product Pack' 
and concept_code in (select pack_concept_code from pc_stage)
and rownum < 1000
;
