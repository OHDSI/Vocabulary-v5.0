CREATE OR REPLACE FUNCTION vocabulary_download.get_umls_ticket(url_auth text, apikey text) RETURNS text
AS
$BODY$
DECLARE
	--UMLS API Technical Documentation: https://documentation.uts.nlm.nih.gov/rest/authentication.html
	pContent text;
	pTGT_URL text;
	pST text;
BEGIN
	--get TGT (Ticket-Granting Ticket)
	select http_content into pContent from vocabulary_download.py_http_post(url=>url_auth,allow_redirects=>true, params=>'apikey='||devv5.urlencode(apikey));
	pTGT_URL:=substring(pContent,'<form action="(.+?)" method="POST">');
	if pTGT_URL is null then
		raise exception 'No valid TGT found. Wrong apikey?';
	end if;
	--get Service Ticket
	select http_content into pST from vocabulary_download.py_http_post(url=>pTGT_URL,allow_redirects=>true, params=>'service=http%3A%2F%2Fumlsks.nlm.nih.gov');
	return pST;
END;
$BODY$
LANGUAGE 'plpgsql'
SECURITY DEFINER;