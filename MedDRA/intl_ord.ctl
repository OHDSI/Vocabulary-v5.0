-- This is the Control file for loading the MedDRA - soc_intl_order table

LOAD        DATA
INFILE      'intl_ord.asc'
BADFILE     'intl_ord.bad'
DISCARDFILE 'intl_ord.dsc'
TRUNCATE
INTO TABLE soc_intl_order
FIELDS TERMINATED BY  "$"
TRAILING NULLCOLS
(
 intl_ord_code,
 soc_code,
 FILLER1           	FILLER    CHAR(1)
)

