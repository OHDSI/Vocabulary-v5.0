/**
 * OHDSI Vocabulary Validation Rules
 *
 * This file contains SQL validation queries for template types (T1-T7).
 *
 * Metadata format:
 * -- TEMPLATE: Comma-separated list of templates (e.g., T1,T2,T3)
 * -- RULE: Rule identifier
 * -- LEVEL: ERROR | WARNING | INFO
 * -- FIELD: Field being validated
 * -- MESSAGE: Default error message
 * -- OPTIONAL: true  (rule is skipped if referenced column does not exist)
 *
 * Query requirements:
 * - Use {TEMP_TABLE} as placeholder for the temporary table name
 * - Must return: source_row_number, validation_message, field_name
 * - OMOP tables are unqualified (concept, vocabulary, …); set PostgreSQL search_path to your vocabulary schema
 *
 * Column conventions:
 * - Concepts can be identified by concept_id OR concept_code + vocabulary_id
 * - Rules marked OPTIONAL: true are skipped when columns are missing
 *
 * OMOP CDM string length limits:
 * - concept_name: 255, concept_code: 50, vocabulary_id: 20
 * - domain_id: 20, concept_class_id: 20, relationship_id: 20
 * - concept_synonym_name: 1000
 * - vocabulary_name: 255, vocabulary_reference: 255
 */

-- ============================================================================
-- SHARED VALIDATION RULES
-- ============================================================================

-- TEMPLATE: T1
-- RULE: REQUIRED_FIELDS_CONCEPT
-- LEVEL: ERROR
-- FIELD: ALL
-- MESSAGE: Required fields are missing
-- OPTIONAL: true
SELECT
  source_row_number,
  'Required field is empty: ' || missing_field AS validation_message,
  missing_field AS field_name
FROM (
  SELECT
    source_row_number,
    CASE
      WHEN concept_name IS NULL OR TRIM(concept_name::text) = '' THEN 'concept_name'
      WHEN concept_code IS NULL OR TRIM(concept_code::text) = '' THEN 'concept_code'
      WHEN vocabulary_id IS NULL OR TRIM(vocabulary_id) = '' THEN 'vocabulary_id'
      WHEN domain_id IS NULL OR TRIM(domain_id) = '' THEN 'domain_id'
      WHEN concept_class_id IS NULL OR TRIM(concept_class_id) = '' THEN 'concept_class_id'
    END AS missing_field
  FROM {TEMP_TABLE}
) missing
WHERE missing_field IS NOT NULL;

-- TEMPLATE: T1,T5
-- RULE: VOCABULARY_EXISTS
-- LEVEL: ERROR
-- FIELD: vocabulary_id
-- MESSAGE: Vocabulary does not exist
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Vocabulary ID does not exist: ' || t.vocabulary_id AS validation_message,
  'vocabulary_id' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN vocabulary v ON v.vocabulary_id = t.vocabulary_id
WHERE v.vocabulary_id IS NULL
  AND t.vocabulary_id IS NOT NULL
  AND TRIM(t.vocabulary_id) != '';

-- TEMPLATE: T1,T5
-- RULE: DOMAIN_EXISTS
-- LEVEL: ERROR
-- FIELD: domain_id
-- MESSAGE: Domain does not exist
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Domain ID does not exist: ' || t.domain_id AS validation_message,
  'domain_id' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN domain d ON d.domain_id = t.domain_id
WHERE d.domain_id IS NULL
  AND t.domain_id IS NOT NULL
  AND TRIM(t.domain_id) != '';

-- TEMPLATE: T1,T5
-- RULE: CONCEPT_CLASS_EXISTS
-- LEVEL: ERROR
-- FIELD: concept_class_id
-- MESSAGE: Concept class does not exist
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Concept Class ID does not exist: ' || t.concept_class_id AS validation_message,
  'concept_class_id' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN concept_class cc ON cc.concept_class_id = t.concept_class_id
WHERE cc.concept_class_id IS NULL
  AND t.concept_class_id IS NOT NULL
  AND TRIM(t.concept_class_id) != '';

-- TEMPLATE: T7
-- RULE: CONCEPT_ID_EXISTS
-- LEVEL: ERROR
-- FIELD: concept_id
-- MESSAGE: Concept does not exist
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Concept ID does not exist: ' || t.concept_id AS validation_message,
  'concept_id' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN concept c ON c.concept_id = t.concept_id::integer
WHERE c.concept_id IS NULL
  AND t.concept_id IS NOT NULL;

-- TEMPLATE: T5
-- RULE: CONCEPT_IDENTIFIABLE
-- LEVEL: ERROR
-- FIELD: concept_code
-- MESSAGE: Concept must be identifiable by (concept_code + vocabulary_id) OR concept_id
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Concept not found: concept_code=' || COALESCE(t.concept_code::text, 'NULL') ||
    ', vocabulary_id=' || COALESCE(t.vocabulary_id, 'NULL') ||
    ', concept_id=' || COALESCE(t.concept_id::text, 'NULL') AS validation_message,
  'concept_code' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN concept c_code ON c_code.concept_code = t.concept_code::text
  AND c_code.vocabulary_id = t.vocabulary_id
