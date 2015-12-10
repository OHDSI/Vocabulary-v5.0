options (direct=true, errors=0)
load data
infile 'RFMLDRH0_DXID_HIST.txt' "str '\r\n'"
truncate
into table RFMLDRH0_DXID_HIST
fields terminated by '|'
trailing nullcols
(
	FMLPRVDXID	 	CHAR(8),	
	FMLREPDXID      CHAR(8),	
	FMLDXREPDT      DATE 'YYYYMMDD'
)