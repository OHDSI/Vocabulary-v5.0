/**
 * OHDSI Vocabulary Validation Rules
 *
 * This file contains SQL validation queries for template types (T1-T7).
 * Queries are combined using UNION when they apply to multiple templates.
 *
 * Metadata format:
 * -- TEMPLATE: Comma-separated list of templates (e.g., T1,T2,T3)
 * -- RULE: Rule identifier
 * -- LEVEL: ERROR | WARNING | INFO
 * -- FIELD: Field being validated
 * -- MESSAGE: Default error message
 *
 * Query requirements:
 * - Use {TEMP_TABLE} as placeholder for the temporary table name
 * - Must return: source_row_number, validation_message, field_name
 */

-- ============================================================================
-- SHARED VALIDATION RULES
-- ============================================================================

-- TEMPLATE: T1,T2
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
      WHEN concept_name IS NULL OR TRIM(concept_name) = '' THEN 'concept_name'
      WHEN concept_code IS NULL OR TRIM(concept_code) = '' THEN 'concept_code'
      WHEN vocabulary_id IS NULL OR TRIM(vocabulary_id) = '' THEN 'vocabulary_id'
      WHEN domain_id IS NULL OR TRIM(domain_id) = '' THEN 'domain_id'
      WHEN concept_class_id IS NULL OR TRIM(concept_class_id) = '' THEN 'concept_class_id'
    END AS missing_field
  FROM {TEMP_TABLE}
) missing
WHERE missing_field IS NOT NULL;

-- TEMPLATE: T1,T2
-- RULE: VOCABULARY_EXISTS
-- LEVEL: ERROR
-- FIELD: vocabulary_id
-- MESSAGE: Vocabulary does not exist
SELECT
  t.source_row_number,
  'Vocabulary ID does not exist: ' || t.vocabulary_id AS validation_message,
  'vocabulary_id' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN vocab.vocabulary v ON v.vocabulary_id = t.vocabulary_id
WHERE v.vocabulary_id IS NULL
  AND t.vocabulary_id IS NOT NULL
  AND TRIM(t.vocabulary_id) != '';

-- TEMPLATE: T1,T2
-- RULE: DOMAIN_EXISTS
-- LEVEL: ERROR
-- FIELD: domain_id
-- MESSAGE: Domain does not exist
SELECT
  t.source_row_number,
  'Domain ID does not exist: ' || t.domain_id AS validation_message,
  'domain_id' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN vocab.domain d ON d.domain_id = t.domain_id
WHERE d.domain_id IS NULL
  AND t.domain_id IS NOT NULL
  AND TRIM(t.domain_id) != '';

-- TEMPLATE: T1,T2
-- RULE: CONCEPT_CLASS_EXISTS
-- LEVEL: ERROR
-- FIELD: concept_class_id
-- MESSAGE: Concept class does not exist
SELECT
  t.source_row_number,
  'Concept Class ID does not exist: ' || t.concept_class_id AS validation_message,
  'concept_class_id' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN vocab.concept_class cc ON cc.concept_class_id = t.concept_class_id
WHERE cc.concept_class_id IS NULL
  AND t.concept_class_id IS NOT NULL
  AND TRIM(t.concept_class_id) != '';

-- TEMPLATE: T4,T5
-- RULE: CONCEPT_EXISTS
-- LEVEL: ERROR
-- FIELD: concept_id
-- MESSAGE: Concept does not exist
SELECT
  t.source_row_number,
  'Concept ID does not exist: ' || t.concept_id AS validation_message,
  'concept_id' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN vocab.concept c ON c.concept_id = t.concept_id
WHERE c.concept_id IS NULL;

-- ============================================================================
-- T1 SPECIFIC: Adding new non-standard concept(s)
-- ============================================================================

-- TEMPLATE: T1
-- RULE: CONCEPT_CODE_UNIQUE
-- LEVEL: ERROR
-- FIELD: concept_code
-- MESSAGE: Concept code already exists in vocabulary
SELECT
  t.source_row_number,
  'Concept code already exists: ' || t.concept_code || ' in vocabulary ' || t.vocabulary_id AS validation_message,
  'concept_code' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN vocab.concept c ON c.concept_code = t.concept_code
  AND c.vocabulary_id = t.vocabulary_id
