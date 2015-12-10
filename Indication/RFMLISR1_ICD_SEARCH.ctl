options (direct=true, errors=0)
load data
infile 'RFMLISR1_ICD_SEARCH.txt' "str '\r\n'"
truncate
into table RFMLISR1_ICD_SEARCH
fields terminated by '|'
trailing nullcols
(
	SEARCH_ICD_CD	 CHAR(10),	
	ICD_CD_TYPE      CHAR(2),	
	RELATED_DXID     CHAR(8),	
	FML_CLIN_CODE	 CHAR(2),	
	FML_NAV_CODE	 CHAR(2)
)