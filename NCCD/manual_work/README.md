Manual content processing:

1. Download the source_file from https://drive.google.com/file/d/1uD-LuaBeQlVV5Qjau64vvX1pu_-B0b-e/view?usp=sharing
2. Run create_source_tables.sql
3. Extract the nccd_full_done.csv file into the nccd_full_done table
4. Download the source_file with additional manual mapping from https://drive.google.com/file/d/1QceKSf6X78zWvN-PWgEHCMpqdkgnmWWG/view?usp=sharing
5. Run create_manual_tables.sql
6. Extract the nccd_manual.csv file into the nccd_manual table
7. Run manual_stage_tables.sql

**csv format:**
* delimiter: ','
* encoding: 'UTF8'
* header: ON
* decimal symbol: '.'
* quote escape: NONE
* quote always: TRUE
* NULL string: empty
