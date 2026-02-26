/**
 * Results Output Module
 *
 * Handles writing validation results to the Output sheet with formatting
 */

/**
 * Writes validation results to the Output sheet
 *
 * @param {Object} validationResults - Results from database validation
 */
function writeValidationResults(validationResults) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let outputSheet = ss.getSheetByName(CONFIG.OUTPUT_SHEET_NAME);

  // Create output sheet if it doesn't exist
  if (!outputSheet) {
    outputSheet = ss.insertSheet(CONFIG.OUTPUT_SHEET_NAME);
  }

  // Clear existing content
  outputSheet.clear();

  // Write header
  const headers = ['Row', 'Level', 'Field', 'Message', 'Rule'];
  outputSheet.getRange(1, 1, 1, headers.length).setValues([headers]);

  // Format header
  const headerRange = outputSheet.getRange(1, 1, 1, headers.length);
  headerRange.setFontWeight('bold');
  headerRange.setBackground('#4a86e8');
  headerRange.setFontColor('#ffffff');
  headerRange.setHorizontalAlignment('center');

  // Write summary at the top
  const summaryData = [
    ['Validation Summary', '', '', '', ''],
    ['Total Rows Validated', validationResults.totalRows, '', '', ''],
    ['Errors Found', validationResults.errorCount, '', '', ''],
    ['Warnings Found', validationResults.warningCount, '', '', ''],
    ['Status', validationResults.success ? 'PASSED' : 'FAILED', '', '', ''],
    ['', '', '', '', '']
  ];

  outputSheet.insertRowsBefore(1, summaryData.length);
  outputSheet.getRange(1, 1, summaryData.length, 5).setValues(summaryData);

  // Format summary section
  outputSheet.getRange(1, 1, 1, 5).merge();
  outputSheet.getRange(1, 1).setFontWeight('bold').setFontSize(14);

  const statusCell = outputSheet.getRange(5, 2);
  if (validationResults.success) {
    statusCell.setBackground('#d9ead3').setFontColor('#38761d').setFontWeight('bold');
  } else {
    statusCell.setBackground('#f4cccc').setFontColor('#cc0000').setFontWeight('bold');
  }

  // Write results data
  if (validationResults.results && validationResults.results.length > 0) {
    const resultsData = validationResults.results.map(result => [
      result.row || 'N/A',
      result.level || 'INFO',
      result.field || '',
      result.message || '',
      result.rule || ''
    ]);

    const startRow = summaryData.length + 2; // +2 for header row
    outputSheet.getRange(startRow, 1, resultsData.length, headers.length).setValues(resultsData);

    // Apply conditional formatting to results
    for (let i = 0; i < resultsData.length; i++) {
      const row = startRow + i;
      const level = resultsData[i][1];

      const rowRange = outputSheet.getRange(row, 1, 1, headers.length);

      if (level === 'ERROR') {
        rowRange.setBackground('#f4cccc');
      } else if (level === 'WARNING') {
        rowRange.setBackground('#fff2cc');
      } else if (level === 'INFO') {
        rowRange.setBackground('#d9ead3');
      }
    }

    // Apply borders
    const dataRange = outputSheet.getRange(startRow - 1, 1, resultsData.length + 1, headers.length);
    dataRange.setBorder(true, true, true, true, true, true);

  } else {
    // No issues found
    const noIssuesRow = summaryData.length + 2;
    outputSheet.getRange(noIssuesRow, 1, 1, 5).merge();
    outputSheet.getRange(noIssuesRow, 1)
      .setValue('No validation issues found!')
      .setBackground('#d9ead3')
      .setFontWeight('bold')
      .setHorizontalAlignment('center');
  }

  // Auto-resize columns
  for (let i = 1; i <= headers.length; i++) {
    outputSheet.autoResizeColumn(i);
  }

  // Set column widths with max limits
  if (outputSheet.getColumnWidth(1) > 100) outputSheet.setColumnWidth(1, 100);
  if (outputSheet.getColumnWidth(2) > 100) outputSheet.setColumnWidth(2, 100);
  if (outputSheet.getColumnWidth(3) > 200) outputSheet.setColumnWidth(3, 200);
  if (outputSheet.getColumnWidth(4) > 500) outputSheet.setColumnWidth(4, 500);
  if (outputSheet.getColumnWidth(5) > 200) outputSheet.setColumnWidth(5, 200);

  // Freeze header rows
  outputSheet.setFrozenRows(summaryData.length + 1);

  // Switch to output sheet
  ss.setActiveSheet(outputSheet);
}

