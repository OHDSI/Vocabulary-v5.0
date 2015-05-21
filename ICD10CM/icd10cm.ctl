OPTIONS (errors=0, direct=true)
LOAD DATA 
INFILE 'icd10cm_order_2015.txt'
TRUNCATE
INTO TABLE icd10cm_table
(
	CODE position(7:14), 
	CODE_TYPE position(15:16),
	SHORT_NAME position(17:77),
	LONG_NAME CHAR(1000)
)