LEFT JOIN concept c_id ON c_id.concept_id = t.concept_id::integer
WHERE c_code.concept_id IS NULL
  AND c_id.concept_id IS NULL;

-- TEMPLATE: T3,T6
-- RULE: VOCABULARY_ID_1_EXISTS
-- LEVEL: ERROR
-- FIELD: vocabulary_id_1
-- MESSAGE: Source vocabulary does not exist
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Vocabulary ID 1 does not exist: ' || t.vocabulary_id_1 AS validation_message,
  'vocabulary_id_1' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN vocabulary v ON v.vocabulary_id = t.vocabulary_id_1
WHERE v.vocabulary_id IS NULL
  AND t.vocabulary_id_1 IS NOT NULL
  AND TRIM(t.vocabulary_id_1) != '';

-- TEMPLATE: T3,T6
-- RULE: VOCABULARY_ID_2_EXISTS
-- LEVEL: ERROR
-- FIELD: vocabulary_id_2
-- MESSAGE: Target vocabulary does not exist
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Vocabulary ID 2 does not exist: ' || t.vocabulary_id_2 AS validation_message,
  'vocabulary_id_2' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN vocabulary v ON v.vocabulary_id = t.vocabulary_id_2
WHERE v.vocabulary_id IS NULL
  AND t.vocabulary_id_2 IS NOT NULL
  AND TRIM(t.vocabulary_id_2) != '';

-- TEMPLATE: T3,T6
-- RULE: CONCEPT_1_IDENTIFIABLE
-- LEVEL: ERROR
-- FIELD: concept_code_1
-- MESSAGE: Source concept must be identifiable by (concept_code_1 + vocabulary_id_1) OR concept_id_1
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Source concept not found: concept_code_1=' || COALESCE(t.concept_code_1::text, 'NULL') ||
    ', vocabulary_id_1=' || COALESCE(t.vocabulary_id_1, 'NULL') ||
    ', concept_id_1=' || COALESCE(t.concept_id_1::text, 'NULL') AS validation_message,
  'concept_code_1' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN concept c_code ON c_code.concept_code = t.concept_code_1::text
  AND c_code.vocabulary_id = t.vocabulary_id_1
LEFT JOIN concept c_id ON c_id.concept_id = t.concept_id_1::integer
WHERE c_code.concept_id IS NULL
  AND c_id.concept_id IS NULL;

-- TEMPLATE: T3,T6
-- RULE: CONCEPT_2_IDENTIFIABLE
-- LEVEL: ERROR
-- FIELD: concept_code_2
-- MESSAGE: Target concept must be identifiable by (concept_code_2 + vocabulary_id_2) OR concept_id_2
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Target concept not found: concept_code_2=' || COALESCE(t.concept_code_2::text, 'NULL') ||
    ', vocabulary_id_2=' || COALESCE(t.vocabulary_id_2, 'NULL') ||
    ', concept_id_2=' || COALESCE(t.concept_id_2::text, 'NULL') AS validation_message,
  'concept_code_2' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN concept c_code ON c_code.concept_code = t.concept_code_2::text
  AND c_code.vocabulary_id = t.vocabulary_id_2
LEFT JOIN concept c_id ON c_id.concept_id = t.concept_id_2::integer
WHERE c_code.concept_id IS NULL
  AND c_id.concept_id IS NULL;

-- ============================================================================
-- STRING LENGTH VALIDATION (shared across templates)
-- ============================================================================

-- TEMPLATE: T1
-- RULE: STRING_LENGTH_CONCEPT_NAME
-- LEVEL: ERROR
-- FIELD: concept_name
-- MESSAGE: concept_name exceeds 255 characters
-- OPTIONAL: true
SELECT
  source_row_number,
  'concept_name exceeds 255 characters (length: ' || LENGTH(concept_name::text) || ')' AS validation_message,
  'concept_name' AS field_name
FROM {TEMP_TABLE}
WHERE concept_name IS NOT NULL
  AND LENGTH(concept_name::text) > 255;

-- TEMPLATE: T4
-- RULE: STRING_LENGTH_CONCEPT_NAME_1
-- LEVEL: ERROR
-- FIELD: concept_name_1
-- MESSAGE: concept_name_1 exceeds 255 characters
-- OPTIONAL: true
SELECT
  source_row_number,
  'concept_name_1 exceeds 255 characters (length: ' || LENGTH(concept_name_1::text) || ')' AS validation_message,
  'concept_name_1' AS field_name
FROM {TEMP_TABLE}
WHERE concept_name_1 IS NOT NULL
  AND LENGTH(concept_name_1::text) > 255;

