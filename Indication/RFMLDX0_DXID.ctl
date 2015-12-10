options (direct=true, errors=0)
load data
infile 'RFMLDX0_DXID.txt' "str '\r\n'"
truncate
into table RFMLDX0_DXID
fields terminated by '|'
trailing nullcols
(
	DXID	 CHAR(8),	
	DXID_DESC56      CHAR(56),	
	DXID_DESC100     CHAR(100),	
	DXID_STATUS	 CHAR(1),	
	FDBDX	 CHAR(9),
	DXID_DISEASE_DURATION_CD	 CHAR(1)
)