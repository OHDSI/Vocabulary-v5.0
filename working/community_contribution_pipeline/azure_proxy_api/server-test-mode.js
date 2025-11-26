/**
 * TEMPORARY TEST MODE VERSION
 *
 * This version bypasses database validation to test the connection.
 * Use this to verify Google Sheets -> Azure proxy is working.
 *
 * To use:
 * 1. Rename server.js to server-original.js
 * 2. Rename this file to server.js
 * 3. Rebuild and redeploy
 */

const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 8080;

app.use(express.json({ limit: '10mb' }));
app.use(cors());

// Middleware: API Key Authentication
function authenticateApiKey(req, res, next) {
  const apiKey = req.get('Authorization');
  const expectedKey = `Bearer ${process.env.API_KEY}`;

  if (!apiKey || apiKey !== expectedKey) {
    return res.status(401).json({
      success: false,
      error: 'Unauthorized'
    });
  }

  next();
}

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    mode: 'TEST MODE - No database validation',
    timestamp: new Date().toISOString()
  });
});

// Test connection (simulated)
app.post('/test-connection', authenticateApiKey, (req, res) => {
  res.json({
    success: true,
    message: 'TEST MODE: Simulated database connection',
    database: 'test_mode',
    version: 'PostgreSQL 15.x (simulated)'
  });
});

// Validation endpoint (TEST MODE - no database)
app.post('/validate', authenticateApiKey, (req, res) => {
  const { data, templateType } = req.body;

  console.log(`TEST MODE: Received ${data?.length || 0} rows for template ${templateType}`);

  if (!data || !Array.isArray(data)) {
    return res.status(400).json({
      success: false,
      error: 'Invalid data format'
    });
  }

  // Simulate validation results
  const results = [];

  // Check for required fields (basic validation)
  const requiredFields = {
    'T1': ['concept_name', 'concept_code', 'vocabulary_id', 'domain_id', 'concept_class_id'],
    'T2': ['concept_name', 'concept_code', 'vocabulary_id', 'domain_id', 'concept_class_id'],
    'T3': ['concept_id_1', 'concept_id_2', 'relationship_id']
  };

  const fields = requiredFields[templateType] || [];

  data.forEach((row, index) => {
    fields.forEach(field => {
      if (!row[field] || row[field] === '') {
        results.push({
          row: row._rowNumber || (index + 2),
          level: 'ERROR',
          message: `Required field is empty: ${field}`,
          field: field,
          rule: 'REQUIRED_FIELDS_TEST'
        });
      }
    });
  });

  // Add success message
  if (results.length === 0) {
    results.push({
      row: 0,
      level: 'INFO',
      message: `TEST MODE: ${data.length} rows passed basic validation. Database validation disabled.`,
      field: 'test',
      rule: 'TEST_MODE'
    });
  }

  res.json({
    success: true,
    totalRows: data.length,
    errorCount: results.filter(r => r.level === 'ERROR').length,
    warningCount: results.filter(r => r.level === 'WARNING').length,
    results: results,
    mode: 'TEST MODE - Database validation disabled'
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    message: err.message
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log('  RUNNING IN TEST MODE - DATABASE VALIDATION DISABLED');
  console.log(` Server running on port ${PORT}`);
  console.log(` Health check: http://localhost:${PORT}/health`);
});