-- TEMPLATE: T1
-- RULE: STRING_LENGTH_CONCEPT_CODE
-- LEVEL: ERROR
-- FIELD: concept_code
-- MESSAGE: concept_code exceeds 50 characters
-- OPTIONAL: true
SELECT
  source_row_number,
  'concept_code exceeds 50 characters (length: ' || LENGTH(concept_code::text) || ')' AS validation_message,
  'concept_code' AS field_name
FROM {TEMP_TABLE}
WHERE concept_code IS NOT NULL
  AND LENGTH(concept_code::text) > 50;

-- TEMPLATE: T1,T5
-- RULE: STRING_LENGTH_VOCABULARY_ID
-- LEVEL: ERROR
-- FIELD: vocabulary_id
-- MESSAGE: vocabulary_id exceeds 20 characters
-- OPTIONAL: true
SELECT
  source_row_number,
  'vocabulary_id exceeds 20 characters (length: ' || LENGTH(vocabulary_id) || ')' AS validation_message,
  'vocabulary_id' AS field_name
FROM {TEMP_TABLE}
WHERE vocabulary_id IS NOT NULL
  AND LENGTH(vocabulary_id) > 20;

-- TEMPLATE: T1,T5
-- RULE: STRING_LENGTH_DOMAIN_ID
-- LEVEL: ERROR
-- FIELD: domain_id
-- MESSAGE: domain_id exceeds 20 characters
-- OPTIONAL: true
SELECT
  source_row_number,
  'domain_id exceeds 20 characters (length: ' || LENGTH(domain_id) || ')' AS validation_message,
  'domain_id' AS field_name
FROM {TEMP_TABLE}
WHERE domain_id IS NOT NULL
  AND LENGTH(domain_id) > 20;

-- TEMPLATE: T1,T5
-- RULE: STRING_LENGTH_CONCEPT_CLASS_ID
-- LEVEL: ERROR
-- FIELD: concept_class_id
-- MESSAGE: concept_class_id exceeds 20 characters
-- OPTIONAL: true
SELECT
  source_row_number,
  'concept_class_id exceeds 20 characters (length: ' || LENGTH(concept_class_id) || ')' AS validation_message,
  'concept_class_id' AS field_name
FROM {TEMP_TABLE}
WHERE concept_class_id IS NOT NULL
  AND LENGTH(concept_class_id) > 20;


-- TEMPLATE: T2
-- RULE: STRING_LENGTH_SYNONYM_NAME
-- LEVEL: ERROR
-- FIELD: synonym_name
-- MESSAGE: synonym_name exceeds 1000 characters
SELECT
  source_row_number,
  'synonym_name exceeds 1000 characters (length: ' || LENGTH(synonym_name::text) || ')' AS validation_message,
  'synonym_name' AS field_name
FROM {TEMP_TABLE}
WHERE synonym_name IS NOT NULL
  AND LENGTH(synonym_name::text) > 1000;

-- ============================================================================
-- T1 SPECIFIC: Adding new non-standard concept(s)
-- ============================================================================

-- TEMPLATE: T1
-- RULE: CONCEPT_CODE_UNIQUE_IN_DB
-- LEVEL: ERROR
-- FIELD: concept_code
-- MESSAGE: Concept code already exists in vocabulary
SELECT
  t.source_row_number,
  'Concept code already exists: ' || t.concept_code::text || ' in vocabulary ' || t.vocabulary_id AS validation_message,
  'concept_code' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept c ON c.concept_code = t.concept_code::text
  AND c.vocabulary_id = t.vocabulary_id
WHERE t.concept_code IS NOT NULL
  AND TRIM(t.concept_code::text) != '';

-- TEMPLATE: T1
-- RULE: CONCEPT_CODE_DUPLICATE_IN_SUBMISSION
-- LEVEL: ERROR
-- FIELD: concept_code
-- MESSAGE: Duplicate concept_code within submission
SELECT
  t1.source_row_number,
  'Duplicate concept_code in submission: ' || t1.concept_code::text AS validation_message,
  'concept_code' AS field_name
FROM {TEMP_TABLE} t1
INNER JOIN {TEMP_TABLE} t2
  ON t1.concept_code::text = t2.concept_code::text
  AND t1.vocabulary_id = t2.vocabulary_id
  AND t1.source_row_number > t2.source_row_number
WHERE t1.concept_code IS NOT NULL
  AND TRIM(t1.concept_code::text) != '';

-- ============================================================================
-- T2 SPECIFIC: Adding synonym(s)
-- ============================================================================

-- TEMPLATE: T2
-- RULE: REQUIRED_FIELDS
-- LEVEL: ERROR
-- FIELD: ALL
-- MESSAGE: Required fields are missing
SELECT
  source_row_number,
  'Required field is empty: ' || missing_field AS validation_message,
  missing_field AS field_name
