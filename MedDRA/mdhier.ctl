-- This is the Control file for loading the MedDRA - md_hierarchy table

LOAD        DATA
INFILE      'mdhier.asc'
BADFILE     'mdhier.bad'
DISCARDFILE 'mdhier.dsc'
APPEND
INTO TABLE md_hierarchy
FIELDS TERMINATED BY  "$"
TRAILING NULLCOLS
(
 pt_code,
 hlt_code,
 hlgt_code,
 soc_code,
 pt_name,
 hlt_name,
 hlgt_name,
 soc_name,
 soc_abbrev,
 null_field,
 pt_soc_code,
 primary_soc_fg,
 FILLER1           	FILLER    CHAR(1)
)

