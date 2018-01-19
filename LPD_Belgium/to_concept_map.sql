create table s_to_c_map as
select
	d.prd_id,
	d.prd_name,
	c.*
from source_data d
left join map_drug m on m.from_code = d.prd_id
left join concept c on m.to_id = c.concept_id
union
select 
	d.prd_id,
	d.prd_name,
	null,null,'Device',null,null,null,null,null,null,null
from source_data d
join devices_mapped m on m.prd_name = d.prd_name;

insert into s_to_c_map
select prd_id,prd_name, b.* from lost_ing  a
join concept b on a.concept_id = b.concept_id;

UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077547,       CONCEPT_NAME = 'gabapentin 100 MG Oral Capsule',       DOMAIN_ID = 'Drug',       VOCABULARY_ID = 'RxNorm',       CONCEPT_CLASS_ID = 'Clinical Drug',       STANDARD_CONCEPT = 'S',       CONCEPT_CODE = '310430',       VALID_START_DATE = TO_DATE('1970-01-01','YYYY-MM-DD'),       VALID_END_DATE = TO_DATE('2099-12-31','YYYY-MM-DD') WHERE PRD_ID = '161312';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077547,       CONCEPT_NAME = 'gabapentin 100 MG Oral Capsule',       DOMAIN_ID = 'Drug',       VOCABULARY_ID = 'RxNorm',       CONCEPT_CLASS_ID = 'Clinical Drug',       STANDARD_CONCEPT = 'S',       CONCEPT_CODE = '310430',       VALID_START_DATE = TO_DATE('1970-01-01','YYYY-MM-DD'),       VALID_END_DATE = TO_DATE('2099-12-31','YYYY-MM-DD') WHERE PRD_ID = '161312';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077548,       CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',       DOMAIN_ID = 'Drug',       VOCABULARY_ID = 'RxNorm',       CONCEPT_CLASS_ID = 'Clinical Drug',       STANDARD_CONCEPT = 'S',       CONCEPT_CODE = '310431',       VALID_START_DATE = TO_DATE('1970-01-01','YYYY-MM-DD'),       VALID_END_DATE = TO_DATE('2099-12-31','YYYY-MM-DD') WHERE PRD_ID = '187234';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077548,       CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',       DOMAIN_ID = 'Drug',       VOCABULARY_ID = 'RxNorm',       CONCEPT_CLASS_ID = 'Clinical Drug',       STANDARD_CONCEPT = 'S',       CONCEPT_CODE = '310431',       VALID_START_DATE = TO_DATE('1970-01-01','YYYY-MM-DD'),       VALID_END_DATE = TO_DATE('2099-12-31','YYYY-MM-DD') WHERE PRD_ID = '187234';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077548,       CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',       DOMAIN_ID = 'Drug',       VOCABULARY_ID = 'RxNorm',       CONCEPT_CLASS_ID = 'Clinical Drug',       STANDARD_CONCEPT = 'S',       CONCEPT_CODE = '310431',       VALID_START_DATE = TO_DATE('1970-01-01','YYYY-MM-DD'),       VALID_END_DATE = TO_DATE('2099-12-31','YYYY-MM-DD') WHERE PRD_ID = '161311';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077548,       CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',       DOMAIN_ID = 'Drug',       VOCABULARY_ID = 'RxNorm',       CONCEPT_CLASS_ID = 'Clinical Drug',       STANDARD_CONCEPT = 'S',       CONCEPT_CODE = '310431',       VALID_START_DATE = TO_DATE('1970-01-01','YYYY-MM-DD'),       VALID_END_DATE = TO_DATE('2099-12-31','YYYY-MM-DD') WHERE PRD_ID = '161311';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077549,       CONCEPT_NAME = 'gabapentin 400 MG Oral Capsule',       DOMAIN_ID = 'Drug',       VOCABULARY_ID = 'RxNorm',       CONCEPT_CLASS_ID = 'Clinical Drug',       STANDARD_CONCEPT = 'S',       CONCEPT_CODE = '310432',       VALID_START_DATE = TO_DATE('1970-01-01','YYYY-MM-DD'),       VALID_END_DATE = TO_DATE('2099-12-31','YYYY-MM-DD') WHERE PRD_ID = '187233';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077549,       CONCEPT_NAME = 'gabapentin 400 MG Oral Capsule',       DOMAIN_ID = 'Drug',       VOCABULARY_ID = 'RxNorm',       CONCEPT_CLASS_ID = 'Clinical Drug',       STANDARD_CONCEPT = 'S',       CONCEPT_CODE = '310432',       VALID_START_DATE = TO_DATE('1970-01-01','YYYY-MM-DD'),       VALID_END_DATE = TO_DATE('2099-12-31','YYYY-MM-DD') WHERE PRD_ID = '187233';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077549,       CONCEPT_NAME = 'gabapentin 400 MG Oral Capsule',       DOMAIN_ID = 'Drug',       VOCABULARY_ID = 'RxNorm',       CONCEPT_CLASS_ID = 'Clinical Drug',       STANDARD_CONCEPT = 'S',       CONCEPT_CODE = '310432',       VALID_START_DATE = TO_DATE('1970-01-01','YYYY-MM-DD'),       VALID_END_DATE = TO_DATE('2099-12-31','YYYY-MM-DD') WHERE PRD_ID = '161310';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077549,       CONCEPT_NAME = 'gabapentin 400 MG Oral Capsule',       DOMAIN_ID = 'Drug',       VOCABULARY_ID = 'RxNorm',       CONCEPT_CLASS_ID = 'Clinical Drug',       STANDARD_CONCEPT = 'S',       CONCEPT_CODE = '310432',       VALID_START_DATE = TO_DATE('1970-01-01','YYYY-MM-DD'),       VALID_END_DATE = TO_DATE('2099-12-31','YYYY-MM-DD') WHERE PRD_ID = '161310';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077548,       CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',       CONCEPT_CLASS_ID = 'Clinical Drug',       CONCEPT_CODE = '310431' WHERE PRD_ID = '159210';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077548,       CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',       CONCEPT_CLASS_ID = 'Clinical Drug',       CONCEPT_CODE = '310431' WHERE PRD_ID = '160281';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077548,       CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',       CONCEPT_CLASS_ID = 'Clinical Drug',       CONCEPT_CODE = '310431' WHERE PRD_ID = '160280';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077549,       CONCEPT_NAME = 'gabapentin 400 MG Oral Capsule',       CONCEPT_CODE = '310432' WHERE PRD_ID = '159209';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077549,       CONCEPT_NAME = 'gabapentin 400 MG Oral Capsule',       CONCEPT_CODE = '310432' WHERE PRD_ID = '160283';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077547,       CONCEPT_NAME = 'gabapentin 100 MG Oral Capsule',       CONCEPT_CLASS_ID = 'Clinical Drug',       CONCEPT_CODE = '310430' WHERE PRD_ID = '197610';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077548,       CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',       CONCEPT_CLASS_ID = 'Clinical Drug',       CONCEPT_CODE = '310431' WHERE PRD_ID = '197611';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 19077549,       CONCEPT_NAME = 'gabapentin 400 MG Oral Capsule',       CONCEPT_CODE = '310432' WHERE PRD_ID = '197668';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 44042852,       CONCEPT_NAME = 'iodoform Topical Solution',       CONCEPT_CODE = 'OMOP1037483' WHERE PRD_ID = '96921';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 44042852,       CONCEPT_NAME = 'iodoform Topical Solution',       CONCEPT_CODE = 'OMOP1037483' WHERE PRD_ID = '96922';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 40148731,       CONCEPT_NAME = 'Rubella Virus Vaccine Live (Wistar RA 27-3 Strain) Injectable Solution',       VOCABULARY_ID = 'RxNorm',       CONCEPT_CODE = '762819' where PRD_ID = '5274';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 40213184,       CONCEPT_NAME = 'measles, mumps, rubella, and varicella virus vaccine',       VOCABULARY_ID = 'CVX',       CONCEPT_CLASS_ID = 'CVX',       CONCEPT_CODE = '94' where PRD_ID = '80231';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 40213184,       CONCEPT_NAME = 'measles, mumps, rubella, and varicella virus vaccine',       VOCABULARY_ID = 'CVX',       CONCEPT_CLASS_ID = 'CVX',       CONCEPT_CODE = '94' where PRD_ID = '188123';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 40213198,       CONCEPT_NAME = 'pneumococcal conjugate vaccine, 13 valent',       VOCABULARY_ID = 'CVX',       CONCEPT_CLASS_ID = 'CVX',       CONCEPT_CODE = '133' where PRD_ID = '109054';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 40213198,       CONCEPT_NAME = 'pneumococcal conjugate vaccine, 13 valent',       VOCABULARY_ID = 'CVX',       CONCEPT_CLASS_ID = 'CVX',       CONCEPT_CODE = '133' where PRD_ID = '2102285';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 40213198,       CONCEPT_NAME = 'pneumococcal conjugate vaccine, 13 valent',       VOCABULARY_ID = 'CVX',       CONCEPT_CLASS_ID = 'CVX',       CONCEPT_CODE = '133' where PRD_ID = '61987';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 40213198,       CONCEPT_NAME = 'pneumococcal conjugate vaccine, 13 valent',       VOCABULARY_ID = 'CVX',       CONCEPT_CLASS_ID = 'CVX',       CONCEPT_CODE = '133' where PRD_ID = '98764';
UPDATE S_TO_C_MAP   SET CONCEPT_ID = 46275090,       CONCEPT_NAME = 'Bordetella pertussis filamentous hemagglutinin vaccine, inactivated 0.05 MG/ML / Bordetella pertussis pertactin vaccine, inactivated 0.016 MG/ML / Bordetella pertussis toxoid vaccine, inactivated 0.05 MG/ML / diphtheria toxoid vaccine, inactivated 50 UNT/ML / tetanus toxoid vaccine, inactivated 20 UNT/ML Injection [Infanrix]',       CONCEPT_CLASS_ID = ' Branded Drug',       CONCEPT_CODE = '1657881' where PRD_ID = '109727';


