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
* Authors: Varvara Savitskaya
* Date: 2022
**************************************************************************/

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'OncoKB',
	pVocabularyDate			=> TO_DATE('20210502','YYYYMMDD'),
	pVocabularyVersion		=> 'OncoKB v20210502',
	pVocabularyDevSchema	=> 'dev_oncokb',
	pAppendVocabulary		=> FALSE
);
END $_$;


truncate concept_stage;
truncate concept_relationship_stage;
truncate concept_synonym_stage;


create table oncokb_source as (
select hugo_symbol||':'||variant as concept_name, 'OncoKB' as vocabulary_id, hugo_symbol||':'||variant as concept_code, hugo_symbol||':p.'||variant as hgvs
from sources.genomic_oncokb);


-- put source variants into concept stage
insert into concept_stage
SELECT DISTINCT NULL::INT,
       trim(substr(concept_name,1,255)) AS concept_name,
       'Measurement' AS domain_id,
       vocabulary_id AS vocabulary_id,
       'Variant' AS concept_class_id,
       NULL AS standard_concept,
       trim(substr(concept_code, 1, 50)) AS concept_code,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM oncokb_source
;


insert into concept_relationship_stage
select DISTINCT NULL::INTEGER AS concept_id_1,
       NULL::INTEGER AS concept_id_2,
       cs.concept_code AS concept_code_1,
       cc.concept_code AS concept_code_2,
       'OncoKB' AS vocabulary_id_1,
       'OMOP Genomic' AS vocabulary_id_2,
       'Maps to' AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
from concept_stage cs
join devv5.concept s on cs.concept_code = s.concept_code
join devv5.concept_relationship dcs on dcs.concept_id_1 = s.concept_id
join devv5.concept cc on cc.concept_id = dcs.concept_id_2
where cc.vocabulary_id = 'OMOP Genomic'
and s.vocabulary_id = 'OncoKB';

-- insert synonyms such as HGNC for all canonical variants
insert into concept_synonym_stage
select *
from (
select
DISTINCT NULL::INT as synonym_concept_id,
hgvs AS synonym_name,
cs.concept_code as synonym_concept_code,
cs.vocabulary_id AS synonym_vocabulary_id,
4180186 as language_concept_id
from oncokb_source a
join concept_stage cs on cs.concept_code = a.concept_code
) r
where synonym_name is not null
;