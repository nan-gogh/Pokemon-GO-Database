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
}

function convertSheetToCSV(sheet) {
  const data = sheet.getDataRange().getValues();
  return data.map(row =>
    row.map(cell =>
      typeof cell === 'string' && cell.includes(',') ?
        '"' + cell.replace(/"/g, '""') + '"' : cell
    ).join(',')
  ).join('\n');
}