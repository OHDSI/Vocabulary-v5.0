options (direct=true, errors=0)
load data
infile 'nfc.txt'
truncate
into table nfc
fields terminated by X'09'
trailing nullcols
(
	CONCEPT_CODE	 CHAR(50),	
	CONCEPT_NAME	 CHAR(1000) "TRIM(REGEXP_REPLACE (:CONCEPT_NAME, '[[:space:]]+', ' '))"
)