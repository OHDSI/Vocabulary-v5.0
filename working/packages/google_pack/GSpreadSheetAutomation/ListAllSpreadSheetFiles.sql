CREATE OR REPLACE FUNCTION google_pack.ListAllSpreadSheetFiles (pFolder_id TEXT)
RETURNS TABLE (
	spreadsheet_id TEXT,
	name TEXT,
	createdtime TIMESTAMPTZ,
	modifiedtime TIMESTAMPTZ
)
AS
$BODY$
  '''
  Lists all Google Sheets in a specified folder in Google Drive
  Please note: the function does NOT show Excel files (*.xlsx), only native Google Sheets.
  
  Example:
  To list all sheets in https://drive.google.com/drive/folders/1B0KzHeET6vm... run
  SELECT * FROM google_pack.ListAllSpreadSheetFiles('1B0KzHeET6vm...');
  END $_$;
  
  Note: don't forget to give view permissions in the folder to the service email
  '''
  import gspread

  credentials = eval(plpy.execute("SELECT var_value::json FROM devv5.config$ where var_name='gspread_credentials'")[0]['var_value'])
  gc = gspread.service_account_from_dict(credentials)

  return [(f['id'], f['name'], f['createdTime'], f['modifiedTime']) for f in gc.list_spreadsheet_files(folder_id=pfolder_id)]
$BODY$
LANGUAGE 'plpython3u' STRICT;

REVOKE EXECUTE ON FUNCTION google_pack.ListAllSpreadSheetFiles FROM PUBLIC;