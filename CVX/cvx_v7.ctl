options (direct=true, errors=0, skip=4)
LOAD DATA
INFILE ValueSetConceptDetailResultSummary.txt
INTO TABLE CVX_DATES
APPEND
FIELDS TERMINATED BY X'09'
TRAILING NULLCOLS
(
  cvx_code char(100) "TRIM(:cvx_code)",
  concept_date date 'YYYYMMDD' "20120829"
)
