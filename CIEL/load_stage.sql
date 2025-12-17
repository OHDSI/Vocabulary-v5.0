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
* Authors: Christian Reich, Timur Vakhitov, Michael Kallfelz, Polina Talapova
* Date: 2020, 2021, 2025
**************************************************************************/
--1. Update latest_update field to new date 
DO $_$
DECLARE
    v_date date;
BEGIN
    -- Get the latest CIEL version date from strings like 'v2025-11-20'
    SELECT MAX(
             to_date(
               regexp_replace(btrim(version), '^[vV]', ''),  -- drop leading v/V if present
               'YYYY-MM-DD'
             )
           )
    INTO v_date
    FROM sources.ciel_source_versions
    WHERE NULLIF(btrim(version), '') ~* '^v?\d{4}-\d{2}-\d{2}$';  -- only versions that look like vYYYY-MM-DD / YYYY-MM-DD

    IF v_date IS NULL THEN
        RAISE EXCEPTION
            'No valid CIEL version (vYYYY-MM-DD / YYYY-MM-DD) found in sources.ciel_source_versions';
    END IF;

    PERFORM vocabulary_pack.SetLatestUpdate(
        pVocabularyName      => 'CIEL',
        pVocabularyDate      => v_date,
        pVocabularyVersion   => 'CIEL ' || to_char(v_date, 'YYYY-MM-DD'),
        pVocabularyDevSchema => 'DEV_CIEL'
    );
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage; 
TRUNCATE TABLE concept_synonym_stage;

