--Concept_synonym_stage 
INSERT INTO Concept_synonym_stage 
(SYNONYM_CONCEPT_ID,SYNONYM_NAME,SYNONYM_CONCEPT_CODE,SYNONYM_VOCABULARY_ID,LANGUAGE_CONCEPT_ID)
Select '', CONCEPT_NAME,CONCEPT_CODE, 'BDPM',  '4180190' -- French language 
from INGR_TRANSLATION_ALL
union  
Select '',FORM_ROUTE, CONCEPT_CODE , 'BDPM',  '4180190' from FORM_TRANSLATION ft
join DRUG_CONCEPT_STAGE dcs on ft.TRANSLATION= dcs.concept_name 
union
select '', concept_name, concept_code, 'BDPM', '4180186' from drug_concept_stage where concept_class_id != 'Unit';
