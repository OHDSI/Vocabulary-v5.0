CREATE OR REPLACE FUNCTION vocabulary_download.py_http_umls(url_auth text, url_download text, user_name text, user_password text, out http_headers json, out http_content text)
AS
$BODY$
  import json, re, requests
  s = requests.session()
  
  umls=s.get(url_auth, timeout=30).text
  hidden_param=re.findall('name="execution" value="(.+?)"',umls)[0]
  
  data={
    'username': user_name,
    'password': user_password,
    '_eventId' : 'submit',
    'execution' : hidden_param
  }
  umls=s.post(url_auth, data=data, timeout=30).text
  umls=s.get(url_auth+'?service='+url_download,allow_redirects=False, timeout=30)
  umls=s.get(umls.headers['Location'],allow_redirects=False, timeout=30)

  return json.dumps(dict(umls.headers)), umls.text
$BODY$
LANGUAGE 'plpythonu'
SECURITY DEFINER;