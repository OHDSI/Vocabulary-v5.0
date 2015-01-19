options (direct=true, errors=0)
load data
infile 'RXNREL.RRF' 
badfile 'RXNREL.bad'
discardfile 'RXNREL.dsc'
truncate
into table RXNREL
fields terminated by '|'
trailing nullcols
(
   RXCUI1	char(8),
   RXAUI1	char(8),
   STYPE1	char(50),
   REL	char(4),
   RXCUI2	char(8),
   RXAUI2	char(8),
   STYPE2	char(50),
   RELA	char(100),
   RUI	char(10),
   SRUI	char(50),
   SAB	char(20),
   SL	char(20),
   RG	char(10),
   DIR	char(1),
   SUPPRESS	char(1),
   CVF	char(50)
)
