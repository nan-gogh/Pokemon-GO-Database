#!/usr/bin/env python3
"""
Google Sheets API script to download all tabs as CSV files
Requirements: pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib
"""

import os
import pickle
from googleapiclient.discovery import build
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request

# If modifying these scopes, delete the file token.pickle.
SCOPES = ['https://www.googleapis.com/auth/spreadsheets.readonly']

def get_credentials():
    """Get Google API credentials"""
    creds = None
    if os.path.exists('token.pickle'):
        with open('token.pickle', 'rb') as token:
            creds = pickle.load(token)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                'credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)

        with open('token.pickle', 'wb') as token:
            pickle.dump(creds, token)

    return creds

def export_sheet_to_csv(service, spreadsheet_id, sheet_name, range_name):
    """Export a single sheet to CSV"""
    result = service.spreadsheets().values().get(
        spreadsheetId=spreadsheet_id,
        range=f'{sheet_name}!{range_name}'
    ).execute()

    values = result.get('values', [])

    if not values:
        print(f'No data found in sheet: {sheet_name}')
        return

    # Convert to CSV format
    csv_content = []
    for row in values:
        csv_row = []
        for cell in row:
            # Escape commas and quotes
            if ',' in str(cell) or '"' in str(cell) or '\n' in str(cell):
                csv_row.append(f'"{str(cell).replace(chr(34), chr(34) + chr(34))}"')
            else:
                csv_row.append(str(cell))
        csv_content.append(','.join(csv_row))

    return '\n'.join(csv_content)

def download_all_sheets(spreadsheet_id, output_dir='sheets_export'):
    """Download all sheets from a Google Spreadsheet"""
    creds = get_credentials()
    service = build('sheets', 'v4', credentials=creds)

    # Get spreadsheet metadata
    spreadsheet = service.spreadsheets().get(spreadsheetId=spreadsheet_id).execute()
    sheet_names = [sheet['properties']['title'] for sheet in spreadsheet['sheets']]

    print(f"Found {len(sheet_names)} sheets: {', '.join(sheet_names)}")

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    for sheet_name in sheet_names:
        print(f"Exporting sheet: {sheet_name}")

        # Export entire sheet
        csv_data = export_sheet_to_csv(service, spreadsheet_id, sheet_name, 'A:Z')

        if csv_data:
            filename = f"{sheet_name.replace('/', '_')}.csv"
            filepath = os.path.join(output_dir, filename)

            with open(filepath, 'w', encoding='utf-8', newline='') as f:
                f.write(csv_data)

            print(f"Saved: {filepath}")

    print(f"\nAll sheets exported to directory: {output_dir}")

if __name__ == '__main__':
    # Replace with your Google Sheet ID
    # The ID is the long string in the URL: https://docs.google.com/spreadsheets/d/SPREADSHEET_ID/edit
    SPREADSHEET_ID = 'YOUR_SPREADSHEET_ID_HERE'

    if SPREADSHEET_ID == 'YOUR_SPREADSHEET_ID_HERE':
        print("Please set your SPREADSHEET_ID in the script!")
        print("1. Open your Google Sheet")
        print("2. Copy the ID from the URL (between /d/ and /edit)")
        print("3. Replace YOUR_SPREADSHEET_ID_HERE with the actual ID")
    else:
        download_all_sheets(SPREADSHEET_ID)