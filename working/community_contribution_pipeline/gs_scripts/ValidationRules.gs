/**
 * Validation Rules Configuration
 *
 * Defines template-specific validation queries and rules for OHDSI vocab.vocabulary submissions
 */

/**
 * Gets validation queries for a specific template type
 *
 * @param {string} templateType - Template type (T1-T7)
 * @return {Array<Object>} Array of validation query objects
 */
function getValidationQueries(templateType) {
  const queries = VALIDATION_RULES[templateType];

  if (!queries) {
    Logger.log(`No validation rules defined for template type: ${templateType}`);
    return [];
  }

  return queries;
}

/**
 * Validation rules configuration for each template type
 *
 * Each rule contains:
 * - name: Rule identifier
 * - level: ERROR, WARNING, or INFO
 * - field: Field being validated
 * - message: Error message template
 * - sql: SQL query to execute (uses {TEMP_TABLE} placeholder)
 *
 * Queries should return rows with:
 * - source_row_number: Row number from input
 * - validation_message: Error message
 * - field_name: Field that failed validation
 */
const VALIDATION_RULES = {
  /**
   * T1: Adding new non-standard concept(s) to an existing vocab.vocabulary
   */
  'T1': [
    {
      name: 'REQUIRED_FIELDS',
      level: 'ERROR',
      field: 'ALL',
      message: 'Required fields are missing',
      sql: `
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
        WHERE missing_field IS NOT NULL
      `
    },
    {
      name: 'VOCABULARY_EXISTS',
      level: 'ERROR',
      field: 'vocabulary_id',
      message: 'Vocabulary does not exist',
      sql: `
        SELECT
          t.source_row_number,
          'Vocabulary ID does not exist: ' || t.vocabulary_id AS validation_message,
          'vocabulary_id' AS field_name
        FROM {TEMP_TABLE} t
        LEFT JOIN vocab.vocabulary v ON v.vocabulary_id = t.vocabulary_id
        WHERE v.vocabulary_id IS NULL
          AND t.vocabulary_id IS NOT NULL
          AND TRIM(t.vocabulary_id) != ''
      `
    },
    {
      name: 'DOMAIN_EXISTS',
      level: 'ERROR',
      field: 'domain_id',
      message: 'Domain does not exist',
      sql: `
        SELECT
          t.source_row_number,
          'Domain ID does not exist: ' || t.domain_id AS validation_message,
          'domain_id' AS field_name
        FROM {TEMP_TABLE} t
        LEFT JOIN vocab.domain d ON d.domain_id = t.domain_id
        WHERE d.domain_id IS NULL
          AND t.domain_id IS NOT NULL
          AND TRIM(t.domain_id) != ''
      `
    },
    {
      name: 'CONCEPT_CLASS_EXISTS',
      level: 'ERROR',
      field: 'concept_class_id',
      message: 'Concept class does not exist',
      sql: `
        SELECT
          t.source_row_number,
          'Concept Class ID does not exist: ' || t.concept_class_id AS validation_message,
          'concept_class_id' AS field_name
        FROM {TEMP_TABLE} t
        LEFT JOIN vocab.concept_class cc ON cc.concept_class_id = t.concept_class_id
        WHERE cc.concept_class_id IS NULL
          AND t.concept_class_id IS NOT NULL
          AND TRIM(t.concept_class_id) != ''
      `
    },
    {
      name: 'CONCEPT_CODE_UNIQUE',
      level: 'ERROR',
      field: 'concept_code',
      message: 'Concept code already exists in vocab.vocabulary',
      sql: `
        SELECT
          t.source_row_number,
          'Concept code already exists: ' || t.concept_code || ' in vocab.vocabulary ' || t.vocabulary_id AS validation_message,
          'concept_code' AS field_name
        FROM {TEMP_TABLE} t
        INNER JOIN vocab.concept c ON c.concept_code = t.concept_code
          AND c.vocabulary_id = t.vocabulary_id
        WHERE t.concept_code IS NOT NULL
          AND TRIM(t.concept_code) != ''
      `
    },
    {
      name: 'CONCEPT_NAME_LENGTH',
      level: 'WARNING',
      field: 'concept_name',
      message: 'Concept name is very long',
      sql: `
        SELECT
          source_row_number,
          'Concept name exceeds 255 characters (length: ' || LENGTH(concept_name) || ')' AS validation_message,
          'concept_name' AS field_name
        FROM {TEMP_TABLE}
        WHERE concept_name IS NOT NULL
          AND LENGTH(concept_name) > 255
      `
    }
  ],

  /**
   * T2: Adding new standard concept(s) to an existing vocab.vocabulary
   */
  'T2': [
    {
      name: 'REQUIRED_FIELDS',
      level: 'ERROR',
      field: 'ALL',
      message: 'Required fields are missing',
      sql: `
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
        WHERE missing_field IS NOT NULL
      `
    },
    {
      name: 'VOCABULARY_EXISTS',
      level: 'ERROR',
      field: 'vocabulary_id',
      message: 'Vocabulary does not exist',
      sql: `
        SELECT
          t.source_row_number,
          'Vocabulary ID does not exist: ' || t.vocabulary_id AS validation_message,
          'vocabulary_id' AS field_name
        FROM {TEMP_TABLE} t
        LEFT JOIN vocab.vocabulary v ON v.vocabulary_id = t.vocabulary_id
        WHERE v.vocabulary_id IS NULL
          AND t.vocabulary_id IS NOT NULL
          AND TRIM(t.vocabulary_id) != ''
      `
    },
    {
      name: 'DOMAIN_EXISTS',
      level: 'ERROR',
      field: 'domain_id',
      message: 'Domain does not exist',
      sql: `
        SELECT
          t.source_row_number,
          'Domain ID does not exist: ' || t.domain_id AS validation_message,
          'domain_id' AS field_name
        FROM {TEMP_TABLE} t
        LEFT JOIN vocab.domain d ON d.domain_id = t.domain_id
        WHERE d.domain_id IS NULL
          AND t.domain_id IS NOT NULL
          AND TRIM(t.domain_id) != ''
      `
    },
    {
      name: 'CONCEPT_CLASS_EXISTS',
      level: 'ERROR',
      field: 'concept_class_id',
      message: 'Concept class does not exist',
      sql: `
        SELECT
          t.source_row_number,
          'Concept Class ID does not exist: ' || t.concept_class_id AS validation_message,
          'concept_class_id' AS field_name
        FROM {TEMP_TABLE} t
        LEFT JOIN vocab.concept_class cc ON cc.concept_class_id = t.concept_class_id
        WHERE cc.concept_class_id IS NULL
          AND t.concept_class_id IS NOT NULL
          AND TRIM(t.concept_class_id) != ''
      `
    }
  ],

  /**
   * T3: Adding concept relationship(s)
   */
  'T3': [
    {
      name: 'REQUIRED_FIELDS',
      level: 'ERROR',
      field: 'ALL',
      message: 'Required fields are missing',
      sql: `
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
        WHERE missing_field IS NOT NULL
      `
    },
    {
      name: 'CONCEPT_1_EXISTS',
      level: 'ERROR',
      field: 'concept_id_1',
      message: 'Source concept does not exist',
      sql: `
        SELECT
          t.source_row_number,
          'Concept ID 1 does not exist: ' || t.concept_id_1 AS validation_message,
          'concept_id_1' AS field_name
        FROM {TEMP_TABLE} t
        LEFT JOIN vocab.concept c ON c.concept_id = t.concept_id_1::integer
        WHERE c.concept_id IS NULL
          AND t.concept_id_1 IS NOT NULL
      `
    },
    {
      name: 'CONCEPT_2_EXISTS',
      level: 'ERROR',
      field: 'concept_id_2',
      message: 'Target concept does not exist',
      sql: `
        SELECT
          t.source_row_number,
          'Concept ID 2 does not exist: ' || t.concept_id_2 AS validation_message,
          'concept_id_2' AS field_name
        FROM {TEMP_TABLE} t
        LEFT JOIN vocab.concept c ON c.concept_id = t.concept_id_2::integer
        WHERE c.concept_id IS NULL
          AND t.concept_id_2 IS NOT NULL
      `
    },
    {
      name: 'RELATIONSHIP_EXISTS',
      level: 'ERROR',
      field: 'relationship_id',
      message: 'Relationship type does not exist',
      sql: `
        SELECT
          t.source_row_number,
          'Relationship ID does not exist: ' || t.relationship_id AS validation_message,
          'relationship_id' AS field_name
        FROM {TEMP_TABLE} t
        LEFT JOIN vocab.relationship r ON r.relationship_id = t.relationship_id
        WHERE r.relationship_id IS NULL
          AND t.relationship_id IS NOT NULL
          AND TRIM(t.relationship_id) != ''
      `
    },
    {
      name: 'RELATIONSHIP_DUPLICATE',
      level: 'ERROR',
      field: 'relationship_id',
      message: 'Relationship already exists',
      sql: `
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
          AND t.concept_id_2 IS NOT NULL
      `
    },
    {
      name: 'SELF_REFERENCE',
      level: 'WARNING',
      field: 'concept_id_1',
      message: 'Concept references itself',
      sql: `
        SELECT
          source_row_number,
          'Concept references itself (concept_id_1 = concept_id_2)' AS validation_message,
          'concept_id_1' AS field_name
        FROM {TEMP_TABLE}
        WHERE concept_id_1 = concept_id_2
      `
    }
  ],

  /**
   * T4: Deprecating concept(s)
   */
  'T4': [
    {
      name: 'REQUIRED_FIELDS',
      level: 'ERROR',
      field: 'ALL',
      message: 'Required fields are missing',
      sql: `
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
        WHERE missing_field IS NOT NULL
      `
    },
    {
      name: 'CONCEPT_EXISTS',
      level: 'ERROR',
      field: 'concept_id',
      message: 'Concept does not exist',
      sql: `
        SELECT
          t.source_row_number,
          'Concept ID does not exist: ' || t.concept_id AS validation_message,
          'concept_id' AS field_name
        FROM {TEMP_TABLE} t
        LEFT JOIN vocab.concept c ON c.concept_id = t.concept_id
        WHERE c.concept_id IS NULL
      `
    },
    {
      name: 'ALREADY_DEPRECATED',
      level: 'WARNING',
      field: 'concept_id',
      message: 'Concept is already deprecated',
      sql: `
        SELECT
          t.source_row_number,
          'Concept is already deprecated: ' || t.concept_id AS validation_message,
          'concept_id' AS field_name
        FROM {TEMP_TABLE} t
        INNER JOIN vocab.concept c ON c.concept_id = t.concept_id
        WHERE c.invalid_reason IS NOT NULL
      `
    },
    {
      name: 'INVALID_REASON_CODE',
      level: 'ERROR',
      field: 'invalid_reason',
      message: 'Invalid reason code',
      sql: `
        SELECT
          source_row_number,
          'Invalid reason must be D (Deleted) or U (Updated): ' || invalid_reason AS validation_message,
          'invalid_reason' AS field_name
        FROM {TEMP_TABLE}
        WHERE invalid_reason NOT IN ('D', 'U')
      `
    }
  ],

  /**
   * T5: Modifying concept(s) attributes
   */
  'T5': [
    {
      name: 'REQUIRED_FIELDS',
      level: 'ERROR',
      field: 'ALL',
      message: 'Required fields are missing',
      sql: `
        SELECT
          source_row_number,
          'Required field concept_id is empty' AS validation_message,
          'concept_id' AS field_name
        FROM {TEMP_TABLE}
        WHERE concept_id IS NULL
      `
    },
    {
      name: 'CONCEPT_EXISTS',
      level: 'ERROR',
      field: 'concept_id',
      message: 'Concept does not exist',
      sql: `
        SELECT
          t.source_row_number,
          'Concept ID does not exist: ' || t.concept_id AS validation_message,
          'concept_id' AS field_name
        FROM {TEMP_TABLE} t
        LEFT JOIN vocab.concept c ON c.concept_id = t.concept_id
        WHERE c.concept_id IS NULL
      `
    },
    {
      name: 'NO_CHANGES',
      level: 'WARNING',
      field: 'ALL',
      message: 'No changes detected',
      sql: `
        SELECT
          t.source_row_number,
          'No changes detected for concept: ' || t.concept_id AS validation_message,
          'concept_id' AS field_name
        FROM {TEMP_TABLE} t
        INNER JOIN vocab.concept c ON c.concept_id = t.concept_id
        WHERE (t.concept_name IS NULL OR c.concept_name = t.concept_name)
          AND (t.domain_id IS NULL OR c.domain_id = t.domain_id)
          AND (t.concept_class_id IS NULL OR c.concept_class_id = t.concept_class_id)
      `
    }
  ],

  /**
   * T6: Creating new vocab.vocabulary
   */
  'T6': [
    {
      name: 'REQUIRED_FIELDS',
      level: 'ERROR',
      field: 'ALL',
      message: 'Required fields are missing',
      sql: `
        SELECT
          source_row_number,
          'Required field is empty: ' || missing_field AS validation_message,
          missing_field AS field_name
        FROM (
          SELECT
            source_row_number,
            CASE
              WHEN vocabulary_id IS NULL OR TRIM(vocabulary_id) = '' THEN 'vocabulary_id'
              WHEN vocab.vocabulary_name IS NULL OR TRIM(vocab.vocabulary_name) = '' THEN 'vocab.vocabulary_name'
              WHEN vocab.vocabulary_reference IS NULL OR TRIM(vocab.vocabulary_reference) = '' THEN 'vocab.vocabulary_reference'
            END AS missing_field
          FROM {TEMP_TABLE}
        ) missing
        WHERE missing_field IS NOT NULL
      `
    },
    {
      name: 'VOCABULARY_ID_FORMAT',
      level: 'ERROR',
      field: 'vocabulary_id',
      message: 'Invalid vocab.vocabulary ID format',
      sql: `
        SELECT
          source_row_number,
          'Vocabulary ID must be uppercase alphanumeric: ' || vocabulary_id AS validation_message,
          'vocabulary_id' AS field_name
        FROM {TEMP_TABLE}
        WHERE vocabulary_id !~ '^[A-Z0-9_]+$'
      `
    },
    {
      name: 'VOCABULARY_EXISTS',
      level: 'ERROR',
      field: 'vocabulary_id',
      message: 'Vocabulary ID already exists',
      sql: `
        SELECT
          t.source_row_number,
          'Vocabulary ID already exists: ' || t.vocabulary_id AS validation_message,
          'vocabulary_id' AS field_name
        FROM {TEMP_TABLE} t
        INNER JOIN vocab.vocabulary v ON v.vocabulary_id = t.vocabulary_id
      `
    }
  ],

  /**
   * T7: Other modifications
   */
  'T7': [
    {
      name: 'BASIC_VALIDATION',
      level: 'INFO',
      field: 'ALL',
      message: 'Basic validation passed',
      sql: `
        SELECT
          source_row_number,
          'Row validated successfully' AS validation_message,
          '' AS field_name
        FROM {TEMP_TABLE}
        LIMIT 0
      `
    }
  ]
};

