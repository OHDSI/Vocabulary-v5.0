/**
 * Submission Module
 *
 * Handles final submission of validated data to Google Drive
 */

/**
 * Submits the final validated version to Google Drive
 */
function submitFinalVersion() {
  const ui = SpreadsheetApp.getUi();
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  try {
    // Step 1: Check if validation has been run
    const outputSheet = ss.getSheetByName(CONFIG.OUTPUT_SHEET_NAME);
    if (!outputSheet || outputSheet.getLastRow() < 2) {
      ui.alert(
        'Validation Required',
        'Please run validation before submitting. Use "Validate Template" from the menu.',
        ui.ButtonSet.OK
      );
      return;
    }

    // Step 2: Check if there are any errors
    const hasErrors = checkForErrors(outputSheet);
    if (hasErrors) {
      const response = ui.alert(
        'Validation Errors Found',
        'Your submission has validation errors. You should fix these before submitting.\n\nDo you want to proceed anyway?',
        ui.ButtonSet.YES_NO
      );

      if (response !== ui.Button.YES) {
        return;
      }
    }

    // Step 3: Get submission metadata
    const metadata = extractMetadata();
    if (!metadata || !metadata['Author Name'] || !metadata['Author Email']) {
      ui.alert(
        'Missing Metadata',
        'Please fill in the required metadata fields (Author Name and Author Email) before submitting.',
        ui.ButtonSet.OK
      );
      return;
    }

    // Step 4: Confirm submission
    const confirmResponse = ui.alert(
      'Confirm Submission',
      `You are about to submit this validated template.\n\nAuthor: ${metadata['Author Name']}\nEmail: ${metadata['Author Email']}\n\nThis will create a final copy in the submission folder. Continue?`,
      ui.ButtonSet.YES_NO
    );

    if (confirmResponse !== ui.Button.YES) {
      return;
    }

    // Step 5: Create submission package
    const submissionUrl = createSubmissionPackage(metadata, hasErrors);

    // Step 6: Log the submission
    logAudit('SUBMISSION', {
      author: metadata['Author Name'],
      email: metadata['Author Email'],
      hasErrors: hasErrors,
      submissionUrl: submissionUrl
    });

    // Step 7: Show success message
    ui.alert(
      'Submission Successful!',
      `Your template has been submitted successfully.\n\nSubmission ID: ${getSubmissionId()}\nLocation: ${submissionUrl}\n\nYou will receive a confirmation email shortly.`,
      ui.ButtonSet.OK
    );

    // Step 8: Optionally lock the sheet or clear it
    offerPostSubmissionOptions();

  } catch (error) {
    logAudit('SUBMISSION_ERROR', { error: error.message }, 'FAILURE');
    ui.alert('Submission Error', error.message, ui.ButtonSet.OK);
  }
}

/**
 * Checks if there are any validation errors in the Output sheet
 *
 * @param {Sheet} outputSheet - The Output sheet
 * @return {boolean} True if errors exist
 */
function checkForErrors(outputSheet) {
  const data = outputSheet.getDataRange().getValues();

  // Look for ERROR level in the results
  for (let i = 1; i < data.length; i++) {
    if (data[i][1] === 'ERROR') {
      return true;
    }
  }

  return false;
}

/**
 * Creates a submission package in Google Drive
 *
 * @param {Object} metadata - Submission metadata
 * @param {boolean} hasErrors - Whether the submission has errors
 * @return {string} URL to the submission folder
 */
