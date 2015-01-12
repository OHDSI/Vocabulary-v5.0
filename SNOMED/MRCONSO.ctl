options (direct=true, errors=0)
load data
infile 'MRCONSO.RRF' 
badfile 'MRCONSO.bad'
discardfile 'MRCONSO.dsc'
truncate
into table MRCONSO
fields terminated by '|'
trailing nullcols(
 CUI CHAR(8),
  LAT CHAR(3),
  TS  CHAR(1),
  LUI CHAR(10),
  STT CHAR(3),
  SUI CHAR(10),
  ISPREF CHAR(1),
  AUI CHAR(9),
  SAUI CHAR(50),
  SCUI CHAR(100),
  SDUI CHAR(100),
  SAB CHAR(40),
  TTY CHAR(40),
  CODE CHAR(100),
  STR CHAR(3000),
  SRL INTEGER external,
  SUPPRESS  CHAR(1),
  CVF INTEGER external
)