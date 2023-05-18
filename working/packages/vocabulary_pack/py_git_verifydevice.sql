CREATE OR REPLACE FUNCTION vocabulary_pack.py_git_verifydevice(verification_code text)
RETURNS text AS
$BODY$
  """
  This script is meant to be used with py_git_wiki when Github asks for the first credential check.
  Github will send an email with the code to use in this function.
  
  Usage: SELECT vocabulary_pack.py_git_verifydevice('XXXXXX');
  
  Returns 'OK' if success.
  """
  
  import re, requests
  s = requests.session()
  
  #get saved cookies and authenticity_token
  git_web_cookies = plpy.execute("SELECT var_value FROM devv5.config$ where var_name='git_web_cookies'")[0]['var_value']
  auth_token = plpy.execute("SELECT var_value FROM devv5.config$ where var_name='git_web_authenticity_token'")[0]['var_value']
  
  #apply cookies
  if (git_web_cookies): s.cookies.update(eval(git_web_cookies))
  
  #verify our 'device'
  data={
      'otp': verification_code,
      'authenticity_token' : auth_token
  }

  github=s.post('https://github.com/sessions/verified-device', data=data, timeout=30).text

  #check authorization
  if not re.search('<meta name="user-login"',github):
    if re.search('<h1>What&#8253;</h1>',github):
      return re.findall('<h1>What&#8253;</h1>.*?<p>(.*?)</p>',github,re.DOTALL)[0].strip()
    else:
      return 'Unknown error: '+github
  
  return 'OK'
$BODY$
LANGUAGE 'plpython3u' STRICT;

REVOKE EXECUTE ON FUNCTION vocabulary_pack.py_git_verifydevice FROM PUBLIC, role_read_only;