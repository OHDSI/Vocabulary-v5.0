options (direct=true, errors=0, SKIP=1)
load data
characterset UTF8 length semantics char
infile 'LOINC_248_MULTI-AXIAL_HIERARCHY.CSV'
truncate
into table LOINC_HIERARCHY
fields terminated by ','
trailing nullcols
(
PATH_TO_ROOT CHAR(8256) "REPLACE(:PATH_TO_ROOT, '\"', '')"     , 
SEQUENCE CHAR(8256) "REPLACE(:SEQUENCE , '\"', '')"    , 
IMMEDIATE_PARENT CHAR(8256) "REPLACE(:IMMEDIATE_PARENT , '\"', '')"    , 
CODE CHAR(8256) "REPLACE(:CODE , '\"', '')"    , 
CODE_TEXT CHAR(8256) "REPLACE(:CODE_TEXT , '\"', '')"    
)