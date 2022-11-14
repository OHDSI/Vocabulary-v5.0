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
    (WITH tab AS
        (SELECT DISTINCT gene_name,
                        genomic_mutation_id,
                        resistance_mutation,
                        tier,
                        mutation_description,
                        mutation_cds,
                        mutation_aa,
                        hgvsp,
                        hgvsc,
                        hgvsg
        FROM cosmicmutantexportcensus
        WHERE genomic_mutation_id NOT IN
            (SELECT genomic_mutation_id FROM
                (WITH tab AS (SELECT DISTINCT gene_name,
                             accession_number,
                             gene_cds_length,
                             hgnc_id,
                             genomic_mutation_id,
                             mutation_id,
                             mutation_cds,
                             mutation_aa,
                             mutation_description,
                             loh,
                             grch,
                             mutation_genome_position,
                             mutation_strand,
                             resistance_mutation,
                             tier,
                             hgvsp,
                             hgvsc,
                             hgvsg
                            FROM cosmicmutantexportcensus
                            WHERE LENGTH(genomic_mutation_id)<>0)
SELECT genomic_mutation_id FROM tab
GROUP BY 1
HAVING COUNT(genomic_mutation_id) > 1
                                   )c
    )
AND LENGTH(genomic_mutation_id) <> 0
AND (mutation_description <> 'Unknown'
OR resistance_mutation = 'Yes'))
    (SELECT concat(gene_name, ':', mutation_aa, ' (', mutation_cds, ')') AS concept_name,
            'COSMIC'           AS vocabulary_id,
            genomic_mutation_id AS concept_code,
            hgvsp              AS hgvs
    FROM tab
    WHERE LENGTH(hgvsp) > 0

    UNION

    SELECT concat(gene_name, ':', mutation_aa, ' (', mutation_cds, ')') AS concept_name,
           'COSMIC'           AS vocabulary_id,
            genomic_mutation_id AS concept_code,
            hgvsc              AS hgvs
    FROM tab
    WHERE LENGTH(genomic_mutation_id) > 0

    UNION

    SELECT concat(gene_name, ':', mutation_aa, ' (', mutation_cds, ')') AS concept_name,
    'COSMIC'           AS vocabulary_id,
    genomic_mutation_id AS concept_code,
    hgvsg              AS hgvs
    FROM tab
    WHERE LENGTH(genomic_mutation_id) > 0));

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
	c.vocabulary_id AS vocabulary_id,
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
	vocabulary_pack.CutConceptSynonymName(hgvs) AS synonym_name,
	vocabulary_id AS synonym_vocabulary_id,
		33071 AS language_concept_id  -- Genetic nomenclature
FROM cosmic_source;

--6. Clean up
DROP TABLE cosmic_source;

-- At the end, the three tables concept_stage, concept_relationship_stage AND concept_synonym_stage should be ready to be fed into the generic_update.sql script