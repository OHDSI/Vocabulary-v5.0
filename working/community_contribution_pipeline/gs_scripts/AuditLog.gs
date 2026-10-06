/**
 * Audit Logging Module
 *
 * Tracks all user actions and system events for compliance and debugging
 */

/**
 * Logs an action to the audit log
 *
 * @param {string} action - Action type (e.g., VALIDATION, SUBMIT, CLEAR_INPUT)
 * @param {Object} details - Additional details about the action
 * @param {string} status - Status of the action (SUCCESS, FAILURE, etc.)
 */
function logAudit(action, details = {}, status = 'SUCCESS') {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let auditSheet = ss.getSheetByName(CONFIG.AUDIT_SHEET_NAME);

    // Create audit sheet if it doesn't exist
    if (!auditSheet) {
      auditSheet = ss.insertSheet(CONFIG.AUDIT_SHEET_NAME);
      auditSheet.getRange(1, 1, 1, 6).setValues([[
        'Timestamp', 'User', 'Action', 'Details', 'Status', 'IP Address'
      ]]);
      auditSheet.getRange(1, 1, 1, 6).setFontWeight('bold');
      auditSheet.setFrozenRows(1);
    }

    // Get user information
    const user = Session.getActiveUser().getEmail() || 'Unknown';
    const timestamp = new Date();

    // Get IP address (if available through a web app context)
    let ipAddress = 'N/A';
    try {
      // This only works in web app context
      ipAddress = Session.getTemporaryActiveUserKey() || 'N/A';
    } catch (e) {
      // Not in web app context
    }

    // Format details as JSON string
    const detailsStr = JSON.stringify(details);

    // Append to audit log
    auditSheet.appendRow([
      timestamp,
      user,
      action,
      detailsStr,
      status,
      ipAddress
    ]);

    // Apply formatting to the new row
    const lastRow = auditSheet.getLastRow();
    auditSheet.getRange(lastRow, 1).setNumberFormat('yyyy-mm-dd hh:mm:ss');

    // Set background color based on status
    if (status === 'FAILURE' || status === 'ERROR') {
      auditSheet.getRange(lastRow, 1, 1, 6).setBackground('#ffcccc');
    } else if (status === 'WARNING') {
      auditSheet.getRange(lastRow, 1, 1, 6).setBackground('#fff4cc');
    }

    // Keep only last 1000 entries to prevent sheet from growing too large
    if (lastRow > 1001) {
      auditSheet.deleteRows(2, lastRow - 1001);
    }

    // Auto-resize columns for better readability
    auditSheet.autoResizeColumn(1);
    auditSheet.autoResizeColumn(2);
    auditSheet.autoResizeColumn(3);

  } catch (error) {
    // Log to Apps Script logger if sheet logging fails
    Logger.log(`Audit logging failed: ${error.message}`);
    Logger.log(`Action: ${action}, Details: ${JSON.stringify(details)}, Status: ${status}`);
  }
}

/**
 * Gets audit log entries for a specific user
 *
 * @param {string} userEmail - Email of the user (optional, defaults to current user)
 * @param {number} limit - Maximum number of entries to return
 * @return {Array<Object>} Array of audit log entries
 */
function getAuditLogForUser(userEmail = null, limit = 100) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const auditSheet = ss.getSheetByName(CONFIG.AUDIT_SHEET_NAME);

  if (!auditSheet) {
    return [];
  }

  const email = userEmail || Session.getActiveUser().getEmail();
  const data = auditSheet.getDataRange().getValues();
  const headers = data[0];
  const entries = [];

  // Find column indices
  const userCol = headers.indexOf('User');
  const timestampCol = headers.indexOf('Timestamp');
  const actionCol = headers.indexOf('Action');
  const detailsCol = headers.indexOf('Details');
  const statusCol = headers.indexOf('Status');

  // Filter by user and collect entries
  for (let i = data.length - 1; i >= 1 && entries.length < limit; i--) {
    if (data[i][userCol] === email) {
      entries.push({
        timestamp: data[i][timestampCol],
        action: data[i][actionCol],
        details: data[i][detailsCol],
        status: data[i][statusCol]
      });
    }
  }

  return entries;
}

/**
 * Gets all audit log entries within a date range
 *
 * @param {Date} startDate - Start date
 * @param {Date} endDate - End date
 * @return {Array<Object>} Array of audit log entries
 */
function getAuditLogByDateRange(startDate, endDate) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const auditSheet = ss.getSheetByName(CONFIG.AUDIT_SHEET_NAME);

  if (!auditSheet) {
    return [];
  }

  const data = auditSheet.getDataRange().getValues();
  const headers = data[0];
  const entries = [];

  // Find column indices
  const timestampCol = headers.indexOf('Timestamp');
  const userCol = headers.indexOf('User');
  const actionCol = headers.indexOf('Action');
  const detailsCol = headers.indexOf('Details');
  const statusCol = headers.indexOf('Status');

  // Filter by date range
  for (let i = 1; i < data.length; i++) {
    const timestamp = new Date(data[i][timestampCol]);

    if (timestamp >= startDate && timestamp <= endDate) {
      entries.push({
        timestamp: timestamp,
        user: data[i][userCol],
        action: data[i][actionCol],
        details: data[i][detailsCol],
        status: data[i][statusCol]
      });
    }
  }

  return entries;
}

