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
	pVocabularyName			=> 'CIViC',
	pVocabularyDate			=> TO_DATE('20170425','YYYYMMDD'),
	pVocabularyVersion		=> 'CIViC v20170425',
	pVocabularyDevSchema	=> 'dev_civic'
);
END $_$;


truncate concept_stage;
truncate concept_relationship_stage;
truncate concept_synonym_stage;

create table civic_source as (
select distinct variant as concept_name, 'CIViC' as vocabulary_id, cast(variant_id as varchar(5)) as concept_code, ( regexp_matches(hgvs_expressions, '[^, ]+', 'g'))[1] as hgvs
from sources.genomic_civic_variantsummaries
where hgvs_expressions ~ '[\w_]+(\.\d+)?:[cCgGoOmMnNrRpP]\.');


-- put source variants into concept stage
insert into concept_stage
SELECT DISTINCT NULL::INT,
       trim(substr(concept_name,1,255)) AS concept_name,
       'Measurement' AS domain_id,
       vocabulary_id AS vocabulary_id,
       'Variant' AS concept_class_id,
       NULL AS standard_concept,
       concept_code AS concept_code,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM civic_source
;


-- insert synonyms
insert into concept_synonym_stage
select *
from (
select
DISTINCT NULL::INT as synonym_concept_id,
hgvs AS synonym_name,
cs.concept_code as synonym_concept_code,
cs.vocabulary_id AS synonym_vocabulary_id,
4180186 as language_concept_id
from civic_source a
join concept_stage cs on cs.concept_code = a.concept_code
) r
where synonym_name is not null
;


insert into concept_relationship_stage
select DISTINCT NULL::INTEGER AS concept_id_1,
       NULL::INTEGER AS concept_id_2,
       cs.concept_code AS concept_code_1,
       dc.concept_code AS concept_code_2,
       'CIViC' AS vocabulary_id_1,
       'OMOP Genomic' AS vocabulary_id_2,
       'Maps to' AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
from concept_stage cs
join concept_synonym_stage s on cs.concept_code = s.synonym_concept_code
join devv5.concept_synonym dcs on dcs.concept_synonym_name = s.synonym_name
join devv5.concept dc on dc.concept_id = dcs.concept_id
where dc.vocabulary_id = 'OMOP Genomic'
;

