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
* Authors: Varvara Savitskaya, Vlad Korsik
* Date: 2022
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'COSMIC',
	pVocabularyDate			=>  TO_DATE('20220531', 'yyyymmdd'),
	pVocabularyVersion		=> 'v.96 20220531',
	pVocabularyDevSchema	=> 'dev_cosmic'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Create temporary table
DROP TABLE IF EXISTS cosmic_source;
CREATE UNLOGGED TABLE cosmic_source AS
	WITH cosmic_concepts AS (
			SELECT DISTINCT c.gene_name,
				c.genomic_mutation_id,
				c.mutation_cds,
				c.mutation_aa,
				c.hgvsp,
				c.hgvsc,
				c.hgvsg
			FROM dev_cosmic.cosmicmutantexportcensus c
			WHERE c.genomic_mutation_id NOT IN (
					SELECT s0.genomic_mutation_id
					FROM (
						SELECT DISTINCT c_int.gene_name,
							c_int.accession_number,
							c_int.gene_cds_length,
							c_int.hgnc_id,
							c_int.genomic_mutation_id,
							c_int.mutation_id,
							c_int.mutation_cds,
							c_int.mutation_aa,
							c_int.mutation_description,
							c_int.loh,
							c_int.grch,
							c_int.mutation_genome_position,
							c_int.mutation_strand,
							c_int.resistance_mutation,
							c_int.tier,
							c_int.hgvsp,
							c_int.hgvsc,
							c_int.hgvsg
						FROM dev_cosmic.cosmicmutantexportcensus c_int
						WHERE c_int.genomic_mutation_id <> ''
						) s0
					GROUP BY s0.genomic_mutation_id
					HAVING COUNT(s0.genomic_mutation_id) > 1
					)
				AND c.genomic_mutation_id <> ''
				AND (
					c.mutation_description <> 'Unknown'
					OR c.resistance_mutation = 'Yes'
					)
			)

SELECT CONCAT (
		gene_name,
		':',
		mutation_aa,
		' (',
		mutation_cds,
		')'
		) AS concept_name,
	genomic_mutation_id AS concept_code,
	hgvsp AS hgvs
FROM cosmic_concepts
WHERE hgvsp <> ''
	AND LENGTH(hgvsp) <= 1000

UNION ALL

SELECT CONCAT (
		gene_name,
		':',
		mutation_aa,
		' (',
		mutation_cds,
		')'
		) AS concept_name,
	genomic_mutation_id AS concept_code,
	hgvsc AS hgvs
FROM cosmic_concepts
WHERE LENGTH(hgvsc) <= 1000

UNION ALL

SELECT CONCAT (
		gene_name,
		':',
		mutation_aa,
		' (',
		mutation_cds,
		')'
		) AS concept_name,
	genomic_mutation_id AS concept_code,
	hgvsg AS hgvs
FROM cosmic_concepts
WHERE LENGTH(hgvsg) <= 1000;

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
SELECT DISTINCT vocabulary_pack.CutConceptName(c.concept_name) AS concept_name,
	'Measurement' AS domain_id,
	'COSMIC' AS vocabulary_id,
	'Variant' AS concept_class_id,
	NULL AS standard_concept,
	c.concept_code AS concept_code,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM cosmic_source c
JOIN vocabulary v ON v.vocabulary_id = 'COSMIC';

--5. Fill the concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT concept_code AS synonym_concept_code,
	hgvs AS synonym_name,
	'COSMIC' AS synonym_vocabulary_id,
	33071 AS language_concept_id -- Genetic nomenclature
FROM cosmic_source;

--6. Clean up
DROP TABLE cosmic_source;

-- At the end, the three tables concept_stage, concept_relationship_stage AND concept_synonym_stage should be ready to be fed into the generic_update.sql script