WHERE t.concept_code IS NOT NULL
  AND TRIM(t.concept_code) != '';

-- TEMPLATE: T1
-- RULE: CONCEPT_NAME_LENGTH
-- LEVEL: WARNING
-- FIELD: concept_name
-- MESSAGE: Concept name is very long
SELECT
  source_row_number,
  'Concept name exceeds 255 characters (length: ' || LENGTH(concept_name) || ')' AS validation_message,
  'concept_name' AS field_name
FROM {TEMP_TABLE}
WHERE concept_name IS NOT NULL
  AND LENGTH(concept_name) > 255;

-- ============================================================================
-- T3 SPECIFIC: Adding concept relationship(s)
-- ============================================================================

-- TEMPLATE: T3
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
      WHEN concept_id_1 IS NULL THEN 'concept_id_1'
      WHEN concept_id_2 IS NULL THEN 'concept_id_2'
      WHEN relationship_id IS NULL OR TRIM(relationship_id) = '' THEN 'relationship_id'
    END AS missing_field
  FROM {TEMP_TABLE}
) missing
WHERE missing_field IS NOT NULL;

-- TEMPLATE: T3
-- RULE: CONCEPT_1_EXISTS
-- LEVEL: ERROR
-- FIELD: concept_id_1
-- MESSAGE: Source concept does not exist
SELECT
  t.source_row_number,
  'Concept ID 1 does not exist: ' || t.concept_id_1 AS validation_message,
  'concept_id_1' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN vocab.concept c ON c.concept_id = t.concept_id_1::integer
WHERE c.concept_id IS NULL
  AND t.concept_id_1 IS NOT NULL;

-- TEMPLATE: T3
-- RULE: CONCEPT_2_EXISTS
-- LEVEL: ERROR
-- FIELD: concept_id_2
-- MESSAGE: Target concept does not exist
SELECT
  t.source_row_number,
  'Concept ID 2 does not exist: ' || t.concept_id_2 AS validation_message,
  'concept_id_2' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN vocab.concept c ON c.concept_id = t.concept_id_2::integer
WHERE c.concept_id IS NULL
  AND t.concept_id_2 IS NOT NULL;

-- TEMPLATE: T3
-- RULE: RELATIONSHIP_EXISTS
-- LEVEL: ERROR
-- FIELD: relationship_id
-- MESSAGE: Relationship type does not exist
SELECT
  t.source_row_number,
  'Relationship ID does not exist: ' || t.relationship_id AS validation_message,
  'relationship_id' AS field_name
FROM {TEMP_TABLE} t
LEFT JOIN vocab.relationship r ON r.relationship_id = t.relationship_id
WHERE r.relationship_id IS NULL
  AND t.relationship_id IS NOT NULL
  AND TRIM(t.relationship_id) != '';

-- TEMPLATE: T3
-- RULE: RELATIONSHIP_DUPLICATE
-- LEVEL: ERROR
-- FIELD: relationship_id
-- MESSAGE: Relationship already exists
SELECT
  t.source_row_number,
  'Relationship already exists between concept ' || t.concept_id_1 || ' and ' || t.concept_id_2 AS validation_message,
  'relationship_id' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN vocab.concept_relationship cr
  ON cr.concept_id_1 = t.concept_id_1::integer
  AND cr.concept_id_2 = t.concept_id_2::integer
  AND cr.relationship_id = t.relationship_id
WHERE t.concept_id_1 IS NOT NULL
  AND t.concept_id_2 IS NOT NULL;

-- TEMPLATE: T3
-- RULE: SELF_REFERENCE
-- LEVEL: WARNING
-- FIELD: concept_id_1
-- MESSAGE: Concept references itself
SELECT
  source_row_number,
  'Concept references itself (concept_id_1 = concept_id_2)' AS validation_message,
  'concept_id_1' AS field_name
FROM {TEMP_TABLE}
WHERE concept_id_1 = concept_id_2;

-- ============================================================================
-- T4 SPECIFIC: Deprecating concept(s)
-- ============================================================================

-- TEMPLATE: T4
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
      WHEN concept_id IS NULL THEN 'concept_id'
      WHEN invalid_reason IS NULL OR TRIM(invalid_reason) = '' THEN 'invalid_reason'
    END AS missing_field
  FROM {TEMP_TABLE}
) missing
WHERE missing_field IS NOT NULL;

