options (direct=true, errors=0)
load data
infile 'RINDMGC0_INDCTS_GCNSEQNO_LINK.txt' "str '\r\n'"
truncate
into table RINDMGC0_INDCTS_GCNSEQNO_LINK
fields terminated by '|'
trailing nullcols
(
	GCN_SEQNO		 CHAR(6),	
	INDCTS     CHAR(5)
)