CREATE OR REPLACE FUNCTION vocabulary_pack.py_git_wiki(wiki_url text, wiki_commit text, wiki_body text, wiki_login text, wiki_password text)
RETURNS text AS
$BODY$
  """
  A small script for publishing any text on the GitHub's Wiki.
  
  The script works as follows: it logs in with a login-password, like a browser, saving cookies in a special technical table (config$).
  At the first authorization, Github will send an email to the specified email address with a request to confirm the "device". In our case, this means calling the py_git_verifydevice script.
  After that the script is ready to work.
  
  Note: wiki_body should be in 'markdown' syntax. 
  
  Installation:
  insert into devv5.config$ values ('git_web_cookies','');
  insert into devv5.config$ values ('git_web_authenticity_token','');
  insert into devv5.config$ values ('git_credentials','{"git_login":"robot@e.mail","git_password":"password","git_repository":"OHDSI/Vocabulary-v5.0","git_token":"ghp_xxx","git_wiki_url":"https://github.com/OHDSI/Vocabulary-v5.0/wiki/Vocabulary-Statistics"}');
  
  Please change the values above to the correct ones. Note: git_token is not used in this script, since GitHub does not currently support working with WiKi via the API, but this parameter is used in other scripts.
  git_wiki_url must refer to the actual URL whose data the script will change (it must be prepared in advance).

  Example:
  
  DO $$
  DECLARE
    cGitLogin CONSTANT TEXT:= (SELECT var_value FROM devv5.config$ WHERE var_name='git_credentials')::json->>'git_login';
    cGitPassword CONSTANT TEXT:= (SELECT var_value FROM devv5.config$ WHERE var_name='git_credentials')::json->>'git_password';
    cGitWiKiURL CONSTANT TEXT := (SELECT var_value FROM devv5.config$ WHERE var_name='git_credentials')::json->>'git_wiki_url';
    cWiKiCommitText CONSTANT TEXT:= (SELECT 'v'||TO_CHAR(CURRENT_DATE,'yyyymmdd')||'_'||EXTRACT(epoch FROM NOW()::TIMESTAMP(0))::VARCHAR);
    cWiKiText TEXT;
    cRet_git TEXT;
  BEGIN
    cWiKiText:='<b>ROBOT TEST</b>';
    SELECT vocabulary_pack.py_git_wiki(cGitWiKiURL,cWiKiCommitText,cWiKiText,cGitLogin,cGitPassword) into cRet_git;
        
    IF cRet_git<>'OK' THEN
      RAISE EXCEPTION '%',cRet_git;
    END IF;
  END $$;
  
  Returns 'OK' if success.
  
  PS If you want to use a new account, please delete any old saved data: update devv5.config$ set var_value='' where var_name in ('git_web_cookies','git_web_authenticity_token');
  """
  
  import re, requests
  s = requests.session()
  
  #get saved cookies
  git_web_cookies = plpy.execute("SELECT var_value FROM devv5.config$ where var_name='git_web_cookies'")[0]['var_value']
  if (git_web_cookies): s.cookies.update(eval(git_web_cookies))
  
  #get the authenticity_token
  github=s.get('https://github.com/login').text
  
  if re.findall('<meta name="user-login" content="(.*?)">',github)[0] == '':
    #if we have no cookies or if they has been expired, then try to log in
    auth_token=re.findall('<input type="hidden" name="authenticity_token" value="(.*?)"',github)[0]
    timestamp=re.findall('<input type="hidden" name="timestamp" value="(.*?)"',github)[0]
    timestamp_secret=re.findall('<input type="hidden" name="timestamp_secret" value="(.*?)"',github)[0]
    
    #now we can log in
    data={
        'login':wiki_login,
        'password':wiki_password,
        'commit':'Sign+in',
        'webauthn-support':'unsupported',
        'webauthn-iuvpaa-support':'unsupported',
        'return_to':'https%3A%2F%2Fgithub.com%2Flogin',
        'allow_signup':'',
        'client_id':'',
        'integration':'',
        'required_field_662b':'',
        'timestamp':timestamp,
        'timestamp_secret':timestamp_secret,
        'authenticity_token':auth_token
    }
    github=s.post('https://github.com/session', data=data, timeout=30).text
    
    #store cookies after POST request, this is necessary for py_git_verifydevice to work properly (GitHub checks them))
    py_plan = plpy.prepare("UPDATE devv5.config$ SET var_value=$1 WHERE var_name='git_web_cookies'", ["text"])
    plpy.execute(py_plan, [s.cookies.get_dict()])
  
    #check authorization
    if not re.search('<meta name="user-login"',github) or re.findall('<meta name="user-login" content="(.*?)">',github)[0] == '':
        if re.search('<div id="device-verification-prompt"',github):
          #GitHub requires device verification
          auth_token=re.findall('<form.*?action="/sessions/verified-device".*?><input type="hidden" name="authenticity_token" value="(.*?)"',github)[0]
          #store the authentication_token, it is needed for the py_git_verifydevice functon
          py_plan = plpy.prepare("UPDATE devv5.config$ SET var_value=$1 WHERE var_name='git_web_authenticity_token'", ["text"])
          plpy.execute(py_plan, [auth_token])
          return 'Device verification required, please run SELECT vocabulary_pack.py_git_verifydevice(your_verification_code); with the code from e-mail'
        elif re.search('<div aria-atomic="true" role="alert" class="js-flash-alert">',github):
          #GitHub returns an error, invalid credentials?
          return re.findall('<div aria-atomic="true" role="alert" class="js-flash-alert">(.*?)</div>',github,re.DOTALL)[0].strip()
        else:
          #Unknown error, probably we were temporarily banned. try to clear cookies and run again
          plpy.execute("UPDATE devv5.config$ SET var_value='' WHERE var_name='git_web_cookies'")
          return 'Unknown error: '+github

  #store cookies
  py_plan = plpy.prepare("UPDATE devv5.config$ SET var_value=$1 WHERE var_name='git_web_cookies'", ["text"])
  plpy.execute(py_plan, [s.cookies.get_dict()])  
  
  #get the new authenticity_token
  github=s.get(wiki_url+'/_edit').text
  if not re.search('<meta name="user-login"',github):
    return wiki_url+' '+github
  auth_token=re.findall('<form name="gollum-editor".*?<input type="hidden" name="authenticity_token" value="(.*?)"',github)[0]
  timestamp=re.findall('<input type="hidden" name="timestamp" value="(.*?)"',github)[0]
  timestamp_secret=re.findall('<input type="hidden" name="timestamp_secret" value="(.*?)"',github)[0]
  
  #send the WiKi data
  #we will not change 'wiki[name]' because in this case we will change the entire URL
  data = {
      'wiki[format]':'markdown',
      'wiki[body]':wiki_body,
      'wiki[commit]':wiki_commit,
      '_method':'put',
      'required_field_c521':'',
      'timestamp':timestamp,
      'timestamp_secret':timestamp_secret,
      'authenticity_token':auth_token
  }
  
  github=s.post(wiki_url, data=data, timeout=30).text
  if not re.search('<meta name="user-login"',github):
      return "Can't send the WiKi data: "+github
  
  return 'OK'
$BODY$
LANGUAGE 'plpython3u' STRICT;

REVOKE EXECUTE ON FUNCTION vocabulary_pack.py_git_wiki FROM PUBLIC, role_read_only;