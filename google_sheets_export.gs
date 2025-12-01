// Google Apps Script to download all tabs from a Google Sheet
// This script creates downloadable files for each sheet tab

function downloadAllSheets() {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  const sheets = spreadsheet.getSheets();
  const folderName = spreadsheet.getName() + '_exports_' + new Date().toISOString().split('T')[0];

  // Create a folder in Google Drive to store exports
  const folder = DriveApp.createFolder(folderName);

  Logger.log('Starting export of ' + sheets.length + ' sheets...');

  sheets.forEach((sheet, index) => {
    const sheetName = sheet.getName();
    Logger.log('Exporting sheet: ' + sheetName);

    // Export as CSV
    exportSheetAsCSV(sheet, folder);

    // Export as PDF (optional)
    // exportSheetAsPDF(sheet, folder);

    // Export as Excel (optional)
    // exportSheetAsExcel(sheet, folder);
  });

  Logger.log('All sheets exported to folder: ' + folder.getUrl());
  Logger.log('Folder URL: ' + folder.getUrl());

  // Optional: Send email with download links
  // sendEmailWithLinks(folder);
}

function exportSheetAsCSV(sheet, folder) {
  const sheetName = sheet.getName();
  const csvContent = getSheetAsCSV(sheet);
  const fileName = sheetName + '.csv';

  const file = folder.createFile(fileName, csvContent, MimeType.CSV);
  Logger.log('Created CSV: ' + file.getUrl());
}

function getSheetAsCSV(sheet) {
  const range = sheet.getDataRange();
  const values = range.getValues();

  return values.map(row =>
    row.map(cell => {
      // Handle commas, quotes, and newlines in cell values
      if (typeof cell === 'string' && (cell.includes(',') || cell.includes('"') || cell.includes('\n'))) {
        return '"' + cell.replace(/"/g, '""') + '"';
      }
      return cell;
    }).join(',')
  ).join('\n');
}

function exportSheetAsPDF(sheet, folder) {
  const sheetName = sheet.getName();
  const spreadsheet = sheet.getParent();
  const fileName = sheetName + '.pdf';

  const pdfBlob = spreadsheet.getBlob().getAs('application/pdf');
  pdfBlob.setName(fileName);

  const file = folder.createFile(pdfBlob);
  Logger.log('Created PDF: ' + file.getUrl());
}

function exportSheetAsExcel(sheet, folder) {
  const sheetName = sheet.getName();
  const spreadsheet = sheet.getParent();
  const fileName = sheetName + '.xlsx';

  const excelBlob = spreadsheet.getBlob().getAs('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  excelBlob.setName(fileName);

  const file = folder.createFile(excelBlob);
  Logger.log('Created Excel: ' + file.getUrl());
}

function sendEmailWithLinks(folder) {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  const userEmail = Session.getActiveUser().getEmail();

  const files = folder.getFiles();
  let emailBody = 'Your Google Sheets export is complete!\n\n';
  emailBody += 'Files exported to folder: ' + folder.getUrl() + '\n\n';
  emailBody += 'Individual file links:\n';

  while (files.hasNext()) {
    const file = files.next();
    emailBody += '- ' + file.getName() + ': ' + file.getUrl() + '\n';
  }

  MailApp.sendEmail(userEmail, 'Google Sheets Export Complete', emailBody);
}

// Alternative: Export specific range instead of entire sheet
function exportSheetRangeAsCSV(sheet, rangeA1, folder) {
  const range = sheet.getRange(rangeA1);
  const values = range.getValues();

  const csvContent = values.map(row =>
    row.map(cell => {
      if (typeof cell === 'string' && (cell.includes(',') || cell.includes('"') || cell.includes('\n'))) {
        return '"' + cell.replace(/"/g, '""') + '"';
      }
      return cell;
    }).join(',')
  ).join('\n');

  const fileName = sheet.getName() + '_range_' + rangeA1.replace(':', '_') + '.csv';
  const file = folder.createFile(fileName, csvContent, MimeType.CSV);

  Logger.log('Created CSV range export: ' + file.getUrl());
}

// Menu function to add to Google Sheets UI
function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('Export Tools')
    .addItem('Download All Sheets as CSV', 'downloadAllSheets')
    .addItem('Download All Sheets as PDF', 'downloadAllSheetsPDF')
    .addItem('Download All Sheets as Excel', 'downloadAllSheetsExcel')
    .addToUi();
}

function downloadAllSheetsPDF() {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  const sheets = spreadsheet.getSheets();
  const folderName = spreadsheet.getName() + '_PDF_exports_' + new Date().toISOString().split('T')[0];

  const folder = DriveApp.createFolder(folderName);

  sheets.forEach(sheet => {
    exportSheetAsPDF(sheet, folder);
  });

  Logger.log('PDF exports complete: ' + folder.getUrl());
}

function downloadAllSheetsExcel() {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  const sheets = spreadsheet.getSheets();
  const folderName = spreadsheet.getName() + '_Excel_exports_' + new Date().toISOString().split('T')[0];

  const folder = DriveApp.createFolder(folderName);

  sheets.forEach(sheet => {
    exportSheetAsExcel(sheet, folder);
  });

  Logger.log('Excel exports complete: ' + folder.getUrl());
}