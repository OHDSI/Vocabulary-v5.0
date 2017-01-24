/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov, Christian Reich
* Date: 2016
**************************************************************************/

--1 Update latest_update field to new date 
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'RxNorm Extension',
                                          pVocabularyDate        => TRUNC(SYSDATE),
                                          pVocabularyVersion     => 'RxNorm Extension '||SYSDATE,
                                          pVocabularyDevSchema   => 'DEV_RXE');									  
END;
COMMIT;

--2 Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3 Load full list of RxNorm Extension concepts
INSERT /*+ APPEND */ INTO  CONCEPT_STAGE (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT concept_name,
          domain_id,
          vocabulary_id,
          concept_class_id,
          standard_concept,
          concept_code,
          valid_start_date,
          valid_end_date,
          invalid_reason
     FROM concept
    WHERE vocabulary_id = 'RxNorm Extension';			   
COMMIT;


--4 Load full list of RxNorm Extension relationships
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT c1.concept_code,
          c2.concept_code,
          c1.vocabulary_id,
          c2.vocabulary_id,
          r.relationship_id,
          r.valid_start_date,
          r.valid_end_date,
          r.invalid_reason
     FROM concept c1, concept c2, concept_relationship r
    WHERE c1.concept_id = r.concept_id_1 AND c2.concept_id = r.concept_id_2 AND 'RxNorm Extension' IN (c1.vocabulary_id, c2.vocabulary_id);
COMMIT;


--5 Load full list of RxNorm Extension drug strength
INSERT /*+ APPEND */
      INTO  drug_strength_stage (drug_concept_code,
                                 vocabulary_id_1,
                                 ingredient_concept_code,
                                 vocabulary_id_2,
                                 amount_value,
                                 amount_unit_concept_id,
                                 numerator_value,
                                 numerator_unit_concept_id,
                                 denominator_value,
                                 denominator_unit_concept_id,
                                 valid_start_date,
                                 valid_end_date,
                                 invalid_reason)
   SELECT c.concept_code,
          c.vocabulary_id,
          c2.concept_code,
          c2.vocabulary_id,
          amount_value,
          amount_unit_concept_id,
          numerator_value,
          numerator_unit_concept_id,
          denominator_value,
          denominator_unit_concept_id,
          ds.valid_start_date,
          ds.valid_end_date,
          ds.invalid_reason
     FROM concept c
          JOIN drug_strength ds ON ds.DRUG_CONCEPT_ID = c.CONCEPT_ID
          JOIN concept c2 ON ds.INGREDIENT_CONCEPT_ID = c2.CONCEPT_ID
    WHERE c.vocabulary_id IN ('RxNorm', 'RxNorm Extension');
COMMIT;

--6 Load full list of RxNorm Extension pack content
INSERT /*+ APPEND */
      INTO  pack_content_stage (pack_concept_code,
                                pack_vocabulary_id,
                                drug_concept_code,
                                drug_vocabulary_id,
                                amount,
                                box_size)
   SELECT c.concept_code,
          c.vocabulary_id,
          c2.concept_code,
          c2.vocabulary_id,
          amount,
          box_size
     FROM pack_content pc
          JOIN concept c ON pc.PACK_CONCEPT_ID = c.CONCEPT_ID
          JOIN concept c2 ON pc.DRUG_CONCEPT_ID = c2.CONCEPT_ID;
COMMIT;		  

--7
/*
Main work HERE
For 'RxNorm Extension' we should directly deprecate concepts and relationships
*/

--8 Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
COMMIT;

--9 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;

--10 Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;

--11 Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script