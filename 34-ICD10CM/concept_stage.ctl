OPTIONS (SKIP=1)
LOAD DATA
INFILE concept_stage.txt
INTO TABLE concept_stage
REPLACE
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
  concept_id,
  concept_name char,
  domain_id char,
  vocabulary_id char,
  concept_class_id char,
  standard_concept char,
  concept_code char,
  valid_start_date date "YYYYMMDD",
  valid_end_date date "YYYYMMDD",
  invalid_reason char
)
