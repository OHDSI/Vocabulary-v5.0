# Package for working with Google Sheets/Drive


### How to install
1. Prepare python modules: pip install gspread googletrans==3.1.0a0 gspread_dataframe pandas
2. Create a schema
```sql
CREATE SCHEMA google_pack AUTHORIZATION devv5;
GRANT USAGE ON SCHEMA google_pack TO role_read_only;
```

3. Run in devv5 all \*.sql

### Available functions

### Text translation
```sql
DO $_$
BEGIN
	PERFORM google_pack.GTranslate(
		pInputTable    =>'input_table', --the name of the input table with untranslated strings
		pInputField    =>'field_with_foreign_names', --the name of the field in that table containing the input rows
		pOutputField   =>'field_with_translated_names', --the name of the field in that table where to put the translation
		pDestLang      =>'en' --the language to translate the source text into (The value should be one of the language codes listed in https://py-googletrans.readthedocs.io/en/latest/#googletrans-languages (optional, default 'en'))
		pSrcLang       =>'auto' --the language of the source text (The value should be one of the language codes listed in https://py-googletrans.readthedocs.io/en/latest/#googletrans-languages (optional, if not specified, the system will attempt to identify the source language automatically, default 'auto'))
	);
END $_$;
```
NOTE: see also the description inside the function for more information and limitations

### Viewing Google Sheets in a specific folder on Google Drive
```sql
SELECT * FROM google_pack.ListAllSpreadSheetFiles('1B0KzHeET6vm...'); -- specify folder_id from the URL https://drive.google.com/drive/folders/_folder_id_
```
Note: don't forget to give view permissions to the service email

### Retrieving the contents of a specific sheet from a specified Google spreadsheet
```sql
SELECT * FROM google_pack.GetSpreadSheetByID('1URpwjK...','concept_synonym_manual',1) --specify spreadsheet_id, list title and the number of rows to skip (e.g. for header)
AS (
	--since the number of columns and their type are unknown in advance, you need to specify this as the output type manually. The field names must match the column names in the sheet
	worksheet_row_id INT4,
	synonym_name TEXT,
	concept_code TEXT,
	vocabulary_id TEXT,
	language_concept_id TEXT
);
```

You can also combine this function with the ListAllSpreadSheetFiles to get the summary content for sheets with the same name (and structure) for all Google Sheets in a folder
```sql
SELECT s.spreadsheet_id,
	s.modifiedtime,
	l.*
FROM google_pack.ListAllSpreadSheetFiles('1B0KzHe...') s
CROSS JOIN LATERAL(SELECT * FROM google_pack.GetSpreadSheetByID(s.spreadsheet_id, 'concept_manual', 1) AS (
	worksheet_row_id int4,
	concept_name TEXT,
	concept_code TEXT,
	vocabulary_id TEXT,
	domain_id TEXT,
	concept_class_id TEXT,
	standard_concept TEXT,
	valid_start_date TEXT,
	valid_end_date TEXT,
	invalid_reason TEXT
	)
) l;
```
Note: don't forget to give view permissions to the service email

### Creating a sheet from a table in specified Google spreadsheet
```sql
SELECT google_pack.SetSpreadSheet(
	'cde_manual_group', --table name or shemaname.tablename
	'1a3os1cjgIuji...', --spreadsheet ID
	'my export' -- the name (title) of the list to be created
);
```
Note: don't forget to give write permissions to the service email