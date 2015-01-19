options (direct=true, errors=0)
load data
infile 'RXNSAB.RRF' 
badfile 'RXNSAB.bad'
discardfile 'RXNSAB.dsc'
truncate
into table RXNSAB
fields terminated by '|'
trailing nullcols
(  
   VCUI	char(8),
   RCUI	char(8) ,
   VSAB	char(40) ,
   RSAB	char(20) ,
   SON	char(3000) ,
   SF	char(20) ,
   SVER	char(20),
   VSTART	char(10),
   VEND	char(10),
   IMETA	char(10) ,
   RMETA	char(10),
   SLC	char(1000),
   SCC	char(1000),
   SRL	integer external,
   TFR	integer external,
   CFR	integer external,
   CXTY	char(50),
   TTYL	char(300),
   ATNL	char(1000),
   LAT	char(3),
   CENC	char(20) ,
   CURVER	char(1) ,
   SABIN	char(1) ,
   SSN	char(3000) ,
   SCIT	char(4000)
) 
