-- This is the Control file for loading MedDRA - hlgt_pref_term table

LOAD        DATA
INFILE      'hlgt.asc'
BADFILE     'hlgt.bad'
DISCARDFILE 'hlgt.dsc'
APPEND
INTO TABLE hlgt_pref_term
FIELDS TERMINATED BY  "$"
TRAILING NULLCOLS
(
hlgt_code,
hlgt_name,
hlgt_whoart_code,
hlgt_harts_code,
hlgt_costart_sym,
hlgt_icd9_code,
hlgt_icd9cm_code,
hlgt_icd10_code,
hlgt_jart_code,
 FILLER1        FILLER    CHAR(1)
)

