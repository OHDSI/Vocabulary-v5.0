CREATE OR REPLACE FUNCTION CPT_Replacements()
RETURNS VOID AS $$
/***
 * CPT_Replacements Function
 *
 * Maps deprecated Category III CPT codes to Category I replacements
 * Uses Levenshtein distance for fuzzy matching
 *
 * Usage: SELECT * FROM CPT_Replacements();
 */
BEGIN

--1. Extract deprecated Category III codes into temp table
DROP TABLE IF EXISTS deprecated_cat3;

CREATE TEMP TABLE deprecated_cat3 AS
SELECT
  c.concept_code as deprecated_code,
  REPLACE(c.concept_name, ' (Deprecated)', '') as deprecated_name,
  c.domain_id,
  c.vocabulary_id as vocabulary_id_1,
  c.valid_start_date,
  c.valid_end_date,
  LENGTH(REPLACE(c.concept_name, ' (Deprecated)', '')) as name_length
FROM concept_stage c
WHERE c.vocabulary_id = 'CPT4'
  AND c.concept_code LIKE '%T'
  AND c.concept_class_id = 'CPT4'
  AND c.standard_concept = 'S'
  AND c.concept_name LIKE '%Deprecated%'
  AND c.concept_code NOT IN ('V-CPT','V-HCPT')
;

--2. Extract Category I candidate codes into temp table
DROP TABLE IF EXISTS category_i;

CREATE TEMP TABLE category_i AS
SELECT
  c.concept_code as replacement_code,
  REPLACE(c.concept_name, ' (Deprecated)', '') as replacement_name,
  c.domain_id,
  c.vocabulary_id as vocabulary_id_2,
  LENGTH(REPLACE(c.concept_name, ' (Deprecated)', '')) as name_length,
  c.standard_concept
FROM concept_stage c
WHERE c.vocabulary_id = 'CPT4'
  AND c.concept_class_id = 'CPT4'
  AND c.concept_code NOT LIKE '%T'
  AND c.invalid_reason IS NULL
;

--3. Calculate all similarity metrics
DROP TABLE IF EXISTS match_scores;

CREATE TEMP TABLE match_scores AS
SELECT
  d.deprecated_code,
  d.deprecated_name,
  d.domain_id,
  c.replacement_code,
  c.replacement_name,
  c.domain_id as c_domain_id,
  devv5.levenshtein(d.deprecated_name, c.replacement_name) as lev_dist,
  GREATEST(LENGTH(d.deprecated_name), LENGTH(c.replacement_name)) as max_len
FROM deprecated_cat3 d
CROSS JOIN category_i c
WHERE devv5.levenshtein(d.deprecated_name, c.replacement_name) <= 20;

--4. Calculate weighted scores
DROP TABLE IF EXISTS scored_matches;

CREATE TEMP TABLE scored_matches AS
SELECT
  deprecated_code,
  deprecated_name,
  replacement_code,
  replacement_name,
  domain_id,
  c_domain_id,
  lev_dist,
  max_len,
  -- Levenshtein ratio
  CASE
    WHEN max_len = 0 THEN 1.0
    ELSE (1.0 - (lev_dist::numeric / max_len))
  END as lev_ratio,
  -- Weighted score (using Levenshtein ratio)
  ROUND((
    CASE
      WHEN max_len = 0 THEN 1.0
      ELSE (1.0 - (lev_dist::numeric / max_len))
    END
  )::numeric, 4) as weighted_score
FROM match_scores
ORDER BY deprecated_code, weighted_score DESC;

--5. Rank candidates
DROP TABLE IF EXISTS ranked_matches;

CREATE TEMP TABLE ranked_matches AS
SELECT
  deprecated_code,
  deprecated_name,
  replacement_code,
  replacement_name,
  domain_id,
  c_domain_id,
  lev_dist as levenshtein_distance,
  ROUND(lev_ratio::numeric, 3) as levenshtein_ratio,
  weighted_score,
  CASE WHEN domain_id = c_domain_id THEN 'SAME' ELSE 'DIFFERENT' END as domain_match,
  CASE
    WHEN weighted_score >= 0.85 THEN 'EXCELLENT'
    WHEN weighted_score >= 0.75 THEN 'GOOD'
    WHEN weighted_score >= 0.65 THEN 'MODERATE'
    ELSE 'WEAK'
  END as match_quality,
  ROW_NUMBER() OVER (PARTITION BY deprecated_code ORDER BY weighted_score DESC) as match_rank
FROM scored_matches
WHERE weighted_score >= 0.65;

--6. Create final mapping table
DROP TABLE IF EXISTS cpt_category3_to_i_mappings CASCADE;

CREATE TABLE cpt_category3_to_i_mappings AS
SELECT
  deprecated_code,
  deprecated_name,
  replacement_code,
  replacement_name,
  weighted_score,
  levenshtein_distance,
  levenshtein_ratio,
  match_quality,
  match_rank,
  domain_match,
  NULL::boolean as approved,
  NULL::text as approval_notes,
  CURRENT_TIMESTAMP as created_at
FROM ranked_matches
WHERE match_rank <= 3
ORDER BY deprecated_code, match_rank;

--7. Insert replacement relationships into concept_relationship_stage
INSERT INTO concept_relationship_stage (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
)
SELECT
  deprecated_code,
  replacement_code,
  'CPT4',
  'CPT4',
  'Concept replaced by',
  (SELECT latest_update
   FROM vocabulary
   WHERE vocabulary_id = 'CPT4'),
  '2099-12-31',
  NULL
FROM cpt_category3_to_i_mappings
WHERE weighted_score >= 0.85 AND match_rank = 1
ORDER BY deprecated_code;

--8. Update invalid_reason for the upgraded concepts
UPDATE concept_stage cs
SET standard_concept = NULL,
    valid_end_date = (SELECT latest_update
                       FROM vocabulary
                       WHERE vocabulary_id = 'CPT4'),
    invalid_reason = 'U'
WHERE EXISTS(SELECT 1
             FROM cpt_category3_to_i_mappings m
             WHERE m.deprecated_code = cs.concept_code
               AND cs.vocabulary_id = 'CPT4'
               AND weighted_score >= 0.85 AND match_rank = 1);

  DROP TABLE IF EXISTS deprecated_cat3;
  DROP TABLE IF EXISTS category_i;
  DROP TABLE IF EXISTS match_scores;
  DROP TABLE IF EXISTS scored_matches;
  DROP TABLE IF EXISTS ranked_matches;

END;
$$ LANGUAGE plpgsql;