CREATE OR REPLACE FUNCTION sources.http_json(url text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  _headers json;
  _body    text;
BEGIN
  -- cookies=NULL, allow_redirects=false
  SELECT http_headers, http_content
    INTO _headers, _body
  FROM sources.py_http_get(url, NULL, false);

  -- If API will provide not a JSON — will brake with cast problem, useful for debug
  RETURN _body::jsonb;
END $function$;

CREATE OR REPLACE FUNCTION sources.py_http_get(url text, cookies text DEFAULT NULL::text, allow_redirects boolean DEFAULT false, OUT http_headers json, OUT http_content text)
 RETURNS record
 LANGUAGE plpython3u
 PARALLEL SAFE
AS $function$
import json, requests, urllib3, time, plpy
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Base Headers
headers = {
    'User-Agent': 'Mozilla/5.0',
    'Accept-Language': 'en-US;q=0.5,en;q=0.3'
}

# take token from current_setting('ocl.token')
token = None
try:
    res = plpy.execute("SELECT current_setting('ocl.token', true) AS t", 1)
    if res and res[0]['t']:
        token = res[0]['t']
except Exception:
    token = None

if token:
    headers['Authorization'] = f"Token {token}"

# cookies as JSON-dict
c = json.loads(cookies) if cookies else None

retries = 3
delay = 5  # seconds between retries
last_exc = None

for i in range(retries):
    try:
        http = requests.get(
            url,
            headers=headers,
            cookies=c,
            timeout=60,
            allow_redirects=allow_redirects,
            verify=False
        )
        return json.dumps(dict(http.headers)), http.text
    except (requests.exceptions.ReadTimeout,
            requests.exceptions.ConnectionError) as e:
        last_exc = e
        time.sleep(delay)

# if all try failed - return last exeption
raise last_exc
$function$
;
