--add COVID and E-cig concepts
insert into concept_synonym_manual (synonym_name,synonym_concept_code,synonym_vocabulary_id,language_concept_id)
select concept_name, concept_code, 'ICD10GM', 4182504 from ddymshyts.sources_icd10gm  where concept_code  in (
'U07.1','U07.2', 'U07.0', 'U99.0'
)
;
insert into concept_manual (vocabulary_id,concept_code,valid_start_date,valid_end_date)
select  'ICD10GM', concept_code, '2019-11-01', '2099-12-31' from ddymshyts.sources_icd10gm  where concept_code  in ( 'U07.0' )
;
insert into concept_manual (vocabulary_id,concept_code,valid_start_date,valid_end_date)
select  'ICD10GM', concept_code, '2020-02-13', '2099-12-31' from ddymshyts.sources_icd10gm  where concept_code  in ( 'U07.1' )
;
insert into concept_manual (vocabulary_id,concept_code,valid_start_date,valid_end_date)
select  'ICD10GM', concept_code, '2020-03-23', '2099-12-31' from ddymshyts.sources_icd10gm  where concept_code  in ( 'U07.2' )
;
insert into concept_manual (vocabulary_id,concept_code,valid_start_date,valid_end_date)
select  'ICD10GM', concept_code, '2020-05-25', '2099-12-31' from ddymshyts.sources_icd10gm  where concept_code  in ( 'U99.0' )
;
UPDATE concept_manual
   SET concept_name = 'Emergency use of U07.0 | Vaping-related disorder'
WHERE concept_code = 'U07.0';
UPDATE concept_manual
   SET concept_name = 'Emergency use of U07.1 | COVID-19, virus identified'
WHERE concept_code = 'U07.1';
UPDATE concept_manual
   SET concept_name = 'Emergency use of U07.2 | COVID-19, virus not identified'
WHERE concept_code = 'U07.2';
UPDATE concept_manual
   SET concept_name = 'Special procedures for testing for SARS-CoV-2'
WHERE concept_code = 'U99.0';
UPDATE concept_manual
   SET concept_class_id = 'ICD10 code'
WHERE concept_code = 'U99.0';

--create output for tranlation
select c.concept_code, synonym_name from concept_synonym_stage s
join concept_stage c on s.synonym_concept_code = c.concept_code
where c.concept_name is null
;
--upload translated version
create table new_concepts_en 
(concept_code varchar, concept_name varchar )
;
--import translations
WbImport -file=C:/work/ICD10GM/new_concepts_en_GT.txt
         -type=text
         -table=new_concepts_en
         -encoding=Cp1251
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -decimal=.
         -fileColumns=concept_code,concept_name
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=1000;

;
--add translations to the concept_manual
insert into concept_manual (concept_name, vocabulary_id,concept_code,concept_class_id)
select concept_name, 'ICD10GM', concept_code ,
CASE 
		WHEN length(concept_code) = 3
			THEN 'ICD10 Hierarchy'
		ELSE 'ICD10 code'
		END AS concept_class_id
from new_concepts_en
;
update 
 concept_manual m
set  concept_name = (select concept_name from concept_stage c where m.concept_code = c.concept_code)
where m.concept_name is null
;
--create file for medical coder which will used for mapping
select  g.concept_code, s.synonym_name as german_name, c.concept_name as english_name from concept_synonym_stage s
join concept_stage g on g.concept_code = s.synonym_concept_code
LEFT JOIN concept c ON c.concept_code = g.concept_code
	AND c.vocabulary_id in ('ICD10', 'ICD10GM');
	
