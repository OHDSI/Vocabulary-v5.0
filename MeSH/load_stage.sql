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
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'MeSH',
                                          pVocabularyDate        => TO_DATE ('20160509', 'yyyymmdd'),
                                          pVocabularyVersion     => '2016 Release',
                                          pVocabularyDevSchema   => 'DEV_MESH');
END;
COMMIT;

--2 Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;

--3 Load into concept_stage.
-- Build Main Heading (Descriptors)
INSERT /*+ APPEND */ INTO CONCEPT_STAGE (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
	select distinct 
		null as concept_id,
		mh.str as concept_name,
		-- Pick the domain from existing mapping in UMLS with the following order of predence:
		first_value(c.domain_id) over (partition by mh.code order by decode(c.vocabulary_id, 'RxNorm', 1, 'SNOMED', 2, 'LOINC', 3, 'CPT4', 4, 9)) as domain_id,
		'MeSH' as vocabulary_id,
		'Main Heading' as concept_class_id,
		null as standard_concept,
		mh.code as concept_code,
		(select latest_update from vocabulary where vocabulary_id='MeSH') as valid_start_date,
		TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
		null as invalid_reason 
	from umls.mrconso mh
	-- join to umls cpt4, hcpcs and rxnorm concepts
	join umls.mrconso m on mh.cui=m.cui and m.sab in ('CPT', 'HCPCS', 'HCPT', 'RXNORM', 'SNOMEDCT_US') and m.suppress='N' and m.tty<>'SY'
	join concept c on c.concept_code=m.code and c.standard_concept = 'S' and c.vocabulary_id=decode(m.sab, 'CPT', 'CPT4', 'HCPT', 'CPT4', 'RXNORM', 'RxNorm', 'SNOMEDCT_US', 'SNOMED', 'LNC', 'LOINC', m.sab) and domain_id in ('Condition', 'Procedure', 'Drug', 'Measurement')
	where mh.suppress='N'
	and mh.sab='MSH' 
	and mh.lat='ENG' 
	and mh.tty='MH';
COMMIT;	

-- Build Supplementary Concepts
INSERT /*+ APPEND */ INTO CONCEPT_STAGE (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
	select distinct 
		null as concept_id,
		mh.str as concept_name,
		-- Pick the domain from existing mapping in UMLS with the following order of predence:
		first_value(c.domain_id) over (partition by mh.code order by decode(c.vocabulary_id, 'RxNorm', 1, 'SNOMED', 2, 'LOINC', 3, 'CPT4', 4, 9)) as domain_id,
		'MeSH' as vocabulary_id,
		'Suppl Concept' as concept_class_id,
		null as standard_concept,
		mh.code as concept_code,
		(select latest_update from vocabulary where vocabulary_id='MeSH') as valid_start_date,
		TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
		null as invalid_reason 
	from umls.mrconso mh
	-- join to umls cpt4, hcpcs and rxnorm concepts
	join umls.mrconso m on mh.cui=m.cui and m.sab in ('CPT', 'HCPCS', 'HCPT', 'RXNORM', 'SNOMEDCT_US') and m.suppress='N' and m.tty<>'SY'
	join concept c on c.concept_code=m.code and c.standard_concept = 'S' and c.vocabulary_id=decode(m.sab, 'CPT', 'CPT4', 'HCPT', 'CPT4', 'RXNORM', 'RxNorm', 'SNOMEDCT_US', 'SNOMED', 'LNC', 'LOINC', m.sab) and domain_id in ('Condition', 'Procedure', 'Drug', 'Measurement')
	where mh.suppress='N'
	and mh.sab='MSH' 
	and mh.lat='ENG' 
	and mh.tty='NM';
COMMIT;	

--4 Create concept_relationship_stage
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
	select distinct 
		mh.code as concept_code_1,
		-- Pick existing mapping from UMLS with the following order of predence:
		first_value(c.concept_code) over (partition by mh.code order by decode(c.vocabulary_id, 'RxNorm', 1, 'SNOMED', 2, 'LOINC', 3, 'CPT4', 4, 9)) as concept_code_2,
		'MeSH' as vocabulary_id_1,  
		first_value(c.vocabulary_id) over (partition by mh.code order by decode(c.vocabulary_id, 'RxNorm', 1, 'SNOMED', 2, 'LOINC', 3, 'CPT4', 4, 9)) as vocabulary_id_2,
		'Maps to' as relationship_id,
		TO_DATE ('19700101', 'yyyymmdd') as valid_start_date,
		TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
		null as invalid_reason   
	from umls.mrconso mh
	-- join to umls cpt4, hcpcs and rxnorm concepts
	join umls.mrconso m on mh.cui=m.cui and m.sab in ('CPT', 'HCPCS', 'HCPT', 'RXNORM', 'SNOMEDCT_US') and m.suppress='N' and m.tty<>'SY'
	join concept c on c.concept_code=m.code and c.standard_concept = 'S' and c.vocabulary_id=decode(m.sab, 'CPT', 'CPT4', 'HCPT', 'CPT4', 'RXNORM', 'RxNorm', 'SNOMEDCT_US', 'SNOMED', 'LNC', 'LOINC', m.sab) and domain_id in ('Condition', 'Procedure', 'Drug', 'Measurement')
	where mh.suppress='N'
	and mh.sab='MSH' 
	and mh.lat='ENG' 
	and mh.tty in ('NM', 'MH');
COMMIT;	 

--5 Add synonyms
INSERT /*+ APPEND */ INTO  concept_synonym_stage (synonym_concept_code,
                                   synonym_vocabulary_id,
                                   synonym_name,
                                   language_concept_id)
                                  
	select c.concept_code as synonym_concept_code,
		'MeSH' as synonym_vocabulary_id,
		 u.str as synonym_name, 
		4180186 AS language_concept_id                    -- English 
	from concept_stage c
	join umls.mrconso u on u.code=c.concept_code and u.sab = 'MSH' and u.suppress = 'N' and u.lat='ENG'
	group by c.concept_code, u.str;
COMMIT;

--6 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;	

--7 Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;		 

--8 Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		