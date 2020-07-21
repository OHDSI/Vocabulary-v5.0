CREATE OR REPLACE FUNCTION apigrabber.getrxnormbystatus (
  rxstatus varchar
)
RETURNS TABLE (
  rxcode varchar
) AS
$body$
BEGIN
  return query 
  select 
  unnest(xpath('/rxcuihistorydata/rxcuiList/rxcuis/text()', h.http_content::xml))::varchar
  from vocabulary_download.py_http_get(url=>'https://rxnav.nlm.nih.gov/REST/rxcuihistory/status.xml?type='||rxstatus,allow_redirects=>true) h;
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY DEFINER
COST 100 ROWS 1000;