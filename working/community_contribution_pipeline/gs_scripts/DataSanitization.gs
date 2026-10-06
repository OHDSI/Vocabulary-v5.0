/**
 * Data Sanitization Module
 *
 * Handles data cleaning and SQL injection prevention for vocabulary validation
 */

/**
 * Sanitizes all data to prevent SQL injection and other security issues
 *
 * @param {Array<Object>} data - Array of row objects to sanitize
 * @return {Array<Object>} Sanitized data
 */
function sanitizeData(data) {
  if (!data || data.length === 0) {
    return [];
  }

  const sanitized = [];

  for (const row of data) {
    const sanitizedRow = {};

    for (const [key, value] of Object.entries(row)) {
      sanitizedRow[key] = sanitizeValue(value, key);
    }

    sanitized.push(sanitizedRow);
  }

  return sanitized;
}

/**
 * Sanitizes a single value based on its type and field name
 *
 * @param {*} value - Value to sanitize
 * @param {string} fieldName - Name of the field (for context)
 * @return {*} Sanitized value
 */
function sanitizeValue(value, fieldName) {
  // Handle null/undefined
  if (value === null || value === undefined) {
    return null;
  }

  // Handle numbers
  if (typeof value === 'number') {
    return sanitizeNumber(value);
  }

  // Handle dates
  if (value instanceof Date) {
    return value;
  }

  // Handle booleans
  if (typeof value === 'boolean') {
    return value;
  }

  // Handle strings (most important for SQL injection)
  if (typeof value === 'string') {
    return sanitizeString(value, fieldName);
  }

  // For other types, convert to string and sanitize
  return sanitizeString(String(value), fieldName);
}

/**
 * Sanitizes string values to prevent SQL injection
 *
 * @param {string} str - String to sanitize
 * @param {string} fieldName - Name of the field (for context)
 * @return {string} Sanitized string
 */
function sanitizeString(str, fieldName) {
  if (!str || str.trim() === '') {
    return '';
  }

  let sanitized = str.trim();

  // Remove or escape dangerous SQL keywords and patterns
  // This is a whitelist approach - only allow specific patterns

  // Check for SQL injection patterns
  const dangerousPatterns = [
    /(\b(ALTER|CREATE|DELETE|DROP|EXEC(UTE)?|INSERT( +INTO)?|MERGE|SELECT|UPDATE|UNION( +ALL)?)\b)/gi,
    /(;|\-\-|\/\*|\*\/|xp_|sp_|exec\s*\()/gi,
    /('|"|\`)/g, // Quote characters
    /(@@|@)/g,   // Variable declarations
    /(\bOR\b.*=.*|1\s*=\s*1|'\s*OR\s*')/gi // Classic SQL injection patterns
  ];

  for (const pattern of dangerousPatterns) {
    if (pattern.test(sanitized)) {
      // Log the attempted injection
      Logger.log(`Potential SQL injection detected in field "${fieldName}": ${sanitized}`);

      // For quote characters, escape them
      if (pattern.toString().includes("'")) {
        sanitized = sanitized.replace(/'/g, "''");
      } else {
        // For other patterns, remove the dangerous content
        sanitized = sanitized.replace(pattern, '');
      }
    }
  }

  // Limit string length to prevent buffer overflow attacks
  const MAX_LENGTH = 5000;
  if (sanitized.length > MAX_LENGTH) {
    Logger.log(`Field "${fieldName}" truncated from ${sanitized.length} to ${MAX_LENGTH} characters`);
    sanitized = sanitized.substring(0, MAX_LENGTH);
  }

  return sanitized;
}

/**
 * Sanitizes numeric values
 *
 * @param {number} num - Number to sanitize
 * @return {number|null} Sanitized number or null if invalid
 */
function sanitizeNumber(num) {
  // Check for valid number
  if (isNaN(num) || !isFinite(num)) {
    return null;
  }

  // Check for reasonable ranges (adjust based on your needs)
  const MAX_SAFE_INTEGER = 9007199254740991; // JavaScript max safe integer

  if (Math.abs(num) > MAX_SAFE_INTEGER) {
    Logger.log(`Number out of safe range: ${num}`);
    return null;
  }

  return num;
}

/**
 * Validates that required fields are present in the data
 *
 * @param {Array<Object>} data - Data to validate
 * @param {Array<string>} requiredFields - List of required field names
 * @return {Object} Validation result with errors
 */
function validateRequiredFields(data, requiredFields) {
  const errors = [];

  for (let i = 0; i < data.length; i++) {
    const row = data[i];
    const rowErrors = [];

    for (const field of requiredFields) {
      if (!row[field] || row[field] === '') {
        rowErrors.push(`Missing required field: ${field}`);
      }
    }

    if (rowErrors.length > 0) {
      errors.push({
        rowNumber: row._rowNumber || (i + 2), // +2 for header and 0-index
        errors: rowErrors
      });
    }
  }

  return {
    isValid: errors.length === 0,
    errors: errors
  };
}

/**
 * Validates data types for specific fields
 *
 * @param {Array<Object>} data - Data to validate
 * @param {Object} fieldTypes - Map of field names to expected types
 * @return {Object} Validation result with errors
 */
function validateDataTypes(data, fieldTypes) {
  const errors = [];

  for (let i = 0; i < data.length; i++) {
    const row = data[i];
    const rowErrors = [];

    for (const [field, expectedType] of Object.entries(fieldTypes)) {
      if (row[field] !== null && row[field] !== undefined && row[field] !== '') {
        const actualType = typeof row[field];

        if (expectedType === 'number' && actualType !== 'number') {
          // Try to convert to number
          const converted = Number(row[field]);
          if (isNaN(converted)) {
            rowErrors.push(`Field "${field}" must be a number, got: ${row[field]}`);
          }
        } else if (expectedType === 'date' && !(row[field] instanceof Date)) {
          // Try to convert to date
          const converted = new Date(row[field]);
          if (isNaN(converted.getTime())) {
            rowErrors.push(`Field "${field}" must be a valid date, got: ${row[field]}`);
          }
        }
      }
    }

    if (rowErrors.length > 0) {
      errors.push({
        rowNumber: row._rowNumber || (i + 2),
        errors: rowErrors
      });
    }
  }

  return {
    isValid: errors.length === 0,
    errors: errors
  };
}

/**
 * Escapes special characters for CSV export
 *
 * @param {string} value - Value to escape
 * @return {string} Escaped value
 */
function escapeCsvValue(value) {
  if (value === null || value === undefined) {
    return '';
  }

  const str = String(value);

  // If contains comma, quote, or newline, wrap in quotes and escape internal quotes
  if (str.includes(',') || str.includes('"') || str.includes('\n')) {
    return `"${str.replace(/"/g, '""')}"`;
  }

  return str;
}

/**
 * Converts data array to CSV format
 *
 * @param {Array<Object>} data - Data to convert
 * @return {string} CSV string
 */
function convertToCSV(data) {
  if (!data || data.length === 0) {
    return '';
  }

  // Get headers from first row
  const headers = Object.keys(data[0]).filter(key => key !== '_rowNumber');

  // Build CSV
  const rows = [headers.map(escapeCsvValue).join(',')];

  for (const row of data) {
    const values = headers.map(header => escapeCsvValue(row[header]));
    rows.push(values.join(','));
  }

  return rows.join('\n');
}
