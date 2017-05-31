create table RxNorm_ingr as select * from devv5.concept b WHERE b.concept_Class_id='Ingredient' and invalid_reason is null;-- and vocabulary_id ='RxNorm';
;

create table Brand_name_exception
as select brand_name from brand_name a 
JOIN RxNorm_ingr b ON utl_match.edit_distance (a.brand_name,b.concept_name)=1
; 

drop table BN_map_0;
create table BN_map_0 as 
select distinct b.brand_name, concept_id, c.concept_name as concept_name_2,'1' as precedence  from brand_name b
join devv5.concept c on lower (c.concept_name)=lower (b.brand_name)
where c.vocabulary_id like 'RxNorm%'
and c.concept_class_id= 'Brand Name' and invalid_reason is null 
;
CREATE TABLE BN_MAP_2
(
   BRAND_NAME      VARCHAR2(1200 Byte),
   CONCEPT_ID      NUMBER                NOT NULL,
   CONCEPT_NAME_2  VARCHAR2(255 Byte)    NOT NULL,
   PRECEDENCE      CHAR(1)
)
TABLESPACE USERS;
WbImport -file=C:/Users/aostropolets/Desktop/bdpm files/bn_map_2.txt
         -type=text
         -table=BN_MAP_2
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=BRAND_NAME,CONCEPT_ID,CONCEPT_NAME_2,PRECEDENCE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false;
create table aut_bn_mapped_all as (
select * from bn_map_0 
union 
select * from bn_map_2);

--inserting BN from other vocabularies' relationship to RxNorm
insert into aut_bn_mapped_all (BRAND_NAME,CONCEPT_ID,CONCEPT_NAME_2,PRECEDENCE)
select distinct brand_name,concept_id_2,c2.concept_name,'1' from brand_name b
join devv5.concept c on lower (c.concept_name)=lower (b.brand_name)
join devv5.concept_relationship cc on c.concept_id=concept_id_1
join devv5.concept c2 on c2.concept_id=concept_id_2
where c.concept_class_id= 'Brand Name' and c.invalid_reason is null 
and brand_name not in (select brand_name from aut_bn_mapped_all)
and relationship_id='Has standard brand';