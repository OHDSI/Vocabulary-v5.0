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
 * Configuration dialog for Azure proxy connection
 */
function configureDatabaseConnection() {
  const ui = SpreadsheetApp.getUi();
  const scriptProperties = PropertiesService.getScriptProperties();

  // Show configuration dialog
  const htmlOutput = HtmlService.createHtmlOutput(`
    <style>
      body { font-family: Arial, sans-serif; padding: 20px; }
      label { display: block; margin-top: 15px; font-weight: bold; }
      input { width: 100%; padding: 8px; margin-top: 5px; box-sizing: border-box; }
      button { margin-top: 20px; padding: 10px 20px; background: #4285f4; color: white; border: none; cursor: pointer; }
      button:hover { background: #357ae8; }
      .help-text { font-size: 12px; color: #666; margin-top: 5px; }
      .success { color: green; margin-top: 10px; }
      .error { color: red; margin-top: 10px; }
      #testResult { margin-top: 15px; padding: 10px; display: none; }
    </style>

    <h3>Azure Proxy Configuration</h3>
    <p>Configure your Azure Container Instance validation proxy:</p>

    <form>
      <label>Proxy URL:</label>
      <input type="text" id="proxyUrl" value="${scriptProperties.getProperty('AZURE_PROXY_URL') || ''}"
             placeholder="https://your-app.azurecontainerapps.io">
      <div class="help-text">The URL of your Azure Container App (with HTTPS) or Container Instance</div>

      <label>API Key:</label>
      <input type="password" id="apiKey" value="${scriptProperties.getProperty('AZURE_API_KEY') || ''}"
             placeholder="Your API key from Azure deployment">
      <div class="help-text">The API_KEY environment variable from your container deployment</div>

      <button type="button" onclick="testConnection()">Test Connection</button>
      <button type="button" onclick="saveConfig()">Save Configuration</button>
    </form>

    <div id="testResult"></div>

    <script>
      function testConnection() {
        const proxyUrl = document.getElementById('proxyUrl').value;
        const apiKey = document.getElementById('apiKey').value;
        const resultDiv = document.getElementById('testResult');

        if (!proxyUrl || !apiKey) {
          resultDiv.className = 'error';
          resultDiv.innerHTML = '❌ Please fill in both fields';
          resultDiv.style.display = 'block';
          return;
        }

        resultDiv.innerHTML = '⏳ Testing connection...';
        resultDiv.style.display = 'block';
        resultDiv.className = '';

        // Save temporarily
        const tempConfig = {
          proxyUrl: proxyUrl,
          apiKey: apiKey
        };

        google.script.run
          .withSuccessHandler(function(result) {
            if (result.success) {
              resultDiv.className = 'success';
              resultDiv.innerHTML = '✅ Connection successful!<br>' +
                'Database: ' + (result.database || 'Connected') + '<br>' +
                (result.version ? 'Version: ' + result.version : '');
            } else {
              resultDiv.className = 'error';
              resultDiv.innerHTML = '❌ Connection failed: ' + result.message;
            }
          })
          .withFailureHandler(function(error) {
            resultDiv.className = 'error';
            resultDiv.innerHTML = '❌ Test failed: ' + error.message;
          })
          .testProxyConnection(tempConfig);
      }

      function saveConfig() {
        const config = {
          proxyUrl: document.getElementById('proxyUrl').value,
          apiKey: document.getElementById('apiKey').value
        };

        if (!config.proxyUrl || !config.apiKey) {
          alert('Please fill in both fields');
          return;
        }

        google.script.run
          .withSuccessHandler(function() {
            alert('Configuration saved successfully!');
            google.script.host.close();
          })
          .withFailureHandler(function(error) {
            alert('Error saving configuration: ' + error.message);
          })
          .saveProxyConfig(config);
      }
    </script>
  `)
  .setWidth(500)
  .setHeight(500);

  ui.showModalDialog(htmlOutput, 'Azure Proxy Configuration');
}

/**
 * Tests proxy connection (called from dialog)
 */
function testProxyConnection(config) {
  try {
    // Temporarily save config for testing
    const scriptProperties = PropertiesService.getScriptProperties();
    scriptProperties.setProperty('AZURE_PROXY_URL', config.proxyUrl);
    scriptProperties.setProperty('AZURE_API_KEY', config.apiKey);

    // Test the connection
    return testAzureProxyConnection();

  } catch (error) {
    return {
      success: false,
      message: error.message
    };
  }
}

/**
 * Saves Azure proxy configuration
 */
function saveProxyConfig(config) {
  const scriptProperties = PropertiesService.getScriptProperties();

  scriptProperties.setProperty('AZURE_PROXY_URL', config.proxyUrl);
  scriptProperties.setProperty('AZURE_API_KEY', config.apiKey);

  Logger.log('Azure proxy configuration saved');
  return true;
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

/**
 * Manual configuration function (run from Script Editor)
 * Use this if the UI dialog doesn't work
 */
function configureProxyManually() {
  const scriptProperties = PropertiesService.getScriptProperties();

  // Update these values:
  const PROXY_URL = 'https://your-app.azurecontainerapps.io';  // Change this (use HTTPS if available)
  const API_KEY = 'YOUR-API-KEY-HERE';                          // Change this

  scriptProperties.setProperty('AZURE_PROXY_URL', PROXY_URL);
  scriptProperties.setProperty('AZURE_API_KEY', API_KEY);

  Logger.log('Configuration saved manually');
  Logger.log('Proxy URL: ' + PROXY_URL);
  Logger.log('API Key: ' + (API_KEY.length > 10 ? API_KEY.substring(0, 10) + '...' : 'Set'));

  // Test connection
  const result = testAzureProxyConnection();
  Logger.log('Connection test result: ' + JSON.stringify(result));

  return result;
}