function createSubmissionPackage(metadata, hasErrors) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  // Get or create submission folder
  const submissionFolder = getOrCreateSubmissionFolder(metadata);

  // Create timestamped subfolder
  const timestamp = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd_HHmmss');
  const authorName = (metadata['Author Name'] || 'Unknown').replace(/[^a-zA-Z0-9]/g, '_');
  const folderName = `${authorName}_${timestamp}${hasErrors ? '_WITH_ERRORS' : ''}`;

  const packageFolder = submissionFolder.createFolder(folderName);

  // Copy the entire spreadsheet
  const ssFile = DriveApp.getFileById(ss.getId());
  const ssCopy = ssFile.makeCopy(`${ss.getName()}_SUBMITTED_${timestamp}`, packageFolder);

  // Export Input sheet as CSV
  const inputSheet = ss.getSheetByName(CONFIG.INPUT_SHEET_NAME);
  if (inputSheet) {
    const inputCsv = convertSheetToCSV(inputSheet);
    packageFolder.createFile(Utilities.newBlob(inputCsv, 'text/csv', 'input_data.csv'));
  }

  // Export Output sheet as CSV
  const outputSheet = ss.getSheetByName(CONFIG.OUTPUT_SHEET_NAME);
  if (outputSheet) {
    const outputCsv = convertSheetToCSV(outputSheet);
    packageFolder.createFile(Utilities.newBlob(outputCsv, 'text/csv', 'validation_results.csv'));
  }

  // Create metadata file
  const metadataJson = JSON.stringify({
    submissionId: getSubmissionId(),
    submissionDate: new Date().toISOString(),
    author: metadata['Author Name'],
    email: metadata['Author Email'],
    templateType: metadata['Template Type'],
    organization: metadata['Organization'],
    description: metadata['Description'],
    hasErrors: hasErrors,
    spreadsheetUrl: ss.getUrl(),
    submissionUrl: packageFolder.getUrl()
  }, null, 2);

  packageFolder.createFile(Utilities.newBlob(metadataJson, 'application/json', 'metadata.json'));

  // Create README
  const readmeContent = createSubmissionReadme(metadata, hasErrors, timestamp);
  packageFolder.createFile(Utilities.newBlob(readmeContent, 'text/plain', 'README.txt'));

  return packageFolder.getUrl();
}

/**
 * Gets or creates the submission folder in Google Drive
 *
 * @param {Object} metadata - Submission metadata
 * @return {GoogleAppsScript.Drive.Folder} Submission folder
 */
function getOrCreateSubmissionFolder(metadata) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const metadataSheet = ss.getSheetByName('Metadata');

  // Get B7 cell content from Metadata sheet
  const b7Content = metadataSheet.getRange('B7').getValue();

  // Get author name and sanitize it
  const authorName = (metadata['Author Name'] || 'Unknown').replace(/[^a-zA-Z0-9]/g, '_');

  // Construct folder name: authorName_B7Content
  const folderName = `${authorName}_${b7Content}`;

  // Check if folder exists
  const folders = DriveApp.getFoldersByName(folderName);
  if (folders.hasNext()) {
    return folders.next();
  }

  // Create folder if it doesn't exist
  const folder = DriveApp.createFolder(folderName);

  // Get submission folder ID from script properties (if configured)
  const scriptProperties = PropertiesService.getScriptProperties();
  const sharedFolderId = scriptProperties.getProperty('SUBMISSION_FOLDER_ID');

  if (sharedFolderId) {
    try {
      // Move to shared folder
      const sharedFolder = DriveApp.getFolderById(sharedFolderId);
      folder.moveTo(sharedFolder);
    } catch (e) {
      Logger.log(`Could not move to shared folder: ${e.message}`);
    }
  }

  return folder;
}

/**
 * Converts a sheet to CSV format
 *
 * @param {Sheet} sheet - Sheet to convert
 * @return {string} CSV content
 */
function convertSheetToCSV(sheet) {
  const data = sheet.getDataRange().getValues();

  return data.map(row =>
    row.map(cell => {
      const cellStr = String(cell);
      if (cellStr.includes(',') || cellStr.includes('"') || cellStr.includes('\n')) {
        return `"${cellStr.replace(/"/g, '""')}"`;
      }
      return cellStr;
    }).join(',')
  ).join('\n');
}

/**
 * Generates a unique submission ID
 *
 * @return {string} Submission ID
 */
function getSubmissionId() {
  const timestamp = new Date().getTime();
  const random = Math.floor(Math.random() * 10000);
  return `SUB-${timestamp}-${random}`;
}

/**
 * Creates a README file for the submission
 *
 * @param {Object} metadata - Submission metadata
 * @param {boolean} hasErrors - Whether submission has errors
 * @param {string} timestamp - Submission timestamp
 * @return {string} README content
 */
