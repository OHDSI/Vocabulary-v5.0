/**
 * Validation Rules Configuration (DEPRECATED)
 * This file is deprecated and kept only for reference.
 * Validation rules are now stored in: /ValidationRules.sql
 * The rules are loaded and executed by the Azure Proxy API server.
 * To modify validation rules edit ValidationRules.sql in the repository root
 */

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
    'T6': ['vocabulary_id', 'vocabulary_name', 'vocabulary_reference'],
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
      'vocabulary_concept_id': 'number'
    },
    'T7': {}
  };

  return dataTypesMap[templateType] || {};
}
