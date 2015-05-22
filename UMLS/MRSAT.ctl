options (direct=true, errors=0)
load data
infile 'MRSAT.RRF' 
badfile 'MRSAT.bad'
discardfile 'MRSAT.dsc'
truncate
into table MRSAT
fields terminated by '|'
trailing nullcols(
 CUI CHAR,
  LUI CHAR,
  SUI CHAR,
  METAUI CHAR,
  STYPE CHAR,
  CODE CHAR,
  ATUI CHAR,
  SATUI CHAR,
  ATN CHAR,
  SAB CHAR,
  ATV CHAR(500000),
  SUPPRESS  CHAR,
  CVF CHAR
)
