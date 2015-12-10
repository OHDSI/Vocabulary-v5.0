options (direct=true, errors=0)
load data
infile 'RDDCMGC0_CONTRA_GCNSEQNO_LINK.txt' "str '\r\n'"
truncate
into table RDDCMGC0_CONTRA_GCNSEQNO_LINK
fields terminated by '|'
trailing nullcols
(
	GCN_SEQNO		 CHAR(6),	
	DDXCN     CHAR(5)
)