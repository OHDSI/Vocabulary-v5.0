/**
 * OHDSI Vocabulary Validation Pipeline - Main Controller
 *
 * This script manages the validation workflow for community-contributed
 * ontology mappings using Google Sheets templates.
 */

// Configuration Constants
const CONFIG = {
  INPUT_SHEET_NAME: 'Input',
  OUTPUT_SHEET_NAME: 'Output',
  METADATA_SHEET_NAME: 'Metadata',
  AUDIT_SHEET_NAME: 'AuditLog',
  COMBINED_VIEW_NAME: 'Combined View',
  WORKING_SHEET_NAME: 'Working Sheet',

  // Template Types (maps to validation rule sets)
  TEMPLATE_TYPES: {
    'T1': 'Adding new non-standard concept(s) to an existing vocabulary',
    'T2': 'Adding new standard concept(s) to an existing vocabulary',
    'T3': 'Adding concept relationship(s)',
    'T4': 'Deprecating concept(s)',
    'T5': 'Modifying concept(s) attributes',
    'T6': 'Creating new vocabulary',
    'T7': 'Other modifications'
  }
};

/**
 * Creates custom menu when spreadsheet opens
 */
function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('OHDSI Validation')
    .addItem('Validate Template', 'validateTemplate')
    .addItem('Clear Input Data', 'clearInputData')
    .addItem('Submit Final Version', 'submitFinalVersion')
    .addSeparator()
    .addItem('View Audit Log', 'showAuditLog')
    .addItem('Export Results', 'exportResults')
    .addSeparator()
    .addSubMenu(ui.createMenu('Admin')
      .addItem('Setup Sheets', 'setupSheets')
      .addItem('Configure Database', 'configureDatabaseConnection')
      .addItem('Configure Submission Folder', 'configureSubmissionFolder')
      .addSeparator()
      .addItem('Debug Metadata', 'debugMetadata')
      .addItem('Fix Metadata Sheet', 'fixMetadataSheet'))
    .addToUi();
}

/**
 * Main validation entry point
 */
function validateTemplate() {
  const ui = SpreadsheetApp.getUi();
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  try {
    // Show progress indicator
    ui.alert('Validation Started',
             'Processing your template. This may take a few moments...',
             ui.ButtonSet.OK);

    // Step 1: Extract and validate metadata
    const metadata = extractMetadata();
    if (!metadata) {
      throw new Error('Please fill in the Metadata sheet before validation');
    }

    // Step 2: Determine template type
    const templateType = metadata.templateType || detectTemplateType();

    // Step 3: Extract input data
    const inputData = extractInputData();
    if (!inputData || inputData.length === 0) {
      throw new Error('No data found in Input sheet');
    }

    // Step 4: Sanitize data (SQL injection prevention)
    const sanitizedData = sanitizeData(inputData);

    // Step 5: Send to database for validation
    const validationResults = performDatabaseValidation(
      sanitizedData,
      templateType,
      metadata
    );

    // Step 6: Write results to Output sheet
    writeValidationResults(validationResults);

    // Step 7: Log the validation attempt
    logAudit('VALIDATION', {
      templateType: templateType,
      rowCount: inputData.length,
      errorCount: validationResults.errorCount,
      warningCount: validationResults.warningCount
    });

    // Step 8: Show summary to user
    showValidationSummary(validationResults);

  } catch (error) {
    logAudit('VALIDATION_ERROR', { error: error.message });
    ui.alert('Validation Error', error.message, ui.ButtonSet.OK);
  }
}

/**
 * Extracts metadata from the Metadata sheet
 */
function extractMetadata() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const metadataSheet = ss.getSheetByName(CONFIG.METADATA_SHEET_NAME);

  if (!metadataSheet) {
    Logger.log('Metadata sheet not found');
    return null;
  }

  const data = metadataSheet.getDataRange().getValues();
  const metadata = {};

  Logger.log(`Metadata sheet has ${data.length} rows`);

  // Assuming key-value pairs in columns A and B
  // Row 0 is typically headers, so we start at row 1
  for (let i = 1; i < data.length; i++) {
    const rawKey = data[i][0];
    const rawValue = data[i][1];

    Logger.log(`Row ${i}: Key="${rawKey}", Value="${rawValue}"`);

    if (rawKey && rawValue) {
      const key = String(rawKey).trim();
      const value = String(rawValue).trim(); // Also trim values

      if (key && value) {
        metadata[key] = value;
        Logger.log(`  -> Added: "${key}" = "${value}"`);
      }
    }
  }

  Logger.log('Final metadata object:', JSON.stringify(metadata, null, 2));
  return metadata;
}

