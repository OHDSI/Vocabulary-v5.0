CREATE OR REPLACE FUNCTION devv5.GetSpreadSheet (url text)
RETURNS SETOF record
AS
$BODY$
  '''
  The function allows you to get a standard Google spreadsheet as a sql query:
  SELECT * FROM devv5.GetSpreadSheet (spreadsheet_url) AS (id int4, column1_name column1_type, column2_name column2_type [, ...]);
  
  Since these tables can have a different number of columns and different names, it is necessary to specify the all output fields and their type in each specific case; at the same time, the names of the columns in the spreadsheet and at the output of the function must match.
  The function also displays the pseudo-column "id" with sequential row numbering (starting from the second row, because the first is the table header).
  
  Example
  Let's say we have a spreadsheet https://docs.google.com/spreadsheets/d/1dJqEfmquPioOKPTKbTUmhCM1v12PYiB79gIx9baH6wM/edit#gid=0 with the following columns:
  source_description	source_code	cnt	unit	percentile_5	percentile_95	flag	comment	target_concept_id	concept_code	concept_name	concept_class_id	standard_concept	invalid_reason	domain_id	target_vocabulary_id
  then we need to write the following query:
  SELECT * FROM devv5.GetSpreadSheet('https://docs.google.com/spreadsheets/d/1dJqEfmquPioOKPTKbTUmhCM1v12PYiB79gIx9baH6wM/edit#gid=0')
  AS (
    id int4,
    source_description text,
    source_code text,
    cnt	int4,
    unit text,
    percentile_5 text,
    percentile_95 text,
    flag text,
    comment text,
    target_concept_id text,
    concept_code text,
    concept_name text,
    concept_class_id text,
    standard_concept text,
    invalid_reason text,
    domain_id text,
    target_vocabulary_id text
    );

  And of course, you can do whatever you need with this query - add WHERE conditions, wrap it in CREATE TABLE, etc. Moreover, you can even change the position of the columns, for example:
  SELECT * FROM devv5.GetSpreadSheet('https://docs.google.com/spreadsheets/d/1dJqEfmquPioOKPTKbTUmhCM1v12PYiB79gIx9baH6wM/edit#gid=0')
  AS (
    id int4,
    domain_id text,
    target_vocabulary_id text,
    source_description text,
    ...
    );
  
  Note: don't forget to give view permissions to the service email
  Note: since the spreadsheet request is in real time over HTTPS, do not use this function in joins, first create a local table, then work with it
  Note: the function only works with the first worksheet
  '''
  import gspread

  res = []
  credentials = eval(plpy.execute("SELECT var_value::json FROM config$ where var_name='gspread_credentials'")[0]['var_value'])
  gc = gspread.service_account_from_dict(credentials)
  sh = gc.open_by_url(url)
  #get first worksheet, all records, replace all empty cells with null
  res = sh.get_worksheet(0).get_all_records(default_blank=None)
  #add row number
  res = [{**{'id':id + 2}, **row} for id, row in enumerate(res)]
  
  return res
$BODY$
LANGUAGE 'plpython3u' STRICT;