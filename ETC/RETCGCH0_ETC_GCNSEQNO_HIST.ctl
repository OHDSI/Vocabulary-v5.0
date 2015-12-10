options (direct=true, errors=0)
load data
infile 'RETCGCH0_ETC_GCNSEQNO_HIST.txt' "str '\r\n'"
truncate
into table RETCGCH0_ETC_GCNSEQNO_HIST
fields terminated by '|'
trailing nullcols
(
	GCN_SEQNO		 CHAR(6),	
	ETC_ID     CHAR(8),	
	ETC_REVISION_SEQNO		 CHAR(5),	
	ETC_COMMON_USE_IND	 CHAR(1),	
	ETC_DEFAULT_USE_IND	 CHAR(1),	
	ETC_CHANGE_TYPE_CODE   	 CHAR(1),	
	ETC_EFFECTIVE_DATE	 date 'YYYYMMDD'
)