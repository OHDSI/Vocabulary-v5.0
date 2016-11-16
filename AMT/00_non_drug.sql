drop table non_drug;
create table non_drug as
select * from concept_stage_sn where
regexp_like (lower(concept_name), 'dialysis|mma/pa|smoflipid|camino|maxamum|sno-pro|lubri|peptamen|pepti-junior|dressing|diagnostic|glove|supplement|containing|rope |procal|glytactin|gauze|keyomega|cystine|docomega|anamix|xlys|xmtvi |pku |tyr |msud |hcu |eaa |cranberry|pedialyte|msud|gastrolyte|movicol|hydralyte|hcu cooler|pouch|burger|needl|biscuits|wipes|kilocalories|cake|roll|adhesive|milk|dessert')       
and concept_class_id in  ('AU Substance','AU Qualifier','Med Product Unit','Med Product Pack','Medicinal Product','Trade Product Pack','Trade Product','Trade Product Unit','Contain Trade Pack')   
and concept_name not like '%Panadol%' and concept_name not like '%ointment%' and concept_name not like '%Scotch pine%'; 

insert into non_drug
select * from concept_stage_sn where
regexp_like (lower(concept_name), 'juice|gluten|medium chain|prozero|amino acid supplement|long chain|low protein|pouches|ribbon|cannula|swabs|bandage|artificial saliva|cylinder|bq |mineral mixture|amino acids|trace elements|energivit|pro-phree|elecare|neocate')       
and concept_class_id in  ('AU Substance','AU Qualifier','Med Product Unit','Med Product Pack','Medicinal Product','Trade Product Pack','Trade Product','Trade Product Unit','Contain Trade Pack')   
and concept_name not like '%Panadol%' and concept_name not like '%ointment%' and concept_name not like '%Scotch pine%'; 


insert into non_drug
select distinct a.* from concept_stage_sn a
join RF2_FULL_RELATIONSHIPS b on a.concept_code=destinationid
join concept_stage_sn c on c.concept_Code=sourceid
where a.concept_name in ('bar','can','roll','rope','sheet' )
;
insert into non_drug
select distinct c.* from concept_stage_sn a
join RF2_FULL_RELATIONSHIPS b on a.concept_code=destinationid
join concept_stage_sn c on c.concept_Code=sourceid
where a.concept_name in ('bar','can','roll','rope','sheet' )
and c.concept_name not like '%ointment%'
and c.concept_code!='159011000036105';--soap bar

insert into non_drug --dietary supplement
select * from concept_stage_sn 
where concept_name like '%Phlexy-10%' or concept_name like '%Wagner 1000%' or concept_name like '%Nutrition Care%' or concept_name like '%amino acid formula%'
or concept_name like '%Crampeze%' or concept_name like '%Elevit%' or concept_name like '%Ostelin%'  or concept_name like '%Oralair%' or concept_name like '%Bio Magnesium%';


insert into non_drug                    --contrast
select distinct a.* from concept_stage_sn a
join RF2_FULL_RELATIONSHIPS b on a.concept_code=sourceid
where destinationid in ('31108011000036106','75889011000036104','31109011000036103','31111011000036100','31527011000036107',
'75888011000036107'	,'48143011000036102','48144011000036100','48145011000036101','31956011000036101','733181000168100','732871000168102','52990011000036102')
and a.concept_code not in (select concept_code from non_drug);
insert into non_drug
select distinct a.* from concept_stage_sn a
where concept_code in ('31108011000036106','75889011000036104','31109011000036103','31111011000036100','31527011000036107','75888011000036107',
'48143011000036102','48144011000036100','48145011000036101','31956011000036101','733181000168100','732871000168102','52990011000036102');

insert into non_drug
select c.* from 
non_drug a join RF2_FULL_RELATIONSHIPS b
on destinationid=a.concept_code
join concept_stage_sn c on sourceid=c.concept_code
where c.concept_code not in (select concept_code from non_drug)
;
insert into non_drug
select distinct c.* from 
non_drug a join RF2_FULL_RELATIONSHIPS b
on sourceid=a.concept_code
join concept_stage_sn c on destinationid=c.concept_code
where c.concept_code not in (select concept_code from non_drug)
and c.concept_class_id  in ('Trade Product Pack','Trade Product','Med Product Unit','Med Product Pack')
;
insert into non_drug
select distinct c.* from 
non_drug a join RF2_FULL_RELATIONSHIPS b
on sourceid=a.concept_code
join concept_stage_sn c on destinationid=c.concept_code
where c.concept_code not in (select concept_code from non_drug)
and (c.concept_name like '%tape%' or c.concept_name like '%amino acid%' or c.concept_name like '%carbohydrate%' or c.concept_name like '%protein %' )
and c.concept_code not in ('31530011000036109','32170011000036100','31034011000036102');

insert into non_drug
select distinct a.* from concept_stage_sn a join RF2_FULL_RELATIONSHIPS b on b.sourceid=a.concept_code
join RF2_FULL_RELATIONSHIPS e on b.destinationid=e.sourceid
join concept_stage_sn c on c.concept_code=e.destinationid
where c.CONCEPT_CLASS_ID in ('AU Qualifier','AU Substance')
and regexp_like (c.concept_name,'dressing|amino acid|trace elements')
and not regexp_like (c.concept_name,'copper|manganese|zinc|magnesium')
and a.concept_code not in (select concept_code from non_drug)
;

delete non_drug where concept_code='159011000036105';