CREATE OR REPLACE FUNCTION google_pack.SetSpreadSheet (
	table_name TEXT,
	spreadsheet_id TEXT,
	worksheet_name TEXT
)
RETURNS VOID
AS
$BODY$
  '''
  The function allows you to create a standard worksheet in existing Google spreadsheet based on your input table (possibly qualified with a schema name)
  For the table "cde_manual_group" the function automatically creates a text column group_code (combination of source_code+source_vocabulary_id), for all other tables the data is taken "as is"
  PS current limit is 50K exported rows
  
  table_name - tablename or shemaname.tablename
  spreadsheet_id - spreadsheet ID (which can be extracted from the spreadsheet's url https://docs.google.com/spreadsheets/d/1dJqEfmqu...)
  worksheet_name - the name (title) of the list to be created
  
  Example:
  SELECT google_pack.SetSpreadSheet ('cde_manual_group', '1a3os1cjgIuji...', 'my export');
  
  Note: don't forget to give write permissions to the service email
  '''
  import gspread
  import pandas as pd
  from gspread_dataframe import set_with_dataframe

  sql_limit=50000
  
  #prepare, get schema and table names
  sql='''SELECT pn.nspname, pc.relname
    FROM pg_class pc
    JOIN pg_namespace pn ON pn.oid = pc.relnamespace
    WHERE pc.oid = %s::REGCLASS
  ''' % (plpy.quote_literal(table_name))
  res=plpy.execute(sql)
  sql_schema_name=res[0]['nspname']
  sql_table_name=res[0]['relname']
  
  if sql_table_name=='cde_manual_group':
    #for 'cde_manual_group' we need co create an additional column - group_code (array of code+vocabulary casted to text)
    sql="SELECT *, (ARRAY_AGG(source_code||':'||source_vocabulary_id) OVER (partition by group_id))::TEXT as group_code FROM %s.%s" % (sql_schema_name, sql_table_name)
  else:
    sql="SELECT * FROM %s.%s" % (sql_schema_name, sql_table_name)
  df = pd.DataFrame.from_records(plpy.execute(sql, sql_limit))
  
  credentials = eval(plpy.execute("SELECT var_value::json FROM devv5.config$ where var_name='gspread_credentials'")[0]['var_value'])
  gc = gspread.service_account_from_dict(credentials)
  #worksheet = gc.open_by_key(spreadsheet_id).worksheet(list_name)
  worksheet = gc.open_by_key(spreadsheet_id).add_worksheet(title=worksheet_name,rows=0,cols=0)
  
  set_with_dataframe(worksheet, df, string_escaping='full')
  
$BODY$
LANGUAGE 'plpython3u' STRICT;

REVOKE EXECUTE ON FUNCTION google_pack.SetSpreadSheet FROM PUBLIC;