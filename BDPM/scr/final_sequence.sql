

-- Create sequence for new OMOP-created standard concepts
declare
 ex number;
begin
select max(iex)+1 into ex from (  
    
    select cast(substr(concept_code, 5) as integer) as iex from concept where concept_code like 'OMOP%'  and concept_code not like '% %'
);
  begin
    execute immediate 'create sequence new_vocab increment by 1 start with ' || ex || ' nocycle cache 20 noorder';
    exception
      when others then null;
  end;
end;
/

drop table code_replace;
 create table code_replace as 
 select 'OMOP'||new_vocab.nextval as new_code, concept_code as old_code from (
select distinct  concept_code from drug_concept_stage where concept_code like '%OMOP%' or concept_code like '%PACK%' order by (cast ( regexp_substr( concept_code, '\d+') as int))
)
;
update drug_concept_stage a set concept_code = (select new_code from code_replace b where a.concept_code = b.old_code) 
where a.concept_code like '%OMOP%' or a.concept_code like '%PACK%'
;
commit
;
update relationship_to_concept a  set concept_code_1 = (select new_code from code_replace b where a.concept_code_1 = b.old_code)
where a.concept_code_1 like '%OMOP%' or a.concept_code_1 like '%PACK%'
;commit
;
update ds_stage a  set ingredient_concept_code = (select new_code from code_replace b where a.ingredient_concept_code = b.old_code)
where a.ingredient_concept_code like '%OMOP%' or a.ingredient_concept_code like '%PACK%'
;
commit
;
update ds_stage a  set drug_concept_code = (select new_code from code_replace b where a.drug_concept_code = b.old_code)
where a.drug_concept_code like '%OMOP%' or a.drug_concept_code like '%PACK%'
;commit
;
update internal_relationship_stage a  set concept_code_1 = (select new_code from code_replace b where a.concept_code_1 = b.old_code)
where a.concept_code_1 like '%OMOP%' or a.concept_code_1 like '%PACK%'
;commit
;
update internal_relationship_stage a  set concept_code_2 = (select new_code from code_replace b where a.concept_code_2 = b.old_code)
where a.concept_code_2 like '%OMOP%' or a.concept_code_2 like '%PACK%'
;
commit
;
update pc_stage a  set DRUG_CONCEPT_CODE = (select new_code from code_replace b where a.DRUG_CONCEPT_CODE = b.old_code)
where a.DRUG_CONCEPT_CODE like '%OMOP%' or a.DRUG_CONCEPT_CODE like '%PACK%'
;
update drug_concept_stage set standard_concept=null where concept_code in (select concept_code from drug_concept_stage 
join internal_relationship_stage on concept_code_1 = concept_code
where concept_class_id ='Ingredient' and standard_concept is not null);

commit;
update drug_concept_stage set concept_class_id = 'Drug Product' where concept_class_id='Drug Pack';
commit; 
commit; 
