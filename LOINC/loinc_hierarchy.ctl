options (direct=true, errors=0, SKIP=1)
load data
characterset UTF8 length semantics char
infile 'LOINC_MULTI-AXIAL_HIERARCHY.CSV'
truncate
into table LOINC_HIERARCHY
fields terminated by ','
OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
PATH_TO_ROOT CHAR(8256), 
SEQUENCE CHAR(8256), 
IMMEDIATE_PARENT, 
CODE CHAR(8256), 
CODE_TEXT CHAR(8256)
)