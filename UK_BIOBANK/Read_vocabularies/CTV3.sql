--READ VERSION 3 VOCABULARY (CTV3)

--PROCESSING OF SOURCES

--UKB 2020

CREATE TABLE sources_ctv3_concept
(
    read_code varchar(20),
    status varchar(1),
    linguistic_role varchar(1),
    subject_type_read_code varchar(20)
);

CREATE TABLE sources_ctv3_hier
(
    child_rc varchar(20),
    parent_rc varchar(20),
    "order" varchar(20)
);

CREATE TABLE sources_ctv3_descrip
(
    read_code varchar(20),
    term_id varchar(20),
    description_type varchar(1)
);

CREATE TABLE sources_ctv3_terms
(
    term_id varchar(20),
    status varchar(1),
    term_30 varchar(30),
    term_60 varchar(60),
    term_198 varchar(198)
);

CREATE TABLE sources_ctv3sct_map
(
    mapid varchar(50),
    ctv3_concept_id varchar(20),
    ctv3_term_id varchar(20),
    ctv3_term_type varchar(1),
    sct_concept_id varchar(18),
    sct_description_id varchar(18),
    map_status varchar(1),
    effective_date varchar(20),
    is_assured smallint
);



--Analysis
-- Counts of different term types
SELECT count(*), 'P'
FROM sources_ctv3sct_map
WHERE ctv3_term_type = 'P'

UNION

SELECT count(*), 'S'
FROM sources_ctv3sct_map
WHERE ctv3_term_type = 'S'

UNION

SELECT count(*), 'NULL'
FROM sources_ctv3sct_map
WHERE ctv3_term_type = ''
;

--Query to take a look on concept as we got used to
SELECT *
FROM sources_ctv3_concept concept
JOIN sources_ctv3_descrip descr
ON concept.read_code = descr.read_code
JOIN sources_ctv3_terms term
ON descr.term_id = term.term_id
WHERE description_type = 'P'
AND descr.read_code = '03I..';

--The most strict mapping rules
with main_mapping AS
    (
SELECT DISTINCT ctv3_concept_id, ctv3_term_id, ctv3_term_type, sct_concept_id, map_status,
                row_number() over (partition by sct_concept_id ORDER BY cast(effective_date AS date) DESC) AS latest_status
FROM sources_ctv3sct_map
WHERE sct_concept_id != '_DRUG'
AND ctv3_term_type = 'P'
    )

SELECT *
FROM main_mapping
WHERE map_status = '1'
    AND latest_status = '1'
ORDER BY ctv3_concept_id;

--Looking for multi-mapping
with a AS (
with main_mapping AS
    (
SELECT DISTINCT ctv3_concept_id, ctv3_term_id, ctv3_term_type, sct_concept_id, map_status,
                row_number() over (partition by sct_concept_id ORDER BY cast(effective_date AS date) DESC) AS latest_status
FROM sources_ctv3sct_map
WHERE sct_concept_id != '_DRUG'
AND ctv3_term_type = 'P'
    )

SELECT *
FROM main_mapping
WHERE map_status = '1'
    AND latest_status = '1'
ORDER BY ctv3_concept_id)

select * from a
WHERE ctv3_concept_id IN (SELECT ctv3_concept_id FROM a GROUP BY ctv3_concept_id HAVING count(*) > 1);





--Examples:
--1156.
--03I..

SELECT *
FROM sources_ctv3sct_map
WHERE ctv3_concept_id = '3167.';









--===============================================
--Read 3 to Snomed lookup
--lookup with mapping
--source_code + preferred term as source_code_description
--target - snomed
with main_mapping AS
    (
SELECT DISTINCT ctv3_concept_id, ctv3_term_id, ctv3_term_type, sct_concept_id, map_status,
                row_number() over (partition by sct_concept_id ORDER BY cast(effective_date AS date) DESC) AS latest_status
FROM dev_ukbiobank.sources_ctv3sct_map
WHERE sct_concept_id != '_DRUG'
AND ctv3_term_type = 'P'
    ),

     latest_valid_map AS (
         SELECT *
FROM main_mapping
WHERE map_status = '1'
    AND latest_status = '1'
ORDER BY ctv3_concept_id
     )

SELECT c.read_code, d.term_id, d.description_type,
       CASE WHEN t.term_198 != '' AND t.term_198 IS NOT NULL THEN t.term_198
            WHEN t.term_60 != '' AND t.term_60 IS NOT NULL THEN t.term_60
                ELSE t.term_30 END
           AS source_code_description,
        lm.sct_concept_id,
        cc.*
FROM dev_ukbiobank.sources_ctv3_concept c
JOIN dev_ukbiobank.sources_ctv3_descrip d
ON c.read_code = d.read_code
JOIN dev_ukbiobank.sources_ctv3_terms t
ON d.term_id = t.term_id
JOIN latest_valid_map lm
ON lm.ctv3_concept_id = c.read_code
JOIN devv5.concept cc
ON cc.concept_code = lm.sct_concept_id
    AND cc.vocabulary_id = 'SNOMED'

WHERE c.status = 'C' --There are also Redundant, Optional and extinct statuses
ORDER BY c.read_code;