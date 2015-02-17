-- This is the Control file for loading the MedDRA - smq_content table

LOAD        DATA
INFILE      'SMQ_Content.asc'
BADFILE     'SMQ_Content.bad'
DISCARDFILE 'SMQ_Content.dsc'
APPEND
INTO TABLE smq_content
FIELDS TERMINATED BY  "$"
TRAILING NULLCOLS
(
 SMQ_code,
 Term_code,
 Term_level,
 Term_scope,
 Term_category,
 Term_weight,
 Term_status,
 Term_addition_version,
 Term_last_modified_version,
 FILLER1           	FILLER    CHAR(1)
)

