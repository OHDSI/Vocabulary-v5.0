CREATE OR REPLACE FUNCTION vocabulary_download.py_http_get(url text, cookies text default null, allow_redirects boolean default false, out http_headers json, out http_content text)
AS
$BODY$
  import json, requests, urllib3
  urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
  headers = {'User-Agent':'Mozilla/5.0','Accept-Language': 'en-US;q=0.5,en;q=0.3'}
  c=json.loads(cookies) if cookies else None
  http=requests.get(url,headers=headers,cookies=c,timeout=10,allow_redirects=allow_redirects,verify=False)
  return json.dumps(dict(http.headers)), http.text
$BODY$
LANGUAGE 'plpythonu'
SECURITY DEFINER;

CREATE OR REPLACE FUNCTION vocabulary_download.py_http_post(url text, params text, cookies text default null, allow_redirects boolean default false, content_type text default 'application/x-www-form-urlencoded', out http_headers json, out http_content text)
AS
$BODY$
  import json, requests
  headers = {'User-Agent':'Mozilla/5.0','Accept-Language': 'en-US;q=0.5,en;q=0.3','Content-type': content_type}
  c=json.loads(cookies) if cookies else None
  http=requests.post(url,headers=headers,cookies=c,data=params,timeout=10,allow_redirects=allow_redirects)
  return json.dumps(dict(http.headers)), http.text
$BODY$
LANGUAGE 'plpythonu'
SECURITY DEFINER;