options (direct=true, errors=0)
load data
infile 'OPCS.txt' 
truncate
into table OPCS
fields terminated by ';' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
	CUI char(50),
	TERM char (150)
)