function createSubmissionReadme(metadata, hasErrors, timestamp) {
  return `
OHDSI Vocabulary Validation Submission
========================================

Submission ID: ${getSubmissionId()}
Submission Date: ${timestamp}

AUTHOR INFORMATION
------------------
Name: ${metadata['Author Name'] || 'N/A'}
Email: ${metadata['Author Email'] || 'N/A'}
Organization: ${metadata['Organization'] || 'N/A'}

SUBMISSION DETAILS
------------------
Template Type: ${metadata['Template Type'] || 'N/A'}
Description: ${metadata['Description'] || 'N/A'}

VALIDATION STATUS
-----------------
Status: ${hasErrors ? 'SUBMITTED WITH ERRORS' : 'PASSED VALIDATION'}
${hasErrors ? 'Note: This submission contains validation errors. Please review validation_results.csv for details.' : ''}

FILES INCLUDED
--------------
1. ${SpreadsheetApp.getActiveSpreadsheet().getName()}_SUBMITTED_${timestamp} - Full spreadsheet copy
2. input_data.csv - Input data in CSV format
3. validation_results.csv - Validation results
4. metadata.json - Submission metadata in JSON format
5. README.txt - This file

NEXT STEPS
----------
${hasErrors ?
'Please review the validation errors and resubmit after corrections.' :
'Your submission will be reviewed by the OHDSI team. You will receive notification once the review is complete.'}

For questions or support, please contact the OHDSI Vocabulary team or visit:
https://github.com/OHDSI/Vocabulary-v5.0/wiki

Generated by OHDSI Validation Pipeline
`;
}

/**
 * Offers post-submission options to the user
 */
function offerPostSubmissionOptions() {
  const ui = SpreadsheetApp.getUi();

  const response = ui.alert(
    'Post-Submission Options',
    'What would you like to do next?\n\n- Yes: Start a new submission (clear input data)\n- No: Keep current data for reference',
    ui.ButtonSet.YES_NO
  );

  if (response === ui.Button.YES) {
    clearInputData();
  }
}

/**
 * Configures the shared submission folder
 */
function configureSubmissionFolder() {
  const ui = SpreadsheetApp.getUi();

  const response = ui.prompt(
    'Configure Submission Folder',
    'Enter the Google Drive Folder ID where submissions should be stored.\n\n' +
    'To get the folder ID:\n' +
    '1. Open the folder in Google Drive\n' +
    '2. Copy the ID from the URL (the part after /folders/)\n\n' +
    'Folder ID:',
    ui.ButtonSet.OK_CANCEL
  );

  if (response.getSelectedButton() === ui.Button.OK) {
    const folderId = response.getResponseText().trim();

    try {
      // Verify folder exists and is accessible
      const folder = DriveApp.getFolderById(folderId);

      // Save to script properties
      const scriptProperties = PropertiesService.getScriptProperties();
      scriptProperties.setProperty('SUBMISSION_FOLDER_ID', folderId);

      ui.alert('Success', `Submission folder configured: ${folder.getName()}`, ui.ButtonSet.OK);

    } catch (e) {
      ui.alert('Error', `Could not access folder: ${e.message}`, ui.ButtonSet.OK);
    }
  }
}

/**
 * Sends submission notification email
 *
 * @param {Object} metadata - Submission metadata
 * @param {string} submissionUrl - URL to submission package
 */
function sendSubmissionNotification(metadata, submissionUrl) {
  const authorEmail = metadata['Author Email'];
  if (!authorEmail) {
    return;
  }

  const subject = `OHDSI Vocabulary Submission Confirmation - ${getSubmissionId()}`;

  const body = `
Dear ${metadata['Author Name']},

Thank you for your contribution to the OHDSI Vocabulary!

Your submission has been received successfully.

Submission Details:
-------------------
Submission ID: ${getSubmissionId()}
Template Type: ${metadata['Template Type']}
Submission Date: ${new Date().toLocaleString()}

Submission Location: ${submissionUrl}

Next Steps:
-----------
Your submission will be reviewed by the OHDSI Vocabulary team. You will receive notification once the review is complete.

If you have any questions, please don't hesitate to contact us.

Best regards,
OHDSI Vocabulary Team

---
This is an automated message from the OHDSI Validation Pipeline.
`;

  try {
    GmailApp.sendEmail(authorEmail, subject, body);
  } catch (e) {
    Logger.log(`Could not send notification email: ${e.message}`);
  }
}
