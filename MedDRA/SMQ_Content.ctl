-- This is the Control file for loading the MedDRA - smq_content table

LOAD        DATA
INFILE      'smq_content.asc'
BADFILE     'smq_content.bad'
DISCARDFILE 'smq_content.dsc'
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

