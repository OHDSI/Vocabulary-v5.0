options (direct=true, errors=0)
load data
infile 'RINDMMA2_INDCTS_MSTR.txt' "str '\r\n'"
truncate
into table RINDMMA2_INDCTS_MSTR
fields terminated by '|'
trailing nullcols
(
	INDCTS		 CHAR(5),	
	INDCTS_SN     CHAR(2),	
	INDCTS_LBL		 CHAR(1),	
	FDBDX	 CHAR(9),	
	DXID	 CHAR(8),
	PROXY_IND	 CHAR(1),
	PRED_CODE	 CHAR(1)
)