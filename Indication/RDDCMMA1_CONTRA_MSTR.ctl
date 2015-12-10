options (direct=true, errors=0)
load data
infile 'RDDCMMA1_CONTRA_MSTR.txt' "str '\r\n'"
truncate
into table RDDCMMA1_CONTRA_MSTR
fields terminated by '|'
trailing nullcols
(
	DDXCN		 CHAR(5),	
	DDXCN_SN     CHAR(2),	
	FDBDX		 CHAR(9),	
	DDXCN_SL	 CHAR(1),	
	DDXCN_REF	 CHAR(26),
	DXID	 	 CHAR(8)
)