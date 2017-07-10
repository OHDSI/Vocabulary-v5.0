create table non_drug as
select b.drug_Code,drug_Descr,ingredient,form,form_code from ingredient a join drug b 
on a.drug_code=b.drug_code
where form_code in ('4307','9354','77898','87188','94901','41804','14832','72310','89969','49487','24033','31035','66548','16621','31035') 
or dosage like '%Bq%' or form like '%dialyse%';
--insert radiopharmaceutical drugs
insert into non_drug (drug_Code,drug_descr,ingredient,form,form_code)
Select a.drug_Code,drug_descr,ingredient,form,form_code from 
drug a join ingredient b 
on a.drug_Code=b.drug_Code
where form like '%radio%' 
and a.drug_Code not in (select drug_code from non_drug);
--ingredients used in diagnostics
insert into non_drug (drug_Code,drug_descr,ingredient,form,form_code)
Select a.drug_Code,drug_descr,ingredient,form,form_code from 
drug a join ingredient b 
on a.drug_Code=b.drug_Code
where ingredient like '%IOXITALAM%' or ingredient like '%GADOTÉR%' or ingredient like '%AMIDOTRIZOATE%'
and a.drug_code not in (select drug_code from non_drug);
--patterns for dosages
insert into non_drug (drug_code,ingredient,form_Code)
select distinct  drug_code,ingredient,form_Code from ingredient a where a.drug_code in (
select drug_code from packaging where packaging  like '%compartiment%') and ( drug_form like '%compartiment%' or drug_form='%émulsion%')
and drug_form not like '%compartiment A%' and drug_form not like '%compartiment B%' and drug_form not like '%compartiment C%'
and drug_form not like '%compartiment (A)%' and drug_form not like '%compartiment (B)%'
and a.drug_code not in (select drug_code from non_drug) ;
--some patterns
insert into non_drug ( drug_Code,drug_descr,ingredient,form,form_code)
Select a.drug_Code,drug_descr,ingredient,form,form_code from 
drug a
left join ingredient b on a.drug_Code=b.drug_code
where regexp_like (drug_descr, 'hémofiltration|AMINOMIX|dialys|test|radiopharmaceutique|MIBG|STRUCTOKABIVEN|NUMETAN|NUMETAH|REANUTRIFLEX|CLINIMIX|REVITALOSE|CONTROLE', 'i') 
and a.drug_code not in (select drug_code from non_drug);
