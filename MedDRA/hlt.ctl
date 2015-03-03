-- This is the Control file for loading the MedDRA - hlt_pref_term table

LOAD        DATA
INFILE      'hlt.asc'
BADFILE     'hlt.bad'
DISCARDFILE 'hlt.dsc'
TRUNCATE
INTO TABLE hlt_pref_term
FIELDS TERMINATED BY  "$" OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
 hlt_code,
 hlt_name,
 hlt_whoart_code,
 hlt_harts_code,
 hlt_costart_sym,
 hlt_icd9_code,
 hlt_icd9cm_code,
 hlt_icd10_code,
 hlt_jart_code,
 FILLER1        FILLER    CHAR(1)
)

