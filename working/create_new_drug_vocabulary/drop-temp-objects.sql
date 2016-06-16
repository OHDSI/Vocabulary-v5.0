drop sequence ds_seq;
drop sequence xxx_seq;

drop table unique_ds purge;
drop table ds cascade constraints purge;
drop table ds_combo purge;
drop table ing purge;
drop table ing_combo purge;
drop table ing_to_ds purge;
drop table quant purge;
drop table bn purge;
drop table df purge;
drop table bs purge;

drop table manufact purge;
drop table nmf_packs purge;

drop table existing_concept_stage purge;
drop table complete_concept_stage cascade constraints purge;
drop table complete_name;

drop table r_drug_ing purge;
drop table r_ing_count purge;
drop table q_drug_ing purge;
drop table q_ing_count purge;
drop table match purge;
drop table shared_ing purge;
drop table r_df purge;
drop table q_bn purge;
drop table q_df purge;
drop table m purge;
drop table r_bn purge;
drop table q_to_r_anydose purge;
drop table q_to_r_wdose purge;
drop table q_to_r purge;
drop table an purge;

drop table xxx_replace purge;