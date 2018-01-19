cat "02_non_drug.sql" > whole_script.sql
cat "03_brand_name.sql" >> whole_script.sql
cat "04_1_packs.sql" >> whole_script.sql
cat "04_2_denorm_list.sql" >> whole_script.sql
cat "06_parse_drug_components.sql" >> whole_script.sql
cat "07_1_create_strength_tmp.sql" >> whole_script.sql
cat "07_2_strength_tmp.sql" >> whole_script.sql
cat "07_3_new_strength_amis.sql" >> whole_script.sql
cat "07_4_pack_content.sql" >> whole_script.sql
cat "08_drug_concept_stage.sql" >> whole_script.sql
cat "09_internal_relationship_stage.sql" >> whole_script.sql
cat "10_concept_synonym_stage_vs_relationship_to_concept.sql" >> whole_script.sql
cat "10_ds_stage.sql" >> whole_script.sql
cat "11_set_dates.sql" >> whole_script.sql
cat "12_post_processing.sql" >> whole_script.sql

echo "commit;" >> whole_script.sql
