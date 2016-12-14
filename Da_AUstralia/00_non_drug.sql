drop table non_drug;
create table non_drug as (select  distinct * from drugs where ATCCODE in('V01AA07','V03AK','V04B','V04CL','V04CX','V20','D02A','D02AD','D09A','D02AX','D02BA','D02AC')
or ATCCODE like 'V06%' or ATCCODE like 'V07%');

insert into non_drug
select * from drugs where regexp_like (PRD_NAME,'STOCKING|STRIPS|REMOVER|KCAL|NUTRISION|BREATH-ALERT|CHAMBER|REMOVAL|GAUZE|SUPPLY|PROTECTORS|SOUP|DRESSING|CLEANSER|BANDAGE|BEVERAGE|RESOURCE|WEIGHT|[^IN]TEST[^O]')
and fo_prd_id not in (select fo_prd_id from non_drug);

insert into non_drug  
select * from drugs where (MAST_PRD_NAME like '%SUN%' or   MAST_PRD_NAME like '%ACCU-CHEK%' or MAST_PRD_NAME like '%ACCUTREND%')  and  MAST_PRD_NAME not like '%SELSUN%'
and fo_prd_id not in (select fo_prd_id from non_drug);

insert into non_drug
select * from drugs where regexp_like(mol_name, 'IUD|LEUCOCYTES|AMIDOTRIZOATE|BANDAGE');

insert into non_drug
select * from drugs where regexp_like(nfc_code,'VZT|VGB|VGA|VZY|VEA|VED|VEK|VZV') and fo_prd_id not in (select fo_prd_id from non_drug);

ALTER TABLE non_drug
RENAME COLUMN fo_prd_id to concept_code;




