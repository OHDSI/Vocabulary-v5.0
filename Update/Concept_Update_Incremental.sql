/******************************************************************************************
*
* Expects a concept_stage table to be present from a vocabulary_specific script
* This script processes incremental files
* concept_id or vocabulary_id/concept_code have to exist to identify the concept, in this order of precedence.
* All existing concepts that have no match in concept_stage will be left untouched
* 1a. Existing concept:
* If concept_name, domain_id, concept_class_id, standard_concept, valid_start_date, valid_end_date, invalid_reason have content, they will overwrite the existing concept.
* valid_start_date has to be before today's date. 
* valid_end_date has to be before today's date (deprecation) or 31-Dec-2099 (undeprecation). 
* If invalid_reason is null and valid_end_date is not 31-Dec-2099, it will be set to 'D'.
' If valid_end_date is 31-Dec-2099 invaid_reason is set to null.
* As a result, only invalid_reason='U' survives if the valid_end_date is before 31-Dec-2099 (before today's really).
* 1a. New concept:
* concept_id is ignored and should be null.
* vocabulary_id/concept_code have to exist to create a new concept.
* concept_name, domain_id, concept_class_id, standard_concept have to have content. 
* If valid_start_date is null, 1-Jan-1970 is assumed as default. Otherwise, it has to be before today's date.
* valid_end_date can only be null (assumed 31-Dec-2099) or 31-Dec-2099.
* invalid_reason is ignored and set to null.
*
**********************************************************************************************/


