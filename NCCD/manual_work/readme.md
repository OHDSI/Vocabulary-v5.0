Manual content processing:

1. Download the source_file with additional manual mapping from https://drive.google.com/file/d/1Oav9OFmtRkB-TFj2H9p_QQBgXpWvEU0a/view?usp=sharing
2. Run create_manual_tables.sql
3. Extract the nccd_manual.csv file into the nccd_manual table
4. Run manual_stage_tables.sql

**csv format:**
* delimiter: ','
* encoding: 'UTF8'
* header: ON
* decimal symbol: '.'
* quote escape: NONE
* quote always: TRUE
* NULL string: empty
