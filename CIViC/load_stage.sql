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
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.civic_variantsummaries LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.civic_variantsummaries LIMIT 1),
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
DROP TABLE IF EXISTS civic_source;
CREATE UNLOGGED TABLE civic_source AS
SELECT variant AS concept_name,
	'CIViC' AS vocabulary_id,
	variant_id AS concept_code,
	(regexp_matches(hgvs_expressions, '[^, ]+', 'g')) [1] AS hgvs
FROM sources.civic_variantsummaries
WHERE hgvs_expressions ~* '[\w_]+(\.\d+)?:[cgomnrp]\.'
	AND variant !~* 'frameshift|truncating'

UNION ALL

SELECT variant AS concept_name,
	'CIViC' AS vocabulary_id,
	variant_id AS concept_code,
	CONCAT (
		gene,
		':p.',
		variant
		) AS hgvs
FROM sources.civic_variantsummaries
WHERE variant ~ '([A-Z][1-9]*[A-Z])'
	AND variant !~* 'expression|amplification|wild type|truncation|truncating|loss|wildtype|mutation|methylation|polymorphism|HOMOZYGOSITY|translocation|PHOSPHORYLATION|deletion|function|shift|alteration|tandem|serum|alternative|REARRANGEMENT|MISLOCALIZATION|and|INACTIVATION|DOMAIN'
	AND variant NOT ILIKE '%rs%'

UNION ALL

SELECT variant AS concept_name,
	'CIViC' AS vocabulary_id,
	variant_id AS concept_code,
	variant AS hgvs
FROM sources.civic_variantsummaries
WHERE variant ~ '([A-Z][1-9]*[A-Z])'
	AND variant !~* 'expression|amplification|wild type|truncation|truncating|wildtype|mutation|loss|methylation|polymorphism|HOMOZYGOSITY|translocation|PHOSPHORYLATION|deletion|function|shift|alteration|tandem|serum|alternative|REARRANGEMENT|MISLOCALIZATION|and|INACTIVATION|DOMAIN'
	AND variant ILIKE '%rs%'
	AND variant NOT LIKE '%::%';

--4. Fill the concept_stage
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT c.concept_name,
	'Measurement' AS domain_id,
	c.vocabulary_id AS vocabulary_id,
	'Variant' AS concept_class_id,
	NULL AS standard_concept,
	c.concept_code AS concept_code,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM civic_source c
JOIN vocabulary v ON v.vocabulary_id = 'CIViC';

--5. Fill the concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT concept_code AS synonym_concept_code,
	hgvs AS synonym_name,
	vocabulary_id AS synonym_vocabulary_id,
	33071 AS language_concept_id --Genetic nomenclature
FROM civic_source;

--6. Clean up
DROP TABLE civic_source;

-- At the end, the three tables concept_stage, concept_relationship_stage AND concept_synonym_stage should be ready to be fed into the generic_update.sql script