FROM (
  SELECT
    source_row_number,
    CASE
      WHEN synonym_name IS NULL OR TRIM(synonym_name::text) = '' THEN 'synonym_name'
      WHEN synonym_concept_code IS NULL OR TRIM(synonym_concept_code::text) = '' THEN 'synonym_concept_code'
      WHEN synonym_vocabulary_id IS NULL OR TRIM(synonym_vocabulary_id) = '' THEN 'synonym_vocabulary_id'
      WHEN language_concept_id IS NULL THEN 'language_concept_id'
    END AS missing_field
  FROM {TEMP_TABLE}
) missing
WHERE missing_field IS NOT NULL;

-- TEMPLATE: T2
-- RULE: VOCABULARY_EXISTS
-- LEVEL: ERROR
-- FIELD: synonym_vocabulary_id
-- MESSAGE: Vocabulary does not exist
SELECT
  t.source_row_number,
  'Vocabulary ID does not exist: ' || t.synonym_vocabulary_id AS validation_message,
  'synonym_vocabulary_id' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN vocabulary v ON v.vocabulary_id = t.synonym_vocabulary_id
WHERE v.vocabulary_id IS NULL
  AND t.synonym_vocabulary_id IS NOT NULL
  AND TRIM(t.synonym_vocabulary_id) != '';

-- TEMPLATE: T2
-- RULE: CONCEPT_EXISTS
-- LEVEL: ERROR
-- FIELD: synonym_concept_code
-- MESSAGE: Concept does not exist for the given code and vocabulary
SELECT
  t.source_row_number,
  'Concept not found for code ' || t.synonym_concept_code::text || ' in vocabulary ' || t.synonym_vocabulary_id AS validation_message,
  'synonym_concept_code' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN concept c ON c.concept_code = t.synonym_concept_code::text
  AND c.vocabulary_id = t.synonym_vocabulary_id
WHERE c.concept_id IS NULL
  AND t.synonym_concept_code IS NOT NULL
  AND TRIM(t.synonym_concept_code::text) != '';

-- TEMPLATE: T2
-- RULE: LANGUAGE_CONCEPT_EXISTS
-- LEVEL: ERROR
-- FIELD: language_concept_id
-- MESSAGE: Language concept does not exist
SELECT
  t.source_row_number,
  'Language concept ID does not exist: ' || t.language_concept_id AS validation_message,
  'language_concept_id' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN concept c ON c.concept_id = t.language_concept_id::integer
WHERE c.concept_id IS NULL
  AND t.language_concept_id IS NOT NULL;

-- TEMPLATE: T2
-- RULE: LANGUAGE_IS_STANDARD
-- LEVEL: ERROR
-- FIELD: language_concept_id
-- MESSAGE: Language concept must be a standard concept
SELECT
  t.source_row_number,
  'Language concept is not standard: ' || t.language_concept_id AS validation_message,
  'language_concept_id' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept c ON c.concept_id = t.language_concept_id::integer
WHERE c.standard_concept IS DISTINCT FROM 'S';

-- TEMPLATE: T2
-- RULE: LANGUAGE_DOMAIN
-- LEVEL: ERROR
-- FIELD: language_concept_id
-- MESSAGE: Language concept must have domain 'Language'
SELECT
  t.source_row_number,
  'Language concept has wrong domain: ' || c.domain_id || ' (expected Language)' AS validation_message,
  'language_concept_id' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept c ON c.concept_id = t.language_concept_id::integer
WHERE c.domain_id != 'Language';

-- TEMPLATE: T2
-- RULE: SYNONYM_DUPLICATE
-- LEVEL: WARNING
-- FIELD: synonym_name
-- MESSAGE: Synonym already exists for this concept
SELECT
  t.source_row_number,
  'Synonym already exists: ' || t.synonym_name::text || ' for concept ' || t.synonym_concept_code::text AS validation_message,
  'synonym_name' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept c ON c.concept_code = t.synonym_concept_code::text
  AND c.vocabulary_id = t.synonym_vocabulary_id
INNER JOIN concept_synonym cs ON cs.concept_id = c.concept_id
  AND cs.concept_synonym_name = t.synonym_name::text
  AND cs.language_concept_id = t.language_concept_id::integer;

-- ============================================================================
-- T3 SPECIFIC: Adding mapping(s)
-- ============================================================================

-- TEMPLATE: T3
-- RULE: REQUIRED_FIELDS_BY_ID
-- LEVEL: ERROR
-- FIELD: ALL
-- MESSAGE: Required fields are missing (concept_id approach)
-- OPTIONAL: true
SELECT
  source_row_number,
  'Required field is empty: ' || missing_field AS validation_message,
  missing_field AS field_name
FROM (
  SELECT
    source_row_number,
    CASE
      WHEN concept_id_1 IS NULL THEN 'concept_id_1'
      WHEN concept_id_2 IS NULL THEN 'concept_id_2'
      WHEN relationship_id IS NULL OR TRIM(relationship_id) = '' THEN 'relationship_id'
    END AS missing_field
  FROM {TEMP_TABLE}
) missing
WHERE missing_field IS NOT NULL;

