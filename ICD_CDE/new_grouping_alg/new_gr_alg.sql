select *
from devv5.concept
WHERE vocabulary_id = 'ICD10'
and invalid_reason is NULL;


WITH normalized_concepts AS (
    SELECT
        concept_id,
        concept_name,
        to_tsvector('english', concept_name) AS normalized_name,
        vocabulary_id
    FROM devv5.concept
    WHERE vocabulary_id IN ('ICD10', 'ICD10CM', 'ICD10GM', 'ICD9CM')
            and invalid_reason is NULL
),
concept_check AS (
    SELECT
        normalized_name,
        string_agg(distinct concept_name, '||') agg_c_name,
        count(distinct concept_name) as cnt_c_names,
        array_agg(concept_id) as agg_c_id,
        MAX(CASE WHEN vocabulary_id = 'ICD10' THEN 1 ELSE 0 END) AS ICD10,
        MAX(CASE WHEN vocabulary_id = 'ICD10CM' THEN 1 ELSE 0 END) AS ICD10CM,
        MAX(CASE WHEN vocabulary_id = 'ICD10GM' THEN 1 ELSE 0 END) AS ICD10GM,
        MAX(CASE WHEN vocabulary_id = 'ICD9CM' THEN 1 ELSE 0 END) AS ICD9CM
    FROM normalized_concepts
    GROUP BY normalized_name
)

SELECT
    DISTINCT
    NORMALIZED_NAME,
    agg_c_name,
    CNT_C_NAMES,
    AGG_C_ID,
    ICD10,
    ICD10CM,
    ICD10GM,
    ICD9CM
FROM concept_check
where CNT_C_NAMES > 1
ORDER BY agg_c_name;



WITH normalized_concepts AS (
    SELECT
        c.concept_id,
        c.concept_name,
        array_agg(l.lexeme ORDER BY l.lexeme) AS normalized_name,
        c.vocabulary_id
    FROM devv5.concept AS c,
         LATERAL ts_debug('custom_english', c.concept_name) AS t,
         LATERAL unnest(t.lexemes) AS l(lexeme)
    WHERE c.vocabulary_id IN ('ICD10', 'ICD10CM', 'ICD10GM', 'ICD9CM')
        AND c.invalid_reason IS NULL
    GROUP BY c.concept_id, c.concept_name, c.vocabulary_id
),
concept_check AS (
    SELECT
        normalized_name,
        string_agg(distinct concept_name, '||') agg_c_name,
        count(distinct concept_name) as cnt_unique_c_names,
        array_agg(concept_id) as agg_c_id,
        MAX(CASE WHEN vocabulary_id = 'ICD10' THEN 1 ELSE 0 END) AS ICD10,
        MAX(CASE WHEN vocabulary_id = 'ICD10CM' THEN 1 ELSE 0 END) AS ICD10CM,
        MAX(CASE WHEN vocabulary_id = 'ICD10GM' THEN 1 ELSE 0 END) AS ICD10GM,
        MAX(CASE WHEN vocabulary_id = 'ICD9CM' THEN 1 ELSE 0 END) AS ICD9CM
    FROM normalized_concepts
    GROUP BY normalized_name
)

SELECT
    DISTINCT
    NORMALIZED_NAME,
    agg_c_name,
    cnt_unique_c_names,
    AGG_C_ID,
    ICD10,
    ICD10CM,
    ICD10GM,
    ICD9CM
FROM concept_check
--where cnt_unique_c_names > 2
ORDER BY agg_c_name;

--121328
--116694

select count(DISTINCT concept_name)
from devv5.concept
where vocabulary_id in ('ICD10', 'ICD10CM', 'ICD10GM', 'ICD9CM')
        and invalid_reason is null;


CREATE TEXT SEARCH DICTIONARY english_stem_nostop (
    TEMPLATE = snowball,
    Language = english,
    StopWords = ''  -- Empty stop words list
);
DROP TEXT SEARCH CONFIGURATION IF EXISTS custom_english;
CREATE TEXT SEARCH CONFIGURATION custom_english (COPY = english);
ALTER TEXT SEARCH CONFIGURATION custom_english
    ALTER MAPPING FOR asciiword, word
    WITH english_stem_nostop;  -- Use the custom dictionary





SELECT to_tsvector('custom_english', 'Above and below elbow amputation status');


    SELECT
        c.concept_id,
        c.concept_name,
        array_agg(l.lexeme ORDER BY l.lexeme) AS normalized_name,
        c.vocabulary_id
    FROM devv5.concept AS c,
         LATERAL ts_debug('custom_english', c.concept_name) AS t,
         LATERAL unnest(t.lexemes) AS l(lexeme)
    WHERE c.vocabulary_id IN ('ICD10', 'ICD10CM', 'ICD10GM', 'ICD9CM')
        AND c.invalid_reason IS NULL
    GROUP BY c.concept_id, c.concept_name, c.vocabulary_id;


select t1.concept_id,
       t2.concept_synonym_name,
       t1.domain_id
from devv5.concept t1
        join devv5.concept_synonym t2 on t1.concept_id = t2.concept_id
        and t1.vocabulary_id = 'ICD10CM'
        and t1.invalid_reason is NULL
        and t1.concept_name is not NULL
        and t2.concept_synonym_name is not NULL
        and t2.language_concept_id = 4180186

UNION

select t1.concept_id,
       t1.concept_name,
       t1.domain_id
from devv5.concept t1
    where t1.vocabulary_id = 'ICD10CM'
    and t1.invalid_reason is null
    and t1.concept_name is not NULL;


select *
from devv5.concept_synonym;