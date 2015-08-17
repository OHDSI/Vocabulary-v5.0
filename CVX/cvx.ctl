options (direct=true, errors=0)
LOAD DATA
INFILE cvx.txt "str '\r\n'"
INTO TABLE CVX
TRUNCATE
FIELDS TERMINATED BY '|'
TRAILING NULLCOLS
(
  cvx_code char(100) "TRIM(:cvx_code)",
  short_description char(4000),
  full_vaccine_name char(4000),
  notes FILLER char(4000),
  vaccine_status char(100),
  nonvaccine char(100),
  last_updated_date date 'YYYY/MM/DD'
)
