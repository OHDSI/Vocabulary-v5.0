CREATE OR REPLACE FUNCTION apigrabber.getrxnormbystatus (
  rxstatus varchar
)
RETURNS TABLE (
  rxcode varchar
) AS
$body$
BEGIN
  perform http_set_curlopt('CURLOPT_TIMEOUT', '30');
  set local http.timeout_msec TO 30000;
  return query 
  select 
  unnest(xpath('/rxcuihistorydata/rxcuiList/rxcuis/text()', h.content::xml))::varchar
  from devv5.http_get('https://rxnav.nlm.nih.gov/REST/rxcuihistory/status.xml?type='||rxstatus) h;
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY DEFINER
COST 100 ROWS 1000;