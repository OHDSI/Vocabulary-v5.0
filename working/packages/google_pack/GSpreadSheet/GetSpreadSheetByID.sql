CREATE OR REPLACE FUNCTION google_pack.GetSpreadSheetByID (
	spreadsheet_id TEXT,
	worksheet_name TEXT,
	skip_rows INT4 DEFAULT 0
)
RETURNS SETOF RECORD
AS
$BODY$
  '''
  Get the contents of a specific sheet from a specified Google spreadsheet
  
  spreadsheet_id - spreadsheet ID (which can be extracted from the spreadsheet's url https://docs.google.com/spreadsheets/d/1dJqEfmqu...)
  worksheet_name - sheet name (title) (which sheet do you want to get)
  skip_rows - skips first N rows (e.g. header)
  
  Note: since the number of columns and their type are unknown in advance, you need to specify this as the output type manually. The field names must match the column names in the sheet
  
  Example:
  SELECT * FROM google_pack.GetSpreadSheetByID('1URpwjK...','concept_synonym_manual',1)
  AS (
    worksheet_row_id INT4,
    synonym_name TEXT,
    concept_code TEXT,
    vocabulary_id TEXT,
    language_concept_id TEXT
  );
  
  Note: don't forget to give view permissions in the folder to the service email
  '''
  import gspread

  res = []
  credentials = eval(plpy.execute("SELECT var_value::json FROM devv5.config$ where var_name='gspread_credentials'")[0]['var_value'])
  gc = gspread.service_account_from_dict(credentials)
  sh = gc.open_by_key(spreadsheet_id)
  worksheet_title_list = [w.title for w in sh.worksheets()]
  if worksheet_name in worksheet_title_list:
    res =sh.worksheet(worksheet_name).get_all_records(default_blank=None, head=1)[skip_rows:] #skip header and next row
    #add row number (row_id)
    return [{**{'worksheet_row_id':id + 2 + skip_rows}, **row} for id, row in enumerate(res)]

  #if worksheet with specified name doesn't exists, return NULL
  return []
$BODY$
LANGUAGE 'plpython3u' STRICT;

REVOKE EXECUTE ON FUNCTION google_pack.GetSpreadSheetByID FROM PUBLIC;