update s_to_c_map
set 
CONCEPT_ID = 19015636,
CONCEPT_NAME ='Bryonia preparation',
DOMAIN_ID = 'Drug',
VOCABULARY_ID = 'RxNorm',
CONCEPT_CLASS_ID = 'Ingredient',
STANDARD_CONCEPT = 'S',
CONCEPT_CODE = '319815',
VALID_START_DATE = to_date ('19700101','yyyymmdd'),
VALID_END_DATE = to_date ('20991231','yyyymmdd')
where PRD_NAME like '%BRYONIA%' and concept_id is null;

update s_to_c_map
set 
CONCEPT_ID = 36878960,
CONCEPT_NAME ='Acerola',
DOMAIN_ID = 'Drug',
VOCABULARY_ID = 'RxNorm Extension',
CONCEPT_CLASS_ID = 'Ingredient',
STANDARD_CONCEPT = 'S',
CONCEPT_CODE = 'OMOP992630',
VALID_START_DATE = to_date ('19700101','yyyymmdd'),
VALID_END_DATE = to_date ('20991231','yyyymmdd')
where PRD_NAME like 'ACEROLA%' and concept_id is null;


update s_to_c_map
set 
CONCEPT_ID = 46276344,
CONCEPT_NAME ='Citrullus colocynthis whole extract',
DOMAIN_ID = 'Drug',
VOCABULARY_ID = 'RxNorm',
CONCEPT_CLASS_ID = 'Ingredient',
STANDARD_CONCEPT = 'S',
CONCEPT_CODE = '1663393',
VALID_START_DATE = to_date ('19700101','yyyymmdd'),
VALID_END_DATE = to_date ('20991231','yyyymmdd')
where PRD_NAME like '%COLOCYNTHIS%' and concept_id is null;


