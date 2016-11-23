select * from ds_stage where drug_concept_code='691061000168106';!!!
;
update ds_0_2 
set numerator_value=numerator_value/57,
new_denom_value=null
where
NEW_DENOM_VALUE is not null and concept_name like '%, 5 Ml%' and concept_name like '%Oral%';





Questions:
--need to regexp 'agent' from substance
--there are inert ingredients
--in trade products there are brand names=ingredients
--supplier need to be regexp-ed +
--duplicates --select * from concept_stage where concept_name='ampoule'; --3
--AU QUAlifier also is presented in such a relationship
Cont Tr Prod Pack	has container type	AU Qualifier
--classes!!
select * from concept_stage where concept_name='Intralipid 30% (75 g/250 mL) intravenous infusion injection, 10 x 250 mL bags';     !!!! (problem in original data)
--select * from FULL_DESCR_DRUG_ONLY where conceptid in ( select CONCEPTID from FULL_DESCR_DRUG_ONLY where term='Intralipid 30% (75 g/250 mL) intravenous infusion injection, 10 x 250 mL bags');  


-- need to check if there are ing+its salt in a drug:
select * from SCT2_RELA_FULL_AU a join SCT2_DESC_FULL_AU b on a.sourceid=b.CONCEPTID
join SCT2_DESC_FULL_AU c on a.DESTINATIONID=c.CONCEPTID
where sourceid='106701000036105';

--there are relationship to form,ing etc only in clinical drug (medicinal product unit of use) 
select distinct b.term,c.term from SCT2_RELA_FULL_AU a 
join SCT2_DESC_FULL_AU b on a.sourceid=b.CONCEPTID
join SCT2_DESC_FULL_AU c on a.DESTINATIONID=c.CONCEPTID
where sourceid='23617011000036104';
 + 
abacavir 600 mg + lamivudine 300 mg tablet has relationship to lamivudine 300 mg tablet,but not to abakavir 600 mg tablet


NEED TO BE CHECKED
Shouldn't be in concept_stage :
1)term='medicinal product' or term='medicinal product (medicinal product)'... 'composite pack','containered trade product pack','containered trade product pack (containered trade product pack)' so on
2)Duplicates with same ID
select distinct * from  SCT2_DESC_FULL_AU b where CONCEPTID='691321000168103';

Shouldn't be in concept_Relationship:
relationship to ing+ing
select distinct b.term,c.term from SCT2_RELA_FULL_AU a 
join SCT2_DESC_FULL_AU b on a.sourceid=b.CONCEPTID
join SCT2_DESC_FULL_AU c on a.DESTINATIONID=c.CONCEPTID
where b.term like '%+%(medicinal product)%'
and c.term like '%+%';
--For instance
select distinct * from SCT2_RELA_FULL_AU a 
join SCT2_DESC_FULL_AU b on a.sourceid=b.CONCEPTID
join SCT2_DESC_FULL_AU c on a.DESTINATIONID=c.CONCEPTID
where b.term like '%abacavir + dolutegravir + lamivudine (medicinal product)%'
;