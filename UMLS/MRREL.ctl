options (direct=true, errors=0)
load data
infile 'MRREL.RRF' 
badfile 'MRREL.bad'
discardfile 'MRREL.dsc'
truncate
into table MRREL
fields terminated by '|'
trailing nullcols(
 CUI1 CHAR,
 AUI1 CHAR,
 STYPE1 CHAR,
 REL CHAR,
 CUI2 CHAR,
 AUI2 CHAR,
 STYPE2 CHAR,
 RELA CHAR,
 RUI CHAR,
 SRUI CHAR,
 SAB CHAR,
 SL CHAR,
 RG CHAR,
 DIR CHAR,
 SUPPRESS CHAR(1),
 CVF INTEGER external
)
