-- This is the Control file for loading the MedDRA - pref_term table

LOAD        DATA
INFILE      'pt.asc'
BADFILE     'pt.bad'
DISCARDFILE 'pt.dsc'
TRUNCATE
INTO TABLE pref_term
FIELDS TERMINATED BY  "$"
TRAILING NULLCOLS
(
 pt_code,
 pt_name,
 null_field,
 pt_soc_code,
 pt_whoart_code,
 pt_harts_code,
 pt_costart_sym,
 pt_icd9_code,
 pt_icd9cm_code,
 pt_icd10_code,
 pt_jart_code,
 FILLER1           	FILLER    CHAR(1)
)

