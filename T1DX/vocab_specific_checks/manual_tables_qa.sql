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
* Authors: Maksym Trofymenko, Polina Talapova, Denys Kaduk
* Date: 2026
**************************************************************************/

/****************************************************************************************
 T1DX manual tables QA

 Purpose:
   Produce issue-level statistics for the T1DX manual staging tables:
     - t1dx_concept_manual
     - t1dx_concept_relationship_manual
     - t1dx_concept_synonym_manual

 Output:
   One row per QA check:
     - check_id
     - severity
     - issue_description
     - issue_count

 Notes:
   - This script does not modify data.
   - It assumes the CSV files have already been imported into the local staging tables.
   - The counts are intended for review before running manual_tables_insert.sql.
   - Some checks are strict errors; others are warnings requiring curator judgement.
****************************************************************************************/


WITH
/****************************************************************************************
 Configuration parameters.

 Adjust these values if T1DX conventions change.
****************************************************************************************/
params AS (
    SELECT
        'T1DX'::varchar(20) AS expected_vocabulary_id,
        'Module'::varchar(20) AS module_concept_class_id,

        /*
         Expected language concept for English.
         If the T1DX synonym layer intentionally uses another language, update this value.
        */
        4180186::integer AS expected_language_concept_id,

        /*
         Default OMOP-style valid_end_date for active records.
        */
        DATE '2099-12-31' AS default_valid_end_date,

        /*
         Relationship IDs treated as module-linking relationships for module coverage checks.
         Adjust if the T1DX model uses a different relationship convention.
        */
        ARRAY[
            'Is a',
            'Subsumes',
            'Has Module',
            'Module of'
        ]::varchar(20)[] AS module_relationship_ids
),


/****************************************************************************************
 Source aliases.
****************************************************************************************/
cm AS (
    SELECT *
    FROM t1dx_concept_manual
),

crm AS (
    SELECT *
    FROM t1dx_concept_relationship_manual
),

csm AS (
    SELECT *
    FROM t1dx_concept_synonym_manual
),


/****************************************************************************************
 Referenced concepts.

 Used to limit joins to the production concept table. This avoids scanning the entire
 concept table when checking external relationship and synonym endpoints.
****************************************************************************************/
referenced_codes AS (
    SELECT vocabulary_id, concept_code
    FROM cm

    UNION

    SELECT vocabulary_id_1 AS vocabulary_id, concept_code_1 AS concept_code
    FROM crm

    UNION

    SELECT vocabulary_id_2 AS vocabulary_id, concept_code_2 AS concept_code
    FROM crm

    UNION

    SELECT synonym_vocabulary_id AS vocabulary_id, synonym_concept_code AS concept_code
    FROM csm
),


/****************************************************************************************
 Combined concept lookup.

 Includes:
   - current T1DX manual concepts from the staging table;
   - already existing concepts from the vocabulary concept table that are referenced
     by relationships or synonyms.

 This is used for endpoint resolution and mapping target checks.
****************************************************************************************/
concept_space_raw AS (
    SELECT
        vocabulary_id,
        concept_code,
        concept_name,
        domain_id,
        concept_class_id,
        standard_concept,
        valid_start_date,
        valid_end_date,
        invalid_reason
    FROM cm

    UNION ALL

    SELECT
        c.vocabulary_id,
        c.concept_code,
        c.concept_name,
        c.domain_id,
        c.concept_class_id,
        c.standard_concept,
        c.valid_start_date,
        c.valid_end_date,
        c.invalid_reason
    FROM concept c
    JOIN referenced_codes rc
      ON rc.vocabulary_id = c.vocabulary_id
     AND rc.concept_code = c.concept_code
),

concept_space AS (
    SELECT
        vocabulary_id,
        concept_code,

        bool_or(NULLIF(btrim(invalid_reason), '') IS NULL) AS has_active_version,

        bool_or(
            standard_concept = 'S'
            AND NULLIF(btrim(invalid_reason), '') IS NULL
        ) AS has_active_standard_concept,

        bool_or(
            standard_concept = 'C'
            AND NULLIF(btrim(invalid_reason), '') IS NULL
        ) AS has_active_classification_concept,

        bool_or(
            concept_class_id = (SELECT module_concept_class_id FROM params)
            AND NULLIF(btrim(invalid_reason), '') IS NULL
        ) AS is_active_module,

        min(concept_name) AS representative_concept_name
    FROM concept_space_raw
    GROUP BY vocabulary_id, concept_code
),


