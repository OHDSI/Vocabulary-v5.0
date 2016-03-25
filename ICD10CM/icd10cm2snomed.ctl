options (direct=true, errors=0, skip=1)
load data
infile 'icd10cm2snomed.txt'
truncate
into table icd10cm2snomed
fields terminated by '|' optionally enclosed by '"'
trailing nullcols
(
	SOURCE_CODE		 CHAR(50),	
	TARGET_CODE		 CHAR(50),	
	MAPPING_TYPE     CHAR(50)
)