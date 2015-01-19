options (direct=true, errors=0)
load data
infile 'RXNCUICHANGES.RRF' 
badfile 'RXNCUICHANGES.bad'
discardfile 'RXNCUICHANGES.dsc'
truncate
into table RXNCUICHANGES
fields terminated by '|'
trailing nullcols
(
   RXAUI char(8),
   CODE char(50),
   SAB  char(20),
   TTY  char(20),
   STR  char(3000),
   OLD_RXCUI char(8),
   NEW_RXCUI char(8)
)
