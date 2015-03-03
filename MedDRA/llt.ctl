-- This is the Control file for loading the MedDRA - low_level_term table

LOAD        DATA
INFILE      'llt.asc'
BADFILE     'llt.bad'
DISCARDFILE 'llt.dsc'
TRUNCATE
INTO TABLE low_level_term
FIELDS TERMINATED BY  "$"
TRAILING NULLCOLS
(
 llt_code,
 llt_name,
 pt_code,
 llt_whoart_code,
 llt_harts_code,
 llt_costart_sym,
 llt_icd9_code,
 llt_icd9cm_code,
 llt_icd10_code,
 llt_currency,
 llt_jart_code,
 FILLER1           	FILLER    CHAR(1)
)

