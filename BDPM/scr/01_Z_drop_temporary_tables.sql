
drop table non_drug;

--01_seq

--drop sequence new_voc;

--02_packs_and_homeop
drop table homeop_drug CASCADE CONSTRAINTS PURGE;
drop table PF_from_pack_comp_list;

--list
drop table brand_name;
drop table dcs_manufacturer CASCADE CONSTRAINTS PURGE;
drop table dcs_bn CASCADE CONSTRAINTS PURGE;
drop table list;
drop sequence new_vocc;

--pack_content
drop table p_c_amount;

--packaging_parsing
drop table packaging_pars_1;
drop table packaging_pars_2;
drop table packaging_pars_3;
drop table drug_ingred_to_ingred;
drop table ingredient_step_1;
drop table ingredient_step_2;
drop table ds_1;


--pack_rebuilt
DROP table pack_st_1 ;
drop TABLE PACK_CONT_1;
drop table ds_pack_1;
drop sequence PACK_SEQ;
drop TABLE PACK_COMP_LIST;

truncate table drug_concept_stage;
truncate table ds_stage;
truncate table internal_relationship_stage;
truncate table relationship_to_concept;
truncate table pc_stage;
truncate table Concept_synonym_stage;


