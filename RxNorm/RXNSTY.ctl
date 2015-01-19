options (direct=true, errors=0)
load data
infile 'RXNSTY.RRF' 
badfile 'RXNSTY.bad'
discardfile 'RXNSTY.dsc'
truncate
into table RXNSTY
fields terminated by '|'
trailing nullcols
(RXCUI	char(8),
TUI	char(4),
STN	char(100),
STY	char(50),
ATUI	char(10),
CVF	char(50)
)