-- TEMPLATE: T3
-- RULE: REQUIRED_FIELDS_BY_CODE
-- LEVEL: ERROR
-- FIELD: ALL
-- MESSAGE: Required fields are missing (concept_code approach)
-- OPTIONAL: true
SELECT
  source_row_number,
  'Required field is empty: ' || missing_field AS validation_message,
  missing_field AS field_name
FROM (
  SELECT
    source_row_number,
    CASE
      WHEN concept_code_1 IS NULL OR TRIM(concept_code_1::text) = '' THEN 'concept_code_1'
      WHEN vocabulary_id_1 IS NULL OR TRIM(vocabulary_id_1) = '' THEN 'vocabulary_id_1'
      WHEN concept_code_2 IS NULL OR TRIM(concept_code_2::text) = '' THEN 'concept_code_2'
      WHEN vocabulary_id_2 IS NULL OR TRIM(vocabulary_id_2) = '' THEN 'vocabulary_id_2'
      WHEN relationship_id IS NULL OR TRIM(relationship_id) = '' THEN 'relationship_id'
    END AS missing_field
  FROM {TEMP_TABLE}
) missing
WHERE missing_field IS NOT NULL;

-- TEMPLATE: T3
-- RULE: RELATIONSHIP_VALID
-- LEVEL: ERROR
-- FIELD: relationship_id
-- MESSAGE: Invalid relationship type for mapping
SELECT
  source_row_number,
  'Invalid relationship_id: ' || relationship_id || '. Must be ''Maps to'' or ''Maps to value''' AS validation_message,
  'relationship_id' AS field_name
FROM {TEMP_TABLE}
WHERE relationship_id NOT IN ('Maps to', 'Maps to value');

-- TEMPLATE: T3
-- RULE: TARGET_IS_STANDARD_BY_ID
-- LEVEL: ERROR
-- FIELD: concept_id_2
-- MESSAGE: Target concept must be standard and valid
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Target concept is not standard/valid: concept_id_2=' || t.concept_id_2 ||
    ' (standard_concept=' || COALESCE(c.standard_concept, 'NULL') ||
    ', invalid_reason=' || COALESCE(c.invalid_reason, 'NULL') || ')' AS validation_message,
  'concept_id_2' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept c ON c.concept_id = t.concept_id_2::integer
WHERE c.standard_concept IS DISTINCT FROM 'S'
  OR c.invalid_reason IS NOT NULL;

-- TEMPLATE: T3
-- RULE: TARGET_IS_STANDARD_BY_CODE
-- LEVEL: ERROR
-- FIELD: concept_code_2
-- MESSAGE: Target concept must be standard and valid
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Target concept is not standard/valid: ' || t.concept_code_2::text || ' in ' || t.vocabulary_id_2 ||
    ' (standard_concept=' || COALESCE(c.standard_concept, 'NULL') ||
    ', invalid_reason=' || COALESCE(c.invalid_reason, 'NULL') || ')' AS validation_message,
  'concept_code_2' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept c ON c.concept_code = t.concept_code_2::text
  AND c.vocabulary_id = t.vocabulary_id_2
WHERE c.standard_concept IS DISTINCT FROM 'S'
  OR c.invalid_reason IS NOT NULL;

-- TEMPLATE: T3
-- RULE: MAPPING_DUPLICATE_BY_ID
-- LEVEL: ERROR
-- FIELD: relationship_id
-- MESSAGE: Mapping already exists
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Mapping already exists between concept ' || t.concept_id_1 || ' and ' || t.concept_id_2 AS validation_message,
  'relationship_id' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept_relationship cr
  ON cr.concept_id_1 = t.concept_id_1::integer
  AND cr.concept_id_2 = t.concept_id_2::integer
  AND cr.relationship_id = t.relationship_id
  AND cr.invalid_reason IS NULL
WHERE t.concept_id_1 IS NOT NULL
  AND t.concept_id_2 IS NOT NULL;

-- TEMPLATE: T3
-- RULE: MAPPING_DUPLICATE_BY_CODE
-- LEVEL: ERROR
-- FIELD: relationship_id
-- MESSAGE: Mapping already exists
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Mapping already exists between ' || t.concept_code_1::text || ' (' || t.vocabulary_id_1 || ') and ' || t.concept_code_2::text || ' (' || t.vocabulary_id_2 || ')' AS validation_message,
  'relationship_id' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept c1 ON c1.concept_code = t.concept_code_1::text
  AND c1.vocabulary_id = t.vocabulary_id_1
INNER JOIN concept c2 ON c2.concept_code = t.concept_code_2::text
  AND c2.vocabulary_id = t.vocabulary_id_2
INNER JOIN concept_relationship cr
  ON cr.concept_id_1 = c1.concept_id
  AND cr.concept_id_2 = c2.concept_id
  AND cr.relationship_id = t.relationship_id
  AND cr.invalid_reason IS NULL;

-- TEMPLATE: T3
-- RULE: SELF_REFERENCE
-- LEVEL: WARNING
-- FIELD: concept_id_1
-- MESSAGE: Concept references itself
-- OPTIONAL: true
SELECT
  source_row_number,
  'Concept references itself (concept_id_1 = concept_id_2)' AS validation_message,
  'concept_id_1' AS field_name
