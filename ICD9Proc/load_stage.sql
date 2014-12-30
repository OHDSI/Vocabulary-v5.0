/*
1. Download from ICD-9-CM-vXX-master-descriptions.zip from http://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/codes.html (already done for ICD9CM)
2. Extract CMSXX_DESC_LONG_SG.txt and CMSXX_DESC_SHORT_SG.txt.
DDL & ctl -> Vocabulary-v5.0\ICD9Proc\

-- Update latest_update field to new date 
update vocabulary set latest_update=to_date('YYYYMMDD','yyyymmdd') where vocabulary_id='ICD9Proc'; commit;
*/

--3. Load into concept_stage from CMS_DESC_LONG_SG
INSERT INTO concept_stage (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT NULL AS concept_id,
          NAME AS concept_name,
          'Procedure' AS domain_id,
          'ICD9Proc' AS vocabulary_id,
          'Procedure' AS concept_class_id,
          'S' AS standard_concept,
          REGEXP_REPLACE (code, '^([0-9]{3})([0-9]+)', '\1.\2')
             AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'ICD9Proc')
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM CMS_DESC_LONG_SG;
COMMIT;					  

--4 load into concept_synonym_stage name from both CMS_DESC_LONG_DX.txt and CMS_DESC_SHORT_DX
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   language_concept_id)
   (SELECT NULL AS synonym_concept_id,
           REGEXP_REPLACE (code, '^([0-9]{3})([0-9]+)', '\1.\2')
              AS synonym_concept_code,
           NAME AS synonym_name,
           4093769 AS language_concept_id                           -- English
      FROM (SELECT * FROM CMS_DESC_LONG_SG
            UNION
            SELECT * FROM CMS_DESC_SHORT_SG));
COMMIT;

--5   Load concept_relationship_stage from the existing one. The reason is that there is no good source for these relationships, and we have to build the ones for new codes from UMLS and manually
INSERT INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT NULL AS concept_id_1,
          NULL AS concept_id_2,
          c.concept_code AS concept_code_1,
          c1.concept_code AS concept_code_2,
          r.relationship_id AS relationship_id,
          c.vocabulary_id AS vocabulary_id_1,
          c1.vocabulary_id AS vocabulary_id_2,
          r.valid_start_date,
          r.valid_end_date,
          r.invalid_reason
     FROM concept_relationship r, concept c, concept c1
    WHERE     c.concept_id = r.concept_id_1
          AND c.vocabulary_id = 'ICD9Proc'
          AND C1.CONCEPT_ID = r.concept_id_2;
COMMIT;		  

--6 create new codes and mappings according to UMLS	   
--N------ run Vocabulary-v5.0\generic_update.sql ---------------			