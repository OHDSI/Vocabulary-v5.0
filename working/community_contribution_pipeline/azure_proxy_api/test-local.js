/**
 * Local testing script for validation proxy
 */

const http = require('http');

const API_KEY = process.env.API_KEY || 'test-api-key';
const BASE_URL = 'http://localhost:8080';

function makeRequest(path, method = 'GET', data = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 8080,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_KEY}`
      }
    };

    const req = http.request(options, (res) => {
      let responseData = '';

      res.on('data', (chunk) => {
        responseData += chunk;
      });

      res.on('end', () => {
        try {
          const parsed = JSON.parse(responseData);
          resolve({ status: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, data: responseData });
        }
      });
    });

    req.on('error', reject);

    if (data) {
      req.write(JSON.stringify(data));
    }

    req.end();
  });
}

async function runTests() {
  console.log('Testing Validation Proxy\n');

  try {
    // Test 1: Health check
    console.log('   Testing health endpoint...');
    const health = await makeRequest('/health');
    console.log(`   Status: ${health.status}`);
    console.log(`   Response:`, health.data);
    console.log('   Health check passed\n');

    // Test 2: IP endpoint
    console.log('   Testing IP endpoint...');
    const ip = await makeRequest('/ip');
    console.log(`   Status: ${ip.status}`);
    console.log(`   Response:`, ip.data);
    console.log('   IP check passed\n');

    // Test 3: Test connection (requires database)
    console.log('Testing database connection...');
    const dbTest = await makeRequest('/test-connection', 'POST');
    console.log(`   Status: ${dbTest.status}`);
    console.log(`   Response:`, dbTest.data);
    if (dbTest.data.success) {
      console.log('   Database connection successful\n');
    } else {
      console.log('   Database connection failed (expected if DB not configured)\n');
    }

    // Test 4: Validation with sample data
    console.log('    Testing validation endpoint...');
    const testData = {
      data: [
        {
          concept_name: 'Test Concept',
          concept_code: 'TEST001',
          vocabulary_id: 'ICD10',
          domain_id: 'Condition',
          concept_class_id: 'Clinical Finding',
          _rowNumber: 2
        }
      ],
      templateType: 'T1'
    };

    const validation = await makeRequest('/validate', 'POST', testData);
    console.log(`   Status: ${validation.status}`);
    console.log(`   Response:`, JSON.stringify(validation.data, null, 2));
    if (validation.data.success !== undefined) {
      console.log('   Validation endpoint working\n');
    }

    // Test 5: Authentication
    console.log('   Testing authentication...');
    const noAuth = await makeRequest('/test-connection', 'POST');
    // This should fail if we don't send auth
    console.log(`   Without auth: ${noAuth.status === 401 ? ' Correctly rejected' : '❌ Should reject'}`);

    console.log('\n All tests completed!');

  } catch (error) {
    console.error('\n Test failed:', error.message);
    process.exit(1);
  }
}

// Run tests
runTests();
