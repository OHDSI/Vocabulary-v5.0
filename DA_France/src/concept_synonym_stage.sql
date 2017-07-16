insert into concept_synonym_stage
(SYNONYM_NAME,SYNONYM_CONCEPT_CODE,SYNONYM_VOCABULARY_ID,LANGUAGE_CONCEPT_ID)
select dose_form,concept_code,'Da_France','4180190' -- French language 
from 
france_names_translation a join drug_concept_stage
on trim(upper(DOSE_FORM_NAME))=upper(concept_name);