FROM {TEMP_TABLE}
WHERE concept_id_1::integer = concept_id_2::integer;

-- ============================================================================
-- T4 SPECIFIC: Creating new vocabulary
-- ============================================================================

-- TEMPLATE: T4
-- RULE: REQUIRED_FIELDS_VOCABULARY
-- LEVEL: ERROR
-- FIELD: vocabulary_id_1
-- MESSAGE: Required vocabulary fields are missing
SELECT
  source_row_number,
  'Required field is empty: vocabulary_id_1' AS validation_message,
  'vocabulary_id_1' AS field_name
FROM {TEMP_TABLE}
WHERE vocabulary_id_1 IS NULL OR TRIM(vocabulary_id_1) = '';

-- TEMPLATE: T4
-- RULE: VOCABULARY_ALREADY_EXISTS
-- LEVEL: ERROR
-- FIELD: vocabulary_id_1
-- MESSAGE: Vocabulary ID already exists
SELECT
  t.source_row_number,
  'Vocabulary ID already exists: ' || t.vocabulary_id_1 AS validation_message,
  'vocabulary_id_1' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN vocabulary v ON v.vocabulary_id = t.vocabulary_id_1;

-- TEMPLATE: T4
-- RULE: CONCEPT_CODE_UNIQUE_IN_DB
-- LEVEL: ERROR
-- FIELD: concept_code_1
-- MESSAGE: Concept code already exists in vocabulary
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Concept code already exists: ' || t.concept_code_1::text || ' in vocabulary ' || t.vocabulary_id_1 AS validation_message,
  'concept_code_1' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept c ON c.concept_code = t.concept_code_1::text
  AND c.vocabulary_id = t.vocabulary_id_1
WHERE t.concept_code_1 IS NOT NULL
  AND TRIM(t.concept_code_1::text) != '';

-- TEMPLATE: T4
-- RULE: CONCEPT_CODE_DUPLICATE_IN_SUBMISSION
-- LEVEL: ERROR
-- FIELD: concept_code_1
-- MESSAGE: Duplicate concept_code_1 within submission
-- OPTIONAL: true
SELECT
  t1.source_row_number,
  'Duplicate concept_code_1 in submission: ' || t1.concept_code_1::text AS validation_message,
  'concept_code_1' AS field_name
FROM {TEMP_TABLE} t1
INNER JOIN {TEMP_TABLE} t2
  ON t1.concept_code_1::text = t2.concept_code_1::text
  AND t1.vocabulary_id_1 = t2.vocabulary_id_1
  AND t1.source_row_number > t2.source_row_number
WHERE t1.concept_code_1 IS NOT NULL
  AND TRIM(t1.concept_code_1::text) != '';

-- ============================================================================
-- T5 SPECIFIC: Modifying concept(s) attributes
-- ============================================================================

-- TEMPLATE: T5
-- RULE: REQUIRED_FIELDS_BY_ID
-- LEVEL: ERROR
-- FIELD: concept_id
-- MESSAGE: Required fields are missing
-- OPTIONAL: true
SELECT
  source_row_number,
  'Required field concept_id is empty' AS validation_message,
  'concept_id' AS field_name
FROM {TEMP_TABLE}
WHERE concept_id IS NULL;

-- TEMPLATE: T5
-- RULE: REQUIRED_FIELDS_BY_CODE
-- LEVEL: ERROR
-- FIELD: ALL
-- MESSAGE: Required fields are missing (concept_code approach)
-- OPTIONAL: true
SELECT
  source_row_number,
  'Required field is empty: ' || missing_field AS validation_message,
  missing_field AS field_name
FROM (
  SELECT
    source_row_number,
    CASE
      WHEN concept_code IS NULL OR TRIM(concept_code::text) = '' THEN 'concept_code'
      WHEN vocabulary_id IS NULL OR TRIM(vocabulary_id) = '' THEN 'vocabulary_id'
    END AS missing_field
  FROM {TEMP_TABLE}
) missing
WHERE missing_field IS NOT NULL;

-- TEMPLATE: T5
-- RULE: NO_CHANGES_BY_ID
-- LEVEL: WARNING
-- FIELD: ALL
-- MESSAGE: No changes detected
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'No changes detected for concept: ' || t.concept_id AS validation_message,
  'concept_id' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept c ON c.concept_id = t.concept_id::integer
WHERE (t.concept_name IS NULL OR c.concept_name = t.concept_name::text)
  AND (t.domain_id IS NULL OR c.domain_id = t.domain_id)
  AND (t.concept_class_id IS NULL OR c.concept_class_id = t.concept_class_id);

-- TEMPLATE: T5
-- RULE: NO_CHANGES_BY_CODE
-- LEVEL: WARNING
-- FIELD: ALL
-- MESSAGE: No changes detected
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'No changes detected for concept: ' || t.concept_code::text AS validation_message,
  'concept_code' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept c ON c.concept_code = t.concept_code::text
  AND c.vocabulary_id = t.vocabulary_id
