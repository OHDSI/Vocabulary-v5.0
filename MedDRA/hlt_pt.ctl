-- This is the Control file for loading the MedDRA - hlt_pref_comp table

LOAD        DATA
INFILE      'hlt_pt.asc'
BADFILE     'hlt_pt.bad'
DISCARDFILE 'hlt_pt.dsc'
TRUNCATE
INTO TABLE hlt_pref_comp
FIELDS TERMINATED BY  "$"
TRAILING NULLCOLS
(
 hlt_code,
 pt_code,
 FILLER1           FILLER    CHAR(1)
)