/**
 * Debug function - Shows what metadata is being read
 * Add this to the menu temporarily: Admin > Debug Metadata
 */
function debugMetadata() {
  const ui = SpreadsheetApp.getUi();
  const metadata = extractMetadata();

  let message = 'Metadata found:\n\n';

  if (!metadata) {
    message = 'ERROR: Metadata sheet not found or empty';
  } else {
    for (const [key, value] of Object.entries(metadata)) {
      message += `"${key}": "${value}"\n`;
    }

    message += '\n---\n';
    message += `Has Author Name? ${metadata['Author Name'] ? 'YES' : 'NO'}\n`;
    message += `Has Author Email? ${metadata['Author Email'] ? 'YES' : 'NO'}\n`;

    if (!metadata['Author Name']) {
      message += '\n⚠️ Missing "Author Name" field!\n';
    }
    if (!metadata['Author Email']) {
      message += '\n⚠️ Missing "Author Email" field!\n';
    }
  }

  ui.alert('Metadata Debug', message, ui.ButtonSet.OK);
}

/**
 * Helper function to fix common Metadata sheet issues
 */
function fixMetadataSheet() {
  const ui = SpreadsheetApp.getUi();
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let metadataSheet = ss.getSheetByName(CONFIG.METADATA_SHEET_NAME);

  // Check if Metadata sheet exists
  if (!metadataSheet) {
    const response = ui.alert(
      'Metadata Sheet Not Found',
      'The "Metadata" sheet does not exist. Create it now?',
      ui.ButtonSet.YES_NO
    );

    if (response === ui.Button.YES) {
      metadataSheet = ss.insertSheet(CONFIG.METADATA_SHEET_NAME);
    } else {
      return;
    }
  }

  // Set up proper structure
  const response = ui.alert(
    'Fix Metadata Sheet',
    'This will reset your Metadata sheet to the correct format.\n\n' +
    'Any existing data will be cleared. Continue?',
    ui.ButtonSet.YES_NO
  );

  if (response !== ui.Button.YES) {
    return;
  }

  // Clear sheet
  metadataSheet.clear();

  // Set up headers and structure
  const headers = [['Field', 'Value']];
  const fields = [
    ['Author Name', ''],
    ['Author Email', ''],
    ['Organization', ''],
    ['Template Type', 'T1'],
    ['Description', '']
  ];

  // Write headers
  metadataSheet.getRange(1, 1, 1, 2).setValues(headers);
  metadataSheet.getRange(1, 1, 1, 2).setFontWeight('bold');
  metadataSheet.getRange(1, 1, 1, 2).setBackground('#4285f4');
  metadataSheet.getRange(1, 1, 1, 2).setFontColor('#ffffff');

  // Write field structure
  metadataSheet.getRange(2, 1, fields.length, 2).setValues(fields);

  // Format field names (column A)
  metadataSheet.getRange(2, 1, fields.length, 1).setFontWeight('bold');

  // Add data validation for Template Type
  const templateTypeCell = metadataSheet.getRange(5, 2); // Template Type is row 5
  const templateTypes = Object.keys(CONFIG.TEMPLATE_TYPES);
  const rule = SpreadsheetApp.newDataValidation()
    .requireValueInList(templateTypes)
    .setAllowInvalid(false)
    .build();
  templateTypeCell.setDataValidation(rule);

  // Auto-resize columns
  metadataSheet.autoResizeColumns(1, 2);
  metadataSheet.setColumnWidth(2, 300); // Make value column wider

  // Add instructions
  metadataSheet.getRange(7, 1, 1, 2).merge();
  metadataSheet.getRange(7, 1).setValue('Instructions: Fill in the values in column B. Field names in column A must not be changed.');
  metadataSheet.getRange(7, 1).setFontStyle('italic');
  metadataSheet.getRange(7, 1).setFontColor('#666666');
  metadataSheet.getRange(7, 1).setWrap(true);

  ui.alert(
    'Success!',
    'Metadata sheet has been set up correctly.\n\n' +
    'Please fill in:\n' +
    '• Author Name (required)\n' +
    '• Author Email (required)\n' +
    '• Organization (optional)\n' +
    '• Template Type (required)\n' +
    '• Description (optional)',
    ui.ButtonSet.OK
  );
}

/**
 * Detects template type from sheet structure or metadata
 */
