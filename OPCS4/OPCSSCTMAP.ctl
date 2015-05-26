options (direct=true, errors=0)
load data
infile 'OPCSSCTMAP.txt' 
truncate
into table OPCSSCTMAP
fields terminated by ';' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
	SCUI char(5),
	STUI char (1) "TRIM(:STUI)",
	TCUI char (18),
	TTUI char (1) "TRIM(:TTUI)",
	MAPTYP char (1),
	ASSURED filler
)
