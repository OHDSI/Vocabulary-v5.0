DELETE
FROM RELATIONSHIP_TO_CONCEPT
WHERE CONCEPT_CODE_1 = '33386-4'
AND   CONCEPT_ID_2 = 1326378
AND   PRECEDENCE = 2;
DELETE
FROM RELATIONSHIP_TO_CONCEPT
WHERE CONCEPT_CODE_1 = '00758-2'
AND   CONCEPT_ID_2 = 975125
AND   PRECEDENCE = 2;
;
update drug_concept_stage 
set concept_class_id  = 'Drug Product' where concept_class_id like 'Drug%'
;
update drug_concept_stage 
set concept_class_id  = 'Supplier' where concept_class_id like 'Manufacturer'
;
commit
;
update drug_concept_stage
set standard_concept = null where concept_code in ( 
select a.concept_code_1 from internal_relationship_Stage a 
join drug_concept_stage b on a.concept_code_1 = b.concept_code 
join drug_concept_stage c on a.concept_code_2 = c.concept_code
where c.concept_class_id = 'Ingredient' and b.concept_class_id ='Ingredient')
;
update drug_concept_stage
set standard_concept = null where concept_class_id like 'Drug%'
;
commit
;
alter table drug_concept_stage add source_concept_class_id (varchar (20)
;
declare
 ex number;
begin
select max(iex)+1 into ex from (  
    select cast(substr(concept_code, 5) as integer) as iex from concept where concept_code like 'OMOP%' and concept_code not like '% %' -- Last valid value of the OMOP123-type codes
);
  begin
    execute immediate 'create sequence new_vocab increment by 1 start with ' || ex || ' nocycle cache 20 noorder';
    exception
      when others then null;
  end;
end;
-- change to procedure in the future
--drop table code_replace;
 create table code_replace as 
 select 'OMOP'||new_vocab.nextval as new_code, concept_code as old_code from (
select distinct  concept_code from drug_concept_stage where concept_code like 'OMOP%' order by (cast ( regexp_substr( concept_code, '\d+') as int))
)
;
update drug_concept_stage a set concept_code = (select new_code from code_replace b where a.concept_code = b.old_code) 
where a.concept_code like 'OMOP%'
;--select * from code_replace where old_code ='OMOP28663';
commit
;
update relationship_to_concept a  set concept_code_1 = (select new_code from code_replace b where a.concept_code_1 = b.old_code)
where a.concept_code_1 like 'OMOP%'
;commit
;
update ds_stage a  set ingredient_concept_code = (select new_code from code_replace b where a.ingredient_concept_code = b.old_code)
where a.ingredient_concept_code like 'OMOP%'
;
commit
;
update ds_stage a  set drug_concept_code = (select new_code from code_replace b where a.drug_concept_code = b.old_code)
where a.drug_concept_code like 'OMOP%'
;commit
;
update internal_relationship_stage a  set concept_code_1 = (select new_code from code_replace b where a.concept_code_1 = b.old_code)
where a.concept_code_1 like 'OMOP%'
;commit
;
update internal_relationship_stage a  set concept_code_2 = (select new_code from code_replace b where a.concept_code_2 = b.old_code)
where a.concept_code_2 like 'OMOP%'
;
commit
;
update pc_stage a  set DRUG_CONCEPT_CODE = (select new_code from code_replace b where a.DRUG_CONCEPT_CODE = b.old_code)
where a.DRUG_CONCEPT_CODE like 'OMOP%'
;
commit;

DELETE
FROM RELATIONSHIP_TO_CONCEPT
WHERE CONCEPT_CODE_1 = 'microg'
AND   CONCEPT_ID_2 = 9655
AND   PRECEDENCE = 1;
DELETE
FROM RELATIONSHIP_TO_CONCEPT
WHERE CONCEPT_CODE_1 = 'microl'
AND   CONCEPT_ID_2 = 9665
AND   PRECEDENCE = 2;
DELETE
FROM RELATIONSHIP_TO_CONCEPT
WHERE CONCEPT_CODE_1 = 'micromol'
AND   CONCEPT_ID_2 = 9667
AND   PRECEDENCE = 2;
UPDATE RELATIONSHIP_TO_CONCEPT
   SET PRECEDENCE = 1
WHERE CONCEPT_CODE_1 = 'M'
AND   CONCEPT_ID_2 = 8510
AND   PRECEDENCE = 2;
UPDATE RELATIONSHIP_TO_CONCEPT
   SET PRECEDENCE = 1
WHERE CONCEPT_CODE_1 = 'microg'
AND   CONCEPT_ID_2 = 8576
AND   PRECEDENCE = 2;
UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONVERSION_FACTOR = 1000000
WHERE CONCEPT_CODE_1 = 'million cells'
AND   CONCEPT_ID_2 = 45744812
AND   PRECEDENCE = 1;
UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 8576,
       CONVERSION_FACTOR = 0.000001
WHERE CONCEPT_CODE_1 = 'ng'
AND   CONCEPT_ID_2 = 9600
AND   PRECEDENCE = 1;
UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 8576,
       CONVERSION_FACTOR = 1E-9
WHERE CONCEPT_CODE_1 = 'pg'
AND   CONCEPT_ID_2 = 8564
AND   PRECEDENCE = 1;



UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 45744812
WHERE CONCEPT_CODE_1 = 'megmo';

commit
;


BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'AMIS',
                                          pVocabularyDate        => TO_DATE ('20161029', 'yyyymmdd'),
                                          pVocabularyVersion     => 'AMIS 20161029',
                                          pVocabularyDevSchema   => 'DEV_amis');
                                          


                                        
                                          
  DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'RxNorm Extension',
                                          pVocabularyDate        => TO_DATE ('20161029', 'yyyymmdd'),
                                          pVocabularyVersion     => 'RxNorm Extension 20161029',
                                          pVocabularyDevSchema   => 'DEV_amis',
                                          pAppendVocabulary      => TRUE);

END;

COMMIT;