WHERE (t.concept_name IS NULL OR c.concept_name = t.concept_name::text)
  AND (t.domain_id IS NULL OR c.domain_id = t.domain_id)
  AND (t.concept_class_id IS NULL OR c.concept_class_id = t.concept_class_id);

-- ============================================================================
-- T6 SPECIFIC: Modifying mapping(s)
-- ============================================================================

-- TEMPLATE: T6
-- RULE: REQUIRED_FIELDS_BY_ID
-- LEVEL: ERROR
-- FIELD: ALL
-- MESSAGE: Required fields are missing (concept_id approach)
-- OPTIONAL: true
SELECT
  source_row_number,
  'Required field is empty: ' || missing_field AS validation_message,
  missing_field AS field_name
FROM (
  SELECT
    source_row_number,
    CASE
      WHEN concept_id_1 IS NULL THEN 'concept_id_1'
      WHEN concept_id_2 IS NULL THEN 'concept_id_2'
      WHEN relationship_id IS NULL OR TRIM(relationship_id) = '' THEN 'relationship_id'
    END AS missing_field
  FROM {TEMP_TABLE}
) missing
WHERE missing_field IS NOT NULL;

-- TEMPLATE: T6
-- RULE: REQUIRED_FIELDS_BY_CODE
-- LEVEL: ERROR
-- FIELD: ALL
-- MESSAGE: Required fields are missing (concept_code approach)
-- OPTIONAL: true
SELECT
  source_row_number,
  'Required field is empty: ' || missing_field AS validation_message,
  missing_field AS field_name
FROM (
  SELECT
    source_row_number,
    CASE
      WHEN concept_code_1 IS NULL OR TRIM(concept_code_1::text) = '' THEN 'concept_code_1'
      WHEN vocabulary_id_1 IS NULL OR TRIM(vocabulary_id_1) = '' THEN 'vocabulary_id_1'
      WHEN concept_code_2 IS NULL OR TRIM(concept_code_2::text) = '' THEN 'concept_code_2'
      WHEN vocabulary_id_2 IS NULL OR TRIM(vocabulary_id_2) = '' THEN 'vocabulary_id_2'
      WHEN relationship_id IS NULL OR TRIM(relationship_id) = '' THEN 'relationship_id'
    END AS missing_field
  FROM {TEMP_TABLE}
) missing
WHERE missing_field IS NOT NULL;

-- TEMPLATE: T6
-- RULE: RELATIONSHIP_VALID
-- LEVEL: ERROR
-- FIELD: relationship_id
-- MESSAGE: Invalid relationship type for mapping
SELECT
  source_row_number,
  'Invalid relationship_id: ' || relationship_id || '. Must be ''Maps to'' or ''Maps to value''' AS validation_message,
  'relationship_id' AS field_name
FROM {TEMP_TABLE}
WHERE relationship_id NOT IN ('Maps to', 'Maps to value');

-- TEMPLATE: T6
-- RULE: DEPRECATED_MAPPING_EXISTS_BY_ID
-- LEVEL: ERROR
-- FIELD: concept_id_2
-- MESSAGE: Mapping to deprecate does not exist in concept_relationship
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Mapping to deprecate not found: concept_id_1=' || t.concept_id_1 || ', concept_id_2=' || t.concept_id_2 || ', relationship_id=' || t.relationship_id AS validation_message,
  'concept_id_2' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN concept_relationship cr
  ON cr.concept_id_1 = t.concept_id_1::integer
  AND cr.concept_id_2 = t.concept_id_2::integer
  AND cr.relationship_id = t.relationship_id
  AND cr.invalid_reason IS NULL
WHERE cr.concept_id_1 IS NULL
  AND t.invalid_reason = 'D';

-- TEMPLATE: T6
-- RULE: DEPRECATED_MAPPING_EXISTS_BY_CODE
-- LEVEL: ERROR
-- FIELD: concept_code_2
-- MESSAGE: Mapping to deprecate does not exist in concept_relationship
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'Mapping to deprecate not found: ' || t.concept_code_1 || ' (' || t.vocabulary_id_1 || ') -> ' || t.concept_code_2 || ' (' || t.vocabulary_id_2 || ')' AS validation_message,
  'concept_code_2' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept c1 ON c1.concept_code = t.concept_code_1::text
  AND c1.vocabulary_id = t.vocabulary_id_1
LEFT JOIN concept c2 ON c2.concept_code = t.concept_code_2::text
  AND c2.vocabulary_id = t.vocabulary_id_2
LEFT JOIN concept_relationship cr
  ON cr.concept_id_1 = c1.concept_id
  AND cr.concept_id_2 = c2.concept_id
  AND cr.relationship_id = t.relationship_id
  AND cr.invalid_reason IS NULL
WHERE cr.concept_id_1 IS NULL
  AND t.invalid_reason = 'D';