/**
 * Exports validation results to a file
 *
 * @param {string} format - Export format ('csv', 'xlsx', 'json')
 * @return {Blob} File blob
 */
function exportResults(format = 'csv') {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const outputSheet = ss.getSheetByName(CONFIG.OUTPUT_SHEET_NAME);

  if (!outputSheet) {
    throw new Error('No validation results to export. Please run validation first.');
  }

  const data = outputSheet.getDataRange().getValues();
  const timestamp = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd_HHmmss');

  if (format === 'csv') {
    const csv = data.map(row =>
      row.map(cell => {
        const cellStr = String(cell);
        if (cellStr.includes(',') || cellStr.includes('"') || cellStr.includes('\n')) {
          return `"${cellStr.replace(/"/g, '""')}"`;
        }
        return cellStr;
      }).join(',')
    ).join('\n');

    const fileName = `ValidationResults_${timestamp}.csv`;
    const blob = Utilities.newBlob(csv, 'text/csv', fileName);

    // Save to Google Drive
    const folder = getOrCreateOutputFolder();
    const file = folder.createFile(blob);

    SpreadsheetApp.getUi().alert(
      'Export Successful',
      `Results exported to: ${file.getName()}\nURL: ${file.getUrl()}`,
      SpreadsheetApp.getUi().ButtonSet.OK
    );

    return blob;

  } else if (format === 'json') {
    // Convert to JSON format
    const headers = data[0];
    const jsonData = [];

    for (let i = 1; i < data.length; i++) {
      const row = {};
      for (let j = 0; j < headers.length; j++) {
        row[headers[j]] = data[i][j];
      }
      jsonData.push(row);
    }

    const json = JSON.stringify(jsonData, null, 2);
    const fileName = `ValidationResults_${timestamp}.json`;
    const blob = Utilities.newBlob(json, 'application/json', fileName);

    // Save to Google Drive
    const folder = getOrCreateOutputFolder();
    const file = folder.createFile(blob);

    SpreadsheetApp.getUi().alert(
      'Export Successful',
      `Results exported to: ${file.getName()}\nURL: ${file.getUrl()}`,
      SpreadsheetApp.getUi().ButtonSet.OK
    );

    return blob;

  } else if (format === 'xlsx') {
    // For XLSX, we create a copy of the sheet
    const fileName = `ValidationResults_${timestamp}`;
    const newSs = SpreadsheetApp.create(fileName);
    const newSheet = newSs.getActiveSheet();

    // Copy data
    newSheet.getRange(1, 1, data.length, data[0].length).setValues(data);

    // Copy formatting (simplified)
    outputSheet.getDataRange().copyFormatToRange(newSheet, 1, data[0].length, 1, data.length);

    SpreadsheetApp.getUi().alert(
      'Export Successful',
      `Results exported to: ${fileName}\nURL: ${newSs.getUrl()}`,
      SpreadsheetApp.getUi().ButtonSet.OK
    );

    return null;
  }

  throw new Error(`Unsupported export format: ${format}`);
}

/**
 * Gets or creates the output folder in Google Drive
 *
 * @return {GoogleAppsScript.Drive.Folder} Output folder
 */
function getOrCreateOutputFolder() {
  const folderName = 'OHDSI_Validation_Results';
  const folders = DriveApp.getFoldersByName(folderName);

  if (folders.hasNext()) {
    return folders.next();
  } else {
    return DriveApp.createFolder(folderName);
  }
}

/**
 * Creates a visual chart/summary of validation results
 */
