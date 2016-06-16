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

   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'ETC',
                                          pVocabularyDate        => cNDDFDate,
                                          pVocabularyVersion     => cNDDFVer,
                                          pVocabularyDevSchema   => 'DEV_GCNSEQNO');
END;
COMMIT;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;

--3. Add ETC to concept_stage from RETCTBL0_ETC_ID
INSERT /*+ APPEND */ INTO concept_stage (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
	SELECT  NULL AS concept_id,
		SUBSTR (r.etc_name, 1, 255) AS concept_name,
		'Drug' AS domain_id,
		'ETC' AS vocabulary_id,
		'ETC' AS concept_class_id,
		'C' AS standard_concept,
		r.etc_id AS concept_code,
		(select v.latest_update from vocabulary v where v.vocabulary_id = 'ETC' ) AS valid_start_date,
		CASE r.etc_retired_date WHEN '00000000' THEN TO_DATE ('20991231', 'yyyymmdd') ELSE TO_DATE(r.etc_retired_date,'YYYYMMDD') END AS valid_end_date,
		CASE r.etc_retired_date WHEN '00000000' THEN NULL ELSE 'D' END AS invalid_reason
	FROM RETCTBL0_ETC_ID r;
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
SELECT concept_code_1,
       concept_code_2,
	   'ETC' AS vocabulary_id_1,
       'RxNorm' AS vocabulary_id_2,
       'ETC - RxNorm' AS relationship_id,
       valid_start_date, 
       TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
    FROM (
        SELECT e.etc_id AS concept_code_1,
        rx.concept_code AS concept_code_2,
        MIN(e.etc_effective_date) AS valid_start_date
        FROM concept rx
        JOIN concept_relationship r ON r.concept_id_1 = rx.concept_id AND r.invalid_reason IS NULL AND r.relationship_id = 'Mapped from'
        JOIN concept gc ON gc.concept_id = r.concept_id_2 AND gc.vocabulary_id = 'GCN_SEQNO'
        JOIN RETCGCH0_ETC_GCNSEQNO_HIST e ON e.gcn_seqno = gc.concept_code
        GROUP BY rx.concept_code, e.etc_id
 );
COMMIT;

--5. Hierarchy within ETC
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT r.etc_id AS concept_code_1,
          r.etc_parent_etc_id AS concept_code_2,
          'ETC' AS vocabulary_id_1,
          'ETC' AS vocabulary_id_2,
          'Is a' AS relationship_id,
          (select v.latest_update from vocabulary v where v.vocabulary_id = 'ETC' ) AS valid_start_date,
		CASE r.etc_retired_date WHEN '00000000' THEN TO_DATE ('20991231', 'yyyymmdd') ELSE TO_DATE(r.etc_retired_date,'YYYYMMDD') END AS valid_end_date,
		CASE r.etc_retired_date WHEN '00000000' THEN NULL ELSE 'D' END AS invalid_reason
     FROM RETCTBL0_ETC_ID r;
COMMIT;

--6. From ETC to RxNorm Ingredient using file RETCHCH0_ETC_HICSEQN_HIST
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
SELECT 
       concept_code_1,
       concept_code_2,
       'ETC' AS vocabulary_id_1,	   
       'RxNorm' AS vocabulary_id_2,
       'ETC - RxNorm' AS relationship_id,
       valid_start_date, 
       TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM
(
	SELECT e.etc_id AS concept_code_1,
		 rx.rxaui AS concept_code_2,
		 MIN (e.etc_effective_date) AS valid_start_date
	FROM rxnconso rx
		 JOIN rxnconso i
			ON i.rxcui = rx.rxcui AND i.sab = 'NDDF' AND i.tty = 'IN' -- map to FDB ingredient
		 JOIN retchch0_etc_hicseqn_hist e ON e.hic_seqn = i.code
		 JOIN concept c
			ON c.concept_code = rx.rxaui AND c.vocabulary_id = 'RxNorm'
	WHERE     rx.sab = 'RXNORM'
		 AND rx.tty = 'IN'            -- pick RxNorm Ingredients to start with
		 AND c.concept_class_id <> 'Brand Name'
	GROUP BY rx.rxaui, e.etc_id
);
COMMIT;	

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		