--3. Load CIEL concepts into the concept_stage
INSERT INTO concept_stage
(	
concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
WITH base AS (
  SELECT
    a.*,
    vocabulary_pack.CutConceptName(a.display_name) AS norm_name
  FROM sources.ciel_concepts a
  WHERE a.display_locale = 'en'
    AND EXISTS (
      SELECT 1
      FROM sources.ciel_concept_names n
      WHERE n.concept_id = a.id
        AND n.name_type  = 'FULLY_SPECIFIED'
    )
),
-- duplicate-name awareness: does a normalized name have an active (non-retired) twin?
name_flags AS (
  SELECT
    b.norm_name,
    (MAX(CASE WHEN b.retired IS FALSE THEN 1 ELSE 0 END) = 1) AS has_active_same_name
  FROM base b
  GROUP BY b.norm_name
),
-- 1 row per concept: choose the "best" retired record via window ranking
ret_hist AS (
  SELECT
    ch.concept_id::bigint AS id,
    ch.retired_since_on,
    CASE
      WHEN NULLIF(btrim(ch.retired_since_version),'') ~* '^v?\d{4}-\d{2}-\d{2}$'
        THEN to_date(regexp_replace(btrim(ch.retired_since_version),'^[vV]',''),'YYYY-MM-DD')
      ELSE NULL
    END AS ver_date,
    ROW_NUMBER() OVER (
      PARTITION BY ch.concept_id
      ORDER BY
        CASE
          WHEN NULLIF(btrim(ch.retired_since_version),'') ~* '^v?\d{4}-\d{2}-\d{2}$'
            THEN to_date(regexp_replace(btrim(ch.retired_since_version),'^[vV]',''),'YYYY-MM-DD')
          ELSE NULL
        END DESC NULLS LAST,
        ch.retired_since_on DESC NULLS LAST,
        ch.pulled_at DESC NULLS LAST
    ) AS rn
  FROM sources.ciel_concept_retired_history ch
),
-- OMOP concept start preservation (at most one per code)
omop_keep AS (
  SELECT c.concept_code, MIN(c.valid_start_date) AS omop_start_date
  FROM concept c
  WHERE c.vocabulary_id = 'CIEL'
  GROUP BY c.concept_code
),
-- main rows, one logical row per concept_id (but add final dedupe guard anyway)
ins AS (
  SELECT
    vocabulary_pack.CutConceptName(btrim(replace(a.display_name, chr(160), ' '), E' \t\r\n\f\v')  ) AS concept_name,    
    -- Domain mapping
    CASE
      WHEN a.concept_class IN ('Test','LabSet','Aggregate Measurement') THEN 'Measurement'
      WHEN a.concept_class IN ('Procedure','Radiology/Imaging Procedure') THEN 'Procedure'
      WHEN a.concept_class IN ('Drug','MedSet','Pharmacologic Drug Class','Drug form','InteractSet') THEN 'Drug'
      WHEN a.concept_class IN ('Diagnosis','Finding','Symptom','Symptom/Finding') THEN 'Condition'
      WHEN a.concept_class IN ('Question','ConvSet','Misc','Misc Order','Workflow','State','Program','Organism') THEN 'Observation'
      WHEN a.concept_class = 'Anatomy' THEN 'Spec Anatomic Site'
      WHEN a.concept_class = 'Specimen' THEN 'Specimen'
      WHEN a.concept_class = 'Units of Measure' THEN 'Unit'
      WHEN a.concept_class = 'Medical supply' THEN 'Device'
      WHEN a.concept_class = 'Frequency' THEN 'Meas Value'
    END AS domain_id,
    'CIEL' AS vocabulary_id,
    -- shorten to <= 20 chars
    CASE a.concept_class
      WHEN 'Aggregate Measurement' THEN 'Aggregate Meas'
      WHEN 'Radiology/Imaging Procedure' THEN 'Radiology'
      WHEN 'Pharmacologic Drug Class' THEN 'Drug Class'
      WHEN 'InteractSet' THEN 'Drug Class'
      ELSE a.concept_class
    END AS concept_class_id,
    NULL::varchar AS standard_concept,
    a.id::varchar AS concept_code,
    -- compute end date once
    CASE
      WHEN a.retired IS FALSE THEN DATE '2099-12-31'
      ELSE COALESCE(k.ver_date, k.retired_since_on::date)
    END AS end_val,
    -- compute start date (preserve OMOP; else parse version; else pulled_at)
    COALESCE(
      ok.omop_start_date,
      CASE
        WHEN NULLIF(btrim(a.latest_source_version),'') ~* '^v?\d{4}-\d{2}-\d{2}$'
          THEN to_date(regexp_replace(btrim(a.latest_source_version),'^[vV]',''),'YYYY-MM-DD')
        ELSE a.pulled_at::date
      END
    ) AS start_pre,
    -- invalid reason decision
    CASE
      WHEN a.retired IS FALSE THEN NULL
      WHEN nf.has_active_same_name THEN 'U'  -- retired but an active twin with the same normalized name exists
      ELSE 'D'
    END AS invalid_reason,
    a.created_on::date AS created_on_date
  FROM base a
  LEFT JOIN ret_hist k
    ON k.id = a.id::bigint AND k.rn = 1
  LEFT JOIN omop_keep ok
    ON ok.concept_code = a.id::varchar
  LEFT JOIN name_flags nf
    ON lower(nf.norm_name) = lower(a.norm_name)
),
-- clamp start if start >= end, then dedupe by concept_code with a clear preference
final_ranked AS (
  SELECT
    concept_name,
    domain_id,
    vocabulary_id,
    concept_class_id,
    standard_concept,
    concept_code,
    CASE WHEN start_pre >= end_val THEN created_on_date ELSE start_pre END AS valid_start_date,
    end_val AS valid_end_date,
    invalid_reason,
    ROW_NUMBER() OVER (
      PARTITION BY concept_code
      ORDER BY
        (invalid_reason IS NULL) DESC,        -- prefer active
        (invalid_reason = 'U') DESC,          -- then 'U'
        CASE WHEN start_pre >= end_val THEN created_on_date ELSE start_pre END ASC,
        end_val DESC
    ) AS rn
  FROM ins
)
SELECT
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date,
  invalid_reason
FROM final_ranked
WHERE rn = 1; -- 58348
  
-- Add concepts which are absent in source CIEL but present in OMOP CIEL as deprecated concepts
INSERT INTO concept_stage
(	
concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
WITH max_ver AS (  -- latest known CIEL snapshot date
  SELECT MAX(
           CASE
             WHEN NULLIF(btrim(version),'') ~* '^v?\d{4}-\d{2}-\d{2}$'
               THEN to_date(regexp_replace(btrim(version),'^[vV]',''),'YYYY-MM-DD')
             ELSE NULL
           END
         ) AS max_version_date
  FROM sources.ciel_source_versions
),
missing AS (  -- OMOP CIEL concepts missing in source OR not present in manual
  SELECT c.*
  FROM concept c
  WHERE c.vocabulary_id = 'CIEL'
    AND (
          NOT EXISTS (SELECT 1 FROM sources.ciel_concepts s WHERE s.id::varchar = c.concept_code)
       OR NOT EXISTS (SELECT 1 FROM ciel_concept_manual  m WHERE m.concept_code   = c.concept_code)
        )
)
SELECT DISTINCT ON (c.concept_code)
  c.concept_name AS concept_name,   -- prefer source name if available (but ES language violate OMOP rules)
  c.domain_id,
  c.vocabulary_id,
  c.concept_class_id,
  c.standard_concept,
  c.concept_code,
  c.valid_start_date,
  COALESCE(h.end_date, mv.max_version_date) AS valid_end_date, -- expected retired date if in source, else snapshot date
  'D'::varchar AS invalid_reason
FROM missing c
CROSS JOIN max_ver mv
LEFT JOIN sources.ciel_concepts k
       ON k.id::varchar = c.concept_code
-- expected end date from retired history (only if the concept exists in source)
LEFT JOIN LATERAL (
  SELECT
    COALESCE(
      CASE
        WHEN NULLIF(btrim(ch.retired_since_version),'') ~* '^v?\d{4}-\d{2}-\d{2}$'
          THEN to_date(regexp_replace(btrim(ch.retired_since_version),'^[vV]',''),'YYYY-MM-DD')
        ELSE NULL
      END,
      ch.retired_since_on::date
    ) AS end_date
  FROM sources.ciel_concept_retired_history ch
  WHERE ch.concept_id = k.id::text      -- ties to the source row; yields NULL if k is NULL
  ORDER BY end_date DESC NULLS LAST, ch.pulled_at DESC NULLS LAST
  LIMIT 1
) h ON TRUE
ORDER BY c.concept_code; -- 1 

--4. Add synonyms to the concept_synonym_stage
INSERT INTO concept_synonym_stage --ciel_concept_synonym_manual
(
  synonym_name,
  synonym_concept_code,
  synonym_vocabulary_id,
  language_concept_id
)
WITH locale_map(locale, language_concept_id) AS (
  VALUES
    ('en',4180186),     -- English
    ('am',4182354),     -- Amharic
    ('ar',4181374),     -- Arabic
    ('bn',4052786),     -- Bengali
    ('es',4182511),     -- Spanish
    ('fr',4180190),     -- French
    ('ht',44802876),    -- Haitian
    ('it',4182507),     -- Italian
    ('nl',4182503),     -- Dutch
    ('pt',4181536),     -- Portuguese
    ('ru',4181539),     -- Russian
    ('rw',4175935),     -- Kinyarwanda
    ('sw',4181698),     -- Swahili
    ('ti',4182356),     -- Tigrinya
    ('ur',4059788),     -- Urdu
    ('vi',4181526),     -- Vietnamese
   -- ('in',4183663),     -- Indonesian  (NB: source uses 'in'; ISO 639-1 is 'id' - error in prev. CIEL versions) 
    ('id',4183663),     -- Indonesian
    ('km',4183770),     -- Khmer
    ('ne',4175908),     -- Nepali
    ('om',4182349)      -- Oromo
),
src_syn AS (
  SELECT
 btrim(replace(n.name, chr(160), ' '), E' \t\r\n\f\v') AS synonym_name,
    n.concept_id::varchar AS synonym_concept_code,
    lower(n.locale) AS locale
  FROM sources.ciel_concept_names n
    WHERE n.locale IS NOT NULL AND name <> '' 
    AND (name_type in ('FULLY_SPECIFIED','SHORT') OR name_type IS NULL)
)
SELECT
  s.synonym_name,
  s.synonym_concept_code,
  'CIEL'::varchar,
  m.language_concept_id
FROM src_syn s
JOIN locale_map m ON m.locale = s.locale
JOIN concept_stage c ON c.concept_code = s.synonym_concept_code
AND NOT EXISTS (SELECT 1 FROM concept_synonym_stage cs
WHERE cs.synonym_concept_code = s.synonym_concept_code::VARCHAR
AND   lower(cs.synonym_name) = lower(BTRIM(REPLACE(s.synonym_name,CHR(160),' '),E' \t\r\n\f\v'))
AND   cs.language_concept_id = m.language_concept_id)
AND NOT EXISTS (SELECT 1 FROM concept_synonym cs
  JOIN concept c
    ON c.concept_id = cs.concept_id
   AND c.vocabulary_id = 'CIEL'
WHERE lower(cs.concept_synonym_name) = lower(BTRIM(REPLACE(s.synonym_name,CHR(160),' '),E' \t\r\n\f\v'))
AND   cs.language_concept_id = m.language_concept_id)
  );  -- 56986 

--5. Add automated mappings to concept_relationship_stage
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
SELECT DISTINCT
  a.source_code AS concept_code_1,
  a.target_concept_code AS concept_code_2,
  'CIEL' AS vocabulary_id_1,
  a.target_vocabulary_id AS vocabulary_id_2,
  a.relationship_id AS relationship_id,
  /* Prefer existing valid_start_date; otherwise use CIEL mapping version date */
  COALESCE(
    r.valid_start_date,
    to_date(btrim(b.version_updated_on::text), 'YYYY-MM-DD')
  ) AS valid_start_date,
  DATE '2099-12-31' AS valid_end_date,
  NULL::varchar AS invalid_reason
FROM maps_for_load_stage a
JOIN sources.ciel_mappings b
  ON btrim(b.from_concept_code) = btrim(a.source_code)
 AND b.retired IS FALSE
LEFT JOIN concept c
  ON c.concept_code   = a.source_code
 AND c.vocabulary_id  = 'CIEL'
LEFT JOIN concept_relationship r
  ON r.concept_id_1    = c.concept_id
 AND r.concept_id_2    = a.target_concept_id
 AND r.relationship_id = a.relationship_id
 AND r.invalid_reason IS NULL
WHERE a.target_concept_code IS NOT NULL
  AND a.relationship_id IS NOT NULL
  AND rank_num in (1, 2); -- 57950

--6. Remove relationships processed manually
DELETE
FROM concept_relationship_stage crs
WHERE EXISTS (SELECT 1
              FROM concept_relationship_manual crm
              WHERE crm.concept_code_1 = crs.concept_code_1
              AND   crm.vocabulary_id_1 = 'CIEL');

--7. Add manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--8. Add concept replacement mapping
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
WITH replacement_pairs AS (
  -- Retired CIEL concepts (c1) and their active replacements (c2)
  SELECT DISTINCT
    c1.concept_code AS old_code,
    c1.vocabulary_id AS old_vocab,
    c2.concept_code AS new_code,
    c2.vocabulary_id AS new_vocab
  FROM concept_stage c1
  JOIN concept_stage c2
    ON lower(btrim(c2.concept_name)) = lower(btrim(c1.concept_name))
   AND c1.vocabulary_id  = c2.vocabulary_id -- same vocab 
  WHERE c1.invalid_reason = 'U' -- retired
    AND c2.invalid_reason IS NULL -- active
    AND c1.concept_code <> c2.concept_code -- avoid self-pairs
),
-- 1) 'Concept replaced by' relationships: c1 -> c2
base_replacements AS (
  SELECT
    p.old_code AS concept_code_1,
    p.new_code AS concept_code_2,
    p.old_vocab AS vocabulary_id_1,
    p.new_vocab AS vocabulary_id_2,
    'Concept replaced by' AS relationship_id,
    v.latest_update::date AS valid_start_date,
    DATE '2099-12-31' AS valid_end_date,
    NULL::varchar AS invalid_reason
  FROM replacement_pairs p
  JOIN vocabulary v
    ON v.vocabulary_id = p.old_vocab
),
-- 2) Propagate all existing relationships from new concept (c2) to old concept (c1)
propagated_rels AS (
  SELECT
    p.old_code AS concept_code_1,
    r.concept_code_2,
    p.old_vocab AS vocabulary_id_1,
    r.vocabulary_id_2,
    r.relationship_id,
    r.valid_start_date,
    r.valid_end_date,
    r.invalid_reason
  FROM replacement_pairs p
  JOIN concept_relationship_stage r
    ON r.concept_code_1 = p.new_code
   AND r.vocabulary_id_1 = p.new_vocab
   AND r.invalid_reason IS NULL
)
SELECT * FROM base_replacements
UNION ALL
SELECT * FROM propagated_rels;

