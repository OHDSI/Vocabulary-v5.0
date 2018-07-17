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

insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('CURASPOTAQUA',	43126463, 1	);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('ACARBOSE ARROW LAB',	43126723, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('ACICLOVIR TEVA SANTE',	43126871, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('CEFUROXIME BGR',	43127334	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('AMBROXOL EG LABO CONSEIL',	43127353, 1	);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('AMLODIPINE EVOLUGEN PHARMA',	43127403, 1	);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('AMOROLFINE EG LABO CONSEIL',	43127423	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('AMOXICILLINE/ACIDE CLAVULANIQUE BGR',	43127469, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('AMOXICILLINE/ACIDE CLAVULANIQUE ZENTIVA K',	43127481, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('AMOXICILLINE/ACIDE CLAVULANIQUE ZENTIVA K',	43127482	, 2);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('ATORVASTATINE ARROW GENERIQUES',	43127659,	1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('ATORVASTATINE ARROW GENERIQUES',	43127660,	2);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('PANTOPRAZOLE EG LABO C',	43128061	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('DULOXETINE MYLAN PHARMA',	43128259	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('PERINDOPRIL ARROW LAB',	43128438	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('PERINDOPRIL/INDAPAMIDE ZYDUS FRANCE',	43128462, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('TRAMADOL/PARACETAMOL ARROW LAB',	43128474	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('PRAMIPEXOLE SANDOZ L',	43129071	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('PRAVASTATINE CRISTERS PHARMA',	43129085, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('LOPERAMIDE TEVA CONSEIL',	43129265	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('VENLAFAXINE TEVA SANTE L',	43129480	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('FLECAINIDE ARROW LAB',	43129804	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('METFORMINE ARROW GENERIQUES',	43129882, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('REPAGLINIDE EVOLUGEN',	43129978	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('FORMODUAL NEXTHALER',	43130323	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('FOSINOPRIL/HYDROCHLOROTHIAZIDE ARROW LAB',	43130345, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('FOSINOPRIL/HYDROCHLOROTHIAZIDE BIOGARAN',	43130346	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('GLICLAZIDE ARROW LAB',	43130797	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('OMEPRAZOLE EVOLUGEN PHARMA',	43131691, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('SUPPOSITOIRE A LA GLYCERINE  SOGIPHAR',	43131749, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('SUPPOSITOIRE A LA GLYCERINE CENTRAPHARM', 	43131750, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('SUPPOSITOIRE A LA GLYCERINE  GIFRER',	43131754	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('SUPPOSITOIRE A LA GLYCERINE MAYOLY SPINDLER', 	43131756, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('SUPPOSITOIRES A LA GLYCERINE CENTRAPHARM', 	43131759	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('SUPPOSITOIRES A LA GLYCERINE COOPER', 	43131761	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('SUPPOSITOIRES A LA GLYCERINE EVOLUPHARM', 	43131762, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('SUPPOSITOIRES A LA GLYCERINE MONOT', 	43131763	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('IRBESARTAN BGR',	43132201	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('IRBESARTAN EVOLUGEN',	43132203, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('IRBESARTAN/HYDROCHLOROTHIAZIDE EVOLUGEN PHARMA',	43132220, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('LEVETIRACETAM ZENTIVA LAB',	43571542	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('VORICONAZOLE MYLAN',	44017062	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('IMATINIB MYLAN',	44017899	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('DULOXETINE TEVA SANTE',	44022579, 1);	
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('EFAVIRENZ TEVA',	44022581	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('IMATINIB TEVA',	44022612	, 1);
insert into AUT_BN_MAPPED_ALL (brand_name,concept_id,precedence) values ('VALGANCICLOVIR TEVA',	44022764, 1);	



