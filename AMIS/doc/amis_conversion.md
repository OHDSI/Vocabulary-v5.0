# AMIS conversion

## Prepare schema

1.  Setup standard vocabulary development schema by executing the following SQL script

https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/DevV5_DDL.sql

2.  Create additional to standard DDL tables

See `additional_ddl.sql`
Execute this SQL scirpt, ensure there are no errors.

3.  Load source data

* First prepare the source data. Open original file `data/AM-Liste.xlsx` and save it as "Tab Delimited Text".
Assign it the name "data/AM-Liste.txt"
Take note that original source file contains unallowed characters in column names, in particular the minus sign ("-").
Replace the "-" sign with underscore "_" in tab delimited source file (data/AM-Liste.txt).

* Create source table. Use `source_table.sql` script.

* Load data into `SOURCE_TABLE` using SQLWorkbenchJ Data Pumper tool. See the import script in `import_initial_data.txt`
  for reference.

* Create backup copy of `SOURCE_TABLE`

        CREATE TABLE SOURCE_TABLE_BKP AS (SELECT * FROM SOURCE_TABLE);

If there were no errors, you've done.


