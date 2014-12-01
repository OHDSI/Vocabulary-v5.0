options (direct=true, errors=0)
load data
infile 'RXNATOMARCHIVE.RRF' 
badfile 'RXNATOMARCHIVE.bad'
discardfile 'RXNATOMARCHIVE.dsc'
truncate
into table RXNATOMARCHIVE
fields terminated by '|'
trailing nullcols(
   rxaui char(8),
   aui char(10),
   str char(4000),
   archive_timestamp char(280),
   created_timestamp char(280),
   updated_timestamp char(280),
   code char(50),
   is_brand char(1),
   lat char(3),
   last_released char(30),
   saui char(50),
   vsab char(40),
   rxcui char(8),
   sab char(20),
   tty char(20),
   merged_to_rxcui char(8)
   )
