// Simple version - just CSV export of all sheets
function exportAllSheetsToCSV() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheets = ss.getSheets();
  const folderName = ss.getName() + '_CSV_' + new Date().toISOString().split('T')[0];

  const folder = DriveApp.createFolder(folderName);

  sheets.forEach(sheet => {
    const csvData = convertSheetToCSV(sheet);
    const fileName = sheet.getName() + '.csv';
    folder.createFile(fileName, csvData, MimeType.CSV);
  });

  Logger.log('CSV exports saved to: ' + folder.getUrl());
  Logger.log('Folder URL: ' + folder.getUrl());
}

function convertSheetToCSV(sheet) {
  const data = sheet.getDataRange().getValues();
  return data.map(row =>
    row.map(cell => {
      if (typeof cell === 'string' && (cell.includes(',') || cell.includes('"') || cell.includes('\n'))) {
        return '"' + cell.replace(/"/g, '""') + '"';
      }
      return cell;
    }).join(',')
  ).join('\n');
}

// Add menu to Google Sheets UI
function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('Export Tools')
    .addItem('Export All Sheets as CSV', 'exportAllSheetsToCSV')
    .addToUi();
}

// Test function to verify the script works
function testExport() {
  Logger.log('Testing export function...');
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  Logger.log('Spreadsheet name: ' + ss.getName());
  Logger.log('Number of sheets: ' + ss.getSheets().length);
  Logger.log('Test completed successfully!');
}