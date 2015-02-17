-- This is the Control file for loading the MedDRA - soc_hlgt_comp table

LOAD        DATA
INFILE      'soc_hlgt.asc'
BADFILE     'soc_hlgt.bad'
DISCARDFILE 'soc_hlgt.dsc'
APPEND
INTO TABLE soc_hlgt_comp
FIELDS TERMINATED BY  "$"
TRAILING NULLCOLS
(
 soc_code,
 hlgt_code,
 FILLER1           	FILLER    CHAR(1)
)

