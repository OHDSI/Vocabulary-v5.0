--A small script for publishing any text on the GitHub's Wiki
--Returns 'OK' if success
CREATE OR REPLACE FUNCTION vocabulary_pack.py_git_wiki(git_repo text, wiki_title text, wiki_body text, wiki_login text, wiki_password text)
RETURNS text AS
$BODY$
    import re, requests
    s = requests.session()
    
    #get the authenticity_token
    github=s.get('https://github.com/login').text
    auth_token=re.findall('<input type="hidden" name="authenticity_token" value="(.*?)"',github)[0]

    #now we can log in
    data={
        'login': wiki_login,
        'password': wiki_password,
        'commit' : 'Sign+in',
        'authenticity_token' : auth_token
    }

    github_post=s.post('https://github.com/session', data=data, timeout=30).text

    #if error return full HTML-page
    if re.findall('<meta.*?name="dimension1" content="(.*?)">',github_post)[0] != 'Logged In':
        return github_post

    #get the new authenticity_token
    github=s.get(git_repo+'/_new').text
    auth_token=re.findall('<form name="gollum-editor".*?<input type="hidden" name="authenticity_token" value="(.*?)"',github)[0]
    
    #send the WiKi data
    data = {
        'wiki[name]': wiki_title,
        'wiki[format]': 'markdown',
        'wiki[body]' : wiki_body,
        'wiki[commit]': 'Automation notification service',
        'authenticity_token' : auth_token
    }

    github_post=s.post(git_repo, data=data, timeout=30).text
    
    #if error return full HTML-page
    if re.findall('<div id="start-of-content" class="show-on-focus"></div>.*?<div id="js-flash-container">(.*?)</div>',github_post,re.DOTALL)[0].strip() != '':
        return github_post
    
    return 'OK'
$BODY$
LANGUAGE 'plpythonu'
SECURITY INVOKER;