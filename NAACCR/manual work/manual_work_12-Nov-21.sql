--restore the vocabulary from dev_cancer_modifier schema where it was run correctly
--filling manual tables and then process them in the load_stage
insert into concept_manual
select  concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason from dev_cancer_modifier.concept a 
where a.vocabulary_id ='NAACCR' 
;
insert into concept_relationship_manual
select 
a.concept_code, c.concept_code, a.vocabulary_id, c.vocabulary_id, r.relationship_id , r.valid_start_date, r.valid_end_date, r.invalid_reason
 from dev_cancer_modifier.concept a 
join dev_cancer_modifier.concept_relationship r on a.concept_id = r.concept_id_1
join dev_cancer_modifier.concept c on c.concept_id = r.concept_id_2
where a.vocabulary_id ='NAACCR'
--load only 'direct' relationships
and r.relationship_id in ('Schema to ICDO','Has Answer','Start date of','Type of','Value to Schema','ICDO to Proc Schema','Variable has date','Has unit','Variable to Schema','Parent item of','Permiss range of','Has end date','Maps to');
