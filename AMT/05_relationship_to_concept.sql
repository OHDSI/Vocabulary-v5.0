--as sequence is changing we need to introduce table with names but with no codes
create table aut_bn_all_nc as (
select concept_code_1,concept_name_1,concept_id_2,precedence from aut_bn_2_1
union
select concept_code_1,concept_name_1,concept_id_2,precedence from aut_bn_1);


create table relationship_to_concept_nc as (  select * from
(
select AMOUNT_UNIT as concept_name_1,CONCEPT_id_2,precedence, CONVERSION_FACTOR from aut_unit_all_mapped 
union
select concept_name_1,CONCEPT_id_2,cast (precedence as number),null from aut_supplier_all_mapped
union
select concept_name_1,CONCEPT_id_2,cast (precedence as number),null from aut_form_all_mapped
--union
--select concept_name_1,CONCEPT_id_2,cast (precedence as number),null from aut_bn_all_nc
))
;

create table relationship_to_concept_2 as
select a.*,concept_code as concept_code_1 from relationship_to_concept_nc a join drug_concept_stage b on lower(b.concept_name)=lower(a.concept_name_1);

truncate table relationship_to_concept ;
insert into  relationship_to_concept (concept_code_1,vocabulary_id_1,concept_id_2,precedence,conversion_factor) 
select distinct concept_code_1,'AMT',concept_id_2,precedence,conversion_factor from
RELATIONSHIP_TO_CONCEPT_2
;
insert into relationship_to_concept
(concept_code_1,vocabulary_id_1,concept_id_2,precedence) 
select concept_code_1,'AMT',CONCEPT_id_2,cast (precedence as number) from aut_ing_all_mapped
union
select concept_code_1,'AMT',CONCEPT_id_2,cast (precedence as number) from aut_bn_all_nc 
;

insert into relationship_to_concept (concept_code_1,vocabulary_id_1,concept_id_2,precedence)
select distinct d.concept_code,'AMT',c.concept_id,1
from drug_concept_stage d 
join devv5.concept c on lower(c.concept_name)=lower(d.concept_name) and c.concept_class_id=d.concept_class_id and c.vocabulary_id like 'Rx%' and c.invalid_reason is null
where d.concept_class_id not in ('Drug Product','Device') 
and d.concept_code not in (select concept_code_1 from relationship_to_concept);

--introducings missing mappings from previous run
insert into relationship_to_concept (concept_code_1,vocabulary_id_1,concept_id_2,precedence)
select distinct d.concept_code,'AMT',c2.concept_id,1
from drug_concept_stage d 
join devv5.concept c on d.concept_code=c.concept_code
join devv5.concept_relationship cr on cr.concept_id_1=c.concept_id and relationship_id='Source - RxNorm eq'
join devv5.concept c2 on c2.concept_id=cr.concept_id_2 and c2.vocabulary_id like 'Rx%' and c2.invalid_reason is null and c2.concept_class_id=d.concept_class_id
where d.concept_class_id not in ('Drug Product','Device') 
and d.concept_code not in (select CONCEPT_CODE_1 from RELATIONSHIP_TO_CONCEPT );

delete relationship_to_concept where concept_code_1='65191011000036105';

--working with replaced suppliers
merge into RELATIONSHIP_TO_CONCEPT r
using (
select distinct r.concept_code_1,c2.concept_id from RELATIONSHIP_TO_CONCEPT r
join devv5.concept c on r.concept_id_2=c.concept_id
join dev_rxe.suppliers_to_repl sr on sr.concept_code_1=c.concept_code
join devv5.concept c2 on sr.concept_code_2=c2.concept_code and c2.vocabulary_id='RxNorm Extension'
where c.invalid_reason is not null ) n
on (n.concept_code_1=r.concept_code_1)
when matched then update 
set concept_id_2=n.concept_id;

update RELATIONSHIP_TO_CONCEPT 
set concept_id_2=21019525
where concept_code_1 = 'OMOP527837';   --Organon Teknika Ltd
DELETE
FROM RELATIONSHIP_TO_CONCEPT
WHERE CONCEPT_CODE_1 = 'OMOP527837'
AND   PRECEDENCE = 2;

update RELATIONSHIP_TO_CONCEPT 
set concept_id_2=40820756
where concept_code_1 = 'OMOP527854';--Orphan Europe (UK) Ltd

DELETE
FROM RELATIONSHIP_TO_CONCEPT
WHERE CONCEPT_CODE_1 = 'OMOP527958'
AND   PRECEDENCE = 2; --PIRAMAL IMAGING (ROYAUME-UNI) (OMOP527958  -- > 43132620)


--inserting data from current manual mapping
insert into relationship_to_concept (concept_code_1,vocabulary_id_1,concept_id_2,precedence,conversion_factor)
select distinct d.concept_code,'AMT',concept_id_2,precedence,conversion_factor
from mapping_150817 m join drug_concept_stage d on d.concept_name=m.concept_name
;
--gadotexate
UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 19031583
WHERE CONCEPT_CODE_1 = '31274011000036106'
AND   CONCEPT_ID_2 = 19124319;

UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 43567157
WHERE CONCEPT_CODE_1 = '30251000168107'
;

delete relationship_to_concept 
where rowid not in (
        select min(rowid)
        from relationship_to_concept 
        group by concept_code_1,concept_id_2,precedence)
      ;
