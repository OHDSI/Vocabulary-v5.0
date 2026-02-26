/**
 * Azure Container App - Database Validation Proxy
 *
 * Express.js server that can be deployed to Azure Container Apps
 * with a static outbound IP for database whitelisting.
 */

const express = require('express');
const { Pool } = require('pg'); // or 'mysql2' for MySQL
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(express.json({ limit: '10mb' }));
app.use(cors());

// Database connection pool
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: process.env.DB_SSL === 'true' ? {
    rejectUnauthorized: false // Set to true in production with proper certs
  } : false,
  max: 10, // connection pool size
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

// Test pool connection on startup
pool.connect((err, client, release) => {
  if (err) {
    console.error('Error connecting to database on startup:', err.stack);
  } else {
    console.log('Database connection pool initialized successfully');
    release();
  }
});

// Middleware: API Key Authentication
function authenticateApiKey(req, res, next) {
  const apiKey = req.get('Authorization');
  const expectedKey = `Bearer ${process.env.API_KEY}`;

  if (!apiKey || apiKey !== expectedKey) {
    return res.status(401).json({
      success: false,
      error: 'Unauthorized',
      message: 'Invalid or missing API key'
    });
  }

  next();
}

// Health check endpoint (no auth required)
app.get('/health', async (req, res) => {
  try {
    const client = await pool.connect();
    await client.query('SELECT 1');
    client.release();

    res.json({
      status: 'healthy',
      database: 'connected',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      database: 'disconnected',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Get outbound IP (useful for whitelisting)
app.get('/ip', (req, res) => {
  res.json({
    clientIp: req.ip,
    forwardedFor: req.get('X-Forwarded-For'),
    message: 'This is the IP you see. For outbound IP, check Azure Container App logs when connecting to database.'
  });
});

// Test database connection
app.post('/test-connection', authenticateApiKey, async (req, res) => {
  try {
    const client = await pool.connect();
    const result = await client.query('SELECT version() as version, current_database() as database');
    client.release();

    res.json({
      success: true,
      message: 'Database connection successful',
      database: result.rows[0].database,
      version: result.rows[0].version
    });
  } catch (error) {
    console.error('Database connection error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      code: error.code
    });
  }
});

// Main validation endpoint
app.post('/validate', authenticateApiKey, async (req, res) => {
  const startTime = Date.now();

  try {
    const { data, templateType } = req.body;

    // Validate request
    if (!data || !Array.isArray(data) || data.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Invalid request',
        message: 'Data must be a non-empty array'
      });
    }

    if (!templateType) {
      return res.status(400).json({
        success: false,
        error: 'Invalid request',
        message: 'Template type is required'
      });
    }

    console.log(`Processing validation: templateType=${templateType}, rows=${data.length}`);

    // Perform validation
    const result = await performValidation(data, templateType);

    // Add performance metrics
    result.processingTime = Date.now() - startTime;

    res.json(result);

  } catch (error) {
    console.error('Validation error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
      message: error.message,
      processingTime: Date.now() - startTime
    });
  }
});

/**
 * Performs validation on the provided data
 */
async function performValidation(data, templateType) {
  const client = await pool.connect();

  try {
    // Start transaction
    await client.query('BEGIN');

    // Create temporary table
    const tempTableName = `temp_validation_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
    await createTemporaryTable(client, tempTableName, data);

    // Get validation queries
    const queries = getValidationQueries(templateType);

    // Execute validation queries
    const results = [];
    for (const query of queries) {
      try {
        const sql = query.sql.replace(/{TEMP_TABLE}/g, tempTableName);
        const queryResult = await client.query(sql);

        queryResult.rows.forEach(row => {
          results.push({
            row: row.source_row_number || 0,
            level: query.level || 'ERROR',
            message: row.validation_message || query.message,
            field: row.field_name || query.field || '',
            rule: query.name
          });
        });
      } catch (queryError) {
        console.error(`Query error for rule ${query.name}:`, queryError);
        results.push({
          row: 0,
          level: 'ERROR',
          message: `Validation rule failed: ${query.name} - ${queryError.message}`,
          field: 'SYSTEM',
          rule: query.name
        });
      }
    }

    // Clean up temporary table
    await client.query(`DROP TABLE IF EXISTS ${tempTableName}`);

    // Commit transaction
    await client.query('COMMIT');

    // Return results
    return {
      success: true,
      totalRows: data.length,
      errorCount: results.filter(r => r.level === 'ERROR').length,
      warningCount: results.filter(r => r.level === 'WARNING').length,
      results: results
    };

  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Creates temporary table with user data
 */
async function createTemporaryTable(client, tableName, data) {
  if (!data || data.length === 0) {
    throw new Error('No data provided');
  }

  // Get column definitions from first row
  const firstRow = data[0];
  const columns = [];

  for (const [key, value] of Object.entries(firstRow)) {
    if (key === '_rowNumber') continue;

    let sqlType = 'TEXT';
    if (typeof value === 'number') {
      sqlType = 'NUMERIC';
    } else if (value instanceof Date || isValidDate(value)) {
      sqlType = 'DATE';
    }

    const columnName = sanitizeSqlIdentifier(key);
    columns.push(`${columnName} ${sqlType}`);
  }

  columns.push('source_row_number INTEGER');

  // Create temporary table
  const createTableSql = `
    CREATE TEMPORARY TABLE ${tableName} (
      ${columns.join(', ')}
    )
  `;

  await client.query(createTableSql);

  // Insert data using parameterized queries
  const columnNames = Object.keys(firstRow)
    .filter(k => k !== '_rowNumber')
    .map(sanitizeSqlIdentifier);

  columnNames.push('source_row_number');

  for (const row of data) {
    const values = [];
    const placeholders = [];
    let paramIndex = 1;

    for (const key of Object.keys(firstRow)) {
      if (key === '_rowNumber') continue;
      values.push(row[key] === '' ? null : row[key]);
      placeholders.push(`$${paramIndex++}`);
    }

    values.push(row._rowNumber || 0);
    placeholders.push(`$${paramIndex++}`);

    const insertSql = `
      INSERT INTO ${tableName} (${columnNames.join(', ')})
      VALUES (${placeholders.join(', ')})
    `;

    await client.query(insertSql, values);
  }

  console.log(`Created temporary table ${tableName} with ${data.length} rows`);
}

/**
 * Sanitizes SQL identifiers
 */
function sanitizeSqlIdentifier(identifier) {
  return identifier.replace(/[^a-zA-Z0-9_]/g, '_').toLowerCase();
}

/**
 * Checks if a value is a valid date
 */
function isValidDate(value) {
  if (!value) return false;
  const date = new Date(value);
  return date instanceof Date && !isNaN(date);
}

/**
 * Gets validation queries for template type
 */
function getValidationQueries(templateType) {
  // Validation rules with vocab. schema prefix
  const rules = {
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
        message: 'Concept code already exists',
        sql: `
          SELECT
            t.source_row_number,
            'Concept code already exists: ' || t.concept_code || ' in vocabulary ' || t.vocabulary_id AS validation_message,
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
      }
    ],
    'T3': [],
    'T4': [],
    'T5': [],
    'T6': [],
    'T7': []
  };

  return rules[templateType] || [];
}

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    message: err.message
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Not found',
    message: `Route ${req.method} ${req.path} not found`
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(` Validation proxy server running on port ${PORT}`);
  console.log(` Health check: http://localhost:${PORT}/health`);
  console.log(` API Key authentication enabled: ${process.env.API_KEY ? 'Yes' : 'No'}`);
  console.log(` Database: ${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing server...');
  await pool.end();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, closing server...');
  await pool.end();
  process.exit(0);
});
