options (direct=true, errors=0)
load data
infile 'RFMLSYN0_DXID_SYN.txt' "str '\r\n'"
truncate
into table RFMLSYN0_DXID_SYN
fields terminated by '|'
trailing nullcols
(
	DXID_SYNID	 CHAR(8),	
	DXID      CHAR(8),	
	DXID_SYN_NMTYP     CHAR(2),	
	DXID_SYN_DESC56	 CHAR(56),	
	DXID_SYN_DESC100	 CHAR(100),	
	DXID_SYN_STATUS	 CHAR(1)
)