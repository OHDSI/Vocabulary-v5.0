
update drug_concept_stage set concept_name='Independent Pharmacy Cooperative' where concept_name='Ipc';
update drug_concept_stage set concept_name='Sun Pharmaceutical' where concept_name='Sun';
update drug_concept_stage set concept_name='Boucher & Muir Pty Ltd' where concept_name='Bnm';
update drug_concept_stage set concept_name='Pharma GXP' where concept_name='Gxp';
update drug_concept_stage set concept_name='Douglas Pharmaceuticals' where concept_name='Douglas';
update drug_concept_stage set concept_name='FBM-PHARMA' where concept_name='Fbm';
update drug_concept_stage set concept_name='DRX Pharmaceutical Consultants' where concept_name='Drx';
update drug_concept_stage set concept_name='Saudi pharmaceutical' where concept_name='Sau';
update drug_concept_stage set concept_name='FBM-PHARMA' where concept_name='Fbm';
delete drug_concept_stage where concept_Code in (
select distinct a.concept_code from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
where a.concept_class_id= 'Brand Name' and b.concept_code_1 is null
union
select distinct a.concept_code from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
where a.concept_class_id= 'Dose Form' and b.concept_code_1 is null
);