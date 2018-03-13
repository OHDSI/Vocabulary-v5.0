options (direct=true, errors=0)
load data
infile 'icd10pcs.txt'
truncate
into table ICD10PCS
(
	CONCEPT_CODE position(7:14),
	CONCEPT_NAME position(78:300) "TRIM(:CONCEPT_NAME)"
)