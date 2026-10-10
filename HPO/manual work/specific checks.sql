--check source ETL quality after LS
-- should return 0 to proof that HPO scraping was sufficient (UMLS-distributive as reference)
SELECT count(*)
from sources.mrconso
where sab='HPO'
and regexp_replace(code,':','_') NOT IN (SELECT concept_code from concept_stage);