--9. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--10. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--11. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--12. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--13. Add and deprecate all relationships from the concept_relationship that do not exist in the concept_relationship_stage
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
  c.concept_code AS concept_code_1,
  d.concept_code AS concept_code_2,
  c.vocabulary_id AS vocabulary_id_1,
  d.vocabulary_id AS vocabulary_id_2,
  r.relationship_id AS relationship_id,
  r.valid_start_date,
  (CASE
     WHEN v.latest_update::date <= r.valid_start_date
       THEN r.valid_start_date + 1 -- safety: never end before start
     ELSE v.latest_update::date - 1 -- typical vocab approach
   END) AS valid_end_date,
  'D' AS invalid_reason
FROM concept_relationship r
JOIN concept c
  ON c.concept_id = r.concept_id_1
 AND c.vocabulary_id = 'CIEL'
JOIN concept d
  ON d.concept_id = r.concept_id_2
JOIN vocabulary v
  ON v.vocabulary_id = c.vocabulary_id
WHERE r.invalid_reason IS NULL
  AND r.relationship_id NOT IN ('Concept replaced by','Concept replaces')
  AND NOT EXISTS (
        SELECT 1
        FROM concept_relationship_stage s
        WHERE s.concept_code_1 = c.concept_code
          AND s.vocabulary_id_1 = c.vocabulary_id
          AND s.relationship_id = r.relationship_id
          AND s.concept_code_2 = d.concept_code
          AND s.vocabulary_id_2 = d.vocabulary_id
      );

SELECT * FROM qa_tests.Check_Stage_Tables(); -- should be empty

-- THE END