/****************************************************************************************
 QA checks.
****************************************************************************************/
checks AS (

    /************************************************************************************
     A. Structural checks: concept_manual
    ************************************************************************************/

    SELECT
        'CM001' AS check_id,
        'ERROR' AS severity,
        'concept_manual: duplicate concept keys by vocabulary_id + concept_code' AS issue_description,
        count(*)::bigint AS issue_count
    FROM (
        SELECT vocabulary_id, concept_code
        FROM cm
        GROUP BY vocabulary_id, concept_code
        HAVING count(*) > 1
    ) x

    UNION ALL

    SELECT
        'CM002',
        'ERROR',
        'concept_manual: exact duplicate rows',
        count(*)::bigint
    FROM (
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
        FROM cm
        GROUP BY
            concept_name,
            domain_id,
            vocabulary_id,
            concept_class_id,
            standard_concept,
            concept_code,
            valid_start_date,
            valid_end_date,
            invalid_reason
        HAVING count(*) > 1
    ) x

    UNION ALL

    SELECT
        'CM003',
        'ERROR',
        'concept_manual: same vocabulary_id + concept_code has different name/domain/class/status/date attributes',
        count(*)::bigint
    FROM (
        SELECT vocabulary_id, concept_code
        FROM cm
        GROUP BY vocabulary_id, concept_code
        HAVING count(DISTINCT concat_ws(
            '¦',
            concept_name,
            domain_id,
            concept_class_id,
            coalesce(standard_concept, '<NULL>'),
            valid_start_date::text,
            valid_end_date::text,
            coalesce(invalid_reason, '<NULL>')
        )) > 1
    ) x

    UNION ALL

    SELECT
        'CM004',
        'WARNING',
        'concept_manual: same concept_name is used with multiple concept_codes',
        count(*)::bigint
    FROM (
        SELECT vocabulary_id, lower(btrim(concept_name)) AS normalized_concept_name
        FROM cm
        GROUP BY vocabulary_id, lower(btrim(concept_name))
        HAVING count(DISTINCT concept_code) > 1
    ) x

    UNION ALL

    SELECT
        'CM005',
        'WARNING',
        'concept_manual: same concept_name is used across multiple domains or classes',
        count(*)::bigint
    FROM (
        SELECT vocabulary_id, lower(btrim(concept_name)) AS normalized_concept_name
        FROM cm
        GROUP BY vocabulary_id, lower(btrim(concept_name))
        HAVING count(DISTINCT domain_id) > 1
            OR count(DISTINCT concept_class_id) > 1
    ) x

    UNION ALL

    SELECT
        'CM006',
        'ERROR',
        'concept_manual: vocabulary_id differs from expected T1DX vocabulary_id',
        count(*)::bigint
    FROM cm
    CROSS JOIN params p
    WHERE vocabulary_id <> p.expected_vocabulary_id

    UNION ALL

    SELECT
        'CM007',
        'ERROR',
        'concept_manual: likely vocabulary spelling/case error for T1DX',
        count(*)::bigint
    FROM cm
    CROSS JOIN params p
    WHERE lower(vocabulary_id) = lower(p.expected_vocabulary_id)
      AND vocabulary_id <> p.expected_vocabulary_id

    UNION ALL

    SELECT
        'CM008',
        'ERROR',
        'concept_manual: domain_id does not exist in domain table',
        count(*)::bigint
    FROM cm c
    LEFT JOIN domain d
      ON d.domain_id = c.domain_id
    WHERE d.domain_id IS NULL

    UNION ALL

    SELECT
        'CM009',
        'ERROR',
        'concept_manual: concept_class_id does not exist in concept_class table',
        count(*)::bigint
    FROM cm c
    LEFT JOIN concept_class cc
      ON cc.concept_class_id = c.concept_class_id
    WHERE cc.concept_class_id IS NULL

    UNION ALL

    SELECT
        'CM010',
        'ERROR',
        'concept_manual: vocabulary_id does not exist in vocabulary table',
        count(*)::bigint
    FROM cm c
    LEFT JOIN vocabulary v
      ON v.vocabulary_id = c.vocabulary_id
    WHERE v.vocabulary_id IS NULL

    UNION ALL

    SELECT
        'CM011',
        'ERROR',
        'concept_manual: valid_start_date is greater than valid_end_date',
        count(*)::bigint
    FROM cm
    WHERE valid_start_date > valid_end_date

    UNION ALL

    SELECT
        'CM012',
        'ERROR',
        'concept_manual: invalid_reason has disallowed value',
        count(*)::bigint
    FROM cm
    WHERE NULLIF(btrim(invalid_reason), '') IS NOT NULL
      AND invalid_reason NOT IN ('D', 'U')

    UNION ALL

    SELECT
        'CM013',
        'ERROR',
        'concept_manual: standard_concept has disallowed value',
        count(*)::bigint
    FROM cm
    WHERE NULLIF(btrim(standard_concept), '') IS NOT NULL
      AND standard_concept NOT IN ('S', 'C')

    UNION ALL

    SELECT
        'CM014',
        'WARNING',
        'concept_manual: active concept has non-default valid_end_date',
        count(*)::bigint
    FROM cm
    CROSS JOIN params p
    WHERE NULLIF(btrim(invalid_reason), '') IS NULL
      AND valid_end_date <> p.default_valid_end_date

    UNION ALL

    SELECT
        'CM015',
        'WARNING',
        'concept_manual: invalid concept has default future valid_end_date',
        count(*)::bigint
    FROM cm
    CROSS JOIN params p
    WHERE NULLIF(btrim(invalid_reason), '') IS NOT NULL
      AND valid_end_date = p.default_valid_end_date

    UNION ALL

    SELECT
        'CM016',
        'WARNING',
        'concept_manual: concept_name has leading or trailing spaces',
        count(*)::bigint
    FROM cm
    WHERE concept_name <> btrim(concept_name)

    UNION ALL

    SELECT
        'CM017',
        'WARNING',
        'concept_manual: concept_code has leading, trailing, or internal whitespace',
        count(*)::bigint
    FROM cm
    WHERE concept_code <> btrim(concept_code)
       OR concept_code ~ '[[:space:]]'

    UNION ALL

    SELECT
        'CM018',
        'WARNING',
        'concept_manual: concept_name contains repeated whitespace',
        count(*)::bigint
    FROM cm
    WHERE concept_name ~ '[[:space:]]{2,}'

    UNION ALL

    SELECT
        'CM019',
        'WARNING',
        'concept_manual: concept_name contains control characters, replacement characters, or HTML-like tags',
        count(*)::bigint
    FROM cm
    WHERE concept_name ~ '[[:cntrl:]]'
       OR concept_name LIKE '%�%'
       OR concept_name ~ '<[^>]+>'

    UNION ALL

    SELECT
        'CM020',
        'WARNING',
        'concept_manual: concept_name contains Excel/null-like placeholder values',
        count(*)::bigint
    FROM cm
    WHERE lower(btrim(concept_name)) IN ('#n/a', 'n/a', 'na', 'null', 'none', 'nan', 'tbd')

    UNION ALL

    SELECT
        'CM021',
        'WARNING',
        'concept_manual: concept_name is identical or nearly identical to concept_code',
        count(*)::bigint
    FROM cm
    WHERE regexp_replace(lower(btrim(concept_name)), '[^[:alnum:]]+', '', 'g')
        = regexp_replace(lower(btrim(concept_code)), '[^[:alnum:]]+', '', 'g')

    UNION ALL

    SELECT
        'CM022',
        'WARNING',
        'concept_manual: concept_name has unbalanced parentheses',
        count(*)::bigint
    FROM cm
    WHERE
        length(concept_name) - length(replace(concept_name, '(', ''))
        <>
        length(concept_name) - length(replace(concept_name, ')', ''))


    /************************************************************************************
     B. Structural checks: concept_relationship_manual
    ************************************************************************************/

    UNION ALL

    SELECT
        'CRM001',
        'ERROR',
        'concept_relationship_manual: duplicate relationship keys',
        count(*)::bigint
    FROM (
        SELECT
            concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id
        FROM crm
        GROUP BY
            concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id
        HAVING count(*) > 1
    ) x

    UNION ALL

    SELECT
        'CRM002',
        'ERROR',
        'concept_relationship_manual: exact duplicate rows',
        count(*)::bigint
    FROM (
        SELECT
            concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id,
            valid_start_date,
            valid_end_date,
            invalid_reason
        FROM crm
        GROUP BY
            concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id,
            valid_start_date,
            valid_end_date,
            invalid_reason
        HAVING count(*) > 1
    ) x

    UNION ALL

    SELECT
        'CRM003',
        'ERROR',
        'concept_relationship_manual: same relationship key has different dates or invalid_reason',
        count(*)::bigint
    FROM (
        SELECT
            concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id
        FROM crm
        GROUP BY
            concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id
        HAVING count(DISTINCT concat_ws(
            '¦',
            valid_start_date::text,
            valid_end_date::text,
            coalesce(invalid_reason, '<NULL>')
        )) > 1
    ) x

    UNION ALL

    SELECT
        'CRM004',
        'ERROR',
        'concept_relationship_manual: relationship row has no T1DX endpoint',
        count(*)::bigint
    FROM crm
    CROSS JOIN params p
    WHERE vocabulary_id_1 <> p.expected_vocabulary_id
      AND vocabulary_id_2 <> p.expected_vocabulary_id

    UNION ALL

    SELECT
        'CRM005',
        'ERROR',
        'concept_relationship_manual: likely T1DX vocabulary spelling/case error in relationship endpoint',
        count(*)::bigint
    FROM crm
    CROSS JOIN params p
    WHERE (
            lower(vocabulary_id_1) = lower(p.expected_vocabulary_id)
            AND vocabulary_id_1 <> p.expected_vocabulary_id
          )
       OR (
            lower(vocabulary_id_2) = lower(p.expected_vocabulary_id)
            AND vocabulary_id_2 <> p.expected_vocabulary_id
          )

    UNION ALL

    SELECT
        'CRM006',
        'ERROR',
        'concept_relationship_manual: vocabulary_id_1 does not exist in vocabulary table',
        count(*)::bigint
    FROM crm r
    LEFT JOIN vocabulary v
      ON v.vocabulary_id = r.vocabulary_id_1
    WHERE v.vocabulary_id IS NULL

    UNION ALL

    SELECT
        'CRM007',
        'ERROR',
        'concept_relationship_manual: vocabulary_id_2 does not exist in vocabulary table',
        count(*)::bigint
    FROM crm r
    LEFT JOIN vocabulary v
      ON v.vocabulary_id = r.vocabulary_id_2
    WHERE v.vocabulary_id IS NULL

    UNION ALL

    SELECT
        'CRM008',
        'ERROR',
        'concept_relationship_manual: relationship_id does not exist in relationship table',
        count(*)::bigint
    FROM crm r
    LEFT JOIN relationship rel
      ON rel.relationship_id = r.relationship_id
    WHERE rel.relationship_id IS NULL

    UNION ALL

    SELECT
        'CRM009',
        'ERROR',
        'concept_relationship_manual: valid_start_date is greater than valid_end_date',
        count(*)::bigint
    FROM crm
    WHERE valid_start_date > valid_end_date

    UNION ALL

    SELECT
        'CRM010',
        'ERROR',
        'concept_relationship_manual: invalid_reason has disallowed value',
        count(*)::bigint
    FROM crm
    WHERE NULLIF(btrim(invalid_reason), '') IS NOT NULL
      AND invalid_reason NOT IN ('D', 'U')

    UNION ALL

    SELECT
        'CRM011',
        'WARNING',
        'concept_relationship_manual: active relationship has non-default valid_end_date',
        count(*)::bigint
    FROM crm
    CROSS JOIN params p
    WHERE NULLIF(btrim(invalid_reason), '') IS NULL
      AND valid_end_date <> p.default_valid_end_date

    UNION ALL

    SELECT
        'CRM012',
        'WARNING',
        'concept_relationship_manual: invalid relationship has default future valid_end_date',
        count(*)::bigint
    FROM crm
    CROSS JOIN params p
    WHERE NULLIF(btrim(invalid_reason), '') IS NOT NULL
      AND valid_end_date = p.default_valid_end_date

    UNION ALL

    SELECT
        'CRM013',
        'ERROR',
        'concept_relationship_manual: concept_code_1/vocabulary_id_1 endpoint cannot be resolved in concept_manual or concept',
        count(*)::bigint
    FROM crm r
    WHERE NOT EXISTS (
        SELECT 1
        FROM concept_space cs
        WHERE cs.vocabulary_id = r.vocabulary_id_1
          AND cs.concept_code = r.concept_code_1
    )

    UNION ALL

    SELECT
        'CRM014',
        'ERROR',
        'concept_relationship_manual: concept_code_2/vocabulary_id_2 endpoint cannot be resolved in concept_manual or concept',
        count(*)::bigint
    FROM crm r
    WHERE NOT EXISTS (
        SELECT 1
        FROM concept_space cs
        WHERE cs.vocabulary_id = r.vocabulary_id_2
          AND cs.concept_code = r.concept_code_2
    )

    UNION ALL

    SELECT
        'CRM015',
        'ERROR',
        'concept_relationship_manual: T1DX endpoint in vocabulary_id_1 is absent from t1dx_concept_manual',
        count(*)::bigint
    FROM crm r
    CROSS JOIN params p
    WHERE r.vocabulary_id_1 = p.expected_vocabulary_id
      AND NOT EXISTS (
          SELECT 1
          FROM cm c
          WHERE c.vocabulary_id = r.vocabulary_id_1
            AND c.concept_code = r.concept_code_1
      )

    UNION ALL

    SELECT
        'CRM016',
        'ERROR',
        'concept_relationship_manual: T1DX endpoint in vocabulary_id_2 is absent from t1dx_concept_manual',
        count(*)::bigint
    FROM crm r
    CROSS JOIN params p
    WHERE r.vocabulary_id_2 = p.expected_vocabulary_id
      AND NOT EXISTS (
          SELECT 1
          FROM cm c
          WHERE c.vocabulary_id = r.vocabulary_id_2
            AND c.concept_code = r.concept_code_2
      )

    UNION ALL

    SELECT
        'CRM017',
        'WARNING',
        'concept_relationship_manual: self-relationship other than Maps to',
        count(*)::bigint
    FROM crm
    WHERE vocabulary_id_1 = vocabulary_id_2
      AND concept_code_1 = concept_code_2
      AND relationship_id <> 'Maps to'

    /************************************************************************************
     C. Mapping semantics
    ************************************************************************************/

    UNION ALL

    SELECT
        'MAP001',
        'ERROR',
        'mapping: active non-standard T1DX concept has no active Maps to relationship to an active standard concept',
        count(*)::bigint
    FROM cm c
    CROSS JOIN params p
    WHERE c.vocabulary_id = p.expected_vocabulary_id
      AND NULLIF(btrim(c.invalid_reason), '') IS NULL
      AND NULLIF(btrim(c.standard_concept), '') IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM crm r
          JOIN concept_space target
            ON target.vocabulary_id = r.vocabulary_id_2
           AND target.concept_code = r.concept_code_2
          WHERE r.vocabulary_id_1 = c.vocabulary_id
            AND r.concept_code_1 = c.concept_code
            AND r.relationship_id = 'Maps to'
            AND NULLIF(btrim(r.invalid_reason), '') IS NULL
            AND target.has_active_standard_concept = true
      )

    UNION ALL

    SELECT
        'MAP002',
        'ERROR',
        'mapping: active standard T1DX concept has no active self Maps to relationship',
        count(*)::bigint
    FROM cm c
    CROSS JOIN params p
    WHERE c.vocabulary_id = p.expected_vocabulary_id
      AND NULLIF(btrim(c.invalid_reason), '') IS NULL
      AND c.standard_concept = 'S'
      AND NOT EXISTS (
          SELECT 1
          FROM crm r
          WHERE r.vocabulary_id_1 = c.vocabulary_id
            AND r.concept_code_1 = c.concept_code
            AND r.vocabulary_id_2 = c.vocabulary_id
            AND r.concept_code_2 = c.concept_code
            AND r.relationship_id = 'Maps to'
            AND NULLIF(btrim(r.invalid_reason), '') IS NULL
      )

    UNION ALL

    SELECT
        'MAP003',
        'ERROR',
        'mapping: active Maps to relationship from T1DX points to missing, inactive, or non-standard target',
        count(*)::bigint
    FROM crm r
    CROSS JOIN params p
    LEFT JOIN concept_space target
      ON target.vocabulary_id = r.vocabulary_id_2
     AND target.concept_code = r.concept_code_2
    WHERE r.vocabulary_id_1 = p.expected_vocabulary_id
      AND r.relationship_id = 'Maps to'
      AND NULLIF(btrim(r.invalid_reason), '') IS NULL
      AND coalesce(target.has_active_standard_concept, false) = false

    UNION ALL

    SELECT
        'MAP004',
        'WARNING',
        'mapping: active standard T1DX concept maps to a different concept instead of only itself',
        count(*)::bigint
    FROM cm c
    CROSS JOIN params p
    WHERE c.vocabulary_id = p.expected_vocabulary_id
      AND c.standard_concept = 'S'
      AND NULLIF(btrim(c.invalid_reason), '') IS NULL
      AND EXISTS (
          SELECT 1
          FROM crm r
          WHERE r.vocabulary_id_1 = c.vocabulary_id
            AND r.concept_code_1 = c.concept_code
            AND r.relationship_id = 'Maps to'
            AND NULLIF(btrim(r.invalid_reason), '') IS NULL
            AND (
                r.vocabulary_id_2 <> c.vocabulary_id
                OR r.concept_code_2 <> c.concept_code
            )
      )

    UNION ALL

    SELECT
        'MAP005',
        'WARNING',
        'mapping: active non-standard T1DX concept maps to itself',
        count(*)::bigint
    FROM cm c
    CROSS JOIN params p
    JOIN crm r
      ON r.vocabulary_id_1 = c.vocabulary_id
     AND r.concept_code_1 = c.concept_code
     AND r.vocabulary_id_2 = c.vocabulary_id
     AND r.concept_code_2 = c.concept_code
     AND r.relationship_id = 'Maps to'
     AND NULLIF(btrim(r.invalid_reason), '') IS NULL
    WHERE c.vocabulary_id = p.expected_vocabulary_id
      AND NULLIF(btrim(c.invalid_reason), '') IS NULL
      AND NULLIF(btrim(c.standard_concept), '') IS NULL

    UNION ALL

    SELECT
        'MAP006',
        'WARNING',
        'mapping: active T1DX source concept has multiple active Maps to targets',
        count(*)::bigint
    FROM (
        SELECT
            r.vocabulary_id_1,
            r.concept_code_1
        FROM crm r
        CROSS JOIN params p
        WHERE r.vocabulary_id_1 = p.expected_vocabulary_id
          AND r.relationship_id = 'Maps to'
          AND NULLIF(btrim(r.invalid_reason), '') IS NULL
        GROUP BY r.vocabulary_id_1, r.concept_code_1
        HAVING count(DISTINCT r.vocabulary_id_2 || '|' || r.concept_code_2) > 1
    ) x

    UNION ALL

    SELECT
        'MAP007',
        'WARNING',
        'mapping: active relationship uses inactive T1DX concept as source or target',
        count(*)::bigint
    FROM crm r
    CROSS JOIN params p
    WHERE NULLIF(btrim(r.invalid_reason), '') IS NULL
      AND (
          EXISTS (
              SELECT 1
              FROM cm c
              WHERE c.vocabulary_id = r.vocabulary_id_1
                AND c.concept_code = r.concept_code_1
                AND c.vocabulary_id = p.expected_vocabulary_id
                AND NULLIF(btrim(c.invalid_reason), '') IS NOT NULL
          )
          OR EXISTS (
              SELECT 1
              FROM cm c
              WHERE c.vocabulary_id = r.vocabulary_id_2
                AND c.concept_code = r.concept_code_2
                AND c.vocabulary_id = p.expected_vocabulary_id
                AND NULLIF(btrim(c.invalid_reason), '') IS NOT NULL
          )
      )


    /************************************************************************************
     D. Synonym checks
    ************************************************************************************/

    UNION ALL

    SELECT
        'CSM001',
        'ERROR',
        'concept_synonym_manual: duplicate synonym keys',
        count(*)::bigint
    FROM (
        SELECT
            synonym_name,
            synonym_concept_code,
            synonym_vocabulary_id,
            language_concept_id
        FROM csm
        GROUP BY
            synonym_name,
            synonym_concept_code,
            synonym_vocabulary_id,
            language_concept_id
        HAVING count(*) > 1
    ) x

    UNION ALL

    SELECT
        'CSM002',
        'ERROR',
        'concept_synonym_manual: synonym_vocabulary_id differs from expected T1DX vocabulary_id',
        count(*)::bigint
    FROM csm
    CROSS JOIN params p
    WHERE synonym_vocabulary_id <> p.expected_vocabulary_id

    UNION ALL

    SELECT
        'CSM003',
        'ERROR',
        'concept_synonym_manual: likely T1DX vocabulary spelling/case error in synonym_vocabulary_id',
        count(*)::bigint
    FROM csm
    CROSS JOIN params p
    WHERE lower(synonym_vocabulary_id) = lower(p.expected_vocabulary_id)
      AND synonym_vocabulary_id <> p.expected_vocabulary_id

    UNION ALL

    SELECT
        'CSM004',
        'ERROR',
        'concept_synonym_manual: synonym concept endpoint cannot be resolved in concept_manual or concept',
        count(*)::bigint
    FROM csm s
    WHERE NOT EXISTS (
        SELECT 1
        FROM concept_space cs
        WHERE cs.vocabulary_id = s.synonym_vocabulary_id
          AND cs.concept_code = s.synonym_concept_code
    )

    UNION ALL

    SELECT
        'CSM005',
        'ERROR',
        'concept_synonym_manual: T1DX synonym endpoint is absent from t1dx_concept_manual',
        count(*)::bigint
    FROM csm s
    CROSS JOIN params p
    WHERE s.synonym_vocabulary_id = p.expected_vocabulary_id
      AND NOT EXISTS (
          SELECT 1
          FROM cm c
          WHERE c.vocabulary_id = s.synonym_vocabulary_id
            AND c.concept_code = s.synonym_concept_code
      )

    UNION ALL

    SELECT
        'CSM006',
        'WARNING',
        'concept_synonym_manual: language_concept_id differs from expected language concept',
        count(*)::bigint
    FROM csm
    CROSS JOIN params p
    WHERE language_concept_id <> p.expected_language_concept_id

    UNION ALL

    SELECT
        'CSM007',
        'ERROR',
        'concept_synonym_manual: language_concept_id does not exist in concept table',
        count(*)::bigint
    FROM csm s
    LEFT JOIN concept lang
      ON lang.concept_id = s.language_concept_id
    WHERE lang.concept_id IS NULL

    UNION ALL

    SELECT
        'CSM008',
        'WARNING',
        'concept_synonym_manual: language_concept_id is not in Language domain or is inactive',
        count(*)::bigint
    FROM csm s
    JOIN concept lang
      ON lang.concept_id = s.language_concept_id
    WHERE lang.domain_id <> 'Language'
       OR lang.invalid_reason IS NOT NULL

    UNION ALL

    SELECT
        'CSM009',
        'WARNING',
        'concept_synonym_manual: synonym_name has leading or trailing spaces',
        count(*)::bigint
    FROM csm
    WHERE synonym_name <> btrim(synonym_name)

    UNION ALL

    SELECT
        'CSM010',
        'WARNING',
        'concept_synonym_manual: synonym_name contains repeated whitespace',
        count(*)::bigint
    FROM csm
    WHERE synonym_name ~ '[[:space:]]{2,}'

    UNION ALL

    SELECT
        'CSM011',
        'WARNING',
        'concept_synonym_manual: synonym_name contains control characters, replacement characters, or HTML-like tags',
        count(*)::bigint
    FROM csm
    WHERE synonym_name ~ '[[:cntrl:]]'
       OR synonym_name LIKE '%�%'
       OR synonym_name ~ '<[^>]+>'

    UNION ALL

    SELECT
        'CSM012',
        'WARNING',
        'concept_synonym_manual: synonym_name is identical or nearly identical to concept_name',
        count(*)::bigint
    FROM csm s
    JOIN cm c
      ON c.vocabulary_id = s.synonym_vocabulary_id
     AND c.concept_code = s.synonym_concept_code
    WHERE regexp_replace(lower(btrim(s.synonym_name)), '[^[:alnum:]]+', '', 'g')
        = regexp_replace(lower(btrim(c.concept_name)), '[^[:alnum:]]+', '', 'g')

    UNION ALL

    SELECT
        'CSM013',
        'WARNING',
        'concept_synonym_manual: synonym_name is identical or nearly identical to concept_code',
        count(*)::bigint
    FROM csm s
    WHERE regexp_replace(lower(btrim(s.synonym_name)), '[^[:alnum:]]+', '', 'g')
        = regexp_replace(lower(btrim(s.synonym_concept_code)), '[^[:alnum:]]+', '', 'g')

    UNION ALL

    SELECT
        'CSM014',
        'WARNING',
        'concept_synonym_manual: normalized duplicate synonym for the same concept and language',
        count(*)::bigint
    FROM (
        SELECT
            synonym_vocabulary_id,
            synonym_concept_code,
            language_concept_id,
            regexp_replace(lower(btrim(synonym_name)), '[^[:alnum:]]+', '', 'g') AS normalized_synonym
        FROM csm
        GROUP BY
            synonym_vocabulary_id,
            synonym_concept_code,
            language_concept_id,
            regexp_replace(lower(btrim(synonym_name)), '[^[:alnum:]]+', '', 'g')
        HAVING count(*) > 1
    ) x

    UNION ALL

    SELECT
        'CSM015',
        'WARNING',
        'concept_synonym_manual: same synonym text is assigned to multiple T1DX concepts',
        count(*)::bigint
    FROM (
        SELECT
            synonym_vocabulary_id,
            lower(btrim(synonym_name)) AS normalized_synonym_name
        FROM csm
        CROSS JOIN params p
        WHERE synonym_vocabulary_id = p.expected_vocabulary_id
        GROUP BY synonym_vocabulary_id, lower(btrim(synonym_name))
        HAVING count(DISTINCT synonym_concept_code) > 1
    ) x

    UNION ALL

    SELECT
        'CSM016',
        'WARNING',
        'concept_synonym_manual: synonym attached to inactive T1DX concept',
        count(*)::bigint
    FROM csm s
    JOIN cm c
      ON c.vocabulary_id = s.synonym_vocabulary_id
     AND c.concept_code = s.synonym_concept_code
    WHERE NULLIF(btrim(c.invalid_reason), '') IS NOT NULL


    /************************************************************************************
     E. Cross-table coverage checks
    ************************************************************************************/

    UNION ALL

    SELECT
        'X001',
        'WARNING',
        'cross-table: active T1DX concept is not referenced by any relationship',
        count(*)::bigint
    FROM cm c
    CROSS JOIN params p
    WHERE c.vocabulary_id = p.expected_vocabulary_id
      AND NULLIF(btrim(c.invalid_reason), '') IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM crm r
          WHERE (
                  r.vocabulary_id_1 = c.vocabulary_id
              AND r.concept_code_1 = c.concept_code
          )
          OR (
                  r.vocabulary_id_2 = c.vocabulary_id
              AND r.concept_code_2 = c.concept_code
          )
      )

    UNION ALL

    SELECT
        'X002',
        'WARNING',
        'cross-table: active T1DX concept has no synonym', -- it is fine, but make sure that the output is expected for you
        count(*)::bigint
    FROM cm c
    CROSS JOIN params p
    WHERE c.vocabulary_id = p.expected_vocabulary_id
      AND NULLIF(btrim(c.invalid_reason), '') IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM csm s
          WHERE s.synonym_vocabulary_id = c.vocabulary_id
            AND s.synonym_concept_code = c.concept_code
      )

    UNION ALL

    SELECT
        'X003',
        'WARNING',
        'cross-table: active T1DX concept is absent from both relationship and synonym manual tables',
        count(*)::bigint
    FROM cm c
    CROSS JOIN params p
    WHERE c.vocabulary_id = p.expected_vocabulary_id
      AND NULLIF(btrim(c.invalid_reason), '') IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM crm r
          WHERE (
                  r.vocabulary_id_1 = c.vocabulary_id
              AND r.concept_code_1 = c.concept_code
          )
          OR (
                  r.vocabulary_id_2 = c.vocabulary_id
              AND r.concept_code_2 = c.concept_code
          )
      )
      AND NOT EXISTS (
          SELECT 1
          FROM csm s
          WHERE s.synonym_vocabulary_id = c.vocabulary_id
            AND s.synonym_concept_code = c.concept_code
      )

    UNION ALL

    SELECT
        'X004',
        'ERROR',
        'cross-table: relationship references T1DX concept absent from concept_manual',
        count(*)::bigint
    FROM crm r
    CROSS JOIN params p
    WHERE (
            r.vocabulary_id_1 = p.expected_vocabulary_id
            AND NOT EXISTS (
                SELECT 1
                FROM cm c
                WHERE c.vocabulary_id = r.vocabulary_id_1
                  AND c.concept_code = r.concept_code_1
            )
          )
       OR (
            r.vocabulary_id_2 = p.expected_vocabulary_id
            AND NOT EXISTS (
                SELECT 1
                FROM cm c
                WHERE c.vocabulary_id = r.vocabulary_id_2
                  AND c.concept_code = r.concept_code_2
            )
          )

    UNION ALL

    SELECT
        'X005',
        'ERROR',
        'cross-table: synonym references T1DX concept absent from concept_manual',
        count(*)::bigint
    FROM csm s
    CROSS JOIN params p
    WHERE s.synonym_vocabulary_id = p.expected_vocabulary_id
      AND NOT EXISTS (
          SELECT 1
          FROM cm c
          WHERE c.vocabulary_id = s.synonym_vocabulary_id
            AND c.concept_code = s.synonym_concept_code
      )


    /************************************************************************************
     F. Module relationship checks

     These checks assume that module concepts are represented in concept_manual with
     concept_class_id = params.module_concept_class_id, and that module membership is
     expressed using one of params.module_relationship_ids.

     If T1DX uses different module conventions, update params above.
    ************************************************************************************/

    UNION ALL

    SELECT
        'MOD001',
        'WARNING',
        'module: active non-module T1DX concept has no active relationship to a T1DX Module concept',
        count(*)::bigint
    FROM cm c
    CROSS JOIN params p
    WHERE c.vocabulary_id = p.expected_vocabulary_id
      AND NULLIF(btrim(c.invalid_reason), '') IS NULL
      AND c.concept_class_id <> p.module_concept_class_id
      AND NOT EXISTS (
          SELECT 1
          FROM crm r
          JOIN cm m
            ON (
                    m.vocabulary_id = r.vocabulary_id_2
                AND m.concept_code = r.concept_code_2
                AND r.vocabulary_id_1 = c.vocabulary_id
                AND r.concept_code_1 = c.concept_code
               )
            OR (
                    m.vocabulary_id = r.vocabulary_id_1
                AND m.concept_code = r.concept_code_1
                AND r.vocabulary_id_2 = c.vocabulary_id
                AND r.concept_code_2 = c.concept_code
               )
          WHERE m.vocabulary_id = p.expected_vocabulary_id
            AND m.concept_class_id = p.module_concept_class_id
            AND NULLIF(btrim(m.invalid_reason), '') IS NULL
            AND NULLIF(btrim(r.invalid_reason), '') IS NULL
            AND r.relationship_id = ANY (p.module_relationship_ids)
      )

    UNION ALL

    SELECT
        'MOD002',
        'WARNING',
        'module: active T1DX Module concept has no active relationship to any non-module T1DX concept',
        count(*)::bigint
    FROM cm m
    CROSS JOIN params p
    WHERE m.vocabulary_id = p.expected_vocabulary_id
      AND NULLIF(btrim(m.invalid_reason), '') IS NULL
      AND m.concept_class_id = p.module_concept_class_id
      AND NOT EXISTS (
          SELECT 1
          FROM crm r
          JOIN cm c
            ON (
                    c.vocabulary_id = r.vocabulary_id_2
                AND c.concept_code = r.concept_code_2
                AND r.vocabulary_id_1 = m.vocabulary_id
                AND r.concept_code_1 = m.concept_code
               )
            OR (
                    c.vocabulary_id = r.vocabulary_id_1
                AND c.concept_code = r.concept_code_1
                AND r.vocabulary_id_2 = m.vocabulary_id
                AND r.concept_code_2 = m.concept_code
               )
          WHERE c.vocabulary_id = p.expected_vocabulary_id
            AND c.concept_class_id <> p.module_concept_class_id
            AND NULLIF(btrim(c.invalid_reason), '') IS NULL
            AND NULLIF(btrim(r.invalid_reason), '') IS NULL
            AND r.relationship_id = ANY (p.module_relationship_ids)
      )

    UNION ALL

    SELECT
        'MOD003',
        'WARNING',
        'module: relationship_id configured as module relationship but neither endpoint is a Module concept',
        count(*)::bigint
    FROM crm r
    CROSS JOIN params p
    WHERE r.relationship_id = ANY (p.module_relationship_ids)
      AND NULLIF(btrim(r.invalid_reason), '') IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM cm m
          WHERE m.vocabulary_id = p.expected_vocabulary_id
            AND m.concept_class_id = p.module_concept_class_id
            AND NULLIF(btrim(m.invalid_reason), '') IS NULL
            AND (
                (
                    m.vocabulary_id = r.vocabulary_id_1
                    AND m.concept_code = r.concept_code_1
                )
                OR
                (
                    m.vocabulary_id = r.vocabulary_id_2
                    AND m.concept_code = r.concept_code_2
                )
            )
      )


    /************************************************************************************
     G. Additional curation heuristics
    ************************************************************************************/

    UNION ALL

    SELECT
        'CUR001',
        'WARNING',
        'curation: concept_name looks like a list of synonyms or multiple labels',
        count(*)::bigint
    FROM cm
    WHERE concept_name LIKE '%;%;%'
       OR concept_name LIKE '%||%'
       OR concept_name ~ '[[:space:]]/[[:space:]]'

    UNION ALL

    SELECT
        'CUR002',
        'WARNING',
        'curation: concept_name contains smart quotes or typography artifacts',
        count(*)::bigint
    FROM cm
    WHERE concept_name ~ '[“”‘’]'

    UNION ALL

    SELECT
        'CUR003',
        'WARNING',
        'curation: synonym_name contains smart quotes or typography artifacts',
        count(*)::bigint
    FROM csm
    WHERE synonym_name ~ '[“”‘’]'

    UNION ALL

    SELECT
        'CUR004',
        'WARNING',
        'curation: active T1DX concept has no active relationship of any type',
        count(*)::bigint
    FROM cm c
    CROSS JOIN params p
    WHERE c.vocabulary_id = p.expected_vocabulary_id
      AND NULLIF(btrim(c.invalid_reason), '') IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM crm r
          WHERE NULLIF(btrim(r.invalid_reason), '') IS NULL
            AND (
                (
                    r.vocabulary_id_1 = c.vocabulary_id
                    AND r.concept_code_1 = c.concept_code
                )
                OR
                (
                    r.vocabulary_id_2 = c.vocabulary_id
                    AND r.concept_code_2 = c.concept_code
                )
            )
      )

    UNION ALL

    SELECT
        'CUR005',
        'WARNING',
        'curation: active T1DX concept has no active Maps to relationship as source',
        count(*)::bigint
    FROM cm c
    CROSS JOIN params p
    WHERE c.vocabulary_id = p.expected_vocabulary_id
      AND NULLIF(btrim(c.invalid_reason), '') IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM crm r
          WHERE r.vocabulary_id_1 = c.vocabulary_id
            AND r.concept_code_1 = c.concept_code
            AND r.relationship_id = 'Maps to'
            AND NULLIF(btrim(r.invalid_reason), '') IS NULL
      )

    UNION ALL

    SELECT
        'CUR006',
        'WARNING',
        'curation: inactive T1DX concept still has active relationships',
        count(*)::bigint
    FROM cm c
    CROSS JOIN params p
    WHERE c.vocabulary_id = p.expected_vocabulary_id
      AND NULLIF(btrim(c.invalid_reason), '') IS NOT NULL
      AND EXISTS (
          SELECT 1
          FROM crm r
          WHERE NULLIF(btrim(r.invalid_reason), '') IS NULL
            AND (
                (
                    r.vocabulary_id_1 = c.vocabulary_id
                    AND r.concept_code_1 = c.concept_code
                )
                OR
                (
                    r.vocabulary_id_2 = c.vocabulary_id
                    AND r.concept_code_2 = c.concept_code
                )
            )
      )
)


/****************************************************************************************
 Final QA statistics output.

 To show only failed checks, uncomment:
   WHERE issue_count > 0
****************************************************************************************/
SELECT
    check_id,
    severity,
    issue_description,
    issue_count
FROM checks
-- WHERE issue_count > 0
ORDER BY
    CASE severity
        WHEN 'ERROR' THEN 1
        WHEN 'WARNING' THEN 2
        ELSE 3
    END,
    check_id;