update s_to_c_map
set 
CONCEPT_ID = 19071833,
CONCEPT_NAME ='Arnica montana Extract',
DOMAIN_ID = 'Drug',
VOCABULARY_ID = 'RxNorm',
CONCEPT_CLASS_ID = 'Ingredient',
STANDARD_CONCEPT = 'S',
CONCEPT_CODE = '285208',
VALID_START_DATE = to_date ('19700101','yyyymmdd'),
VALID_END_DATE = to_date ('20991231','yyyymmdd')
where PRD_NAME like 'ARNICA%' and concept_id is null;

update s_to_c_map
set 
CONCEPT_ID = 19071836,
CONCEPT_NAME ='Calendula officinalis extract',
DOMAIN_ID = 'Drug',
VOCABULARY_ID = 'RxNorm',
CONCEPT_CLASS_ID = 'Ingredient',
STANDARD_CONCEPT = 'S',
CONCEPT_CODE = '285222',
VALID_START_DATE = to_date ('19700101','yyyymmdd'),
VALID_END_DATE = to_date ('20991231','yyyymmdd')
where PRD_NAME like '%CALENDULA%' and concept_id is null;

update s_to_c_map
set 
CONCEPT_ID = 19070926,
CONCEPT_NAME ='Drosera rotundifolia extract',
DOMAIN_ID = 'Drug',
VOCABULARY_ID = 'RxNorm',
CONCEPT_CLASS_ID = 'Ingredient',
STANDARD_CONCEPT = 'S',
CONCEPT_CODE = '283557',
VALID_START_DATE = to_date ('19700101','yyyymmdd'),
VALID_END_DATE = to_date ('20991231','yyyymmdd')
where PRD_NAME like '%DROSERA%' and concept_id is null;

