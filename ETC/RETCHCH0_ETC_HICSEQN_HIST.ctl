options (direct=true, errors=0)
load data
infile 'RETCHCH0_ETC_HICSEQN_HIST.txt' "str '\r\n'"
truncate
into table RETCHCH0_ETC_HICSEQN_HIST
fields terminated by '|'
trailing nullcols
(
	HIC_SEQN		 CHAR(6),	
	ETC_ID     CHAR(8),	
	ETC_REVISION_SEQNO		 CHAR(5),	
	ETC_CHANGE_TYPE_CODE	 CHAR(1),	
	ETC_EFFECTIVE_DATE	 date 'YYYYMMDD'
)