/**
 * Gets required fields for a template type
 *
 * @param {string} templateType - Template type
 * @return {Array<string>} Array of required field names
 */
function getRequiredFields(templateType) {
  const requiredFieldsMap = {
    'T1': ['concept_name', 'concept_code', 'vocabulary_id', 'domain_id', 'concept_class_id'],
    'T2': ['concept_name', 'concept_code', 'vocabulary_id', 'domain_id', 'concept_class_id', 'standard_concept'],
    'T3': ['concept_id_1', 'concept_id_2', 'relationship_id'],
    'T4': ['concept_id', 'invalid_reason'],
    'T5': ['concept_id'],
    'T6': ['vocabulary_id', 'vocab.vocabulary_name', 'vocab.vocabulary_reference'],
    'T7': []
  };

  return requiredFieldsMap[templateType] || [];
}

/**
 * Gets field data types for a template type
 *
 * @param {string} templateType - Template type
 * @return {Object} Map of field names to expected types
 */
function getFieldDataTypes(templateType) {
  const dataTypesMap = {
    'T1': {
      'concept_id': 'number',
      'valid_start_date': 'date',
      'valid_end_date': 'date'
    },
    'T2': {
      'concept_id': 'number',
      'valid_start_date': 'date',
      'valid_end_date': 'date'
    },
    'T3': {
      'concept_id_1': 'number',
      'concept_id_2': 'number',
      'valid_start_date': 'date',
      'valid_end_date': 'date'
    },
    'T4': {
      'concept_id': 'number',
      'valid_end_date': 'date'
    },
    'T5': {
      'concept_id': 'number'
    },
    'T6': {
      'vocab.vocabulary_concept_id': 'number'
    },
    'T7': {}
  };

  return dataTypesMap[templateType] || {};
}
