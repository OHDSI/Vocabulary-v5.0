/**************************************************************************
* Copyright 2016 Observational Health Data Sciences AND Informatics (OHDSI)
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
* Authors: Varvara Savitskaya, Vlad Korsik
* Date: 2022
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CIViC',
	pVocabularyDate			=>  TO_DATE('20221001', 'yyyymmdd'),
	pVocabularyVersion		=> 'CIViC'||'20221001',
	pVocabularyDevSchema	=> 'dev_civic'
);
END $_$;


--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;


--3. Create temporary table
DROP TABLE civic_source;
CREATE TABLE civic_source as (
SELECT DISTINCT variant as concept_name, 'CIViC' as vocabulary_id, variant_id as concept_code, (regexp_matches(hgvs_expressions, '[^, ]+', 'g'))[1] as hgvs
FROM sources.civic_variantsummaries
WHERE hgvs_expressions ~ '[\w_]+(\.\d+)?:[cCgGoOmMnNrRpP]\.'
AND variant!~*'frameshift|truncating'

UNION

SELECT DISTINCT variant as concept_name, 'CIViC' as vocabulary_id, variant_id as concept_code, concat(gene, ':p.', variant) as hgvs
FROM sources.civic_variantsummaries
WHERE variant ~'([A-Z][1-9]*[A-Z])'
AND variant!~*'expression|amplification|wild type|truncation|truncating|loss|wildtype|mutation|methylation|polymorphism|HOMOZYGOSITY|translocation|PHOSPHORYLATION|deletion|function|shift|alteration|tandem|serum|alternative|REARRANGEMENT|MISLOCALIZATION|and|INACTIVATION|DOMAIN'
AND variant not ilike '%rs%'

UNION

SELECT DISTINCT variant as concept_name, 'CIViC' as vocabulary_id, variant_id as concept_code, variant as hgvs
FROM sources.civic_variantsummaries
WHERE variant ~'([A-Z][1-9]*[A-Z])'
AND variant!~*'expression|amplification|wild type|truncation|truncating|wildtype|mutation|loss|methylation|polymorphism|HOMOZYGOSITY|translocation|PHOSPHORYLATION|deletion|function|shift|alteration|tandem|serum|alternative|REARRANGEMENT|MISLOCALIZATION|and|INACTIVATION|DOMAIN'
AND variant ilike '%rs%'
AND variant not like '%::%');


-- 4 Fill the concept_stage
INSERT INTO concept_stage (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date)
SELECT          DISTINCT        vocabulary_pack.CutConceptName(n.concept_name)                     AS concept_name,
                           'Measurement'                                               AS domain_id,
                           n.vocabulary_id                                             AS vocabulary_id,
                           'Variant'                                                   AS concept_class_id,
                           NULL                                                        AS standard_concept,
                           trim(substr(n.concept_code, 1, 50))                         AS concept_code,
                           v.latest_update           as valid_start_date,
                           TO_DATE('20991231', 'yyyymmdd') as valid_end_date
           FROM civic_source n
                    JOIN vocabulary v ON v.vocabulary_id = 'CIViC'
;


-- 5 Fill the concept_synonym_stage
INSERT INTO concept_synonym_stage
SELECT *
FROM (
SELECT
NULL::INT as synonym_concept_id,
hgvs AS synonym_name,
cs.concept_code as synonym_concept_code,
cs.vocabulary_id AS synonym_vocabulary_id,
4180186 as language_concept_id
FROM civic_source a
JOIN concept_stage cs on cs.concept_code = a.concept_code
) r
;


--6. Clean up
DROP TABLE civic_source;

-- At the end, the three tables concept_stage, concept_relationship_stage AND concept_synonym_stage should be ready to be fed into the generic_update.sql script