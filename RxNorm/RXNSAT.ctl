options (direct=true, errors=0)
UNRECOVERABLE
load data 
infile 'RXNSAT.RRF' 
badfile 'RXNSAT.bad'
discardfile 'RXNSAT.dsc'
truncate
into table RXNSAT
fields terminated by '|'
trailing nullcols
(RXCUI	char(8),
LUI	char(8),
SUI	char(8),
RXAUI	char(9),
STYPE	char(50),
CODE	char(50),
ATUI	char(11),
SATUI	char(50),
ATN	char(1000),
SAB	char(20),
ATV	char(4000),
SUPPRESS	char(1),
CVF	char(50)
)
