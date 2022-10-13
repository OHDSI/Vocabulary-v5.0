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
* Authors: Varvara Savitskaya, Vlad Korsik, Alexander Davydov
* Date: 2022
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CGI',
	pVocabularyDate			=> TO_DATE('20180216', 'yyyymmdd'),
	pVocabularyVersion		=> 'CGI' || '20180216', -- should be hardcoded when API will not provide reproducible way for Updates
	pVocabularyDevSchema	=> 'dev_cgi'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Create temporary table
DROP TABLE IF EXISTS cgi_source;
CREATE UNLOGGED TABLE cgi_source AS
SELECT DISTINCT REGEXP_SPLIT_TO_TABLE(gdna, '__') AS concept_name,
	'CGI' AS vocabulary_id,
	REGEXP_SPLIT_TO_TABLE(gdna, '__') AS concept_code,
	REGEXP_SPLIT_TO_TABLE(gdna, '__') AS hgvs,
	gene,
	protein,
	gdna
FROM dev_cgi.genomic_cgi_source
WHERE gdna <> ''
	AND protein <> '.';

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
SELECT vocabulary_pack.CutConceptName(n.concept_name) AS concept_name,
	'Measurement' AS domain_id,
	n.vocabulary_id AS vocabulary_id,
	'Variant' AS concept_class_id,
	NULL AS standard_concept,
	TRIM(SUBSTR(n.concept_code, 1, 50)) AS concept_code,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM cgi_source n
JOIN vocabulary v ON v.vocabulary_id = 'CGI';

--5. Fill the concept_synonym_stage
WITH tab
AS (
	SELECT *,
		REGEXP_REPLACE((REGEXP_MATCH(reference, 'NM_.\d.+\(p\..+\)\s|NM_.\d.+\(p\..+\)(?<!__PMID)|NM_.\d.+\(p\..+\)$')) [1], 'AND .+__Clinvar:|__PMID.+__Clinvar:|__PMID', ' @ ', 'gi') AS hgvs_array,
		TRIM(SUBSTR(REGEXP_SPLIT_TO_TABLE(gdna, '__'), 1, 50)) AS concept_code
	FROM dev_cgi.genomic_cgi_source
	WHERE reference ILIKE '%Clinvar%'
		AND protein <> '.'
	),
ref_hgvs
AS (
	SELECT gene,
		gdna,
		protein,
		transcript,
		info,
		context,
		cancer_acronym,
		source,
		reference,
		COALESCE(hgvs_array, (REGEXP_MATCH(SPLIT_PART(reference, ' AND ', 1), 'NM_.\d.+\s|NM_.\d.+$')) [1]) AS hgvs,
		concept_code
	FROM tab
	),
hgvs_synonyms
AS (
	SELECT 'ref' AS flag,
		'CGI' AS synonym_vocabulary_id,
		4180186 AS language_concept_id,
		TRIM(REGEXP_SPLIT_TO_TABLE(hgvs, ' @ ')) AS synonym_name,
		concept_code AS synonym_concept_code
	FROM ref_hgvs
	
	UNION ALL
	
	SELECT 'gdna' AS flag,
		'CGI' AS synonym_vocabulary_id,
		4180186 AS language_concept_id,
		TRIM(REGEXP_SPLIT_TO_TABLE(gdna, '__')) AS synonym_name,
		concept_code AS synonym_concept_code
	FROM cgi_source
	WHERE protein <> '.'
	
	UNION ALL
	
	SELECT 'protein' AS flag,
		'CGI' AS synonym_vocabulary_id,
		4180186 AS language_concept_id,
		TRIM(CONCAT (
				gene,
				':',
				protein
				)) AS synonym_name,
		concept_code AS synonym_concept_code
	FROM cgi_source
	WHERE protein <> '.'
	),
synonyms
AS (
	SELECT DISTINCT flag,
		synonym_vocabulary_id,
		language_concept_id,
		synonym_name,
		synonym_concept_code
	FROM hgvs_synonyms
	WHERE flag IN (
			'protein',
			'gdna'
			)
		OR (
			flag = 'ref'
			AND synonym_name ILIKE 'NM%'
			)
	)
INSERT INTO concept_synonym_stage (
	synonym_concept_id,
	synonym_vocabulary_id,
	language_concept_id,
	synonym_name,
	synonym_concept_code
	)
SELECT cs.concept_id,
	synonym_vocabulary_id,
	language_concept_id,
	synonym_name,
	synonym_concept_code
FROM synonyms s
JOIN concept_stage cs ON cs.concept_code = s.synonym_concept_code
	AND s.synonym_name <> cs.concept_name
	AND s.synonym_name NOT IN (
		SELECT concept_code
		FROM concept_stage
		);

--6. Clean up
DROP TABLE cgi_source;

-- At the end, the three tables concept_stage, concept_relationship_stage AND concept_synonym_stage should be ready to be fed into the generic_update.sql script