-- TEMPLATE: T4
-- RULE: ALREADY_DEPRECATED
-- LEVEL: WARNING
-- FIELD: concept_id
-- MESSAGE: Concept is already deprecated
SELECT
  t.source_row_number,
  'Concept is already deprecated: ' || t.concept_id AS validation_message,
  'concept_id' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN vocab.concept c ON c.concept_id = t.concept_id
WHERE c.invalid_reason IS NOT NULL;

-- TEMPLATE: T4
-- RULE: INVALID_REASON_CODE
-- LEVEL: ERROR
-- FIELD: invalid_reason
-- MESSAGE: Invalid reason code
SELECT
  source_row_number,
  'Invalid reason must be D (Deleted) or U (Updated): ' || invalid_reason AS validation_message,
  'invalid_reason' AS field_name
FROM {TEMP_TABLE}
WHERE invalid_reason NOT IN ('D', 'U');

-- ============================================================================
-- T5 SPECIFIC: Modifying concept(s) attributes
-- ============================================================================

-- TEMPLATE: T5
-- RULE: REQUIRED_FIELDS
-- LEVEL: ERROR
-- FIELD: ALL
-- MESSAGE: Required fields are missing
SELECT
  source_row_number,
  'Required field concept_id is empty' AS validation_message,
  'concept_id' AS field_name
FROM {TEMP_TABLE}
WHERE concept_id IS NULL;

-- TEMPLATE: T5
-- RULE: NO_CHANGES
-- LEVEL: WARNING
-- FIELD: ALL
-- MESSAGE: No changes detected
SELECT
  t.source_row_number,
  'No changes detected for concept: ' || t.concept_id AS validation_message,
  'concept_id' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN vocab.concept c ON c.concept_id = t.concept_id
WHERE (t.concept_name IS NULL OR c.concept_name = t.concept_name)
  AND (t.domain_id IS NULL OR c.domain_id = t.domain_id)
  AND (t.concept_class_id IS NULL OR c.concept_class_id = t.concept_class_id);

-- ============================================================================
-- T6 SPECIFIC: Creating new vocabulary
-- ============================================================================

-- TEMPLATE: T6
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
      WHEN vocabulary_id IS NULL OR TRIM(vocabulary_id) = '' THEN 'vocabulary_id'
      WHEN vocabulary_name IS NULL OR TRIM(vocabulary_name) = '' THEN 'vocabulary_name'
      WHEN vocabulary_reference IS NULL OR TRIM(vocabulary_reference) = '' THEN 'vocabulary_reference'
    END AS missing_field
  FROM {TEMP_TABLE}
) missing
WHERE missing_field IS NOT NULL;

-- TEMPLATE: T6
-- RULE: VOCABULARY_ID_FORMAT
-- LEVEL: ERROR
-- FIELD: vocabulary_id
-- MESSAGE: Invalid vocabulary ID format
SELECT
  source_row_number,
  'Vocabulary ID must be uppercase alphanumeric: ' || vocabulary_id AS validation_message,
  'vocabulary_id' AS field_name
FROM {TEMP_TABLE}
WHERE vocabulary_id !~ '^[A-Z0-9_]+$';

-- TEMPLATE: T6
-- RULE: VOCABULARY_EXISTS
-- LEVEL: ERROR
-- FIELD: vocabulary_id
-- MESSAGE: Vocabulary ID already exists
SELECT
  t.source_row_number,
  'Vocabulary ID already exists: ' || t.vocabulary_id AS validation_message,
  'vocabulary_id' AS field_name
FROM {TEMP_TABLE} t
INNER JOIN vocab.vocabulary v ON v.vocabulary_id = t.vocabulary_id;

-- ============================================================================
-- T7: Other modifications
-- ============================================================================

-- TEMPLATE: T7
-- RULE: BASIC_VALIDATION
-- LEVEL: INFO
-- FIELD: ALL
-- MESSAGE: Basic validation passed
SELECT
  source_row_number,
  'Row validated successfully' AS validation_message,
  '' AS field_name
FROM {TEMP_TABLE}
LIMIT 0;
