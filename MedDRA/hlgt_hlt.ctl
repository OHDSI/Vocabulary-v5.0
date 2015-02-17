-- This is the Control file for loading the MedDRA - hlgt_hlt_comp table

LOAD        DATA
INFILE      'hlgt_hlt.asc'
BADFILE     'hlgt_hlt.bad'
DISCARDFILE 'hlgt_hlt.dsc'
APPEND
INTO TABLE hlgt_hlt_comp
FIELDS TERMINATED BY  "$" OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
 hlgt_code,
 hlt_code,
 FILLER1        FILLER    CHAR(1)
)