-- TEMPLATE: T6
-- RULE: NEW_MAPPING_TARGET_STANDARD_BY_ID
-- LEVEL: ERROR
-- FIELD: concept_id_2
-- MESSAGE: New mapping target must be standard and valid
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'New mapping target is not standard/valid: concept_id_2=' || t.concept_id_2 AS validation_message,
  'concept_id_2' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept c ON c.concept_id = t.concept_id_2::integer
WHERE (t.invalid_reason IS NULL OR TRIM(t.invalid_reason) = '')
  AND (c.standard_concept IS DISTINCT FROM 'S' OR c.invalid_reason IS NOT NULL);

-- TEMPLATE: T6
-- RULE: NEW_MAPPING_TARGET_STANDARD_BY_CODE
-- LEVEL: ERROR
-- FIELD: concept_code_2
-- MESSAGE: New mapping target must be standard and valid
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'New mapping target is not standard/valid: ' || t.concept_code_2::text || ' in ' || t.vocabulary_id_2 AS validation_message,
  'concept_code_2' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept c ON c.concept_code = t.concept_code_2::text
  AND c.vocabulary_id = t.vocabulary_id_2
WHERE (t.invalid_reason IS NULL OR TRIM(t.invalid_reason) = '')
  AND (c.standard_concept IS DISTINCT FROM 'S' OR c.invalid_reason IS NOT NULL);

-- TEMPLATE: T6
-- RULE: NEW_MAPPING_INVALID_REASON_NULL
-- LEVEL: ERROR
-- FIELD: invalid_reason
-- MESSAGE: New mapping rows must have invalid_reason = NULL
SELECT
  source_row_number,
  'New mapping row must have invalid_reason = NULL, got: ' || invalid_reason AS validation_message,
  'invalid_reason' AS field_name
FROM {TEMP_TABLE}
WHERE invalid_reason IS NOT NULL
  AND TRIM(invalid_reason) != ''
  AND invalid_reason != 'D';

-- TEMPLATE: T6
-- RULE: MISSING_DEPRECATION
-- LEVEL: ERROR
-- FIELD: concept_id_1
-- MESSAGE: No deprecation row (invalid_reason = D) for this source concept
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'No deprecation row (invalid_reason=D) found for concept_id_1: ' || t.concept_id_1 AS validation_message,
  'concept_id_1' AS field_name
FROM {TEMP_TABLE} t
WHERE (t.invalid_reason IS NULL OR TRIM(t.invalid_reason) = '')
  AND NOT EXISTS (
    SELECT 1 FROM {TEMP_TABLE} d
    WHERE d.concept_id_1 = t.concept_id_1
      AND d.invalid_reason = 'D'
  );

-- TEMPLATE: T6
-- RULE: MISSING_NEW_MAPPING
-- LEVEL: ERROR
-- FIELD: concept_id_1
-- MESSAGE: No new mapping row for this source concept
-- OPTIONAL: true
SELECT
  t.source_row_number,
  'No new mapping row found for concept_id_1: ' || t.concept_id_1 AS validation_message,
  'concept_id_1' AS field_name
FROM {TEMP_TABLE} t
WHERE t.invalid_reason = 'D'
  AND NOT EXISTS (
    SELECT 1 FROM {TEMP_TABLE} n
    WHERE n.concept_id_1 = t.concept_id_1
      AND (n.invalid_reason IS NULL OR TRIM(n.invalid_reason) = '')
  );

-- ============================================================================
-- T7 SPECIFIC: Promoting concept(s) to standard
-- ============================================================================

-- TEMPLATE: T7
-- RULE: REQUIRED_FIELDS
-- LEVEL: ERROR
-- FIELD: ALL
-- MESSAGE: Required field is missing
SELECT
  source_row_number,
  'Required field is empty: concept_id' AS validation_message,
  'concept_id' AS field_name
FROM {TEMP_TABLE}
WHERE concept_id IS NULL;

-- TEMPLATE: T7
-- RULE: ALREADY_STANDARD
-- LEVEL: ERROR
-- FIELD: concept_id
-- MESSAGE: Concept is already standard
SELECT
  t.source_row_number,
  'Concept is already standard (standard_concept=S): ' || t.concept_id AS validation_message,
  'concept_id' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept c ON c.concept_id = t.concept_id::integer
WHERE c.standard_concept = 'S';

-- TEMPLATE: T7
-- RULE: DUPLICATE_STANDARD_NAME
-- LEVEL: ERROR
-- FIELD: concept_name
-- MESSAGE: A standard concept with the same name already exists
SELECT
  t.source_row_number,
  'A standard concept with the same name already exists: ' || c.concept_name || ' (concept_id=' || c.concept_id || ')' AS validation_message,
  'concept_name' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN concept src ON src.concept_id = t.concept_id::integer
INNER JOIN concept c ON LOWER(c.concept_name) = LOWER(src.concept_name)
  AND c.standard_concept = 'S'
  AND c.concept_id != src.concept_id;
