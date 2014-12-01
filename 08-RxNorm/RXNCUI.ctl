options (direct=true, errors=0)
load data
infile 'RXNCUI.RRF' 
badfile 'RXNCUI.bad'
discardfile 'RXNCUI.dsc'
truncate
into table RXNCUI
fields terminated by '|'
trailing nullcols
(
cui1        char(8),
 ver_start   char(40),
 ver_end     char(40),
 cardinality char(8),
 cui2        char(8)  
) 
