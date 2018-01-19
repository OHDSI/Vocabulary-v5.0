truncate table pc_stage;
insert into pc_stage (PACK_CONCEPT_CODE,DRUG_CONCEPT_CODE,AMOUNT)
select FO_PRD_ID,CONCEPT_CODE,AMOUNT_PACK from pack_drug_product
join drug_concept_stage on PRD_NAME=concept_name;
