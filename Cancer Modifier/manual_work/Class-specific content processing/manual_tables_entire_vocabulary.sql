--In order to 1) simp;ify load stage structure and 2) provide parallel Cancer Modifier class-based development all the manual tables should be backuped as appropriate tables with obviuos potfixes
--The every actual update of Vocabulary should Use only _manual tables

--CONCEPT MANUAL ENTIRE VOCABULARY (1st iteration)
CREATE TABLE concept_manual_entire_vocabulary as
 SELECT distinct
                 concept_name,
                 domain_id,
                 vocabulary_id,
                 concept_class_id,
                 standard_concept,
                 concept_code,
                 valid_start_date,
                 valid_end_date,
                 invalid_reason
 FROM concept_manual
;
TRUNCATE concept_manual;
--CONCEPT RELATIONSHIP MANUAL ENTIRE VOCABULARY (1st iteration)
CREATE TABLE concept_relationship_manual_entire_vocabulary as
 SELECT distinct
                 concept_code_1,
                 concept_code_2,
                 vocabulary_id_1,
                 vocabulary_id_2,
                 relationship_id,
                 valid_start_date,
                 valid_end_date,
                 invalid_reason
 FROM concept_relationship_manual
;
TRUNCATE concept_relationship_manual;

--CONCEPT SYNONYM MANUAL ENTIRE VOCABULARY (1st iteration)
CREATE TABLE concept_synonym_manual_entire_vocabulary as
 SELECT distinct
                 synonym_name,
                 synonym_concept_code,
                 synonym_vocabulary_id,
                 language_concept_id
 FROM concept_synonym_manual
;

TRUNCATE concept_synonym_manual;