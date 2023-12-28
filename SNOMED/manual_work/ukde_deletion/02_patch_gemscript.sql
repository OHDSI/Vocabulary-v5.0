/*
 * Apply this script to a clean schema to get stage tables that could be applied
 * as a patch before running SNOMED's load_stage.sql.
 */
--0. Clean stage tables and load Gemscript *_manual tables
TRUNCATE concept_relationship_stage;
TRUNCATE concept_synonym_stage;
TRUNCATE concept_stage;
TRUNCATE concept_relationship_manual;
TRUNCATE concept_synonym_manual;
TRUNCATE concept_manual;

INSERT INTO concept_manual
SELECT *
FROM dev_gemscript.concept_manual;
INSERT INTO concept_synonym_manual
SELECT *
FROM dev_gemscript.concept_synonym_manual;
INSERT INTO concept_relationship_manual
SELECT *
FROM dev_gemscript.concept_relationship_manual;

--1. Create table of concepts currently mapped to SNOMED, but that could be
-- mapped to dm+d
DROP TABLE IF EXISTS gemscript_mapped_to_snomed;
CREATE TABLE gemscript_mapped_to_snomed AS
SELECT
    c.concept_id AS gemscript_concept_id,
    c.concept_code AS gemscript_concept_code,
    t.concept_id AS snomed_concept_id,
    d.concept_id AS dmd_concept_id,
    t.concept_code AS shared_concept_code
FROM devv5.concept c
JOIN devv5.concept_relationship r ON
        c.concept_id = r.concept_id_1
    AND r.relationship_id = 'Maps to'
    AND r.invalid_reason IS NULL
    AND c.vocabulary_id = 'Gemscript'
JOIN devv5.concept t ON
        r.concept_id_2 = t.concept_id
    AND t.vocabulary_id = 'SNOMED'
JOIN devv5.concept d ON
        d.concept_code = t.concept_code
    AND d.vocabulary_id = 'dm+d'
-- Concepts staged for the next release would lose their mappings, if any.
-- Serendipitiously, there are no such concepts:
/*
    WITH source AS (
        SELECT vpid AS sctid FROM vmps
            UNION ALL
        SELECT apid AS sctid FROM amps
    )
    SELECT c.*
    FROM devv5.concept c
    JOIN devv5.concept_relationship r ON
            c.concept_id = r.concept_id_1
        AND r.relationship_id = 'Maps to'
        AND r.invalid_reason IS NULL
        AND c.vocabulary_id = 'Gemscript'
    JOIN devv5.concept t ON
            r.concept_id_2 = t.concept_id
        AND t.vocabulary_id = 'SNOMED'
    LEFT JOIN devv5.concept d ON
            d.concept_code = t.concept_code
        AND d.vocabulary_id = 'dm+d'
    JOIN source s ON
            s.sctid = t.concept_code
    WHERE d.concept_id IS NULL
*/
;
--2. Populate new mappings
INSERT INTO concept_relationship_stage
    (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2,
    relationship_id, valid_start_date, valid_end_date)
SELECT
    gemscript_concept_code,
    shared_concept_code,
    'Gemscript',
    'dm+d',
    'Maps to',
    to_date('2023-11-01', 'YYYY-MM-DD'),
    to_date('2099-12-31', 'YYYY-MM-DD')
FROM gemscript_mapped_to_snomed
;
--3. Deprecate existing mappings
INSERT INTO concept_relationship_stage
    (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2,
    relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT
    g.gemscript_concept_code,
    c.concept_code,
    'Gemscript',
    c.vocabulary_id,
    'Maps to',
    c.valid_start_date,
    to_date('2023-10-31', 'YYYY-MM-DD'),
    'D'
FROM gemscript_mapped_to_snomed g
JOIN devv5.concept_relationship r ON
        r.concept_id_1 = g.gemscript_concept_id
    AND r.relationship_id = 'Maps to'
    AND r.invalid_reason IS NULL
JOIN devv5.concept c ON
    r.concept_id_2 = c.concept_id
;
DROP TABLE IF EXISTS gemscript_mapped_to_snomed;
SELECT
	VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'Gemscript',
	pVocabularyDate			=> to_date('01-11-2023', 'dd-mm-yyyy'),
	pVocabularyVersion		=> 'Gemscript 2021-02-01',
	pVocabularyDevSchema	=> 'dev_test3'
)
;
