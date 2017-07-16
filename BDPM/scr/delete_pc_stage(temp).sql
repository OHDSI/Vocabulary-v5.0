delete drug_concept_stage where concept_code in (select pack_concept_code from pc_stage);
delete drug_concept_stage where concept_code in (select drug_concept_code from pc_stage);
delete internal_relationship_stage where concept_code_1 in (select pack_concept_code from pc_stage);
delete internal_relationship_stage where concept_code_1 in (select drug_concept_code from pc_stage);
delete ds_stage where drug_concept_code in (select drug_concept_code from pc_stage);commit; 
truncate table pc_stage;

