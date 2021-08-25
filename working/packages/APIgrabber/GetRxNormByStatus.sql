CREATE OR REPLACE FUNCTION apigrabber.getrxnormbystatus (
  rxstatus varchar
)
RETURNS TABLE (
  rxcode text
) AS
$body$
BEGIN
  return query
  select minConcept->>'rxcui' from
  (select http_content::json#>'{minConceptGroup}' minConceptGroup  from vocabulary_download.py_http_get(url=>'https://rxnav.nlm.nih.gov/REST/allstatus.json?status='||rxstatus,allow_redirects=>true)) concepts
  cross join json_array_elements(concepts.minConceptGroup#>'{minConcept}') minConcept;
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY DEFINER
COST 100 ROWS 1000;