update s_to_c_map
set 
CONCEPT_ID = 42904014,
CONCEPT_NAME ='Solanum dulcamara top extract',
DOMAIN_ID = 'Drug',
VOCABULARY_ID = 'RxNorm',
CONCEPT_CLASS_ID = 'Ingredient',
STANDARD_CONCEPT = 'S',
CONCEPT_CODE = '1331702',
VALID_START_DATE = to_date ('19700101','yyyymmdd'),
VALID_END_DATE = to_date ('20991231','yyyymmdd')
where PRD_NAME like '%DULCAMARA%' and concept_id is null;

update s_to_c_map
set 
CONCEPT_ID = 19014026,
CONCEPT_NAME ='Nux Vomica extract',
DOMAIN_ID = 'Drug',
VOCABULARY_ID = 'RxNorm',
CONCEPT_CLASS_ID = 'Ingredient',
STANDARD_CONCEPT = 'S',
CONCEPT_CODE = '314743',
VALID_START_DATE = to_date ('19700101','yyyymmdd'),
VALID_END_DATE = to_date ('20991231','yyyymmdd')
where PRD_NAME like '%NUX VOMICA%' and concept_id is null;

create table lost_ing as
select distinct b.prd_id, b.prd_name from s_to_c_map a
join s_to_c_map b on regexp_substr(a.PRD_NAME,'\w+')= regexp_substr(b.PRD_NAME,'\w+')
where a.domain_id='Drug'
and  b.domain_id is null
;
delete lost_ing
where regexp_like (prd_name,'ELUSAN|DUCRAY|BRYONIA|NUX VOMICA|ALENCO|ACEROLA|COLOCYNTHIS|ALTISA|GAMMADYN|DULCAMARA|LEHNING|ANTI |AESCULUS|LRP |MPH |NOVIDERM|OMEGA|OMNIBIONTA|PHYSIOLOGICA|COMPOSOR|AQUA|ACIDE |BAUME|BIO |MERCURIUS|MOREPA|VITAFYTEA|VOGEL|WIDMER|GLYCERINE|NATRUM|PURE |SENSODYNE|SORIA|STELLA|VANOCOMPLEX|TESTIS|TENA|GILBERT|SORICAPSULE');


delete from s_to_c_map where prd_id in (select prd_id from gripp);
insert into s_to_c_map
select prd_id, prd_name, c.* 
from gripp g
join concept c on c.concept_id = g.concept_id

--delete all unnecessary concepts
truncate table concept_relationship_stage;
truncate table pack_content_stage;
truncate table drug_strength_stage;

insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select prd_id, m.concept_code, dc.vocabulary_id, m.vocabulary_id, 'Maps to',sysdate,to_date ('20991231', 'yyyymmdd')  
from s_to_c_map m
join drug_concept_stage dc on dc.concept_code = m.prd_id where concept_id is not null
union
select concept_code, concept_code, vocabulary_id, vocabulary_id, 'Maps to', sysdate,to_date ('20991231', 'yyyymmdd')  
from drug_concept_stage where domain_id = 'Device'
;

delete concept_stage 
where concept_code like 'OMOP%' --save devices and unmapped drug
;

delete concept_stage 
where concept_class_id in ('Dose Form','Brand Name','Supplier','Ingredient') --save devices and unmapped drug
;

update concept_stage 
set standard_concept = null 
where concept_code in (select a.concept_code  
                       from concept_stage a
                            left join concept_relationship_stage on concept_code_1 = a.concept_code 
                            and vocabulary_id_1 = a.vocabulary_id
                            left join concept c on c.concept_code = concept_code_2 
                            and c.vocabulary_id = vocabulary_id_2 
                       where a.standard_concept ='S' and c.concept_id is null);
                       
update concept_stage
set 
standard_concept = 'S'
where concept_class_id = 'Device';