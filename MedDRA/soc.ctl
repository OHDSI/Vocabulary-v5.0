-- This is the Control file for loading the MedDRA - soc_term table

LOAD        DATA
INFILE      'soc.asc'
BADFILE     'soc.bad'
DISCARDFILE 'soc.dsc'
TRUNCATE
INTO TABLE soc_term
FIELDS TERMINATED BY  "$"
TRAILING NULLCOLS
(
 soc_code,
 soc_name,
 soc_abbrev,
 soc_whoart_code,
 soc_harts_code,
 soc_costart_sym,
 soc_icd9_code,
 soc_icd9cm_code,
 soc_icd10_code,
 soc_jart_code,
 FILLER1           	FILLER    CHAR(1)
)