/**
 * Generates an audit report and exports it
 *
 * @param {Date} startDate - Start date for report
 * @param {Date} endDate - End date for report
 * @return {string} URL to the generated report
 */
function generateAuditReport(startDate, endDate) {
  const entries = getAuditLogByDateRange(startDate, endDate);

  if (entries.length === 0) {
    SpreadsheetApp.getUi().alert('No audit log entries found for the specified date range.');
    return null;
  }

  // Create a new spreadsheet for the report
  const reportName = `Audit_Report_${Utilities.formatDate(startDate, Session.getScriptTimeZone(), 'yyyyMMdd')}_to_${Utilities.formatDate(endDate, Session.getScriptTimeZone(), 'yyyyMMdd')}`;
  const reportSs = SpreadsheetApp.create(reportName);
  const reportSheet = reportSs.getActiveSheet();

  // Write headers
  reportSheet.getRange(1, 1, 1, 5).setValues([[
    'Timestamp', 'User', 'Action', 'Details', 'Status'
  ]]);
  reportSheet.getRange(1, 1, 1, 5).setFontWeight('bold');

  // Write data
  const reportData = entries.map(entry => [
    entry.timestamp,
    entry.user,
    entry.action,
    entry.details,
    entry.status
  ]);

  reportSheet.getRange(2, 1, reportData.length, 5).setValues(reportData);

  // Format
  reportSheet.autoResizeColumns(1, 5);
  reportSheet.setFrozenRows(1);

  // Generate summary statistics
  const summarySheet = reportSs.insertSheet('Summary');
  const actionCounts = {};
  const userCounts = {};
  let errorCount = 0;

  for (const entry of entries) {
    actionCounts[entry.action] = (actionCounts[entry.action] || 0) + 1;
    userCounts[entry.user] = (userCounts[entry.user] || 0) + 1;
    if (entry.status === 'ERROR' || entry.status === 'FAILURE') {
      errorCount++;
    }
  }

  // Write summary
  const summaryData = [
    ['Summary Statistics', ''],
    ['Total Entries', entries.length],
    ['Date Range', `${startDate.toLocaleDateString()} - ${endDate.toLocaleDateString()}`],
    ['Errors/Failures', errorCount],
    ['', ''],
    ['Actions Breakdown', 'Count']
  ];

  for (const [action, count] of Object.entries(actionCounts)) {
    summaryData.push([action, count]);
  }

  summaryData.push(['', '']);
  summaryData.push(['User Activity', 'Count']);

  for (const [user, count] of Object.entries(userCounts)) {
    summaryData.push([user, count]);
  }

  summarySheet.getRange(1, 1, summaryData.length, 2).setValues(summaryData);
  summarySheet.getRange(1, 1, 1, 2).setFontWeight('bold');
  summarySheet.getRange(6, 1, 1, 2).setFontWeight('bold');
  summarySheet.autoResizeColumns(1, 2);

  return reportSs.getUrl();
}

/**
 * Exports audit log to CSV file
 *
 * @return {Blob} CSV file as blob
 */
function exportAuditLogToCSV() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const auditSheet = ss.getSheetByName(CONFIG.AUDIT_SHEET_NAME);

  if (!auditSheet) {
    throw new Error('Audit log sheet not found');
  }

  const data = auditSheet.getDataRange().getValues();
  const csv = data.map(row => row.map(cell => {
    // Escape quotes and wrap in quotes if contains comma
    const cellStr = String(cell);
    if (cellStr.includes(',') || cellStr.includes('"') || cellStr.includes('\n')) {
      return `"${cellStr.replace(/"/g, '""')}"`;
    }
    return cellStr;
  }).join(',')).join('\n');

  const fileName = `AuditLog_${Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd_HHmmss')}.csv`;

  return Utilities.newBlob(csv, 'text/csv', fileName);
}

/**
 * Clears old audit log entries (admin function)
 *
 * @param {number} daysToKeep - Number of days of history to keep
 */
function clearOldAuditEntries(daysToKeep = 90) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const auditSheet = ss.getSheetByName(CONFIG.AUDIT_SHEET_NAME);

  if (!auditSheet) {
    return;
  }

  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);

  const data = auditSheet.getDataRange().getValues();
  const timestampCol = 0; // Assuming timestamp is in first column

  // Find rows to delete (starting from bottom to avoid index issues)
  const rowsToDelete = [];
  for (let i = data.length - 1; i >= 1; i--) {
    const timestamp = new Date(data[i][timestampCol]);
    if (timestamp < cutoffDate) {
      rowsToDelete.push(i + 1); // +1 for 1-based indexing
    }
  }

  // Delete old rows
  for (const row of rowsToDelete) {
    auditSheet.deleteRow(row);
  }

  logAudit('CLEAR_OLD_AUDIT_ENTRIES', {
    daysToKeep: daysToKeep,
    rowsDeleted: rowsToDelete.length
  });
}
