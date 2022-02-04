--concept_stage generated with map_drug_lookup is fine (dose forms added comparing to the existing names
TRUNCATE concept_stage;
INSERT INTO concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
SELECT DISTINCT source_name AS concept_name,
       'Drug' AS domain_id,
       'DA_France' AS vocabulary_id,
       'Drug Product' AS concept_class_id,
       null AS standard_concept,
       source_code AS concept_code,
       TO_DATE('2022-01-29','yyyy-mm-dd') AS valid_start_date,
  TO_DATE('2099-12-31','yyyy-mm-dd') AS valid_end_date,
       null AS invalid_reason
FROM map_drug_lookup
;
--the mapping is not granular, but better than existing for some concepts, so we create this table
INSERT INTO concept_relationship_stage_polina
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
SELECT DISTINCT source_code,
       c.concept_code,
       'DA_France',
       c.vocabulary_id,
       'Maps to',
       TO_DATE('2022-01-29','yyyy-mm-dd') AS valid_start_date,
       CASE
         WHEN invalid_reason = 'D' THEN CURRENT_DATE
         ELSE TO_DATE('2099-12-31','yyyy-mm-dd')
       END AS valid_end_date,
       invalid_reason AS invalid_reason
FROM dev_da_france_2.map_drug_lookup 
join concept c using (concept_id) 
;
truncate concept_relationship_stage
;
insert into concept_relationship_stage
/*determine concepts that have mapping and target concepts have hierarchy that ends with Ingredient
maybe it's better to use this 
https://github.com/OHDSI/Vocabulary-v5.0/blob/acb7d37c9cc030c546244a7350ba7edb5df5feb3/working/packages/vocabulary_pack/RxECleanUP.sql#L48
do define broken concepts
*/
with aa as (select a.concept_code from concept a
join concept_relationship r on  a.concept_id  = r.concept_id_1 and relationship_id ='Maps to' and r.invalid_reason is null
join concept_ancestor an on an.descendant_concept_id = r.concept_id_2 
join concept c on c.concept_id = ancestor_concept_id and c.concept_class_id in ('Ingredient', 'Device')
 where a.vocabulary_id='DA_France'
) 
select p.* from da_france_source a
join concept_relationship_stage_polina p on p.concept_code_1 = a.pfc
left join aa on pfc = concept_code 
where aa.concept_code is null
  ;
  --adding insulines and vaccines mapped manually
insert into concept_relationship_stage
select p.* from concept_relationship_stage_polina p 
join da_franca_ins_vacc a on p.concept_code_1 = a.pfc
where p.concept_code_1 not in (select concept_code_1 from concept_relationship_stage)
;
--deprecate those mapped to CVX currently and to RxNorm(E) in the existing releaself 
insert into concept_relationship_stage 
with aa as (
select a.concept_code as concept_code_1, c.concept_code as concept_code_2, 
 a.vocabulary_id  as vocabulary_id_1, c.vocabulary_id  as vocabulary_id_2 ,
relationship_id ,r.valid_start_date, current_date as valid_end_date, 'D' as invalid_reason 
from devv5.concept a
join devv5.concept_relationship r on  a.concept_id  = r.concept_id_1 and relationship_id ='Maps to' and r.invalid_reason is null
join devv5.concept c  on c.concept_id = r.concept_id_2)
select null, null, aa.* from aa  
join concept_relationship_stage a on aa.concept_code_1 = a.concept_code_1 and aa.vocabulary_id_1 = a.vocabulary_id_1 and a.vocabulary_id_2 != aa.vocabulary_id_2
join concept d on d.concept_code = a.concept_code_2 and d.vocabulary_id = a.vocabulary_id_2
where a.vocabulary_id_2 ='CVX'
and not exists (select * from concept_relationship_stage b  where aa.concept_code_1 = b.concept_code_1 and aa.vocabulary_id_1 = b.vocabulary_id_1 and b.vocabulary_id_2 = aa.vocabulary_id_2 and  aa.concept_code_2 = b.concept_code_2)
