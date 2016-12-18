create table concept_relat_back_up as select * from concept_relationship
;
    ALTER TABLE concept_relationship
DROP CONSTRAINT xpk_concept_relationship
;
update concept_relationship a set RELATIONSHIP_ID ='Brand name of'
where exists (select 1 from (
select distinct concept_id_1, concept_id_2 from concept a
join concept_relationship r on r.concept_id_1 = a.concept_id 
join concept b on r.concept_id_2 = b.concept_id 
where a.concept_class_id ='Brand Name' and  (b.concept_class_id like '%Drug%' or  b.concept_class_id like '%Box%' or b.concept_class_id ='Marketed Product')
and r.invalid_reason is null
and a.vocabulary_id like 'RxNorm%' AND B.vocabulary_id like 'RxNorm%' 
AND R.RELATIONSHIP_ID ='Has brand name') b where a.concept_id_1 =b.concept_id_1 and  a.concept_id_2 =b.concept_id_2)
;
update concept_relationship a set RELATIONSHIP_ID ='Has brand name'
where exists (select 1 from (
select distinct concept_id_1, concept_id_2 from concept a
join concept_relationship r on r.concept_id_2 = a.concept_id 
join concept b on r.concept_id_1 = b.concept_id 
where a.concept_class_id ='Brand Name' and  (b.concept_class_id like '%Drug%' or  b.concept_class_id like '%Box%' or b.concept_class_id ='Marketed Product')
and r.invalid_reason is null
and a.vocabulary_id like 'RxNorm%' AND B.vocabulary_id like 'RxNorm%' 
AND R.RELATIONSHIP_ID ='Brand name of') b where a.concept_id_1 =b.concept_id_1 and  a.concept_id_2 =b.concept_id_2)
;
delete from concept_relationship r where exists (select 1 from 
(
select concept_id_1,concept_id_2,relationship_id, max (VALID_START_DATE) as dat from concept_relationship
group by concept_id_1,concept_id_2,relationship_id  having count(1)>1) x where
 x.concept_id_1= r.concept_id_1 and 
 x.concept_id_2= r.concept_id_2  and
 x.relationship_id = r.relationship_id and
 x.dat = r.VALID_START_DATE)
 ;
ALTER TABLE concept_relationship ADD CONSTRAINT xpk_concept_relationship PRIMARY KEY (concept_id_1,concept_id_2,relationship_id)
;