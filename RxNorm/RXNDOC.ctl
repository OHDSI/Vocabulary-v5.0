options (direct=true, errors=0)
load data
infile 'RXNDOC.RRF' 
badfile 'RXNDOC.bad'
discardfile 'RXNDOC.dsc'
truncate
into table RXNDOC
fields terminated by '|'
trailing nullcols
(DOCKEY	char(50),
VALUE	char(1000),
TYPE	char(50),
EXPL	char(1000)
)
