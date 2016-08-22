options (direct=true, errors=0)
load data
infile 'icd10pcs_codes.txt'
truncate
into table ICD10PCS
(
	CONCEPT_CODE position(1:7),
	CONCEPT_NAME CHAR(1000) "TRIM(:CONCEPT_NAME)"
)