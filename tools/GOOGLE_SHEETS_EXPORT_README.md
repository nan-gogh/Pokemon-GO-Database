# Google Sheets Export Tools

This repository contains multiple ways to download all tabs (sheets) from a Google Spreadsheet.

## Option 1: Google Apps Script (Easiest)

### Files:
- `google_sheets_export.gs` - Full-featured export script
- `simple_google_sheets_export.gs` - Basic CSV export only

### How to use:

1. **Open your Google Sheet**
2. **Go to Extensions → Apps Script**
3. **Delete the default code and paste one of the scripts above**
4. **Save the script** (give it a name)
5. **Run the function**:
   - For full script: `downloadAllSheets()`
   - For simple script: `exportAllSheetsToCSV()`
6. **Authorize the script** (first run only)
7. **Check the logs** for the download folder URL

### What it does:
- Creates a timestamped folder in Google Drive
- Exports each sheet tab as a separate CSV file
- Provides download links in the script logs

## Option 2: Python with Google Sheets API

### File: `google_sheets_api_export.py`

### Setup:

1. **Enable Google Sheets API**:
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing
   - Enable Google Sheets API
   - Create credentials (OAuth 2.0 client ID)
   - Download `credentials.json` to the same directory

2. **Install dependencies**:
   ```bash
   pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib
   ```

3. **Edit the script**:
   - Replace `YOUR_SPREADSHEET_ID_HERE` with your actual sheet ID
   - The ID is in the URL: `https://docs.google.com/spreadsheets/d/SPREADSHEET_ID/edit`

4. **Run the script**:
   ```bash
   python google_sheets_api_export.py
   ```

### What it does:
- Downloads all sheet tabs as CSV files
- Saves them to a local `sheets_export` directory
- Handles special characters and CSV formatting properly

## Getting Your Spreadsheet ID

Your Google Sheet URL looks like:
```
https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit
```

The Spreadsheet ID is: `1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms`

## Troubleshooting

### Google Apps Script:
- Make sure you're running the function from the script editor
- Check the execution logs for any errors
- Authorize all requested permissions

### Python API:
- Ensure `credentials.json` is in the same directory
- First run will open a browser for authentication
- Token is saved as `token.pickle` for future runs

## Output Formats

Both methods can export to:
- **CSV** (recommended for data analysis)
- **PDF** (for printing/sharing)
- **Excel** (.xlsx format)

## Use Cases

- **Data Analysis**: Export to CSV for import into databases or analysis tools
- **Backup**: Regular automated backups of your sheets
- **Sharing**: Convert to PDF for easy sharing
- **Migration**: Export data for import into other systems

## Automation

### Google Apps Script:
- Add triggers for automatic exports
- Schedule daily/weekly backups
- Send email notifications when complete

### Python:
- Integrate into larger data pipelines
- Run as cron job on server
- Combine with other data processing scripts