/**
 * Database Validation Module - Azure Proxy Version
 *
 * Connects to Azure Container Instance proxy instead of direct database connection
 *
 * SECURITY NOTE:
 * - Never hardcode AZURE_PROXY_URL or AZURE_API_KEY in this file
 * - Credentials are stored in Script Properties (encrypted by Google)
 * - Use Admin > Configure Database to set credentials
 * - Script Properties do NOT copy when users make a copy of this template
 */

/**
 * Performs database validation on sanitized data via Azure proxy
 *
 * @param {Array<Object>} data - Sanitized data to validate
 * @param {string} templateType - Template type (T1-T7)
 * @param {Object} metadata - Metadata about the submission
 * @return {Object} Validation results
 */
function performDatabaseValidation(data, templateType, metadata) {
  try {
    // Get Azure proxy configuration
    const scriptProperties = PropertiesService.getScriptProperties();
    const proxyUrl = scriptProperties.getProperty('AZURE_PROXY_URL');
    const apiKey = scriptProperties.getProperty('AZURE_API_KEY');

    if (!proxyUrl || !apiKey) {
      throw new Error('Azure proxy not configured. Please run "Configure Database" from the Admin menu.');
    }

    // Prepare request payload
    const payload = {
      data: data,
      templateType: templateType
    };

    // Make request to Azure proxy
    const options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      payload: JSON.stringify(payload),
      muteHttpExceptions: true
    };

    Logger.log(`Sending ${data.length} rows to Azure proxy for validation (template: ${templateType})`);

    const response = UrlFetchApp.fetch(`${proxyUrl}/validate`, options);
    const statusCode = response.getResponseCode();
    const responseText = response.getContentText();

    Logger.log(`Azure proxy response: ${statusCode}`);

    if (statusCode !== 200) {
      throw new Error(`Validation service error (${statusCode}): ${responseText}`);
    }

    const result = JSON.parse(responseText);

    if (!result.success && result.error) {
      throw new Error(result.error || result.message || 'Validation failed');
    }

    return result;

  } catch (error) {
    Logger.log(`Azure proxy validation error: ${error.message}`);

    // Return error result
    return {
      success: false,
      errorCount: 1,
      warningCount: 0,
      totalRows: data.length,
      results: [{
        row: 0,
        level: 'ERROR',
        message: `Validation service error: ${error.message}`,
        field: 'SYSTEM'
      }]
    };
  }
}

/**
 * Tests connection to Azure proxy
 *
 * @return {Object} Connection test result
 */
function testAzureProxyConnection() {
  try {
    const scriptProperties = PropertiesService.getScriptProperties();
    const proxyUrl = scriptProperties.getProperty('AZURE_PROXY_URL');
    const apiKey = scriptProperties.getProperty('AZURE_API_KEY');

    if (!proxyUrl || !apiKey) {
      return {
        success: false,
        message: 'Azure proxy not configured'
      };
    }

    // Test health endpoint
    const healthResponse = UrlFetchApp.fetch(`${proxyUrl}/health`, {
      muteHttpExceptions: true
    });

    if (healthResponse.getResponseCode() !== 200) {
      return {
        success: false,
        message: `Health check failed (${healthResponse.getResponseCode()})`
      };
    }

    // Test database connection endpoint
    const options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      muteHttpExceptions: true
    };

    const dbTestResponse = UrlFetchApp.fetch(`${proxyUrl}/test-connection`, options);
    const statusCode = dbTestResponse.getResponseCode();
    const responseText = dbTestResponse.getContentText();

    if (statusCode !== 200) {
      return {
        success: false,
        message: `Database connection test failed (${statusCode}): ${responseText}`
      };
    }

    const result = JSON.parse(responseText);

    return {
      success: result.success,
      message: result.message || 'Connection successful',
      database: result.database,
      version: result.version
    };

  } catch (error) {
    return {
      success: false,
      message: `Connection error: ${error.message}`
    };
  }
}

/**
 * INITIAL SETUP: Configure database connection credentials
 *
 * IMPORTANT: Run this function ONCE after deployment to set up your credentials.
 *
 * HOW TO USE:
 * 1. Open the Apps Script editor (Extensions > Apps Script)
 * 2. Open this file (DatabaseValidation.gs)
 * 3. Replace YOUR_PROXY_URL_HERE and YOUR_API_KEY_HERE below with your actual values
 * 4. Click the "Run" button (or press Ctrl/Cmd + R) to execute this function
 * 5. After running successfully, REPLACE the values back with placeholders before committing to GitHub
 *
 * The credentials will be stored securely in Script Properties (encrypted by Google)
 * and will NOT be visible in the code or copied when users duplicate this spreadsheet.
 */
function configureDatabaseConnection() {
  const scriptProperties = PropertiesService.getScriptProperties();

  // REPLACE THESE VALUES with your actual credentials:
  const PROXY_URL = 'YOUR_PROXY_URL_HERE';  // e.g., 'https://your-app.azurecontainerapps.io'
  const API_KEY = 'YOUR_API_KEY_HERE';       // Your API key from Azure deployment

  // Validate that values have been updated
  if (PROXY_URL === 'YOUR_PROXY_URL_HERE' || API_KEY === 'YOUR_API_KEY_HERE') {
    throw new Error('Please update PROXY_URL and API_KEY in the configureDatabaseConnection() function before running.');
  }

  // Save to Script Properties (encrypted, server-side storage)
  scriptProperties.setProperty('AZURE_PROXY_URL', PROXY_URL);
  scriptProperties.setProperty('AZURE_API_KEY', API_KEY);

  Logger.log('✅ Configuration saved successfully!');
  Logger.log('Proxy URL: ' + PROXY_URL);
  Logger.log('API Key: ' + (API_KEY.substring(0, 10) + '...'));

  // Test the connection
  Logger.log('Testing connection...');
  const testResult = testAzureProxyConnection();

  if (testResult.success) {
    Logger.log('✅ Connection test PASSED!');
    Logger.log('Database: ' + (testResult.database || 'Connected'));
    if (testResult.version) {
      Logger.log('Version: ' + testResult.version);
    }

    // Show success message to user
    SpreadsheetApp.getUi().alert(
      'Configuration Successful!',
      'Database connection has been configured and tested successfully.\n\n' +
      'Database: ' + (testResult.database || 'Connected') + '\n' +
      (testResult.version ? 'Version: ' + testResult.version : ''),
      SpreadsheetApp.getUi().ButtonSet.OK
    );
  } else {
    Logger.log('❌ Connection test FAILED: ' + testResult.message);
    throw new Error('Connection test failed: ' + testResult.message);
  }

  Logger.log('\n⚠️  IMPORTANT: Remember to replace your credentials with placeholders before committing to GitHub!');
}


/**
 * Gets current proxy configuration (for debugging)
 */
function getProxyConfig() {
  const scriptProperties = PropertiesService.getScriptProperties();

  return {
    proxyUrl: scriptProperties.getProperty('AZURE_PROXY_URL') || 'Not configured',
    apiKeySet: scriptProperties.getProperty('AZURE_API_KEY') ? 'Yes' : 'No'
  };
}