function detectTemplateType() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const metadata = extractMetadata();

  // Try to detect from metadata
  if (metadata && metadata['Template Type']) {
    return metadata['Template Type'];
  }

  // Try to detect from sheet name or structure
  const sheetName = ss.getName();
  for (const [code, description] of Object.entries(CONFIG.TEMPLATE_TYPES)) {
    if (sheetName.includes(code) || sheetName.includes(description)) {
      return code;
    }
  }

  // Default to T1 if cannot detect
  return 'T1';
}

/**
 * Extracts data from Input sheet
 */
function extractInputData() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const inputSheet = ss.getSheetByName(CONFIG.INPUT_SHEET_NAME);

  if (!inputSheet) {
    throw new Error(`Input sheet "${CONFIG.INPUT_SHEET_NAME}" not found`);
  }

  const range = inputSheet.getDataRange();
  const values = range.getValues();

  if (values.length <= 1) {
    return [];
  }

  // Convert to array of objects with headers as keys
  const headers = values[0];
  const data = [];

  for (let i = 1; i < values.length; i++) {
    const row = {};
    let hasData = false;

    for (let j = 0; j < headers.length; j++) {
      row[headers[j]] = values[i][j];
      if (values[i][j] !== '') {
        hasData = true;
      }
    }

    if (hasData) {
      row._rowNumber = i + 1; // Store original row number for error reporting
      data.push(row);
    }
  }

  return data;
}

/**
 * Shows validation summary dialog
 */
function showValidationSummary(results) {
  const ui = SpreadsheetApp.getUi();

  let message = `Validation Complete!\n\n`;
  message += `Total Rows Validated: ${results.totalRows}\n`;
  message += `Errors: ${results.errorCount}\n`;
  message += `Warnings: ${results.warningCount}\n\n`;

  if (results.errorCount === 0) {
    message += `✓ No errors found! You can proceed to submit your final version.`;
    ui.alert('Validation Successful', message, ui.ButtonSet.OK);
  } else {
    message += `✗ Please review the Output sheet and correct the errors before submission.`;
    ui.alert('Validation Failed', message, ui.ButtonSet.OK);
  }
}

/**
 * Clears input data (with confirmation)
 */
function clearInputData() {
  const ui = SpreadsheetApp.getUi();
  const response = ui.alert(
    'Clear Input Data',
    'Are you sure you want to clear all data in the Input sheet? This cannot be undone.',
    ui.ButtonSet.YES_NO
  );

  if (response === ui.Button.YES) {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const inputSheet = ss.getSheetByName(CONFIG.INPUT_SHEET_NAME);

    if (inputSheet) {
      const lastRow = inputSheet.getLastRow();
      if (lastRow > 1) {
        inputSheet.getRange(2, 1, lastRow - 1, inputSheet.getLastColumn()).clearContent();
        logAudit('CLEAR_INPUT', {});
        ui.alert('Input data cleared successfully');
      }
    }
  }
}

/**
 * Sets up required sheets if they don't exist
 */
function setupSheets() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const requiredSheets = [
    CONFIG.INPUT_SHEET_NAME,
    CONFIG.OUTPUT_SHEET_NAME,
    CONFIG.METADATA_SHEET_NAME,
    CONFIG.AUDIT_SHEET_NAME
  ];

  requiredSheets.forEach(sheetName => {
    let sheet = ss.getSheetByName(sheetName);
    if (!sheet) {
      sheet = ss.insertSheet(sheetName);

      // Initialize based on sheet type
      if (sheetName === CONFIG.AUDIT_SHEET_NAME) {
        sheet.getRange(1, 1, 1, 5).setValues([[
          'Timestamp', 'User', 'Action', 'Details', 'Status'
        ]]);
      } else if (sheetName === CONFIG.METADATA_SHEET_NAME) {
        sheet.getRange(1, 1, 7, 2).setValues([
          ['Metadata Field', 'Value'],
          ['Author Name', ''],
          ['Author Email', ''],
          ['Template Type', ''],
          ['Submission Date', ''],
          ['Organization', ''],
          ['Description', '']
        ]);
      }
    }
  });

  SpreadsheetApp.getUi().alert('Setup complete! Required sheets have been created.');
}

/**
 * Shows audit log
 */
function showAuditLog() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const auditSheet = ss.getSheetByName(CONFIG.AUDIT_SHEET_NAME);

  if (auditSheet) {
    ss.setActiveSheet(auditSheet);
  } else {
    SpreadsheetApp.getUi().alert('Audit log not found. Please run Setup Sheets first.');
  }
}
