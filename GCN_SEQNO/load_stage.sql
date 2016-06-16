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

-- 1. Update latest_update field to new date 
DECLARE
   cNDDFDate   DATE;
   cNDDFVer    VARCHAR2 (100);
BEGIN
   SELECT TO_DATE (NDDF_VERSION, 'YYYYMMDD'), NDDF_VERSION || ' Release'
     INTO cNDDFDate, cNDDFVer
     FROM NDDF_PRODUCT_INFO;

   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'GCN_SEQNO',
                                          pVocabularyDate        => cNDDFDate,
                                          pVocabularyVersion     => cNDDFVer,
                                          pVocabularyDevSchema   => 'DEV_GCNSEQNO');
END;
COMMIT;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;

--3. Add GCN_SEQNO to concept_stage from rxnconso
INSERT /*+ APPEND */ INTO  concept_stage (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT SUBSTR (c.str, 1, 255) AS concept_name,
          'Drug' AS domain_id,
          'GCN_SEQNO' AS vocabulary_id,
          'GCN_SEQNO' AS concept_class_id,
          NULL AS standard_concept,
          c.code AS concept_code,
		 (select v.latest_update from vocabulary v where v.vocabulary_id = 'GCN_SEQNO' ) AS valid_start_date,
		 TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM rxnconso c
    WHERE c.sab = 'NDDF' AND c.tty = 'CDC';
COMMIT;

--4. Load into concept_relationship_stage
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT gcn.code AS concept_code_1,
                   rxn.code AS concept_code_2,
                   'GCN_SEQNO' AS vocabulary_id_1,
                   'RxNorm' AS vocabulary_id_2,
                   'Maps to' AS relationship_id,
				   (select v.latest_update from vocabulary v where v.vocabulary_id = 'GCN_SEQNO') AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM rxnconso gcn
          JOIN rxnconso rxn ON rxn.rxcui = gcn.rxcui AND rxn.sab = 'RXNORM'
    WHERE gcn.sab = 'NDDF' AND gcn.tty = 'CDC';
COMMIT;	 


--5. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;	

--6. Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;		 

--7. Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		