function createValidationChart() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const outputSheet = ss.getSheetByName(CONFIG.OUTPUT_SHEET_NAME);

  if (!outputSheet) {
    return;
  }

  // Count issues by level
  const data = outputSheet.getDataRange().getValues();
  const levelCounts = {
    'ERROR': 0,
    'WARNING': 0,
    'INFO': 0
  };

  // Find level column (usually column B)
  for (let i = 1; i < data.length; i++) {
    const level = data[i][1];
    if (levelCounts.hasOwnProperty(level)) {
      levelCounts[level]++;
    }
  }

  // Create chart data
  const chartData = [
    ['Level', 'Count'],
    ['Errors', levelCounts.ERROR],
    ['Warnings', levelCounts.WARNING],
    ['Info', levelCounts.INFO]
  ];

  // Find a place to put the chart (or create a new sheet)
  let chartSheet = ss.getSheetByName('Validation Chart');
  if (!chartSheet) {
    chartSheet = ss.insertSheet('Validation Chart');
  } else {
    chartSheet.clear();
    // Remove existing charts
    const charts = chartSheet.getCharts();
    charts.forEach(chart => chartSheet.removeChart(chart));
  }

  // Write chart data
  chartSheet.getRange(1, 1, chartData.length, 2).setValues(chartData);

  // Create pie chart
  const chart = chartSheet.newChart()
    .setChartType(Charts.ChartType.PIE)
    .addRange(chartSheet.getRange(1, 1, chartData.length, 2))
    .setPosition(5, 5, 0, 0)
    .setOption('title', 'Validation Results Summary')
    .setOption('width', 400)
    .setOption('height', 300)
    .setOption('colors', ['#cc0000', '#ff9900', '#38761d'])
    .build();

  chartSheet.insertChart(chart);

  // Create bar chart for errors by field
  const fieldCounts = {};
  for (let i = 1; i < data.length; i++) {
    if (data[i][1] === 'ERROR') {
      const field = data[i][2] || 'Unknown';
      fieldCounts[field] = (fieldCounts[field] || 0) + 1;
    }
  }

  if (Object.keys(fieldCounts).length > 0) {
    const fieldChartData = [['Field', 'Error Count']];
    for (const [field, count] of Object.entries(fieldCounts)) {
      fieldChartData.push([field, count]);
    }

    chartSheet.getRange(1, 4, fieldChartData.length, 2).setValues(fieldChartData);

    const fieldChart = chartSheet.newChart()
      .setChartType(Charts.ChartType.BAR)
      .addRange(chartSheet.getRange(1, 4, fieldChartData.length, 2))
      .setPosition(5, 7, 0, 0)
      .setOption('title', 'Errors by Field')
      .setOption('width', 500)
      .setOption('height', 300)
      .build();

    chartSheet.insertChart(fieldChart);
  }
}

/**
 * Highlights errors in the Input sheet
 */
function highlightErrorsInInput() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const inputSheet = ss.getSheetByName(CONFIG.INPUT_SHEET_NAME);
  const outputSheet = ss.getSheetByName(CONFIG.OUTPUT_SHEET_NAME);

  if (!inputSheet || !outputSheet) {
    SpreadsheetApp.getUi().alert('Input or Output sheet not found');
    return;
  }

  // Clear existing highlights
  inputSheet.getDataRange().setBackground(null);

  // Get validation results
  const resultsData = outputSheet.getDataRange().getValues();

  // Map errors to input rows
  for (let i = 1; i < resultsData.length; i++) {
    const rowNum = resultsData[i][0];
    const level = resultsData[i][1];

    if (typeof rowNum === 'number' && rowNum > 1) {
      const color = level === 'ERROR' ? '#f4cccc' :
                    level === 'WARNING' ? '#fff2cc' : '#d9ead3';

      inputSheet.getRange(rowNum, 1, 1, inputSheet.getLastColumn()).setBackground(color);
    }
  }

  SpreadsheetApp.getUi().alert('Errors highlighted in Input sheet');
}
