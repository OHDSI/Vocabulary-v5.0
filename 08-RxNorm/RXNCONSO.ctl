options (direct=true, errors=0)
load data
infile 'RXNCONSO.RRF' 
badfile 'RXNCONSO.bad'
discardfile 'RXNCONSO.dsc'
truncate
into table RXNCONSO
fields terminated by '|'
trailing nullcols
(
   RXCUI	char(8),
   LAT	char(3),
   TS	char(1),
   LUI	char(8),
   STT	char(3),
   SUI	char(8),
   ISPREF	char(1),
   RXAUI	char(8),
   SAUI	char(50),
   SCUI	char(50),
   SDUI	char(50),
   SAB	char(20),
   TTY	char(20),
   CODE	char(50),
   STR	char(3000),
   SRL	integer external,
   SUPPRESS	char(1),
   CVF	char(50)
)
