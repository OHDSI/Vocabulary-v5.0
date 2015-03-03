-- This is the Control file for loading the MedDRA - smq_list table

LOAD        DATA
INFILE      'smq_list.asc'
BADFILE     'smq_list.bad'
DISCARDFILE 'smq_list.dsc'
TRUNCATE
INTO TABLE smq_list
FIELDS TERMINATED BY  "$"
TRAILING NULLCOLS
(
 SMQ_code,
 SMQ_name,
 SMQ_level,
 SMQ_description CHAR(31000) "SUBSTR(:SMQ_description, 1, 256)",
 SMQ_source CHAR(31000) "SUBSTR(:SMQ_source, 1, 256)",
 SMQ_note CHAR(31000) "SUBSTR(:SMQ_note, 1, 256)",
 MedDRA_version,
 Status,
 SMQ_Algorithm,
 FILLER1           	FILLER    CHAR(1)
)

